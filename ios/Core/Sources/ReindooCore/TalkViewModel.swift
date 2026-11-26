import Foundation
import Observation

/// « Giao tiếp » : les histoires rangées par intention, et l'histoire ouverte,
/// une carte par écran comme le reel.
///
/// Rien ici ne note. Une réponse à côté montre ce qu'il fallait entendre :
/// une réplique chacal se voit traduite en girafe, et la girafe montre le
/// français qui la fait parler ainsi. Un onglet qui enseigne à ne pas juger
/// ne juge pas celui qui s'y entraîne.
///
/// Les réponses restent sur l'appareil, dans `setting`, comme `memory` et
/// `recall` : le serveur n'a pas de route pour elles.
@MainActor
@Observable
public final class TalkViewModel: Introspectable {
    public struct State: Codable, Equatable, Sendable {
        public var title = ""
        public var intro = ""
        public var sections: [Section] = []
        /// L'histoire ouverte, par-dessus la liste.
        public var player: Player?
        /// Le mot ouvert dans le dictionnaire, par-dessus l'histoire.
        public var lookingUp: String?
    }

    /// Une intention et ses histoires. Sans titre : les lignes d'en haut.
    public struct Section: Codable, Equatable, Sendable, Identifiable {
        public var id: String
        public var title: String?
        /// Quand s'en servir, en une phrase.
        public var when: String?
        public var rows: [Row]
    }

    public struct Row: Codable, Equatable, Sendable, Identifiable {
        public var id: String
        public var title: String
        public var gloss: String
        public var cast: [Animal]
        public var scene: String?
        /// Le décor dessiné de l'histoire.
        public var motif: Motif { Motif(scene: scene) }
        /// Combien de répliques. Pas de score : on ne note pas.
        public var detail: String
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
        public var giraffeWouldSay: String
        public var giraffeFrench: String
        public var lookUpLabel: String
        public var writeLabel: String
        public var writePlaceholder: String
        public var keepLabel: String
        public var rereadLabel: String
        /// Les quatre questions pour relire sa phrase, dans l'ordre des temps.
        public var checks: [Check]
    }

    public struct Check: Codable, Equatable, Sendable {
        public var part: Part
        public var label: String
    }

    public struct Card: Codable, Equatable, Sendable, Identifiable {
        public enum Kind: String, Codable, Sendable { case narration, sort, rewrite, body, need, hint, report }
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
        /// Sur une réplique chacal : la même chose, dite par la girafe.
        public var translation: String? = nil
        /// Le français qui fait parler girafe, montré après la réponse.
        public var forms: [GiraffeForm] = []
        /// Un bouton qui ferme l'histoire, sur la dernière carte de l'accueil.
        public var done: String? = nil
        /// Sur une reformulation : on peut écrire la sienne.
        public var canWrite = false
        public var written: String? = nil
        /// Les temps qu'on a cochés en relisant sa phrase.
        public var checked: [Part] = []
        /// La réponse. Une fois donnée, elle reste : on ne reprend pas un tour.
        public var sorted: Voice?
        public var picked: Int?
        public var verdict: Verdict?
        public var verdictLabel: String?
        public var report: Report?

        public var isAnswered: Bool { verdict != nil }
        public var asksAnswer: Bool { kind != .narration && kind != .report && verdict == nil }
        /// Une carte où l'on choisit parmi des propositions.
        public var hasChoices: Bool { kind == .rewrite || kind == .body || kind == .need || kind == .hint }
    }

    public struct Choice: Codable, Equatable, Sendable {
        public var text: String
        public var gloss: String
        public var isRight: Bool
    }

    /// La dernière carte. Pas de note : ce qu'on a entendu, ce qu'on réentendra,
    /// ce qu'on a dit avec ses mots, et le français de la girafe rencontré.
    public struct Report: Codable, Equatable, Sendable {
        public struct Pile: Codable, Equatable, Sendable {
            public var label: String
            public var lines: [String]
        }
        public var title: String
        public var right: Pile
        public var wrong: Pile
        public var skipped: Pile
        public var own: Pile
        public var formsTitle: String
        public var forms: [GiraffeForm]
        public var playAgain: String
    }

    public enum Action: Sendable {
        case appear
        /// Ouvrir une histoire. `review` : les répliques à réentendre ;
        /// `welcome` : l'accueil ; `mix.<intention>` : un pêle-mêle.
        case open(String)
        case close
        case setPosition(Int)
        /// Trier la réplique. Sans identifiant : la carte à l'écran.
        case sort(String?, Voice)
        /// Choisir une proposition.
        case choose(String?, Int)
        /// Écrire sa propre phrase, sur une reformulation.
        case write(String?, String)
        /// Cocher ou décocher un temps en relisant sa phrase.
        case check(String?, Part)
        /// Rejouer l'histoire ouverte, réponses effacées de l'écran.
        case replay
        /// Ouvrir un mot dans le dictionnaire, sans quitter l'histoire.
        case lookUp(String)
        case closeLookUp
    }

    public static let reviewID = "review"
    public static let welcomeID = "welcome"
    static let mixPrefix = "mix."
    static let resultsKey = "talk.results"
    static let writtenKey = "talk.written"
    static let welcomedKey = "talk.welcomed"
    /// Un pêle-mêle tient en une dizaine de répliques : un rappel, pas une épreuve.
    static let mixLength = 10

    public private(set) var state = State()
    /// L'entrée ouverte depuis une histoire.
    public private(set) var entry: EntryViewModel?
    private let user: UserStore
    private let copy: Copy
    private let stories: [Story]
    private let makeEntry: ((String) -> EntryViewModel)?

    public init(user: UserStore, copy: Copy, stories: [Story] = Story.all, entry: ((String) -> EntryViewModel)? = nil) {
        self.user = user
        self.copy = copy
        self.stories = stories
        self.makeEntry = entry
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
            closeLookUp()
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
        case .write(let id, let text):
            edit(id) { card in
                let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard card.canWrite, !line.isEmpty else { return false }
                card.written = line
                card.checked = []
                return true
            }
            if let card = current(id), let line = card.written { remember(card.id, line) }
            refreshReport()
        case .check(let id, let part):
            edit(id) { card in
                guard card.written != nil else { return false }
                if let at = card.checked.firstIndex(of: part) { card.checked.remove(at: at) } else { card.checked.append(part) }
                card.checked.sort { Part.allCases.firstIndex(of: $0)! < Part.allCases.firstIndex(of: $1)! }
                return true
            }
        case .replay:
            guard let id = state.player?.storyID else { return }
            open(id)
        case .lookUp(let word):
            guard state.player != nil, let makeEntry else { return }
            entry = makeEntry(word)
            state.lookingUp = word
        case .closeLookUp:
            closeLookUp()
        }
    }

    private func closeLookUp() {
        entry = nil
        state.lookingUp = nil
    }

    // MARK: Les réponses

    /// Les dernières réponses, par réplique : `right` ou `wrong`.
    private func results() -> [String: Card.Verdict] {
        read(Self.resultsKey) ?? [:]
    }

    private func save(_ id: String, _ verdict: Card.Verdict) {
        var saved = results()
        saved[id] = verdict
        write(Self.resultsKey, saved)
    }

    /// Les phrases écrites, par reformulation. On les retrouve en rejouant.
    private func writtenLines() -> [String: String] {
        read(Self.writtenKey) ?? [:]
    }

    private func remember(_ id: String, _ line: String) {
        var saved = writtenLines()
        saved[id] = line
        write(Self.writtenKey, saved)
    }

    private func read<T: Decodable>(_ key: String) -> T? {
        guard let text = try? user.setting(key), let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ key: String, _ value: T) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        if let data = try? encoder.encode(value), let text = String(data: data, encoding: .utf8) {
            try? user.setSetting(key, text)
        }
    }

    private func index(_ id: String?, in player: Player) -> Int? {
        let index = id.flatMap { id in player.cards.firstIndex { $0.id == id } } ?? player.position
        return player.cards.indices.contains(index) ? index : nil
    }

    private func current(_ id: String?) -> Card? {
        guard let player = state.player, let index = index(id, in: player) else { return nil }
        return player.cards[index]
    }

    /// Modifie une carte ; `change` rend `false` si elle ne s'y prête pas.
    private func edit(_ id: String?, change: (inout Card) -> Bool) {
        guard var player = state.player, let index = index(id, in: player) else { return }
        var card = player.cards[index]
        guard change(&card) else { return }
        player.cards[index] = card
        state.player = player
    }

    /// Une réponse, une seule fois : `decide` rend `nil` si la carte n'en attend pas.
    private func answer(_ id: String?, decide: (inout Card) -> Bool?) {
        guard var player = state.player, let index = index(id, in: player), player.cards[index].asksAnswer else { return }
        var card = player.cards[index]
        guard let right = decide(&card) else { return }
        card.verdict = right ? .right : .wrong
        if card.kind == .sort, let voice = card.voice {
            // Le tri dit ce qu'était la réplique. Bien entendu ou non, on
            // apprend la même chose : qui parlait.
            card.verdictLabel = right ? "\(copy.heard) · \(copy.wasVoice(voice))" : copy.wasVoice(voice)
        } else {
            let kind = Beat.Kind(rawValue: card.kind.rawValue) ?? .rewrite
            card.verdictLabel = right ? copy.heard : copy.otherWay(kind)
        }
        player.cards[index] = card
        state.player = player
        save(card.id, card.verdict!)
        refreshReport()
    }

    // MARK: Les histoires

    private func open(_ id: String) {
        closeLookUp()
        if id == Self.welcomeID {
            openWelcome()
            return
        }
        let beats: [(Story, Beat)]
        let title: String
        let scene: String?
        if id == Self.reviewID {
            let missed = results().filter { $0.value == .wrong }
            beats = stories.flatMap { story in story.questions.filter { missed[$0.id] != nil }.map { (story, $0) } }
            guard !beats.isEmpty else { return }
            title = copy.talkReview
            scene = "night-reef"
        } else if id.hasPrefix(Self.mixPrefix), let intent = Intent(rawValue: String(id.dropFirst(Self.mixPrefix.count))) {
            let group = group(intent)
            beats = Self.mixed(group)
            guard !beats.isEmpty else { return }
            title = "\(copy.talkMix) · \(copy.intent(intent).title)"
            scene = group.first?.scene
        } else {
            guard let story = stories.first(where: { $0.id == id }) else { return }
            beats = story.beats.map { (story, $0) }
            title = story.title
            scene = story.scene
        }
        let written = writtenLines()
        var cards = beats.map { pair in
            var card = card(pair.1, in: pair.0)
            card.written = card.canWrite ? written[card.id] : nil
            return card
        }
        cards.append(Card(id: "\(id).report", kind: .report, cast: [], text: copy.storyEnd, gloss: "", why: ""))
        state.player = player(id, title: title, scene: scene, cards: cards)
        refreshReport()
    }

    /// Les histoires d'une intention, dans l'ordre des chapitres du livre :
    /// la progression qu'il a choisie, du concret vers le nuancé.
    func group(_ intent: Intent) -> [Story] {
        stories.enumerated()
            .filter { $0.element.intent == intent }
            .sorted { ($0.element.chapters.first ?? 0, $0.offset) < ($1.element.chapters.first ?? 0, $1.offset) }
            .map(\.element)
    }

    /// Les répliques d'une intention, une histoire après l'autre à tour de
    /// rôle : deux histoires voisines se rappellent l'une l'autre.
    static func mixed(_ group: [Story]) -> [(Story, Beat)] {
        let queues = group.map { story in story.questions.map { (story, $0) } }
        var out: [(Story, Beat)] = []
        var round = 0
        while out.count < mixLength, queues.contains(where: { $0.count > round }) {
            for queue in queues where queue.count > round && out.count < mixLength { out.append(queue[round]) }
            round += 1
        }
        return out
    }

    /// L'accueil : quatre cartes, la girafe et le chacal, et un bouton pour
    /// aller choisir. On le lit une fois ; il reste dans la liste, en bas.
    private func openWelcome() {
        let pages = copy.talkWelcome
        let casts: [[Animal]] = [[.giraffe, .jackal], [.jackal], [.giraffe], [.giraffe, .jackal]]
        let cards = pages.enumerated().map { index, text in
            Card(
                id: "\(Self.welcomeID).\(index)", kind: .narration, cast: casts[index % casts.count], text: text, gloss: "", why: "",
                done: index == pages.count - 1 ? copy.talkWelcomeDone : nil
            )
        }
        try? user.setSetting(Self.welcomedKey, "1")
        state.player = player(Self.welcomeID, title: copy.talkWelcomeTitle, scene: "paper-garden", cards: cards)
    }

    private func player(_ id: String, title: String, scene: String?, cards: [Card]) -> Player {
        Player(
            storyID: id, title: title, scene: scene, cards: cards,
            giraffeLabel: copy.giraffe, jackalLabel: copy.jackal, sortHint: copy.sortHint,
            continueHint: copy.continueHint, closeLabel: copy.close, listenLabel: copy.listen,
            giraffeWouldSay: copy.giraffeWouldSay, giraffeFrench: copy.giraffeFrench, lookUpLabel: copy.lookUp,
            writeLabel: copy.writeOwn, writePlaceholder: copy.writePlaceholder, keepLabel: copy.keep,
            rereadLabel: copy.rereadOwn, checks: Part.allCases.map { Check(part: $0, label: copy.check($0)) }
        )
    }

    func card(_ beat: Beat, in story: Story) -> Card {
        let speaker = beat.speaker.map { [story.cast[$0]] }
        switch beat.kind {
        case .narration:
            return Card(id: beat.id, kind: .narration, cast: story.cast, text: beat.text, gloss: beat.gloss, why: "")
        case .sort:
            // La réplique chacal a sa traduction : la réplique girafe du même
            // temps, dans la même histoire.
            let translation = beat.voice == .jackal
                ? story.beats.first { $0.kind == .sort && $0.voice == .giraffe && $0.part == beat.part }?.text
                : nil
            return Card(
                id: beat.id, kind: .sort, cast: speaker ?? [], text: beat.text, gloss: beat.gloss,
                question: copy.sortQuestion, voice: beat.voice, part: beat.part.map(copy.part), why: beat.why,
                translation: translation,
                forms: GiraffeForm.found(in: beat.voice == .giraffe ? beat.text : translation ?? "")
            )
        case .rewrite:
            return Card(
                id: beat.id, kind: .rewrite, cast: speaker ?? [], text: beat.text, gloss: beat.gloss,
                question: copy.rewriteQuestion, voice: .jackal, part: copy.part(.request), why: beat.why,
                choices: choices(beat), forms: GiraffeForm.found(in: Self.right(beat)), canWrite: true
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
                reply: beat.reply, replyGloss: beat.replyGloss,
                // Le besoin commun se dit « j'ai besoin de » + nom : la forme est la réponse.
                forms: GiraffeForm.all.filter { $0.id == "need" }
            )
        case .hint:
            return Card(
                id: beat.id, kind: .hint, cast: speaker ?? [], text: beat.text, gloss: beat.gloss,
                question: copy.hintQuestion, part: copy.part(.need), why: beat.why,
                choices: choices(beat), forms: GiraffeForm.found(in: Self.right(beat))
            )
        }
    }

    private static func right(_ beat: Beat) -> String {
        beat.choices.first(where: \.isRight)?.text ?? ""
    }

    private func choices(_ beat: Beat) -> [Choice] {
        Self.arranged(beat).map { Choice(text: $0.text, gloss: $0.gloss, isRight: $0.isRight) }
    }

    /// Les propositions dans un ordre qui tient à la réplique : la bonne
    /// n'est pas toujours à la même place, et l'ordre ne doit rien au hasard.
    static func arranged(_ beat: Beat) -> [Rewrite] {
        guard !beat.choices.isEmpty else { return [] }
        let shift = beat.id.unicodeScalars.reduce(0) { $0 + Int($1.value) } % beat.choices.count
        return Array(beat.choices[shift...] + beat.choices[..<shift])
    }

    /// Le bilan se tient à jour à chaque réponse : il est la dernière carte.
    private func refreshReport() {
        guard var player = state.player, let last = player.cards.indices.last, player.cards[last].kind == .report else { return }
        let questions = player.cards.filter { $0.kind != .narration && $0.kind != .report }
        let lines: (Card.Verdict?) -> [String] = { verdict in
            questions.filter { $0.verdict == verdict }.map { $0.complete ?? $0.text }
        }
        var forms: [GiraffeForm] = []
        for form in questions.flatMap(\.forms) where !forms.contains(form) { forms.append(form) }
        forms.sort { a, b in GiraffeForm.all.firstIndex(of: a)! < GiraffeForm.all.firstIndex(of: b)! }
        player.cards[last].report = Report(
            title: copy.storyEnd,
            right: .init(label: copy.pileRight, lines: lines(.right)),
            wrong: .init(label: copy.pileWrong, lines: lines(.wrong)),
            skipped: .init(label: copy.pileSkipped, lines: lines(nil)),
            own: .init(label: copy.pileOwn, lines: questions.compactMap(\.written)),
            formsTitle: copy.formsTitle,
            forms: forms,
            playAgain: copy.playAgain
        )
        state.player = player
    }

    private func refreshRows() {
        let saved = results()
        let welcomed = (try? user.setting(Self.welcomedKey)) != nil
        let row: (Story) -> Row = { story in
            let questions = story.questions
            return Row(
                id: story.id, title: story.title, gloss: story.gloss, cast: story.cast, scene: story.scene,
                detail: self.copy.talkLines(questions.count),
                isDone: questions.allSatisfy { saved[$0.id] != nil }
            )
        }
        let welcome = Row(
            id: Self.welcomeID, title: copy.talkWelcomeTitle, gloss: "", cast: [.giraffe, .jackal],
            scene: "paper-garden", detail: copy.talkWelcomeLength, isDone: welcomed
        )

        var top: [Row] = []
        // L'accueil en tête tant qu'on ne l'a pas lu ; ensuite il descend.
        if !welcomed { top.append(welcome) }
        let missed = stories.flatMap(\.questions).filter { saved[$0.id] == .wrong }.count
        if missed > 0 {
            top.append(Row(
                id: Self.reviewID, title: copy.talkReview, gloss: "",
                cast: [.giraffe, .jackal], scene: "night-reef", detail: copy.talkReviewCount(missed), isDone: false
            ))
        }

        var sections: [Section] = top.isEmpty ? [] : [Section(id: "top", title: nil, when: nil, rows: top)]
        for intent in Intent.allCases {
            let group = group(intent)
            guard !group.isEmpty else { continue }
            var rows = group.map(row)
            // Le pêle-mêle s'ouvre quand deux histoires de l'intention sont faites.
            if rows.filter(\.isDone).count >= 2 {
                rows.append(Row(
                    id: Self.mixPrefix + intent.rawValue, title: copy.talkMix, gloss: "",
                    cast: Array(group.flatMap(\.cast).prefix(2)), scene: group.first?.scene,
                    detail: copy.talkMixLines(Self.mixed(group).count), isDone: false
                ))
            }
            let words = copy.intent(intent)
            sections.append(Section(id: intent.rawValue, title: words.title, when: words.when, rows: rows))
        }
        if welcomed { sections.append(Section(id: "end", title: nil, when: nil, rows: [welcome])) }
        state.sections = sections
    }

    // MARK: Introspection

    public var nodeName: String { state.player == nil ? "talk" : "story" }
    public func nodeState() throws -> Data { try Input.encode(state) }
    public var nodeActions: [(name: String, input: String)] {
        [("open", "{name}"), ("close", ""), ("setPosition", "{index}"),
         ("sort", "{name: giraffe|jackal}"), ("choose", "{index}"), ("write", "{text}"),
         ("check", "{name: observation|feeling|need|request}"), ("replay", ""),
         ("lookUp", "{word}"), ("closeLookUp", "")]
    }
    public var childNode: (any Introspectable)? { entry }

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
        case "write":
            send(.write(nil, try Input.decode(Input.Text.self, input, action: action, expected: "{text}").text))
        case "check":
            let name = try Input.decode(Input.Name.self, input, action: action, expected: "{name}").name
            guard let part = Part(rawValue: name) else {
                throw IntrospectionError.badInput(action: action, expected: "{name: observation|feeling|need|request}")
            }
            send(.check(nil, part))
        case "lookUp": send(.lookUp(try Input.decode(Input.Word.self, input, action: action, expected: "{word}").word))
        case "closeLookUp": send(.closeLookUp)
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
