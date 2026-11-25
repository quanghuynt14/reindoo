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

    static func image(_ plan: SketchPlan) -> CGImage? {
        let w = plan.width, h = plan.height
        guard let base = context(w, h), let paper = pixels(base) else { return nil }
        let tooth = Paper.tooth(width: w, height: h)
        Paper.sheet(tooth, width: w, height: h, into: paper)
        let full = CGRect(x: 0, y: 0, width: w, height: h)
        // Core compte en pixels depuis le haut ; Core Graphics depuis le bas.
        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(h))
        // Une même liste de formes de devant revient d'une couche à l'autre :
        // son masque se calcule une fois par dessin.
        var masks: [[[Pt]]: CGImage] = [:]

        for layer in plan.layers {
            guard let ink = context(w, h) else { continue }
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
            guard let painted = ink.makeImage() else { continue }
            base.setBlendMode(layer.blend == .multiply ? .multiply : .normal)
            base.draw(painted, in: full)
        }

        base.setBlendMode(.normal)
        base.concatenate(flip)
        base.setFillColor(CGColor(srgbRed: 1, green: 0.99, blue: 0.965, alpha: 0.95))
        for glint in plan.glints {
            base.fillEllipse(in: CGRect(x: glint.center.x - glint.radius, y: glint.center.y - glint.radius, width: glint.radius * 2, height: glint.radius * 2))
        }
        return base.makeImage()
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

/// Une image peinte. Elle ne change plus une fois faite : la passer d'un fil à
/// l'autre est sans risque.
struct Painted: @unchecked Sendable {
    let image: CGImage
}

/// Les dessins déjà peints : peindre coûte, et une carte revient souvent.
/// Le budget se compte en octets : une tête pèse peu, un décor plein écran beaucoup.
actor SketchCache {
    static let shared = SketchCache()

    struct Key: Hashable {
        var sketch: Sketch
        var width: Int
        var height: Int
        var head: Bool
        var frame: Int
    }

    private static let budget = 96 << 20
    private var images: [Key: Painted] = [:]
    private var order: [Key] = []
    private var bytes = 0
    /// Deux vues qui demandent le même dessin attendent la même peinture.
    private var running: [Key: Task<Painted?, Never>] = [:]

    func image(_ key: Key) async -> Painted? {
        if let image = images[key] {
            if let i = order.firstIndex(of: key) { order.remove(at: i) }
            order.append(key)
            return image
        }
        if let task = running[key] { return await task.value }
        let task = Task.detached(priority: .userInitiated) { () -> Painted? in
            SketchPainter.image(key.sketch.plan(width: key.width, height: key.height, head: key.head, frame: key.frame)).map(Painted.init)
        }
        running[key] = task
        let image = await task.value
        running[key] = nil
        if let image, images[key] == nil {
            images[key] = image
            order.append(key)
            bytes += image.image.bytesPerRow * image.image.height
            while bytes > Self.budget, order.count > 1 {
                let old = order.removeFirst()
                if let gone = images.removeValue(forKey: old) { bytes -= gone.image.bytesPerRow * gone.image.height }
            }
        }
        return image
    }
}

/// Un dessin de la girafe ou du chacal. Le trait « bout » : trois versions du
/// même dessin se succèdent, comme dans un dessin animé fait à la main.
/// Immobile si l'utilisateur demande moins de mouvement.
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

    private static let boil = 3

    var body: some View {
        // Une image seule ne change pas : rien à redessiner six fois par seconde.
        TimelineView(.animation(minimumInterval: 0.16, paused: frames.count < 2)) { timeline in
            let index = frames.isEmpty ? 0 : Int(timeline.date.timeIntervalSinceReferenceDate / 0.16) % frames.count
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
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .task(id: Request(sketch: sketch, head: head, size: size, still: reduceMotion || still)) {
            guard size.width > 1, size.height > 1 else { return }
            let scale = min(displayScale, sharpness)
            let width = Int(size.width * scale), height = Int(size.height * scale)
            var painted: [CGImage] = []
            for frame in 0..<(reduceMotion || still ? 1 : Self.boil) {
                let key = SketchCache.Key(sketch: sketch, width: width, height: height, head: head, frame: frame)
                guard let image = await SketchCache.shared.image(key) else { break }
                if Task.isCancelled { return }
                painted.append(image.image)
                // La première version se montre tout de suite ; les autres suivent.
                if frame == 0 { withAnimation(.easeOut(duration: 0.2)) { frames = painted } }
            }
            frames = painted
        }
        .accessibilityHidden(true)
    }

    private struct Request: Equatable {
        var sketch: Sketch
        var head: Bool
        var size: CGSize
        var still: Bool
    }
}
