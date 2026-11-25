import CoreGraphics
import ReindooCore
import SwiftUI

/// Peint un dessin de Core : les couches de traits, mangées par le grain du
/// papier, posées l'une sur l'autre. Core a décidé de chaque trait ; ici, on
/// ne fait que les poser.
enum SketchPainter {
    private static var space: CGColorSpace { CGColorSpace(name: CGColorSpace.sRGB)! }
    private static let info = CGImageAlphaInfo.premultipliedLast.rawValue

    private static func context(_ width: Int, _ height: Int) -> CGContext? {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space, bitmapInfo: info)
    }

    private static func pixels(_ context: CGContext) -> UnsafeMutableBufferPointer<UInt8>? {
        guard let data = context.data else { return nil }
        return UnsafeMutableBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: context.bytesPerRow * context.height)
    }

    private static func polygon(_ points: [Pt]) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: points.map { CGPoint(x: $0.x, y: $0.y) })
        path.closeSubpath()
        return path
    }

    private static func color(_ c: RGBA, _ alpha: Double) -> CGColor {
        CGColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: c.a * alpha)
    }

    /// Les versions d'un même dessin. Seul le contour change de l'une à
    /// l'autre : le papier, les couleurs et les ombres se peignent une fois,
    /// puis chaque version n'y pose que son crayon.
    static func frames(_ plans: [SketchPlan]) -> [CGImage] {
        guard let first = plans.first else { return [] }
        let w = first.width, h = first.height
        guard let base = context(w, h), let paper = pixels(base) else { return [] }
        let tooth = Paper.tooth(width: w, height: h)
        Paper.sheet(tooth, width: w, height: h, into: paper)
        let full = CGRect(x: 0, y: 0, width: w, height: h)
        // Core compte en pixels depuis le haut ; Core Graphics depuis le bas.
        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(h))
        // Une même liste de formes de devant revient d'une couche à l'autre :
        // son masque se calcule une fois par dessin.
        var masks: [[[Pt]]: CGImage] = [:]
        for layer in first.layers.dropLast() {
            paint(layer, onto: base, tooth: tooth, flip: flip, masks: &masks)
        }
        guard let under = base.makeImage() else { return [] }

        var images: [CGImage] = []
        for plan in plans {
            guard let sheet = context(w, h) else { break }
            sheet.draw(under, in: full)
            if let ink = plan.layers.last { paint(ink, onto: sheet, tooth: tooth, flip: flip, masks: &masks) }
            sheet.setBlendMode(.normal)
            sheet.concatenate(flip)
            sheet.setFillColor(CGColor(srgbRed: 1, green: 0.99, blue: 0.965, alpha: 0.95))
            for glint in plan.glints {
                sheet.fillEllipse(in: CGRect(x: glint.center.x - glint.radius, y: glint.center.y - glint.radius, width: glint.radius * 2, height: glint.radius * 2))
            }
            if let image = sheet.makeImage() { images.append(image) }
        }
        return images
    }

    /// Une couche : peinte à part, mangée par le grain, puis posée sur la feuille.
    private static func paint(_ layer: SketchPlan.Layer, onto base: CGContext, tooth: [Float], flip: CGAffineTransform, masks: inout [[[Pt]]: CGImage]) {
        let w = base.width, h = base.height
        let full = CGRect(x: 0, y: 0, width: w, height: h)
        guard let ink = context(w, h) else { return }
        ink.setLineCap(.round)
        ink.setLineJoin(.round)
        for batch in layer.batches {
            ink.saveGState()
            if let clip = batch.clip, !clip.cuts.isEmpty {
                let mask = masks[clip.cuts] ?? cutout(clip.cuts, width: w, height: h, flip: flip)
                masks[clip.cuts] = mask
                if let mask { ink.clip(to: full, mask: mask) }
            }
            ink.concatenate(flip)
            if let clip = batch.clip, !clip.shape.isEmpty {
                ink.addPath(polygon(clip.shape))
                ink.clip()
            }
            if let wash = batch.wash {
                let rect = CGRect(x: wash.rect.0.x, y: wash.rect.0.y, width: wash.rect.1.x - wash.rect.0.x, height: wash.rect.1.y - wash.rect.0.y)
                if wash.radial, let gradient = CGGradient(colorsSpace: space, colors: [color(batch.color, wash.alpha), color(batch.color, 0)] as CFArray, locations: [0, 1]) {
                    let center = CGPoint(x: rect.midX, y: rect.midY)
                    ink.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: max(rect.width, rect.height) / 2, options: [])
                } else {
                    ink.setFillColor(color(batch.color, wash.alpha))
                    ink.fill(rect)
                }
            }
            stroke(batch.lines, color: batch.color, in: ink)
            if !batch.erase.isEmpty {
                ink.setBlendMode(.clear)
                for shape in batch.erase { ink.addPath(polygon(shape)); ink.fillPath() }
                ink.setBlendMode(.normal)
            }
            ink.restoreGState()
        }
        if let layerPixels = pixels(ink) {
            Paper.bite(layerPixels, tooth: tooth, threshold: layer.threshold, softness: layer.softness)
        }
        guard let painted = ink.makeImage() else { return }
        base.setBlendMode(layer.blend == .multiply ? .multiply : .normal)
        base.draw(painted, in: full)
    }

    /// Les traits d'un lot, rangés par force et par épaisseur : un seul geste
    /// de Core Graphics par rangée au lieu d'un par trait. Des dizaines de
    /// milliers de traits deviennent quelques centaines de chemins.
    private static func stroke(_ lines: [SketchPlan.Line], color c: RGBA, in ink: CGContext) {
        var rows: [Int: CGMutablePath] = [:]
        for line in lines where line.points.count > 1 {
            let a = min(23, max(0, Int(line.alpha * 24))), wide = min(399, max(0, Int(line.width * 4)))
            let path = rows[a * 400 + wide] ?? CGMutablePath()
            path.addLines(between: line.points.map { CGPoint(x: $0.x, y: $0.y) })
            rows[a * 400 + wide] = path
        }
        for (key, path) in rows {
            ink.setStrokeColor(color(c, (Double(key / 400) + 0.5) / 24))
            ink.setLineWidth((CGFloat(key % 400) + 0.5) / 4)
            ink.addPath(path)
            ink.strokePath()
        }
    }

    /// Le masque d'une zone : blanc partout, sauf sous les formes de devant.
    private static func cutout(_ cuts: [[Pt]], width: Int, height: Int, flip: CGAffineTransform) -> CGImage? {
        guard let mask = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        mask.setFillColor(gray: 1, alpha: 1)
        mask.fill(CGRect(x: 0, y: 0, width: width, height: height))
        mask.concatenate(flip)
        mask.setFillColor(gray: 0, alpha: 1)
        for cut in cuts { mask.addPath(polygon(cut)); mask.fillPath() }
        return mask.makeImage()
    }

    /// Rien que le crayon, sans papier : pour un signe que le texte teinte.
    static func pencil(_ plan: SketchPlan) -> CGImage? {
        guard let layer = plan.layers.last, let ink = context(plan.width, plan.height) else { return nil }
        ink.translateBy(x: 0, y: CGFloat(plan.height))
        ink.scaleBy(x: 1, y: -1)
        ink.setLineCap(.round)
        ink.setLineJoin(.round)
        for batch in layer.batches { stroke(batch.lines, color: batch.color, in: ink) }
        return ink.makeImage()
    }
}

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

/// Les versions peintes d'un dessin. Elles ne changent plus une fois faites :
/// les passer d'un fil à l'autre est sans risque.
struct Painted: @unchecked Sendable {
    let images: [CGImage]
}

/// Les dessins déjà peints : peindre coûte, et une carte revient souvent.
/// On peut y lire sans attendre : une vue qui revient à l'écran retrouve son
/// dessin dès sa première image, sans passer par une feuille vide.
/// Le budget se compte en octets : une tête pèse peu, un décor plein écran beaucoup.
final class SketchCache: @unchecked Sendable {
    static let shared = SketchCache()

    struct Key: Hashable {
        var sketch: Sketch
        var width: Int
        var height: Int
        var head: Bool
        var frames: Int
    }

    private static let budget = 96 << 20
    private let lock = NSLock()
    private var images: [Key: Painted] = [:]
    private var order: [Key] = []
    private var bytes = 0
    /// Deux vues qui demandent le même dessin attendent la même peinture.
    private var running: [Key: Task<Painted, Never>] = [:]

    func cached(_ key: Key) -> [CGImage]? {
        lock.withLock {
            guard let painted = images[key] else { return nil }
            if let i = order.firstIndex(of: key) { order.remove(at: i) }
            order.append(key)
            return painted.images
        }
    }

    func frames(_ key: Key, priority: TaskPriority = .userInitiated) async -> [CGImage] {
        if let ready = cached(key) { return ready }
        let task = lock.withLock { () -> Task<Painted, Never> in
            if let task = running[key] { return task }
            let task = Task.detached(priority: priority) {
                Painted(images: SketchPainter.frames((0..<key.frames).map {
                    key.sketch.plan(width: key.width, height: key.height, head: key.head, frame: $0)
                }))
            }
            running[key] = task
            return task
        }
        let painted = await task.value
        lock.withLock {
            running[key] = nil
            guard images[key] == nil, !painted.images.isEmpty else { return }
            images[key] = painted
            order.append(key)
            bytes += painted.images.reduce(0) { $0 + $1.bytesPerRow * $1.height }
            while bytes > Self.budget, order.count > 1 {
                let old = order.removeFirst()
                if let gone = images.removeValue(forKey: old) { bytes -= gone.images.reduce(0) { $0 + $1.bytesPerRow * $1.height } }
            }
        }
        return painted.images
    }
}

/// Un dessin de Core à l'écran. Le trait « bout » : trois versions du même
/// dessin se succèdent, comme dans un dessin animé fait à la main ; seul le
/// contour tremble. Immobile si l'utilisateur demande moins de mouvement.
struct SketchView: View {
    let sketch: Sketch
    /// Seulement la tête, pour un bouton ou un avatar.
    var head = false
    /// Une seule version : un décor ne bout pas, il reste derrière.
    var still = false
    /// Pixels par point, au plus. Un décor flou de pastel n'a pas besoin de la
    /// finesse d'un visage : moins de pixels, il se peint plus vite.
    var sharpness: CGFloat = 2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @State private var frames: [CGImage] = []
    @State private var size: CGSize = .zero

    private static let beat = 0.2

    var body: some View {
        // Une image seule ne change pas : rien à redessiner cinq fois par seconde.
        TimelineView(.animation(minimumInterval: Self.beat, paused: frames.count < 2)) { timeline in
            let index = frames.isEmpty ? 0 : Int(timeline.date.timeIntervalSinceReferenceDate / Self.beat) % frames.count
            ZStack {
                if frames.indices.contains(index) {
                    Image(decorative: frames[index], scale: min(displayScale, sharpness))
                        .resizable()
                        .interpolation(.high)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { new in
            size = new
            if let key = key(new), let ready = SketchCache.shared.cached(key) { frames = ready }
        }
        .task(id: key(size)) {
            guard let key = key(size) else { return }
            if let ready = SketchCache.shared.cached(key) { frames = ready; return }
            let painted = await SketchCache.shared.frames(key)
            if Task.isCancelled { return }
            // Un dessin qui arrive sur une feuille vide se pose doucement ; une
            // humeur qui change remplace l'autre sans clignoter.
            if frames.isEmpty {
                withAnimation(.easeOut(duration: 0.2)) { frames = painted }
            } else {
                frames = painted
            }
        }
        .accessibilityHidden(true)
    }

    private func key(_ size: CGSize) -> SketchCache.Key? {
        Self.key(sketch, size: size, head: head, still: still || reduceMotion, sharpness: sharpness, displayScale: displayScale)
    }

    static func key(_ sketch: Sketch, size: CGSize, head: Bool = false, still: Bool, sharpness: CGFloat = 2, displayScale: CGFloat) -> SketchCache.Key? {
        guard size.width > 1, size.height > 1 else { return nil }
        let scale = min(displayScale, sharpness)
        return .init(sketch: sketch, width: Int(size.width * scale), height: Int(size.height * scale), head: head, frames: still ? 1 : 3)
    }
}
