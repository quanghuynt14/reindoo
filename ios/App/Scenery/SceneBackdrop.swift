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
    @Environment(\.displayScale) private var displayScale
    @State private var built: SceneRenderer?
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    var body: some View {
        GeometryReader { geometry in
            let key = SceneCache.Key(theme: theme.id, size: geometry.size, moves: !reduceMotion && !lowPower)
            // Un décor déjà prêt se montre dès la première image, sans fondu
            // depuis le vide. Sinon, le précédent reste jusqu'à ce que le
            // nouveau soit construit.
            let shown = SceneCache.shared.ready(key) ?? built
            ZStack {
                if let shown {
                    SceneCanvas(renderer: shown, paused: paused)
                        .id(shown.id)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: shown?.id)
            .task(id: key) {
                guard geometry.size.width > 0, geometry.size.height > 0 else { return }
                SceneCache.shared.remember(size: geometry.size, moves: key.moves, displayScale: displayScale)
                built = await SceneCache.shared.renderer(theme, key: key)
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

/// Les décors construits, chauffés, prêts à peindre. Ils pèsent peu (quelques
/// centaines de chemins chacun) : tous les thèmes tiennent, et passer d'un mot
/// à l'autre, ou ouvrir l'onglet, ne construit plus rien.
final class SceneCache: @unchecked Sendable {
    static let shared = SceneCache()

    struct Key: Hashable, Sendable {
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

        var size: CGSize { CGSize(width: width, height: height) }
    }

    private let lock = NSLock()
    private var built: [Key: SceneRenderer] = [:]
    private var order: [Key] = []
    private var building: [Key: Task<SceneRenderer, Never>] = [:]
    /// Tous les thèmes, à deux tailles (l'écran tourne) : rien ne part de ce
    /// qu'on vient de chauffer.
    private let capacity = SceneTheme.all.count * 2

    /// La taille du dernier décor montré : celle des suivants. Avant le
    /// premier, celle de l'écran, que le décor couvre en entier.
    private var size = CGSize.zero
    private var moves = true
    private var displayScale = 3.0

    /// Le décor, s'il est déjà prêt. Ne construit rien, n'attend rien.
    func ready(_ key: Key) -> SceneRenderer? {
        lock.withLock { built[key] }
    }

    func remember(size: CGSize, moves: Bool, displayScale: Double) {
        lock.withLock { (self.size, self.moves, self.displayScale) = (size, moves, displayScale) }
    }

    func renderer(_ theme: SceneTheme, key: Key, priority: TaskPriority = .userInitiated) async -> SceneRenderer {
        let (found, task): (SceneRenderer?, Task<SceneRenderer, Never>?) = lock.withLock {
            if let found = built[key] {
                touch(key)
                return (found, nil)
            }
            if let running = building[key] { return (nil, running) }
            let scale = displayScale
            let made = Task { await SceneRenderer.make(theme: theme, size: key.size, moves: key.moves, displayScale: scale, priority: priority) }
            building[key] = made
            return (nil, made)
        }
        if let found { return found }
        let made = await task!.value
        lock.withLock {
            building[key] = nil
            built[key] = made
            touch(key)
        }
        return made
    }

    /// Prépare un décor qu'on verra bientôt, à la taille du dernier montré.
    func prepare(_ theme: SceneTheme) {
        let key = nextKey(theme)
        guard key.width > 0 else { return }
        Task { _ = await renderer(theme, key: key) }
    }

    /// Chauffe tous les thèmes, l'un après l'autre et sans presser : d'abord
    /// ceux qu'on verra en premier, puis le reste. Le paquet se rebat quand
    /// l'historique change, et « un par mot » peut alors tomber sur n'importe
    /// lequel ; le sélecteur aussi.
    func warmAll(first: [SceneTheme], size: CGSize, moves: Bool, displayScale: Double) {
        guard size.width > 0, size.height > 0 else { return }
        remember(size: size, moves: moves, displayScale: displayScale)
        let firstIDs = Set(first.map(\.id))
        let rest = SceneTheme.all.filter { !firstIDs.contains($0.id) }
        Task.detached(priority: .utility) {
            for theme in first { _ = await self.renderer(theme, key: self.nextKey(theme)) }
            for theme in rest { _ = await self.renderer(theme, key: self.nextKey(theme), priority: .utility) }
        }
    }

    private func nextKey(_ theme: SceneTheme) -> Key {
        lock.withLock { Key(theme: theme.id, size: size, moves: moves) }
    }

    /// Appelé sous le verrou.
    private func touch(_ key: Key) {
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > capacity {
            let old = order.removeFirst()
            built[old] = nil
        }
    }
}
