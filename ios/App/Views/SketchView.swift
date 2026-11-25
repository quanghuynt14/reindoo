import CoreGraphics
import ImageIO
import ReindooCore
import SwiftUI

/// Les signes tracés à la main. Petits : on les trace sur place, une fois.
enum Hand {
    @MainActor private static var images: [String: Image] = [:]

    @MainActor static func glyph(_ glyph: Glyph, size: CGFloat = 20) -> Image {
        let key = "\(glyph.rawValue).\(size)"
        if let image = images[key] { return image }
        let pixels = Int(size * 3)
        guard let drawn = SketchPainter.pencil(Sketch.glyph(glyph).plan(width: pixels, height: pixels)) else { return Image(systemName: "circle") }
        let image = Image(decorative: drawn, scale: 3).renderingMode(.template)
        images[key] = image
        return image
    }
}

/// Les dessins, peints à la construction de l'app et rangés dans son paquet.
/// Les lire et les décoder prend quelques millisecondes : assez peu pour le
/// faire au moment où la vue se dessine. Une vue n'a donc jamais de feuille
/// vide, ni rien qui apparaisse après coup.
final class SketchCache: @unchecked Sendable {
    static let shared = SketchCache()

    private let lock = NSLock()
    private var images: [Still: CGImage] = [:]
    /// Ceux que le paquet n'a pas : on les peint ici, une fois.
    private var running: [Still: Task<Painted, Never>] = [:]

    private struct Painted: @unchecked Sendable { let image: CGImage? }

    /// Le dessin, tout de suite, s'il est dans le paquet ou déjà peint.
    func image(_ still: Still) -> CGImage? {
        if let image = lock.withLock({ images[still] }) { return image }
        guard let url = Bundle.main.url(forResource: still.name, withExtension: "jpg"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              // Décodé ici, pas plus tard pendant un défilement.
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { return nil }
        lock.withLock { images[still] = image }
        return image
    }

    /// Le secours, pour un dessin oublié du paquet : peint à part.
    func paint(_ still: Still) async -> CGImage? {
        if let ready = image(still) { return ready }
        let task = lock.withLock { () -> Task<Painted, Never> in
            if let task = running[still] { return task }
            let task = Task.detached(priority: .userInitiated) { Painted(image: SketchPainter.paint(still.plan())) }
            running[still] = task
            return task
        }
        let painted = await task.value
        lock.withLock {
            running[still] = nil
            if let image = painted.image { images[still] = image }
        }
        return painted.image
    }

    /// Lit d'avance ceux que l'écran suivant montrera.
    func warm(_ stills: [Still]) async {
        await Task.detached(priority: .utility) {
            for still in stills { _ = self.image(still) }
        }.value
    }
}

/// Un dessin de Core à l'écran. Il ne bouge pas : un dessin qui tremble se
/// lit comme un écran qui clignote.
struct SketchView: View {
    let still: Still

    @State private var painted: CGImage?

    init(_ still: Still) { self.still = still }

    var body: some View {
        let image = SketchCache.shared.image(still) ?? painted
        Color.clear
            .overlay {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: still.fills ? .fill : .fit)
                }
            }
            .clipped()
            .task(id: still) {
                guard SketchCache.shared.image(still) == nil else { return }
                painted = await SketchCache.shared.paint(still)
            }
            .accessibilityHidden(true)
    }
}
