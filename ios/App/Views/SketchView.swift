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

        for layer in plan.layers {
            guard let ink = context(w, h) else { continue }
            // Core compte en pixels depuis le haut ; Core Graphics depuis le bas.
            ink.translateBy(x: 0, y: CGFloat(h))
            ink.scaleBy(x: 1, y: -1)
            ink.setLineCap(.round)
            ink.setLineJoin(.round)
            for batch in layer.batches {
                ink.saveGState()
                if let clip = batch.clip {
                    if !clip.shape.isEmpty {
                        ink.addPath(polygon(clip.shape))
                        ink.clip()
                    }
                    // Chaque forme de devant se retire à son tour : deux formes
                    // qui se chevauchent ne se réannulent pas.
                    for cut in clip.cuts {
                        ink.addRect(full)
                        ink.addPath(polygon(cut))
                        ink.clip(using: .evenOdd)
                    }
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
                for line in batch.lines where line.points.count > 1 {
                    ink.setStrokeColor(color(batch.color, line.alpha))
                    ink.setLineWidth(line.width)
                    ink.addLines(between: line.points.map { CGPoint(x: $0.x, y: $0.y) })
                    ink.strokePath()
                }
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
        base.translateBy(x: 0, y: CGFloat(h))
        base.scaleBy(x: 1, y: -1)
        base.setFillColor(CGColor(srgbRed: 1, green: 0.99, blue: 0.965, alpha: 0.95))
        for glint in plan.glints {
            base.fillEllipse(in: CGRect(x: glint.center.x - glint.radius, y: glint.center.y - glint.radius, width: glint.radius * 2, height: glint.radius * 2))
        }
        return base.makeImage()
    }
}

/// Une image peinte. Elle ne change plus une fois faite : la passer d'un fil à
/// l'autre est sans risque.
struct Painted: @unchecked Sendable {
    let image: CGImage
}

/// Les dessins déjà peints : peindre coûte, et une carte revient souvent.
actor SketchCache {
    static let shared = SketchCache()

    struct Key: Hashable {
        var sketch: Sketch
        var width: Int
        var height: Int
        var head: Bool
        var frame: Int
    }

    private var images: [Key: Painted] = [:]
    private var order: [Key] = []

    func image(_ key: Key) async -> Painted? {
        if let image = images[key] { return image }
        let image = await Task.detached(priority: .userInitiated) { () -> Painted? in
            SketchPainter.image(key.sketch.plan(width: key.width, height: key.height, head: key.head, frame: key.frame)).map(Painted.init)
        }.value
        if let image {
            images[key] = image
            order.append(key)
            // Une trentaine de dessins suffit à une séance ; les plus vieux partent.
            if order.count > 36 { images[order.removeFirst()] = nil }
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @State private var frames: [CGImage] = []
    @State private var size: CGSize = .zero

    private static let boil = 3

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.16)) { timeline in
            let index = frames.isEmpty ? 0 : Int(timeline.date.timeIntervalSinceReferenceDate / 0.16) % frames.count
            ZStack {
                if frames.indices.contains(index) {
                    Image(decorative: frames[index], scale: min(displayScale, 2))
                        .resizable()
                        .interpolation(.high)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .task(id: Request(sketch: sketch, head: head, size: size, still: reduceMotion)) {
            guard size.width > 1, size.height > 1 else { return }
            let scale = min(displayScale, 2)
            let width = Int(size.width * scale), height = Int(size.height * scale)
            var painted: [CGImage] = []
            for frame in 0..<(reduceMotion ? 1 : Self.boil) {
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
