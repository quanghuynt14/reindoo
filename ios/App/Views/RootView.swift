import ReindooCore
import SwiftUI
import UIKit

/// Quatre onglets, chacun avec sa pile. La vue ne décide de rien : elle lit
/// l'état de Core et lui renvoie des actions.
struct RootView: View {
    let app: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        TabView(selection: Binding(
            get: { app.state.tab },
            set: { app.send(.selectTab($0)) }
        )) {
            Tab(label(.search), systemImage: "character.book.closed", value: AppModel.Tab.search) {
                stack(.search) { SearchView(model: app.search, title: label(.search)) }
            }
            Tab(label(.review), systemImage: "rectangle.stack", value: AppModel.Tab.review) {
                stack(.review) { ReviewView(model: app.review) }
            }
            Tab(label(.talk), systemImage: "bubble.left.and.bubble.right", value: AppModel.Tab.talk) {
                stack(.talk) { TalkView(model: app.talk) }
            }
            Tab(label(.history), systemImage: "clock", value: AppModel.Tab.history) {
                stack(.history) { HistoryView(model: app.history) }
            }
        }
        // Les décors et les voix se chauffent dès le lancement, le décor de la
        // première carte d'abord : ouvrir l'onglet n'attend plus rien.
        .task {
            Speaker.shared.warm()
            let first = app.review.state.cards.prefix(3).compactMap { $0.scene.flatMap(SceneTheme.named) }
            let moves = !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
            let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen
            SceneCache.shared.warmAll(first: first, size: screen?.bounds.size ?? .zero, moves: moves, displayScale: displayScale)
        }
    }

    private func label(_ tab: AppModel.Tab) -> String {
        app.state.tabs.first { $0.tab == tab }?.label ?? ""
    }

    private func stack(_ tab: AppModel.Tab, @ViewBuilder root: () -> some View) -> some View {
        NavigationStack(path: Binding(
            get: { app.stacks[tab] ?? [] },
            // Le geste de retour raccourcit la pile ; Core l'apprend ici.
            set: { app.send(.popTo($0.count)) }
        )) {
            root()
                .navigationDestination(for: EntryViewModel.self) { EntryView(model: $0) }
        }
    }
}

#Preview("Nouveau") {
    RootView(app: try! Fixture.sample.makeApp()).tint(Theme.accent)
}

#Preview("De retour, en français") {
    RootView(app: try! Fixture.returning.makeApp(ui: .french)).tint(Theme.accent)
}
