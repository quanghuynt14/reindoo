import Foundation
import Observation

/// La racine : les onglets, leurs piles, et ce dont tous les écrans dépendent.
/// La navigation est un état, ici. Le CLI parcourt l'app sans créer une vue.
@MainActor
@Observable
public final class AppModel: Introspectable {
    public enum Tab: String, Codable, Sendable, CaseIterable { case search, review, history }

    public struct State: Codable, Equatable, Sendable {
        public var tab: Tab = .search
        public var tabs: [TabOption] = []
        /// Combien d'entrées sont empilées sur l'onglet courant.
        public var depth = 0
        /// Changements locaux que le serveur ne connaît pas encore.
        public var pendingChanges = 0
    }

    public struct TabOption: Codable, Equatable, Sendable {
        public var tab: Tab
        public var label: String
        public var isSelected: Bool
    }

    public enum Action: Sendable {
        case selectTab(Tab)
        case back
        /// La vue rend la pile après un geste de retour : on la raccourcit.
        case popTo(Int)
    }

    public private(set) var state = State()
    public private(set) var stacks: [Tab: [EntryViewModel]] = [.search: [], .review: [], .history: []]

    @ObservationIgnored public private(set) var search: SearchViewModel!
    @ObservationIgnored public private(set) var review: ReviewViewModel!
    @ObservationIgnored public private(set) var history: HistoryViewModel!

    private let lexicon: Lexicon
    public let user: UserStore
    public let copy: Copy

    /// `shuffle` bat les cartes du reel, et `chance(n)` tire un nombre de 0 à
    /// n − 1 pour ses surprises. Les fixtures en passent qui ne doivent rien
    /// au hasard.
    public init(
        lexicon: Lexicon, user: UserStore, copy: Copy,
        shuffle: @escaping ([SavedWord]) -> [SavedWord] = { $0.shuffled() },
        chance: @escaping (Int) -> Int = { Int.random(in: 0..<max($0, 1)) }
    ) {
        self.lexicon = lexicon
        self.user = user
        self.copy = copy
        let open: (String, Language) -> Void = { [weak self] word, language in
            self?.push(word, language, remembers: true)
        }
        search = SearchViewModel(lexicon: lexicon, user: user, copy: copy, open: open)
        review = ReviewViewModel(lexicon: lexicon, user: user, copy: copy, shuffle: shuffle, chance: chance) { [weak self] word, language in
            self?.push(word, language, remembers: false)
        }
        history = HistoryViewModel(lexicon: lexicon, user: user, copy: copy, open: open) { [weak self] in self?.countPending() }
        refresh()
    }

    public var stack: [EntryViewModel] { stacks[state.tab] ?? [] }

    public func send(_ action: Action) {
        switch action {
        case .selectTab(let tab):
            // Retoucher l'onglet courant ramène à sa racine, comme partout sur iOS.
            if tab == state.tab { stacks[tab] = [] }
            state.tab = tab
        case .back:
            guard !stack.isEmpty else { return }
            stacks[state.tab]?.removeLast()
        case .popTo(let depth):
            // Le compte d'abord, la modification ensuite : lire la pile pendant
            // qu'on la modifie est un accès simultané, et Swift arrête l'app.
            let surplus = stack.count - depth
            guard depth >= 0, surplus > 0 else { return }
            stacks[state.tab]?.removeLast(surplus)
        }
        refresh()
    }

    private func push(_ word: String, _ language: Language, remembers: Bool) {
        let entry = EntryViewModel(
            query: word, language: language, lexicon: lexicon, user: user, copy: copy, remembers: remembers,
            // Un renvoi suivi depuis une entrée garde la règle de son onglet.
            open: { [weak self] word, language in self?.push(word, language, remembers: remembers) }
        )
        stacks[state.tab, default: []].append(entry)
        refresh()
    }

    /// Un écran qui redevient visible relit la base : l'historique a pu
    /// changer pendant qu'il était couvert.
    private func refresh() {
        state.depth = stack.count
        state.tabs = Tab.allCases.map {
            TabOption(tab: $0, label: label($0), isSelected: $0 == state.tab)
        }
        countPending()
        if stack.isEmpty {
            switch state.tab {
            case .search: search.send(.appear)
            case .review: review.send(.appear)
            case .history: history.send(.appear)
            }
        }
    }

    private func label(_ tab: Tab) -> String {
        switch tab {
        case .search: copy.tabSearch
        case .review: copy.tabReview
        case .history: copy.tabHistory
        }
    }

    private func countPending() {
        state.pendingChanges = (try? user.pendingCount()) ?? 0
    }

    // MARK: Introspection

    public var nodeName: String { "app" }
    public func nodeState() throws -> Data { try Input.encode(state) }
    public var nodeActions: [(name: String, input: String)] { [("selectTab", "{name: search|review|history}"), ("back", "")] }

    public var childNode: (any Introspectable)? {
        if let top = stack.last { return top }
        switch state.tab {
        case .search: return search
        case .review: return review
        case .history: return history
        }
    }

    public func perform(_ action: String, input: Data?) throws -> Bool {
        switch action {
        case "selectTab":
            let name = try Input.decode(Input.Name.self, input, action: action, expected: "{name}").name
            guard let tab = Tab(rawValue: name) else {
                throw IntrospectionError.badInput(action: action, expected: "{name: search|review|history}")
            }
            send(.selectTab(tab))
        case "back": send(.back)
        default: return false
        }
        return true
    }
}
