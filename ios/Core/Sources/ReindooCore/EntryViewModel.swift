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
        public var translated = ""
        /// « allions » est une forme de « aller ».
        public var matchedNote: String?
        public var alsoFromTitle = ""
        public var alsoFrom: [String] = []
        public var senses: [SenseState] = []
        public var derivedTitle = ""
        public var derived: [String] = []
        public var wiki: String?

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
        public var number: Int
        public var explain: String
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
    }

    public private(set) var state = State()

    private let open: (String, Language) -> Void
    private var typed = ""

    /// `remembers` : chercher un mot l'inscrit à l'historique ; le revoir en
    /// révision, non — sinon réviser changerait l'ordre de ce qu'on révise.
    init(
        query: String, language: Language, lexicon: Lexicon, user: UserStore, copy: Copy, remembers: Bool,
        open: @escaping (String, Language) -> Void
    ) {
        self.open = open
        state.language = language
        state.alsoFromTitle = copy.alsoFrom
        state.derivedTitle = copy.derived

        let lookup = (try? lexicon.lookUp(query, in: language)) ?? .notFound(query: query, suggestions: [])
        switch lookup {
        case .found(let entry, let matchedForm, let alsoFrom):
            state.status = .found
            state.title = entry.word
            state.word = entry.word
            state.ipa = entry.ipa.joined(separator: " · ")
            state.translated = entry.translated
            state.matchedNote = matchedForm.map { copy.matchedForm($0, entry.word) }
            state.alsoFrom = alsoFrom
            state.senses = entry.explains.enumerated().map { index, sense in
                SenseState(
                    number: index + 1, explain: sense.explain, examples: sense.exampleSentences,
                    synonymsTitle: copy.synonyms, synonyms: sense.synonyms,
                    antonymsTitle: copy.antonyms, antonyms: sense.antonyms
                )
            }
            state.derived = entry.derived
            state.wiki = entry.wiki
            // Chercher un mot, c'est aussi s'en souvenir — comme sur le site.
            if remembers { try? user.remember(WordKey(language, entry.word)) }
        case .notFound(let typed, let suggestions):
            state.status = .notFound
            state.title = copy.notFound(typed)
            self.typed = typed
            state.suggestions = suggestions
            // « went » tapé côté français : on ne l'invente pas, on dit où il est.
            state.elsewhere = Language.allCases.filter { $0 != language }.compactMap { other in
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
        }
    }

    // MARK: Introspection

    public var nodeName: String { "entry" }
    public func nodeState() throws -> Data { try Input.encode(state) }
    public var childNode: (any Introspectable)? { nil }
    public var nodeActions: [(name: String, input: String)] { [("open", "{word}"), ("openElsewhere", "{name: french|english}")] }

    public func perform(_ action: String, input: Data?) throws -> Bool {
        switch action {
        case "open": send(.open(try Input.decode(Input.Word.self, input, action: action, expected: "{word}").word))
        case "openElsewhere":
            let name = try Input.decode(Input.Name.self, input, action: action, expected: "{name}").name
            guard let language = Language(rawValue: name) else {
                throw IntrospectionError.badInput(action: action, expected: "{name: french|english}")
            }
            send(.openElsewhere(language))
        default: return false
        }
        return true
    }
}

extension EntryViewModel: Hashable {
    public nonisolated static func == (lhs: EntryViewModel, rhs: EntryViewModel) -> Bool { lhs === rhs }
    public nonisolated func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}
