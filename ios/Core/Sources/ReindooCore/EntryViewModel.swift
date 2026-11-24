import Foundation
import Observation

/// Une entrée du dictionnaire — ou l'aveu qu'il n'y en a pas.
@MainActor
@Observable
public final class EntryViewModel: Introspectable, Identifiable {
    public struct State: Codable, Equatable, Sendable {
        public enum Status: String, Codable, Sendable { case found, notFound }

        public var status: Status = .notFound
        public var language: Language = .french
        /// Le titre : la vedette, ou « introuvable ».
        public var title = ""

        // Trouvé
        public var word = ""
        public var ipa = ""
        /// « Hán Việt: nhĩ hảo », sous le pinyin d'un mot chinois. Absent ailleurs.
        public var hanViet: String?
        public var translated = ""
        /// « allions » est une forme de « aller ».
        public var matchedNote: String?
        public var alsoFromTitle = ""
        public var alsoFrom: [String] = []
        public var senses: [SenseState] = []
        public var derivedTitle = ""
        public var derived: [String] = []
        public var wiki: String?
        /// Le cœur, le même que dans le reel : un mot aimé y revient plus souvent.
        public var isLiked = false
        public var likeLabel = ""
        public var listenLabel = ""
        /// Ce qui aide à retenir le mot. Absent : pas de bouton au cerveau.
        public var memo: MemoState?
        public var memoLabel = ""
        public var closeLabel = ""
        /// La note est ouverte, par-dessus l'entrée.
        public var isMemoShown = false

        // Introuvable
        public var hint: String?
        public var suggestions: [String] = []
        /// Le mot manque ici, mais l'autre dictionnaire l'a.
        public var elsewhere: [Elsewhere] = []
    }

    public struct Elsewhere: Codable, Equatable, Sendable {
        public var language: Language
        public var title: String
        public var word: String
        public var translated: String
    }

    public struct SenseState: Codable, Equatable, Sendable {
        /// Sa place dans l'entrée, de 0 : les numéros recommencent à 1 sous
        /// le titre du Wiktionnaire, l'index, lui, ne se répète pas.
        public var index: Int
        public var number: Int
        /// Le titre à poser au-dessus de ce sens, quand une partie commence :
        /// les sens reindoo d'abord, ceux du Wiktionnaire ensuite.
        public var heading: String?
        public var explain: String
        public var note: String?
        public var examples: [Example]
        public var synonymsTitle: String
        public var synonyms: [String]
        public var antonymsTitle: String
        public var antonyms: [String]
    }

    public enum Action: Sendable {
        /// Suivre un renvoi : synonyme, dérivé, proposition.
        case open(String)
        /// Ouvrir le mot dans l'autre dictionnaire, celui qui l'a.
        case openElsewhere(Language)
        /// Poser ou retirer le cœur.
        case like
        /// Ouvrir la note pour retenir le mot, s'il en a une.
        case showMemo
        case hideMemo
    }

    public private(set) var state = State()

    private let open: (String, Language) -> Void
    private let user: UserStore
    private let languages: [Language]
    private var typed = ""

    /// `remembers` : chercher un mot l'inscrit à l'historique ; le revoir en
    /// révision, non — sinon réviser changerait l'ordre de ce qu'on révise.
    init(
        query: String, language: Language, languages: [Language], lexicon: Lexicon, user: UserStore, copy: Copy, remembers: Bool,
        open: @escaping (String, Language) -> Void
    ) {
        self.open = open
        self.user = user
        self.languages = languages
        state.language = language
        state.likeLabel = copy.like
        state.listenLabel = copy.listen
        state.memoLabel = copy.memo
        state.closeLabel = copy.close
        state.alsoFromTitle = copy.alsoFrom
        state.derivedTitle = copy.derived

        let lookup = (try? lexicon.lookUp(query, in: language)) ?? .notFound(query: query, suggestions: [])
        switch lookup {
        case .found(let entry, let matchedForm, let alsoFrom):
            state.status = .found
            state.title = entry.word
            state.word = entry.word
            state.ipa = entry.ipa.joined(separator: " · ")
            state.hanViet = entry.hanViet.isEmpty ? nil : copy.hanViet(entry.hanViet)
            state.translated = entry.translated
            state.matchedNote = matchedForm.map { copy.matchedForm($0, entry.word) }
            state.alsoFrom = alsoFrom
            // Sans entrée reindoo, rien ne change : pas de titre, une seule suite.
            let hasOwn = entry.explains.contains(where: \.isOwn)
            var number = 0
            state.senses = entry.explains.enumerated().map { index, sense in
                let starts = index == 0 || entry.explains[index - 1].isOwn != sense.isOwn
                number = starts ? 1 : number + 1
                return SenseState(
                    index: index, number: number,
                    heading: hasOwn && starts ? (sense.isOwn ? copy.ownSenses : copy.wiktionarySenses) : nil,
                    explain: sense.explain, note: sense.note, examples: sense.exampleSentences,
                    synonymsTitle: copy.synonyms, synonyms: sense.synonyms,
                    antonymsTitle: copy.antonyms, antonyms: sense.antonyms
                )
            }
            state.derived = entry.derived
            state.wiki = entry.wiki
            state.memo = MemoState(entry.memo, word: entry.word, copy: copy)
            state.isLiked = (try? user.liked().contains(WordKey(language, entry.word))) ?? false
            // Chercher un mot, c'est aussi s'en souvenir — comme sur le site.
            if remembers { try? user.remember(WordKey(language, entry.word)) }
        case .notFound(let typed, let suggestions):
            state.status = .notFound
            state.title = copy.notFound(typed)
            self.typed = typed
            state.suggestions = suggestions
            // « went » tapé côté français : on ne l'invente pas, on dit où il est.
            state.elsewhere = languages.filter { $0 != language }.compactMap { other in
                guard !typed.isEmpty, case .found(let entry, _, _)? = try? lexicon.lookUp(typed, in: other) else { return nil }
                return Elsewhere(language: other, title: copy.foundElsewhere(other), word: entry.word, translated: entry.translated)
            }
            if !suggestions.isEmpty {
                state.hint = copy.notFoundHint
            } else if state.elsewhere.isEmpty {
                state.hint = copy.notFoundNoHint
            }
        }
    }

    public func send(_ action: Action) {
        switch action {
        case .open(let word):
            guard !word.isEmpty else { return }
            open(word, state.language)
        case .openElsewhere(let language):
            // On rouvre ce qui a été tapé : la note « est une forme de » suit.
            guard state.elsewhere.contains(where: { $0.language == language }) else { return }
            open(typed, language)
        case .like:
            guard state.status == .found else { return }
            let liked = !state.isLiked
            // S'il ne s'écrit pas, le cœur ne bouge pas : il ne ment pas.
            guard (try? user.setLiked(WordKey(state.language, state.word), liked)) != nil else { return }
            state.isLiked = liked
        case .showMemo:
            guard state.memo != nil else { return }
            state.isMemoShown = true
        case .hideMemo:
            state.isMemoShown = false
        }
    }

    // MARK: Introspection

    public var nodeName: String { "entry" }
    public func nodeState() throws -> Data { try Input.encode(state) }
    public var childNode: (any Introspectable)? { nil }
    public var nodeActions: [(name: String, input: String)] { [("open", "{word}"), ("openElsewhere", "{name: \(names)}"), ("like", ""), ("showMemo", ""), ("hideMemo", "")] }

    private var names: String { languages.map(\.rawValue).joined(separator: "|") }

    public func perform(_ action: String, input: Data?) throws -> Bool {
        switch action {
        case "open": send(.open(try Input.decode(Input.Word.self, input, action: action, expected: "{word}").word))
        case "openElsewhere":
            let name = try Input.decode(Input.Name.self, input, action: action, expected: "{name}").name
            guard let language = Language(rawValue: name) else {
                throw IntrospectionError.badInput(action: action, expected: "{name: \(names)}")
            }
            send(.openElsewhere(language))
        case "like": send(.like)
        case "showMemo": send(.showMemo)
        case "hideMemo": send(.hideMemo)
        default: return false
        }
        return true
    }
}

extension EntryViewModel: Hashable {
    public nonisolated static func == (lhs: EntryViewModel, rhs: EntryViewModel) -> Bool { lhs === rhs }
    public nonisolated func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}
