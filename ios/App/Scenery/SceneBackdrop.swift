import ReindooCore
import SwiftUI
import UIKit

/// Le décor animé derrière le reel. Il se construit hors du fil principal, se
/// fond dans le suivant, et reste immobile quand l'utilisateur demande moins de
/// mouvement ou que l'iPhone économise sa batterie.
struct SceneBackdrop: View {
    let theme: SceneTheme
    /// Figé pour l'instant : on fait défiler, ou l'onglet est caché.
    var paused = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var renderer: SceneRenderer?
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let renderer {
                    SceneCanvas(renderer: renderer, paused: paused)
                        .id(renderer.id)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: renderer?.id)
            .task(id: SceneCache.Key(theme: theme.id, size: geometry.size, moves: !reduceMotion && !lowPower)) {
                guard geometry.size.width > 0, geometry.size.height > 0 else { return }
                SceneCache.shared.lastSize = geometry.size
                SceneCache.shared.lastMoves = !reduceMotion && !lowPower
                renderer = await SceneCache.shared.renderer(theme, size: geometry.size, moves: !reduceMotion && !lowPower)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .accessibilityHidden(true)
    }
}

/// Une toile qui repeint le décor au rythme qu'il demande.
private struct SceneCanvas: View {
    let renderer: SceneRenderer
    let paused: Bool
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / renderer.frameRate, paused: paused || !renderer.moves)) { timeline in
            Canvas(opaque: true, rendersAsynchronously: true) { context, _ in
                renderer.draw(in: &context, at: timeline.date.timeIntervalSince(start))
            }
        }
    }
}

/// Les derniers décors construits. Dans le mode « un par mot », passer d'une
/// carte à l'autre change de décor : le suivant est souvent déjà prêt.
@MainActor
final class SceneCache {
    static let shared = SceneCache()

    struct Key: Hashable {
        var theme: String
        var width: Int
        var height: Int
        var moves: Bool

        init(theme: String, size: CGSize, moves: Bool) {
            self.theme = theme
            width = Int(size.width.rounded())
            height = Int(size.height.rounded())
            self.moves = moves
        }
    }

    private var ready: [Key: SceneRenderer] = [:]
    private var order: [Key] = []
    private var building: [Key: Task<SceneRenderer, Never>] = [:]
    private let capacity = 6

    func renderer(_ theme: SceneTheme, size: CGSize, moves: Bool) async -> SceneRenderer {
        let key = Key(theme: theme.id, size: size, moves: moves)
        if let found = ready[key] {
            touch(key)
            return found
        }
        let task = building[key] ?? Task { await SceneRenderer.make(theme: theme, size: size, moves: moves) }
        building[key] = task
        let made = await task.value
        building[key] = nil
        ready[key] = made
        touch(key)
        return made
    }

    /// La taille du dernier décor montré : celle du suivant. Avant le premier,
    /// celle de l'écran, que le décor couvre en entier.
    var lastSize: CGSize = {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return scene?.screen.bounds.size ?? .zero
    }()
    var lastMoves = true

    /// Prépare le décor de la carte suivante, à la taille de celle-ci.
    func prepareNext(_ theme: SceneTheme) {
        prepare(theme, size: lastSize, moves: lastMoves)
    }

    /// Prépare un décor qu'on verra bientôt, sans l'attendre.
    func prepare(_ theme: SceneTheme, size: CGSize, moves: Bool) {
        let key = Key(theme: theme.id, size: size, moves: moves)
        guard ready[key] == nil, building[key] == nil, size.width > 0 else { return }
        Task { _ = await renderer(theme, size: size, moves: moves) }
    }

    private func touch(_ key: Key) {
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > capacity {
            let old = order.removeFirst()
            ready[old] = nil
        }
    }
}
