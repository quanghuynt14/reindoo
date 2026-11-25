import Foundation
import Observation

/// « Giao tiếp » : la liste des histoires, et l'histoire ouverte, une carte par
/// écran comme le reel. On trie les répliques (girafe ou chacal), on reformule
/// les phrases chacal, et la dernière carte fait le bilan.
///
/// Les réponses restent sur l'appareil, dans `setting`, comme `memory` et
/// `recall` : le serveur n'a pas de route pour elles.
@MainActor
@Observable
public final class TalkViewModel: Introspectable {
    public struct State: Codable, Equatable, Sendable {
        public var title = ""
        public var intro = ""
        public var stories: [Row] = []
        /// L'histoire ouverte, par-dessus la liste.
        public var player: Player?
    }

    public struct Row: Codable, Equatable, Sendable, Identifiable {
        public var id: String
        public var title: String
        public var gloss: String
        public var cast: [Animal]
        public var scene: String?
        /// Le décor dessiné de l'histoire.
        public var motif: Motif { Motif(scene: scene) }
        /// « 4/6 justes », ou le nombre de répliques si l'histoire est neuve.
        public var score: String
        public var isDone: Bool
    }

    public struct Player: Codable, Equatable, Sendable {
        public var storyID: String
        public var title: String
        public var scene: String?
        public var motif: Motif { Motif(scene: scene) }
        public var cards: [Card]
        public var position = 0
        public var giraffeLabel: String
        public var jackalLabel: String
        public var sortHint: String
        public var continueHint: String
        public var closeLabel: String
        public var listenLabel: String
    }

    public struct Card: Codable, Equatable, Sendable, Identifiable {
        public enum Kind: String, Codable, Sendable { case narration, sort, rewrite, body, need, report }
        public enum Verdict: String, Codable, Sendable { case right, wrong }

        public var id: String
        public var kind: Kind
        /// Sur un récit : tous les personnages. Sur une réplique : celui qui parle.
        public var cast: [Animal]
        public var text: String
        public var gloss: String
        public var question: String?
        /// Ce que la réplique est vraiment. La vue ne le montre qu'après la réponse.
        public var voice: Voice?
        public var part: String?
        public var why: String
        public var choices: [Choice] = []
        /// Sur une carte « besoin » : la réplique du second personnage.
        public var reply: String? = nil
        public var replyGloss: String? = nil
        /// Sur une carte « corps » : l'expression entière, montrée après la réponse.
        public var complete: String? = nil
        /// La réponse. Une fois donnée, elle reste : on ne reprend pas un tour.
        public var sorted: Voice?
        public var picked: Int?
        public var verdict: Verdict?
        public var verdictLabel: String?
        public var report: Report?

        public var isAnswered: Bool { verdict != nil }
        public var asksAnswer: Bool { kind != .narration && kind != .report && verdict == nil }
        /// Une carte où l'on choisit parmi des propositions.
        public var hasChoices: Bool { kind == .rewrite || kind == .body || kind == .need }
    }

    public struct Choice: Codable, Equatable, Sendable {
        public var text: String
        public var gloss: String
        public var isRight: Bool
    }

    public struct Report: Codable, Equatable, Sendable {
        public struct Pile: Codable, Equatable, Sendable {
            public var label: String
            public var lines: [String]
        }
        public var title: String
        public var right: Pile
        public var wrong: Pile
        /// La troisième pile, et la plus importante : ce qu'on a évité.
        public var skipped: Pile
        public var note: String
        public var playAgain: String
    }

    public enum Action: Sendable {
        case appear
        /// Ouvrir une histoire. `review` : les répliques ratées.
        case open(String)
        case close
        case setPosition(Int)
        /// Trier la réplique. Sans identifiant : la carte à l'écran.
        case sort(String?, Voice)
        /// Choisir une reformulation.
        case choose(String?, Int)
        /// Rejouer l'histoire ouverte, réponses effacées de l'écran.
        case replay
    }

    public static let reviewID = "review"
    static let resultsKey = "talk.results"

    public private(set) var state = State()
    private let user: UserStore
    private let copy: Copy
    private let stories: [Story]

    public init(user: UserStore, copy: Copy, stories: [Story] = Story.all) {
        self.user = user
        self.copy = copy
        self.stories = stories
        state.title = copy.tabTalk
        state.intro = copy.talkIntro
    }

    public func send(_ action: Action) {
        switch action {
        case .appear:
            refreshRows()
        case .open(let id):
            open(id)
        case .close:
            state.player = nil
            refreshRows()
        case .setPosition(let position):
            guard var player = state.player, player.cards.indices.contains(position) else { return }
            player.position = position
            state.player = player
            refreshReport()
        case .sort(let id, let voice):
            answer(id) { card in
                guard card.kind == .sort, let truth = card.voice else { return nil }
                card.sorted = voice
                return voice == truth
            }
        case .choose(let id, let index):
            answer(id) { card in
                guard card.hasChoices, card.choices.indices.contains(index) else { return nil }
                card.picked = index
                return card.choices[index].isRight
            }
        case .replay:
            guard let id = state.player?.storyID else { return }
            open(id)
        }
    }

    // MARK: Les réponses

    /// Les dernières réponses, par réplique : `right` ou `wrong`.
    private func results() -> [String: Card.Verdict] {
        guard let text = try? user.setting(Self.resultsKey), let data = text.data(using: .utf8),
              let saved = try? JSONDecoder().decode([String: Card.Verdict].self, from: data) else { return [:] }
        return saved
    }

    private func save(_ id: String, _ verdict: Card.Verdict) {
        var saved = results()
        saved[id] = verdict
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        if let data = try? encoder.encode(saved), let text = String(data: data, encoding: .utf8) {
            try? user.setSetting(Self.resultsKey, text)
        }
    }

    /// Une réponse, une seule fois : `decide` rend `nil` si la carte n'en attend pas.
    private func answer(_ id: String?, decide: (inout Card) -> Bool?) {
        guard var player = state.player else { return }
        let index = id.flatMap { id in player.cards.firstIndex { $0.id == id } } ?? player.position
        guard player.cards.indices.contains(index), player.cards[index].asksAnswer else { return }
        var card = player.cards[index]
        guard let right = decide(&card) else { return }
        card.verdict = right ? .right : .wrong
        card.verdictLabel = right ? copy.rightAnswer : copy.wrongAnswer
        if let voice = card.voice, card.kind == .sort {
            card.verdictLabel = "\(card.verdictLabel ?? "") · \(copy.wasVoice(voice))"
        }
        player.cards[index] = card
        state.player = player
        save(card.id, card.verdict!)
        refreshReport()
    }

    // MARK: Les histoires

    private func open(_ id: String) {
        let beats: [(Story, Beat)]
        let title: String
        let scene: String?
        if id == Self.reviewID {
            let missed = results().filter { $0.value == .wrong }
            beats = stories.flatMap { story in story.questions.filter { missed[$0.id] != nil }.map { (story, $0) } }
            guard !beats.isEmpty else { return }
            title = copy.talkReview
            scene = "night-reef"
        } else {
            guard let story = stories.first(where: { $0.id == id }) else { return }
            beats = story.beats.map { (story, $0) }
            title = story.title
            scene = story.scene
        }
        var cards = beats.map { card($0.1, in: $0.0) }
        cards.append(Card(id: "\(id).report", kind: .report, cast: [], text: copy.storyEnd, gloss: "", why: ""))
        state.player = Player(
            storyID: id, title: title, scene: scene, cards: cards,
            giraffeLabel: copy.giraffe, jackalLabel: copy.jackal, sortHint: copy.sortHint,
            continueHint: copy.continueHint, closeLabel: copy.close, listenLabel: copy.listen
        )
        refreshReport()
    }

    func card(_ beat: Beat, in story: Story) -> Card {
        let speaker = beat.speaker.map { [story.cast[$0]] }
        switch beat.kind {
        case .narration:
            return Card(id: beat.id, kind: .narration, cast: story.cast, text: beat.text, gloss: beat.gloss, why: "")
        case .sort:
            return Card(
                id: beat.id, kind: .sort, cast: speaker ?? [], text: beat.text, gloss: beat.gloss,
                question: copy.sortQuestion, voice: beat.voice, part: beat.part.map(copy.part), why: beat.why
            )
        case .rewrite:
            return Card(
                id: beat.id, kind: .rewrite, cast: speaker ?? [], text: beat.text, gloss: beat.gloss,
                question: copy.rewriteQuestion, voice: .jackal, part: copy.part(.request), why: beat.why,
                choices: choices(beat)
            )
        case .body:
            return Card(
                id: beat.id, kind: .body, cast: [], text: beat.text, gloss: beat.gloss,
                question: copy.bodyQuestion, part: beat.label, why: beat.why, choices: choices(beat), complete: beat.complete
            )
        case .need:
            return Card(
                id: beat.id, kind: .need, cast: story.cast, text: beat.text, gloss: beat.gloss,
                question: copy.needQuestion, part: copy.part(.need), why: beat.why, choices: choices(beat),
                reply: beat.reply, replyGloss: beat.replyGloss
            )
        }
    }

    private func choices(_ beat: Beat) -> [Choice] {
        Self.arranged(beat).map { Choice(text: $0.text, gloss: $0.gloss, isRight: $0.isRight) }
    }

    /// Les reformulations dans un ordre qui tient à la réplique : la bonne
    /// n'est pas toujours à la même place, et l'ordre ne doit rien au hasard.
    static func arranged(_ beat: Beat) -> [Rewrite] {
        guard !beat.choices.isEmpty else { return [] }
        let shift = beat.id.unicodeScalars.reduce(0) { $0 + Int($1.value) } % beat.choices.count
        return Array(beat.choices[shift...] + beat.choices[..<shift])
    }

    /// Le bilan se tient à jour à chaque réponse : il est la dernière carte.
    private func refreshReport() {
        guard var player = state.player, let last = player.cards.indices.last else { return }
        let questions = player.cards.filter { $0.kind != .narration && $0.kind != .report }
        let lines: (Card.Verdict?) -> [String] = { verdict in
            questions.filter { $0.verdict == verdict }.map { $0.complete ?? $0.text }
        }
        player.cards[last].report = Report(
            title: copy.storyEnd,
            right: .init(label: copy.pileRight, lines: lines(.right)),
            wrong: .init(label: copy.pileWrong, lines: lines(.wrong)),
            skipped: .init(label: copy.pileSkipped, lines: lines(nil)),
            note: copy.skippedNote,
            playAgain: copy.playAgain
        )
        state.player = player
    }

    private func refreshRows() {
        let saved = results()
        var rows: [Row] = []
        let missed = stories.flatMap(\.questions).filter { saved[$0.id] == .wrong }.count
        if missed > 0 {
            rows.append(Row(
                id: Self.reviewID, title: copy.talkReview, gloss: "",
                cast: [.giraffe, .jackal], scene: "night-reef", score: copy.talkReviewCount(missed), isDone: false
            ))
        }
        for story in stories {
            let questions = story.questions
            let answered = questions.filter { saved[$0.id] != nil }
            let right = questions.filter { saved[$0.id] == .right }.count
            rows.append(Row(
                id: story.id, title: story.title, gloss: story.gloss,
                cast: story.cast, scene: story.scene,
                score: answered.isEmpty ? copy.talkLines(questions.count) : copy.talkScore(right, questions.count),
                isDone: answered.count == questions.count
            ))
        }
        state.stories = rows
    }

    // MARK: Introspection

    public var nodeName: String { state.player == nil ? "talk" : "story" }
    public func nodeState() throws -> Data { try Input.encode(state) }
    public var nodeActions: [(name: String, input: String)] {
        [("open", "{name}"), ("close", ""), ("setPosition", "{index}"),
         ("sort", "{name: giraffe|jackal}"), ("choose", "{index}"), ("replay", "")]
    }
    public var childNode: (any Introspectable)? { nil }

    public func perform(_ action: String, input: Data?) throws -> Bool {
        struct Index: Decodable { var index: Int }
        switch action {
        case "open": send(.open(try Input.decode(Input.Name.self, input, action: action, expected: "{name}").name))
        case "close": send(.close)
        case "replay": send(.replay)
        case "setPosition":
            send(.setPosition(try Input.decode(Index.self, input, action: action, expected: "{index}").index))
        case "choose":
            send(.choose(nil, try Input.decode(Index.self, input, action: action, expected: "{index}").index))
        case "sort":
            let name = try Input.decode(Input.Name.self, input, action: action, expected: "{name}").name
            guard let voice = Voice(rawValue: name) else {
                throw IntrospectionError.badInput(action: action, expected: "{name: giraffe|jackal}")
            }
            send(.sort(nil, voice))
        default: return false
        }
        return true
    }
}
