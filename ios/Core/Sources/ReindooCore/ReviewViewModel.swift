import Foundation
import Observation

/// Le reel (« Lướt ôn ») : les mots déjà cherchés, une carte par écran, sans
/// fin. Le mot d'abord, le sens ensuite. De temps en temps une surprise : une
/// question, un mot nouveau, un compte de la série.
@MainActor
@Observable
public final class ReviewViewModel: Introspectable {
    public enum Sort: String, Codable, Sendable, CaseIterable { case random, newest, oldest }

    public struct State: Codable, Equatable, Sendable {
        public var title = ""
        /// Les cartes déjà tirées. Il y en a toujours quelques-unes d'avance :
        /// le reel ne s'arrête pas.
        public var cards: [Card] = []
        /// La carte à l'écran. La vue la suit en défilant.
        public var position = 0
        public var sort: Sort = .random
        public var sortTitle = ""
        public var sortLabel = ""
        public var sorts: [Option] = []
        /// `all`, ou une langue du dictionnaire.
        public var filter = "all"
        public var filterTitle = ""
        public var filters: [Option] = []
        public var revealHint = ""
        public var openLabel = ""
        public var likeLabel = ""
        public var listenLabel = ""
        public var readAloudLabel = ""
        public var optionsLabel = ""
        public var emptyMessage: String?
        /// Le décor choisi : `word` (un par mot), `colours`, ou un thème.
        public var scene = "word"
        public var sceneTitle = ""
        public var scenes: [Option] = []
    }

    public struct Card: Codable, Equatable, Sendable, Identifiable {
        public enum Kind: String, Codable, Sendable {
            /// Un mot de l'historique.
            case word
            /// Un mot courant que l'utilisateur n'a jamais cherché.
            case discovery
            /// Un mot vu il y a peu, et plusieurs sens au choix.
            case quiz
            /// Le compte des mots passés.
            case streak
        }

        public var id: String
        public var kind: Kind
        /// Le mot. Sur une carte de série : le nombre.
        public var word: String
        public var language: Language
        public var languageLabel: String
        public var ipa: String
        public var gloss: String
        public var example: Example?
        public var isRevealed: Bool
        public var isLiked: Bool
        /// La teinte du fond, de 0 à 1. Elle tient au mot : il garde sa couleur.
        public var hue: Double
        /// Le décor de la carte, un thème de `SceneTheme`, ou `nil` pour la
        /// teinte seule. En mode « un par mot », il tient au mot, comme la teinte.
        public var scene: String? = nil
        /// Le décor est clair : le texte de la carte se met en sombre.
        public var isLight = false
        /// Ce que la carte annonce : « Từ mới », la question, la série.
        public var badge: String?
        public var choices: [Choice]
        /// Le choix fait. On ne répond qu'une fois.
        public var picked: Int?
    }

    public struct Choice: Codable, Equatable, Sendable {
        public var label: String
        public var isCorrect: Bool
    }

    public struct Option: Codable, Equatable, Sendable {
        public var name: String
        public var label: String
        public var isSelected: Bool
    }

    public enum Action: Sendable {
        case appear
        /// Aléatoire → récents → anciens → aléatoire.
        case cycleSort
        case setSort(Sort)
        /// `nil` : toutes les langues.
        case setFilter(Language?)
        /// La vue a défilé jusqu'à cette carte.
        case setPosition(Int)
        /// Montrer ou recacher le sens. Sans identifiant : la carte à l'écran.
        case reveal(String?)
        /// Montrer le sens, sans jamais le recacher : la carte le fait seule
        /// après un temps.
        case unveil(String?)
        /// Poser ou retirer un cœur. Un mot aimé revient plus souvent.
        case like(String?)
        /// Répondre à une question.
        case choose(String?, Int)
        case open(String?)
        /// Rebattre les cartes et repartir du début.
        case restart
        /// `word`, `colours`, ou l'identifiant d'un thème.
        case setScene(String)
    }

    /// Un décor par mot : le mot choisit son thème, et le garde.
    public nonisolated static let perWord = "word"
    /// La teinte du mot, sans décor : la plus légère pour la batterie.
    public nonisolated static let colours = "colours"
    static let sceneSetting = "reel.scene"

    public private(set) var state = State()

    private let lexicon: Lexicon
    private let user: UserStore
    private let copy: Copy
    private let shuffle: ([SavedWord]) -> [SavedWord]
    private let chance: (Int) -> Int
    private let open: (String, Language) -> Void

    private var filter: Language?
    /// L'historique dont le reel est tiré. Tant qu'il ne change pas, le reel
    /// ne bouge pas : revenir d'une entrée ne rebat pas les cartes.
    private var dealtFrom: [SavedWord]?
    /// Combien de fois chaque identifiant a servi : un mot revient à chaque
    /// tour, et chaque carte doit rester unique.
    private var issued: [String: Int] = [:]
    private var wordsSinceSurprise = 0
    private var surprises = 0

    init(
        lexicon: Lexicon, user: UserStore, copy: Copy,
        shuffle: @escaping ([SavedWord]) -> [SavedWord],
        chance: @escaping (Int) -> Int,
        open: @escaping (String, Language) -> Void
    ) {
        self.lexicon = lexicon
        self.user = user
        self.copy = copy
        self.shuffle = shuffle
        self.chance = chance
        self.open = open
        state.title = copy.tabReview
        state.sortTitle = copy.sortTitle
        state.filterTitle = copy.filterTitle
        state.revealHint = copy.revealHint
        state.openLabel = copy.openEntry
        state.likeLabel = copy.like
        state.listenLabel = copy.listen
        state.readAloudLabel = copy.readAloud
        state.optionsLabel = copy.options
        state.sceneTitle = copy.sceneTitle
        if let saved = try? user.setting(Self.sceneSetting), Self.isScene(saved) { state.scene = saved }
        state.scenes = sceneOptions()
        deal()
    }

    static func isScene(_ name: String) -> Bool {
        name == perWord || name == colours || SceneTheme.named(name) != nil
    }

    private func sceneOptions() -> [Option] {
        [Option(name: Self.perWord, label: copy.scenePerWord, isSelected: state.scene == Self.perWord)]
            + SceneTheme.all.map { Option(name: $0.id, label: $0.title, isSelected: state.scene == $0.id) }
            + [Option(name: Self.colours, label: copy.sceneColours, isSelected: state.scene == Self.colours)]
    }

    /// Le décor d'une carte, selon le choix. Un mot garde le sien d'un tour à
    /// l'autre : le même hachage que sa teinte.
    private static func dress(_ card: inout Card, in scene: String) {
        let theme: SceneTheme?
        switch scene {
        case Self.colours: theme = nil
        case Self.perWord:
            let all = SceneTheme.all
            theme = all[Int(Self.fnv("\(card.language.rawValue)/\(card.word)") % UInt64(all.count))]
        default: theme = SceneTheme.named(scene)
        }
        card.scene = theme?.id
        card.isLight = theme?.window == .light
    }

    public func send(_ action: Action) {
        switch action {
        case .appear:
            if (try? user.history(limit: Self.deckLimit)) != dealtFrom { deal() }
        case .cycleSort:
            let all = Sort.allCases
            state.sort = all[(all.firstIndex(of: state.sort)! + 1) % all.count]
            deal()
        case .setSort(let sort):
            guard sort != state.sort else { return }
            state.sort = sort
            deal()
        case .setFilter(let language):
            filter = language
            deal()
        case .restart:
            deal()
        case .setScene(let name):
            guard Self.isScene(name), name != state.scene else { return }
            // Le choix reste sur l'appareil ; s'il ne s'écrit pas, il vaut pour la séance.
            try? user.setSetting(Self.sceneSetting, name)
            state.scene = name
            state.scenes = sceneOptions()
            // Le choix est lu avant : lire `state` pendant qu'on le modifie arrête l'app.
            for index in state.cards.indices { Self.dress(&state.cards[index], in: name) }
        case .setPosition(let index):
            guard state.cards.indices.contains(index) else { return }
            state.position = index
            topUp()
        case .reveal(let id):
            guard let index = index(of: id), Self.hasMeaning(state.cards[index]) else { return }
            state.cards[index].isRevealed.toggle()
        case .unveil(let id):
            guard let index = index(of: id), Self.hasMeaning(state.cards[index]) else { return }
            state.cards[index].isRevealed = true
        case .like(let id):
            guard let index = index(of: id), state.cards[index].kind != .streak else { return }
            let card = state.cards[index]
            let liked = !card.isLiked
            guard (try? user.setLiked(WordKey(card.language, card.word), liked)) != nil else { return }
            // Le même mot revient sur plusieurs cartes : toutes portent le cœur.
            for other in state.cards.indices
            where state.cards[other].kind != .streak
                && state.cards[other].word == card.word && state.cards[other].language == card.language {
                state.cards[other].isLiked = liked
            }
        case .choose(let id, let choice):
            guard let index = index(of: id), state.cards[index].kind == .quiz,
                  state.cards[index].picked == nil, state.cards[index].choices.indices.contains(choice)
            else { return }
            state.cards[index].picked = choice
            state.cards[index].isRevealed = true
        case .open(let id):
            guard let index = index(of: id), state.cards[index].kind != .streak else { return }
            open(state.cards[index].word, state.cards[index].language)
        }
    }

    private static let deckLimit = 500
    /// Les cartes tirées d'avance, au-delà de celle à l'écran.
    private static let ahead = 3
    /// Le nombre de mots entre deux surprises. Il varie : on ne sait pas quand
    /// vient la prochaine.
    private static let gaps = [5, 4, 6, 5, 7]
    private static let surpriseOrder: [Card.Kind] = [.quiz, .discovery, .quiz, .streak]

    private static func hasMeaning(_ card: Card) -> Bool {
        card.kind == .word || card.kind == .discovery
    }

    private func index(of id: String?) -> Int? {
        guard let id else { return state.cards.indices.contains(state.position) ? state.position : nil }
        return state.cards.firstIndex { $0.id == id }
    }

    /// `chance`, tenu dans ses bornes.
    private func draw(_ count: Int) -> Int {
        min(max(chance(count), 0), max(count - 1, 0))
    }

    // MARK: Tirer les cartes

    /// Repart de zéro : un historique relu, un premier tour, la première carte.
    private func deal() {
        dealtFrom = (try? user.history(limit: Self.deckLimit)) ?? []
        state.cards = []
        state.position = 0
        issued = [:]
        wordsSinceSurprise = 0
        surprises = 0
        topUp()

        state.filter = filter?.rawValue ?? "all"
        state.filters = [Option(name: "all", label: copy.allLanguages, isSelected: filter == nil)]
            + Language.allCases.map { Option(name: $0.rawValue, label: copy.languageShort($0), isSelected: $0 == filter) }
        state.sorts = Sort.allCases.map { Option(name: $0.rawValue, label: label(for: $0), isSelected: $0 == state.sort) }
        state.sortLabel = label(for: state.sort)
        state.emptyMessage = state.cards.isEmpty
            ? (filter == nil ? copy.reviewEmpty : copy.reviewEmptyFiltered)
            : nil
    }

    private func label(for sort: Sort) -> String {
        switch sort {
        case .random: copy.sortRandom
        case .newest: copy.sortNewest
        case .oldest: copy.sortOldest
        }
    }

    /// Ajoute des tours tant qu'il manque des cartes devant celle à l'écran.
    private func topUp() {
        for _ in 0..<8 where state.cards.count - 1 - state.position < Self.ahead {
            let before = state.cards.count
            appendLap()
            // Rien à tirer : inutile d'insister.
            if state.cards.count == before { return }
        }
    }

    /// Un tour : chaque mot une fois, les mots aimés deux fois.
    private func appendLap() {
        let kept = (dealtFrom ?? []).filter { filter == nil || $0.key.language == filter }
        var lap: [SavedWord]
        switch state.sort {
        case .random: lap = shuffle(kept)
        case .newest: lap = kept
        case .oldest: lap = kept.reversed()
        }

        // Le second passage d'un mot aimé tombe loin du premier.
        let liked = (try? user.liked()) ?? []
        let count = lap.count
        if count >= 3, !liked.isEmpty {
            let shift = max(2, count / 2)
            let copies = lap.enumerated()
                .filter { liked.contains($0.element.key) }
                .map { (at: ($0.offset + shift) % count, word: $0.element) }
                .sorted { $0.at > $1.at }
            for copy in copies { lap.insert(copy.word, at: copy.at) }
        }

        // Pas deux fois le même mot de suite, d'un tour à l'autre.
        if let last = state.cards.last(where: { $0.kind == .word }),
           let first = lap.firstIndex(where: { $0.key != WordKey(last.language, last.word) }), first > 0 {
            lap.swapAt(0, first)
        }

        for word in lap {
            // Un mot que le lexique n'a plus n'a pas de sens à cacher : on le passe.
            guard let entry = try? lexicon.entry(word.key.word, in: word.key.language) else { continue }
            state.cards.append(card(.word, for: entry, liked: liked))
            wordsSinceSurprise += 1
            if wordsSinceSurprise >= Self.gaps[surprises % Self.gaps.count] {
                if let surprise = makeSurprise(liked: liked) { state.cards.append(surprise) }
                wordsSinceSurprise = 0
                surprises += 1
            }
        }
    }

    private func card(_ kind: Card.Kind, for entry: Entry, liked: Set<WordKey>, badge: String? = nil) -> Card {
        let key = "\(entry.language.rawValue)/\(entry.word)"
        var card = Card(
            id: issue(kind == .word ? key : "\(kind.rawValue)/\(key)"), kind: kind,
            word: entry.word, language: entry.language,
            languageLabel: copy.languageShort(entry.language),
            ipa: entry.ipa.joined(separator: " · "), gloss: entry.translated,
            example: entry.explains.lazy.compactMap(\.exampleSentences.first).first,
            isRevealed: false, isLiked: liked.contains(WordKey(entry.language, entry.word)),
            hue: Self.hue(of: key), badge: badge, choices: [], picked: nil
        )
        Self.dress(&card, in: state.scene)
        return card
    }

    /// La première carte d'un mot porte son nom ; les suivantes, un numéro.
    private func issue(_ base: String) -> String {
        let count = issued[base, default: 0] + 1
        issued[base] = count
        return count == 1 ? base : "\(base)#\(count)"
    }

    /// La teinte d'un mot. FNV-1a : le même mot donne la même couleur à chaque
    /// lancement, ce que `hashValue` ne promet pas.
    static func hue(of text: String) -> Double {
        Double(fnv(text) % 360) / 360
    }

    static func fnv(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }

    // MARK: Surprises

    /// La surprise dont c'est le tour. Si elle ne peut pas se faire, la
    /// suivante ; la série, elle, se fait toujours.
    private func makeSurprise(liked: Set<WordKey>) -> Card? {
        for step in 0..<Self.surpriseOrder.count {
            let kind = Self.surpriseOrder[(surprises + step) % Self.surpriseOrder.count]
            let made: Card? = switch kind {
            case .quiz: quiz(liked: liked)
            case .discovery: discovery(liked: liked)
            case .streak: streak()
            case .word: nil
            }
            if let made { return made }
        }
        return nil
    }

    /// Une question sur un des cinq derniers mots, avec des sens pris ailleurs
    /// dans le lexique.
    private func quiz(liked: Set<WordKey>) -> Card? {
        var recent: [Card] = []
        for card in state.cards.reversed() where card.kind == .word && !card.gloss.isEmpty {
            if recent.contains(where: { $0.word == card.word && $0.language == card.language }) { continue }
            recent.append(card)
            if recent.count == 5 { break }
        }
        guard !recent.isEmpty else { return nil }
        recent.reverse()
        let target = recent[draw(recent.count)]

        var wrong: [String] = []
        for other in (try? lexicon.sample(target.language, limit: 12, pick: draw)) ?? [] {
            let gloss = other.translated
            if other.word == target.word || gloss.isEmpty || gloss == target.gloss || wrong.contains(gloss) { continue }
            wrong.append(gloss)
            if wrong.count == 3 { break }
        }
        guard wrong.count >= 2 else { return nil }

        var choices = wrong.map { Choice(label: $0, isCorrect: false) }
        choices.insert(Choice(label: target.gloss, isCorrect: true), at: draw(choices.count + 1))

        var card = target
        card.id = issue("quiz/\(target.language.rawValue)/\(target.word)")
        card.kind = .quiz
        card.isRevealed = false
        card.isLiked = liked.contains(WordKey(target.language, target.word))
        card.badge = copy.quizPrompt
        card.choices = choices
        card.picked = nil
        return card
    }

    /// Un mot courant que l'utilisateur n'a jamais cherché, dans la langue
    /// qu'il est en train de revoir.
    private func discovery(liked: Set<WordKey>) -> Card? {
        guard let language = filter ?? state.cards.last(where: { $0.kind == .word })?.language else { return nil }
        let known = Set((dealtFrom ?? []).map(\.key))
        let found = ((try? lexicon.sample(language, limit: 8, pick: draw)) ?? []).first { entry in
            !entry.translated.isEmpty
                && !known.contains(WordKey(language, entry.word))
                && !state.cards.contains { $0.kind == .discovery && $0.word == entry.word && $0.language == language }
        }
        return found.map { card(.discovery, for: $0, liked: liked, badge: copy.newWord) }
    }

    private func streak() -> Card? {
        guard let last = state.cards.last else { return nil }
        let count = state.cards.count { $0.kind == .word }
        var card = Card(
            id: issue("streak/\(count)"), kind: .streak, word: "\(count)",
            language: last.language, languageLabel: "", ipa: "", gloss: "", example: nil,
            isRevealed: true, isLiked: false, hue: 0.07, badge: copy.streak(count), choices: [], picked: nil
        )
        Self.dress(&card, in: state.scene)
        return card
    }

    // MARK: Introspection

    public var nodeName: String { "review" }
    public func nodeState() throws -> Data { try Input.encode(state) }
    public var childNode: (any Introspectable)? { nil }
    public var nodeActions: [(name: String, input: String)] {
        [
            ("appear", ""), ("cycleSort", ""), ("setSort", "{name: random|newest|oldest}"),
            ("setFilter", "{name: all|french|english}"), ("setPosition", "{index}"),
            ("reveal", "[{id}]"), ("unveil", "[{id}]"), ("like", "[{id}]"), ("choose", "{index}"),
            ("open", "[{id}]"), ("restart", ""), ("setScene", "{name: word|colours|<theme>}"),
        ]
    }

    private struct Index: Decodable { var index: Int }
    private struct Identifier: Decodable { var id: String }

    public func perform(_ action: String, input: Data?) throws -> Bool {
        func optionalID() throws -> String? {
            input == nil ? nil : try Input.decode(Identifier.self, input, action: action, expected: "[{id}]").id
        }
        switch action {
        case "appear": send(.appear)
        case "cycleSort": send(.cycleSort)
        case "restart": send(.restart)
        case "setSort":
            let name = try Input.decode(Input.Name.self, input, action: action, expected: "{name}").name
            guard let sort = Sort(rawValue: name) else {
                throw IntrospectionError.badInput(action: action, expected: "{name: random|newest|oldest}")
            }
            send(.setSort(sort))
        case "setFilter":
            let name = try Input.decode(Input.Name.self, input, action: action, expected: "{name}").name
            guard name == "all" || Language(rawValue: name) != nil else {
                throw IntrospectionError.badInput(action: action, expected: "{name: all|french|english}")
            }
            send(.setFilter(Language(rawValue: name)))
        case "setPosition":
            send(.setPosition(try Input.decode(Index.self, input, action: action, expected: "{index}").index))
        case "reveal": send(.reveal(try optionalID()))
        case "unveil": send(.unveil(try optionalID()))
        case "like": send(.like(try optionalID()))
        case "choose":
            send(.choose(nil, try Input.decode(Index.self, input, action: action, expected: "{index}").index))
        case "open": send(.open(try optionalID()))
        case "setScene":
            let name = try Input.decode(Input.Name.self, input, action: action, expected: "{name}").name
            guard Self.isScene(name) else {
                throw IntrospectionError.badInput(action: action, expected: "{name: word|colours|\(SceneTheme.all.map(\.id).joined(separator: "|"))}")
            }
            send(.setScene(name))
        default: return false
        }
        return true
    }
}
