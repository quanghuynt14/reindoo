import Foundation
import Observation

/// Tous les mots déjà cherchés, le plus récent d'abord.
@MainActor
@Observable
public final class HistoryViewModel: Introspectable {
    public struct State: Codable, Equatable, Sendable {
        public var title = ""
        public var items: [Item] = []
        public var removeLabel = ""
        public var emptyMessage: String?
    }

    public struct Item: Codable, Equatable, Sendable, Identifiable {
        public var word: String
        public var language: Language
        public var languageLabel: String
        /// La traduction, ou l'aveu que le lexique a changé sous le mot.
        public var gloss: String
        public var id: String { "\(language.rawValue)/\(word)" }
    }

    public enum Action: Sendable {
        case appear
        case open(String, Language)
        case remove(String, Language)
    }

    public private(set) var state = State()

    private let lexicon: Lexicon
    private let user: UserStore
    private let copy: Copy
    private let open: (String, Language) -> Void
    private let didWrite: () -> Void

    init(lexicon: Lexicon, user: UserStore, copy: Copy, open: @escaping (String, Language) -> Void, didWrite: @escaping () -> Void) {
        self.lexicon = lexicon
        self.user = user
        self.copy = copy
        self.open = open
        self.didWrite = didWrite
        state.title = copy.tabHistory
        state.removeLabel = copy.remove
        refresh()
    }

    public func send(_ action: Action) {
        switch action {
        case .appear:
            break
        case .open(let word, let language):
            open(word, language)
        case .remove(let word, let language):
            try? user.forget(WordKey(language, word))
            didWrite()
        }
        refresh()
    }

    private func refresh() {
        state.items = ((try? user.history()) ?? []).map { word in
            let entry = try? lexicon.entry(word.key.word, in: word.key.language)
            return Item(
                word: word.key.word, language: word.key.language,
                languageLabel: copy.languageShort(word.key.language),
                gloss: entry?.translated ?? copy.missingEntry
            )
        }
        state.emptyMessage = state.items.isEmpty ? copy.historyEmpty : nil
    }

    // MARK: Introspection

    public var nodeName: String { "history" }
    public func nodeState() throws -> Data { try Input.encode(state) }
    public var childNode: (any Introspectable)? { nil }
    public var nodeActions: [(name: String, input: String)] {
        [("appear", ""), ("open", "{word, language}"), ("remove", "{word, language}")]
    }

    public func perform(_ action: String, input: Data?) throws -> Bool {
        switch action {
        case "appear": send(.appear)
        case "open":
            let target = try Input.decode(Input.Target.self, input, action: action, expected: "{word, language}")
            send(.open(target.word, target.language))
        case "remove":
            let target = try Input.decode(Input.Target.self, input, action: action, expected: "{word, language}")
            send(.remove(target.word, target.language))
        default: return false
        }
        return true
    }
}
