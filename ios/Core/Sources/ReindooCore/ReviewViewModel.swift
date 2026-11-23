import Foundation
import Observation

/// Le reel (« Lướt ôn ») : les mots déjà cherchés, une carte par écran, sans
/// fin. Le mot d'abord, le sens ensuite — ou l'inverse, au choix. De temps en
/// temps une surprise : une question, un mot nouveau, un compte de la série.
@MainActor
@Observable
public final class ReviewViewModel: Introspectable {
    public enum Sort: String, Codable, Sendable, CaseIterable { case random, newest, oldest }

    /// Ce que la carte montre d'abord. Reconnaître un mot qu'on voit est plus
    /// facile que le retrouver depuis son sens : `meaningFirst` fait travailler
    /// le second, qui est celui dont on a besoin pour écrire et parler.
    public enum Direction: String, Codable, Sendable, CaseIterable { case wordFirst, meaningFirst }

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
        public var direction: Direction = .wordFirst
        /// Le bouton qui change de sens : il dit ce qu'il va faire.
        public var directionLabel = ""
        public var openLabel = ""
        public var likeLabel = ""
        public var memoLabel = ""
        public var closeLabel = ""
        /// La carte dont la note est ouverte, par-dessus le reel.
        public var memoCard: String?
        public var listenLabel = ""
        public var readAloudLabel = ""
        public var optionsLabel = ""
        /// Les deux gestes : à gauche « je sais », à droite « à revoir ».
        public var knewLabel = ""
        public var forgotLabel = ""
        public var swipeHint = ""
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
        /// Le sens s'est déjà montré une fois. Le recacher ne relance pas
        /// l'attente : deviner, c'est fini pour cette carte.
        public var wasRevealed = false
        public var isLiked: Bool
        /// Ce qui aide à retenir le mot, la même note que dans l'entrée.
        public var memo: MemoState? = nil
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
        /// Ce que l'utilisateur a dit de ce mot sur cette carte. On ne répond
        /// qu'une fois par carte.
        public var recall: Recall? = nil
        /// Le tour d'où vient la carte.
        public var lap = 0
        /// La carte attend un geste : un mot de l'historique, sans réponse.
        /// Le sens n'a pas à être montré : on sait souvent dès le mot.
        public var asksRecall: Bool { kind == .word && recall == nil }
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
        /// Montrer le sens sans attendre. Une fois montré, il reste : retoucher
        /// ne le cache pas. Sans identifiant : la carte à l'écran.
        case reveal(String?)
        /// Montrer le sens, sans jamais le recacher : la carte le fait seule
        /// après un temps.
        case unveil(String?)
        /// Poser ou retirer un cœur. Un mot aimé revient plus souvent.
        case like(String?)
        /// Ouvrir la note d'un mot, s'il en a une. Sans identifiant : la carte à l'écran.
        case showMemo(String?)
        case hideMemo
        /// Répondre à une question.
        case choose(String?, Int)
        case open(String?)
        /// Rebattre les cartes et repartir du début.
        case restart
        /// `word`, `colours`, ou l'identifiant d'un thème.
        case setScene(String)
        /// Le mot d'abord ↔ le sens d'abord. Les cartes pas encore passées
        /// recachent leur moitié : elles repartent dans le nouveau sens.
        case flipDirection
        /// Le geste sur un mot. `knew` (vers la gauche) : il ne revient pas
        /// avant deux tours. `forgot` (vers la droite) : il revient deux fois
        /// par tour. Le reel passe à la carte suivante.
        case answer(String?, Recall)
    }

    /// Un décor par mot : le mot choisit son thème, et le garde.
    public nonisolated static let perWord = "word"
    /// La teinte du mot, sans décor : la plus légère pour la batterie.
    public nonisolated static let colours = "colours"
    static let sceneSetting = "reel.scene"
    static let directionSetting = "reel.direction"
    /// Le numéro du dernier tour tiré. Il survit au lancement : un mot su
    /// ne revient pas parce que l'app a redémarré.
    static let lapSetting = "reel.lap"
    /// Les tours qu'un mot su laisse passer avant de revenir.
    static let knownSkips = 2

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
    private var lap = 0
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
        state.openLabel = copy.openEntry
        state.likeLabel = copy.like
        state.memoLabel = copy.memo
        state.closeLabel = copy.close
        state.listenLabel = copy.listen
        state.readAloudLabel = copy.readAloud
        state.optionsLabel = copy.options
        state.knewLabel = copy.knewIt
        state.forgotLabel = copy.again
        state.swipeHint = copy.swipeHint
        lap = (try? user.setting(Self.lapSetting)).flatMap { $0.flatMap(Int.init) } ?? 0
        if let saved = try? user.setting(Self.directionSetting), let direction = Direction(rawValue: saved) {
            state.direction = direction
        }
        labelDirection()
        state.sceneTitle = copy.sceneTitle
        if let saved = try? user.setting(Self.sceneSetting), Self.isScene(saved) { state.scene = saved }
        state.scenes = sceneOptions()
        deal()
    }

    /// Les textes qui dépendent du sens : ce que le toucher montre, et ce que
    /// fera le bouton.
    private func labelDirection() {
        switch state.direction {
        case .wordFirst:
            state.revealHint = copy.revealHint
            state.directionLabel = copy.meaningFirst
        case .meaningFirst:
            state.revealHint = copy.revealWordHint
            state.directionLabel = copy.wordFirst
        }
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
            if (try? user.history(limit: Self.deckLimit)) != dealtFrom {
                deal()
            } else if let liked = try? user.liked() {
                // Le cœur a pu changer dans le détail d'un mot.
                for index in state.cards.indices where state.cards[index].kind != .streak {
                    let card = state.cards[index]
                    state.cards[index].isLiked = liked.contains(WordKey(card.language, card.word))
                }
            }
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
        case .flipDirection:
            let direction: Direction = state.direction == .wordFirst ? .meaningFirst : .wordFirst
            // Le choix reste sur l'appareil ; s'il ne s'écrit pas, il vaut pour la séance.
            try? user.setSetting(Self.directionSetting, direction.rawValue)
            state.direction = direction
            labelDirection()
            // La position est lue avant : lire `state` pendant qu'on le modifie arrête l'app.
            let from = state.position
            for index in state.cards.indices where index >= from && state.cards[index].kind != .quiz {
                state.cards[index].isRevealed = false
                state.cards[index].wasRevealed = false
            }
        case .setPosition(let index):
            guard state.cards.indices.contains(index) else { return }
            state.position = index
            topUp()
        case .reveal(let id):
            guard let index = index(of: id), Self.hasMeaning(state.cards[index]) else { return }
            state.cards[index].isRevealed = true
            state.cards[index].wasRevealed = true
        case .unveil(let id):
            guard let index = index(of: id), Self.hasMeaning(state.cards[index]) else { return }
            state.cards[index].isRevealed = true
            state.cards[index].wasRevealed = true
        case .showMemo(let id):
            guard let index = index(of: id), state.cards[index].memo != nil else { return }
            // Le sens d'abord, la note donnerait le mot : elle attend qu'il paraisse.
            guard state.direction == .wordFirst || state.cards[index].isRevealed else { return }
            state.memoCard = state.cards[index].id
        case .hideMemo:
            state.memoCard = nil
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
            state.cards[index].wasRevealed = true
            // Une question réussie ou manquée est aussi un rappel : elle compte.
            let card = state.cards[index]
            let answer: Recall = card.choices[choice].isCorrect ? .knew : .forgot
            if (try? user.recall(WordKey(card.language, card.word), answer)) != nil {
                state.cards[index].recall = answer
            }
        case .answer(let id, let answer):
            guard let index = index(of: id), state.cards[index].asksRecall else { return }
            let card = state.cards[index]
            let returnLap = card.lap + Self.knownSkips + 1
            guard (try? user.mark(WordKey(card.language, card.word), answer, returnLap: returnLap)) != nil else { return }
            state.cards[index].recall = answer
            // Le tour suivant est peut-être déjà tiré : un mot su en sort.
            if answer == .knew {
                let doomed = state.cards.indices.filter { other in
                    other > index && other > state.position
                        && state.cards[other].kind == .word && state.cards[other].lap < returnLap
                        && state.cards[other].word == card.word && state.cards[other].language == card.language
                }
                for other in doomed.reversed() { state.cards.remove(at: other) }
            }
            // Le geste vaut « suivant », comme sur Tinder.
            if index == state.position {
                topUp()
                if state.cards.indices.contains(index + 1) {
                    state.position = index + 1
                    topUp()
                }
            }
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
            // Rien à tirer : inutile d'insister. Un tour vide, lui, compte :
            // si tous les mots sont sus, ils reviennent sans attendre.
            if !appendLap() { return }
        }
    }

    /// Un tour : chaque mot une fois. Un mot aimé ou gardé à revoir deux
    /// fois ; un mot su attend son tour de retour.
    /// Rend `false` s'il n'y a aucun mot à tirer, même plus tard.
    @discardableResult
    private func appendLap() -> Bool {
        let all = (dealtFrom ?? []).filter { filter == nil || $0.key.language == filter }
        guard !all.isEmpty else { return false }
        self.lap += 1
        let number = self.lap
        try? user.setSetting(Self.lapSetting, String(number))

        let marks = (try? user.marks()) ?? [:]
        let kept = all.filter { (marks[$0.key]?.returnLap ?? 0) <= number }
        var lap: [SavedWord]
        switch state.sort {
        case .random: lap = shuffle(kept)
        case .newest: lap = kept
        case .oldest: lap = kept.reversed()
        }

        // Le second passage d'un mot aimé, ou gardé à revoir, tombe loin du premier.
        let liked = (try? user.liked()) ?? []
        let twice = liked.union(marks.filter(\.value.isHard).keys)
        let count = lap.count
        if count >= 3, !twice.isEmpty {
            let shift = max(2, count / 2)
            let copies = lap.enumerated()
                .filter { twice.contains($0.element.key) }
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
            var made = card(.word, for: entry, liked: liked)
            made.lap = number
            state.cards.append(made)
            wordsSinceSurprise += 1
            if wordsSinceSurprise >= Self.gaps[surprises % Self.gaps.count] {
                if let surprise = makeSurprise(liked: liked) { state.cards.append(surprise) }
                wordsSinceSurprise = 0
                surprises += 1
            }
        }
        return true
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
        card.memo = MemoState(entry.memo, word: entry.word, copy: copy)
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
            // « Số nhiều của 1ère » se voit de loin : ce n'est pas un piège.
            if lexicon.pointsElsewhere(other) { continue }
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
        card.wasRevealed = false
        card.isLiked = liked.contains(WordKey(target.language, target.word))
        card.badge = copy.quizPrompt
        card.choices = choices
        card.picked = nil
        card.recall = nil
        return card
    }

    /// Un mot courant que l'utilisateur n'a jamais cherché, dans la langue
    /// qu'il est en train de revoir.
    private func discovery(liked: Set<WordKey>) -> Card? {
        guard let language = filter ?? state.cards.last(where: { $0.kind == .word })?.language else { return nil }
        let known = Set((dealtFrom ?? []).map(\.key))
        let found = ((try? lexicon.sample(language, limit: 8, pick: draw)) ?? []).first { entry in
            !entry.translated.isEmpty
                && !lexicon.pointsElsewhere(entry)
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
            ("setFilter", "{name: all|french|english|vietnamese}"), ("setPosition", "{index}"),
            ("reveal", "[{id}]"), ("unveil", "[{id}]"), ("flipDirection", ""), ("like", "[{id}]"), ("showMemo", "[{id}]"), ("hideMemo", ""), ("choose", "{index}"),
            ("open", "[{id}]"), ("restart", ""), ("setScene", "{name: word|colours|<theme>}"),
            ("answer", "{name: knew|forgot, id?}"),
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
        case "flipDirection": send(.flipDirection)
        case "setSort":
            let name = try Input.decode(Input.Name.self, input, action: action, expected: "{name}").name
            guard let sort = Sort(rawValue: name) else {
                throw IntrospectionError.badInput(action: action, expected: "{name: random|newest|oldest}")
            }
            send(.setSort(sort))
        case "setFilter":
            let name = try Input.decode(Input.Name.self, input, action: action, expected: "{name}").name
            guard name == "all" || Language(rawValue: name) != nil else {
                throw IntrospectionError.badInput(action: action, expected: "{name: all|french|english|vietnamese}")
            }
            send(.setFilter(Language(rawValue: name)))
        case "setPosition":
            send(.setPosition(try Input.decode(Index.self, input, action: action, expected: "{index}").index))
        case "reveal": send(.reveal(try optionalID()))
        case "unveil": send(.unveil(try optionalID()))
        case "like": send(.like(try optionalID()))
        case "showMemo": send(.showMemo(try optionalID()))
        case "hideMemo": send(.hideMemo)
        case "choose":
            send(.choose(nil, try Input.decode(Index.self, input, action: action, expected: "{index}").index))
        case "open": send(.open(try optionalID()))
        case "answer":
            struct Answer: Decodable { var name: String; var id: String? }
            let expected = "{name: knew|forgot, id?}"
            let input = try Input.decode(Answer.self, input, action: action, expected: expected)
            guard let answer = Recall(rawValue: input.name) else {
                throw IntrospectionError.badInput(action: action, expected: expected)
            }
            send(.answer(input.id, answer))
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
