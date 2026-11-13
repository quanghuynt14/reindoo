import Foundation
import Observation

/// L'écran de recherche : un champ, des complétions, et les mots récents.
@MainActor
@Observable
public final class SearchViewModel: Introspectable {
    public struct State: Codable, Equatable, Sendable {
        public var query = ""
        public var language: Language = .french
        public var languages: [LanguageOption] = []
        public var prompt = ""
        /// Ce que l'utilisateur peut compléter. Vide quand le champ l'est.
        public var completions: [String] = []
        /// Les derniers mots vus dans cette langue. Montrés quand le champ est vide.
        public var recents: [String] = []
        public var recentsTitle = ""
        /// Dit quoi faire quand il n'y a ni saisie ni passé.
        public var emptyMessage: String?
    }

    public struct LanguageOption: Codable, Equatable, Sendable {
        public var language: Language
        public var label: String
        public var isSelected: Bool
    }

    public enum Action: Sendable {
        case appear
        case setQuery(String)
        case setLanguage(Language)
        case submit
        case open(String)
        case clear
    }

    public private(set) var state = State()

    private let lexicon: Lexicon
    private let user: UserStore
    private let open: (String, Language) -> Void
    private let copy: Copy

    init(lexicon: Lexicon, user: UserStore, copy: Copy, open: @escaping (String, Language) -> Void) {
        self.lexicon = lexicon
        self.user = user
        self.copy = copy
        self.open = open
        state.recentsTitle = copy.recents
        refresh()
    }

    public func send(_ action: Action) {
        switch action {
        case .appear:
            break
        case .setQuery(let text):
            state.query = text
        case .setLanguage(let language):
            state.language = language
        case .clear:
            state.query = ""
        case .submit:
            let typed = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !typed.isEmpty else { return }
            open(typed, state.language)
        case .open(let word):
            guard !word.isEmpty else { return }
            open(word, state.language)
        }
        refresh()
    }

    /// Tout ce qui se déduit de (saisie, langue, base) se recalcule ici.
    private func refresh() {
        let language = state.language
        state.prompt = copy.searchPrompt(language)
        state.languages = Language.allCases.map {
            LanguageOption(language: $0, label: copy.languageShort($0), isSelected: $0 == language)
        }
        state.completions = (try? lexicon.completions(for: state.query, in: language)) ?? []
        state.recents = ((try? user.history(limit: 50)) ?? [])
            .filter { $0.key.language == language }
            .prefix(12)
            .map(\.key.word)
        state.emptyMessage = state.query.isEmpty && state.recents.isEmpty ? copy.searchEmpty : nil
    }

    // MARK: Introspection

    public var nodeName: String { "search" }
    public func nodeState() throws -> Data { try Input.encode(state) }
    public var childNode: (any Introspectable)? { nil }
    public var nodeActions: [(name: String, input: String)] {
        [("appear", ""), ("setQuery", "{text}"), ("setLanguage", "{name: french|english}"), ("submit", ""), ("open", "{word}"), ("clear", "")]
    }

    public func perform(_ action: String, input: Data?) throws -> Bool {
        switch action {
        case "appear": send(.appear)
        case "setQuery": send(.setQuery(try Input.decode(Input.Text.self, input, action: action, expected: "{text}").text))
        case "setLanguage":
            let name = try Input.decode(Input.Name.self, input, action: action, expected: "{name}").name
            guard let language = Language(rawValue: name) else {
                throw IntrospectionError.badInput(action: action, expected: "{name: french|english}")
            }
            send(.setLanguage(language))
        case "submit": send(.submit)
        case "open": send(.open(try Input.decode(Input.Word.self, input, action: action, expected: "{word}").word))
        case "clear": send(.clear)
        default: return false
        }
        return true
    }
}
