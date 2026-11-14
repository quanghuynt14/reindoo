import CoreGraphics
import Foundation
import ReindooCore
import SwiftUI

/// Un geste de Core, traduit une fois : chemins Core Graphics, glyphes trouvés.
indirect enum PaintOp {
    case layer(Layer, clip: CGPath?, [PaintOp], mask: [PaintOp]?)
    case fill(CGPath, ResolvedPaint, evenOdd: Bool)
    case stroke(CGPath, dots: CGPath?, ResolvedPaint, SwiftUI.StrokeStyle)
    case glyphs(GlyphRun, ResolvedPaint)

    static func compile(_ ops: [DrawOp], _ cache: GeometryCache) -> [PaintOp] { ops.map { compile($0, cache) } }

    static func compile(_ op: DrawOp, _ cache: GeometryCache) -> PaintOp {
        switch op {
        case .layer(let layer, let inner, let mask):
            let clip: CGPath? = layer.clip.map { paths in
                let joined = CGMutablePath()
                for path in paths { joined.addPath(cache.path(path)) }
                return joined
            }
            return .layer(layer, clip: clip, compile(inner, cache), mask: mask.map { compile($0, cache) })
        case .fill(let path, let paint, let evenOdd):
            return .fill(cache.path(path), paint, evenOdd: evenOdd)
        case .stroke(let path, let paint, let style):
            var dash = style.dash.map { CGFloat($0) }
            var phase = CGFloat(style.dashOffset)
            let period = dash.reduce(0, +)
            if period > 0 {
                // Un décalage négatif avance le motif, comme en SVG.
                phase = phase.truncatingRemainder(dividingBy: period)
                if phase < 0 { phase += period }
            } else {
                dash = []
                phase = 0
            }
            let stroke = SwiftUI.StrokeStyle(lineWidth: style.width, lineCap: style.cap.cg, lineJoin: .round, dash: dash, dashPhase: phase)
            if style.cap == .round && dash.isEmpty {
                let split = cache.dots(path, radius: style.width / 2)
                return .stroke(split.rest, dots: split.dots, paint, stroke)
            }
            return .stroke(cache.path(path), dots: nil, paint, stroke)
        case .glyphs(let glyphs, let paint, let size, let weight):
            return .glyphs(cache.run(glyphs, size: size, weight: weight), paint)
        }
    }
}

/// La géométrie déjà traduite, sous le numéro que Core donne à chaque chemin
/// et à chaque suite de glyphes. D'une image à l'autre, seuls bougent les
/// transformations, les opacités et les tirets : les formes restent.
final class GeometryCache: @unchecked Sendable {
    private struct DotKey: Hashable {
        var path: Int
        var radius: Double
    }

    private struct RunKey: Hashable {
        var glyphs: Int
        var size: Double
        var weight: Int
    }

    private let lock = NSLock()
    private var paths: [Int: CGPath] = [:]
    private var split: [DotKey: (CGPath, CGPath?)] = [:]
    private var runs: [RunKey: GlyphRun] = [:]

    func path(_ data: PathData) -> CGPath {
        guard let key = data.key else { return data.cgPath }
        lock.lock()
        defer { lock.unlock() }
        if let found = paths[key] { return found }
        let made = data.cgPath
        paths[key] = made
        return made
    }

    /// Les épaisseurs animées (la trame de Halftone) passent par une poignée de
    /// valeurs : chacune est gardée.
    func dots(_ data: PathData, radius: Double) -> (rest: CGPath, dots: CGPath?) {
        guard let key = data.key else { return data.splitDots(radius: radius) }
        let dotKey = DotKey(path: key, radius: (radius * 100).rounded() / 100)
        lock.lock()
        defer { lock.unlock() }
        if let found = split[dotKey] { return found }
        let made = data.splitDots(radius: dotKey.radius)
        split[dotKey] = made
        return made
    }

    func run(_ glyphs: Glyphs, size: Double, weight: Int) -> GlyphRun {
        guard let key = glyphs.key else { return GlyphRun(glyphs, size: size, weight: weight) }
        let runKey = RunKey(glyphs: key, size: size, weight: weight)
        lock.lock()
        defer { lock.unlock() }
        if let found = runs[runKey] { return found }
        let made = GlyphRun(glyphs, size: size, weight: weight)
        runs[runKey] = made
        return made
    }
}

/// Peint un décor. Ce qui ne bouge pas est traduit une fois ; ce qui bouge est
/// redemandé à Core à chaque image. Les motifs deviennent des tuiles, rendues
/// par Core Graphics à la finesse où elles s'affichent.
final class SceneRenderer: @unchecked Sendable {
    enum Part {
        case still([PaintOp])
        case live([Node], SceneStyle)
    }

    let id = UUID()
    /// Le décor planifié, aux chemins numérotés.
    let scene: SceneGraph
    private let cache: GeometryCache
    let frameRate: Double
    let moves: Bool
    private let parts: [Part]
    private let lock = NSLock()
    private var tiles: [String: Image] = [:]

    init(scene graph: SceneGraph, frameRate: Double, moves: Bool) {
        let plan = graph.plan(motion: moves)
        scene = plan.scene
        self.frameRate = frameRate
        self.moves = moves
        let cache = GeometryCache()
        self.cache = cache
        parts = plan.parts.map { part in
            switch part {
            case .still(let ops): .still(PaintOp.compile(ops, cache))
            case .live(let nodes, let style): .live(nodes, style)
            }
        }
    }

    /// Construit le décor hors du fil principal : un décor prend quelques
    /// dizaines de millisecondes à calculer.
    static func make(theme: SceneTheme, size: CGSize, moves: Bool) async -> SceneRenderer {
        await Task.detached(priority: .userInitiated) {
            SceneRenderer(scene: theme.scene(width: size.width, height: size.height), frameRate: theme.frameRate, moves: moves)
        }.value
    }

    func draw(in context: inout GraphicsContext, at time: Double) {
        context.scaleBy(x: scene.pointsPerUnit, y: scene.pointsPerUnit)
        for part in parts {
            switch part {
            case .still(let ops): replay(ops, in: &context)
            case .live(let nodes, let style): replay(PaintOp.compile(scene.record(nodes, style, at: moves ? time : nil), cache), in: &context)
            }
        }
    }

    // MARK: Rejouer dans un GraphicsContext

    private func replay(_ ops: [PaintOp], in context: inout GraphicsContext) {
        for op in ops { replay(op, in: &context) }
    }

    private func replay(_ op: PaintOp, in context: inout GraphicsContext) {
        switch op {
        case .layer(let layer, let clip, let inner, let mask):
            var c = context
            c.concatenate(layer.transform.cg)
            if let clip { c.clip(to: Path(clip)) }
            let isolated = layer.opacity < 1 || mask != nil || layer.blend != .normal
            guard isolated else {
                replay(inner, in: &c)
                return
            }
            c.opacity *= layer.opacity
            c.blendMode = layer.blend == .multiply ? .multiply : layer.blend == .screen ? .screen : .normal
            c.drawLayer { l in
                if let region = layer.maskRegion {
                    l.clip(to: Path(CGRect(x: region.x, y: region.y, width: region.width, height: region.height)))
                }
                self.replay(inner, in: &l)
                if let mask {
                    // Le masque garde ce qui est sous son alpha : Core a déjà fait
                    // de sa luminance un alpha.
                    l.blendMode = .destinationIn
                    l.drawLayer { m in self.replay(mask, in: &m) }
                }
            }
        case .fill(let path, let paint, let evenOdd):
            shade(path, paint, in: &context) { c, p, shading in c.fill(p, with: shading, style: FillStyle(eoFill: evenOdd)) }
        case .stroke(let path, let dots, let paint, let style):
            shade(path, paint, in: &context) { c, p, shading in c.stroke(p, with: shading, style: style) }
            if let dots { shade(dots, paint, in: &context) { c, p, shading in c.fill(p, with: shading) } }
        case .glyphs(let run, let paint):
            guard case .color(let color) = paint else { return }
            context.withCGContext { cg in run.draw(in: cg, color: color.cg) }
        }
    }

    /// Peint un chemin avec une couleur, un dégradé ou un motif. Un dégradé en
    /// unités de boîte se peint dans le repère de la boîte.
    private func shade(_ path: CGPath, _ paint: ResolvedPaint, in context: inout GraphicsContext,
                       _ draw: (inout GraphicsContext, Path, GraphicsContext.Shading) -> Void) {
        switch paint {
        case .color(let color):
            draw(&context, Path(path), .color(color.color))
        case .linear(let start, let end, let transform, let stops):
            var c = context
            c.concatenate(transform.cg)
            draw(&c, Path(path).applying(transform.cg.inverted()),
                 .linearGradient(stops.gradient, startPoint: CGPoint(x: start.x, y: start.y), endPoint: CGPoint(x: end.x, y: end.y)))
        case .radial(let center, let radius, let transform, let stops):
            var c = context
            c.concatenate(transform.cg)
            draw(&c, Path(path).applying(transform.cg.inverted()),
                 .radialGradient(stops.gradient, center: CGPoint(x: center.x, y: center.y), startRadius: 0, endRadius: radius))
        case .pattern(let name, let pattern, let opacity):
            let t = context.transform
            let pixels = (abs(t.a * t.d - t.b * t.c)).squareRoot() * context.environment.displayScale
            guard pixels > 0, let image = tile(name, pattern, pixels: pixels) else { return }
            var c = context
            c.opacity *= opacity
            draw(&c, Path(path), .tiledImage(image, origin: CGPoint(x: pattern.x, y: pattern.y), scale: 1 / pixels))
        }
    }

    // MARK: Les tuiles des motifs

    /// La tuile d'un motif, rendue à `pixels` pixels par unité. Gardée : la
    /// finesse change peu d'une image à l'autre.
    private func tile(_ name: String, _ pattern: Pattern, pixels: Double) -> Image? {
        let step = max(1, (pixels * 4).rounded() / 4)
        let key = "\(name)@\(step)"
        lock.lock()
        defer { lock.unlock() }
        if let cached = tiles[key] { return cached }
        let width = max(1, Int((pattern.width * step).rounded())), height = max(1, Int((pattern.height * step).rounded()))
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        // L'axe y des décors descend ; celui d'un bitmap monte.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: CGFloat(width) / pattern.width, y: -CGFloat(height) / pattern.height)
        var recorder = OpRecorder()
        scene.paint(pattern.nodes, at: nil, into: &recorder)
        CGReplay.replay(PaintOp.compile(recorder.ops, cache), in: context)
        guard let made = context.makeImage() else { return nil }
        let image = Image(decorative: made, scale: 1)
        tiles[key] = image
        return image
    }
}

/// Les mêmes gestes, rejoués dans un contexte Core Graphics : pour les tuiles,
/// qui se rendent hors de l'écran.
enum CGReplay {
    static func replay(_ ops: [PaintOp], in context: CGContext) {
        for op in ops { replay(op, in: context) }
    }

    static func replay(_ op: PaintOp, in context: CGContext) {
        switch op {
        case .layer(let layer, let clip, let inner, let mask):
            context.saveGState()
            context.concatenate(layer.transform.cg)
            if let clip {
                context.addPath(clip)
                context.clip()
            }
            let isolated = layer.opacity < 1 || mask != nil || layer.blend != .normal
            if isolated {
                context.setAlpha(layer.opacity)
                context.setBlendMode(layer.blend == .multiply ? .multiply : layer.blend == .screen ? .screen : .normal)
                context.beginTransparencyLayer(auxiliaryInfo: nil)
                context.setAlpha(1)
                context.setBlendMode(.normal)
            }
            replay(inner, in: context)
            if let mask {
                context.setBlendMode(.destinationIn)
                context.beginTransparencyLayer(auxiliaryInfo: nil)
                context.setBlendMode(.normal)
                replay(mask, in: context)
                context.endTransparencyLayer()
            }
            if isolated { context.endTransparencyLayer() }
            context.restoreGState()
        case .fill(let path, let paint, let evenOdd):
            paintPath(path, paint, in: context) { $0.fillPath(using: evenOdd ? .evenOdd : .winding) }
        case .stroke(let path, let dots, let paint, let style):
            context.saveGState()
            context.setLineWidth(style.lineWidth)
            context.setLineCap(style.lineCap)
            context.setLineJoin(style.lineJoin)
            if !style.dash.isEmpty { context.setLineDash(phase: style.dashPhase, lengths: style.dash) }
            if case .color = paint {
                paintPath(path, paint, in: context) { $0.strokePath() }
            } else {
                context.addPath(path)
                context.replacePathWithStrokedPath()
                if let stroked = context.path { paintPath(stroked, paint, in: context) { $0.fillPath() } }
            }
            context.restoreGState()
            if let dots { paintPath(dots, paint, in: context) { $0.fillPath() } }
        case .glyphs(let run, let paint):
            if case .color(let color) = paint { run.draw(in: context, color: color.cg) }
        }
    }

    private static func paintPath(_ path: CGPath, _ paint: ResolvedPaint, in context: CGContext, _ finish: (CGContext) -> Void) {
        switch paint {
        case .color(let color):
            context.saveGState()
            context.setFillColor(color.cg)
            context.setStrokeColor(color.cg)
            context.addPath(path)
            finish(context)
            context.restoreGState()
        case .linear(let start, let end, let transform, let stops):
            guard let gradient = stops.cgGradient else { return }
            context.saveGState()
            context.addPath(path)
            context.clip()
            context.concatenate(transform.cg)
            context.drawLinearGradient(gradient, start: CGPoint(x: start.x, y: start.y), end: CGPoint(x: end.x, y: end.y),
                                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            context.restoreGState()
        case .radial(let center, let radius, let transform, let stops):
            guard let gradient = stops.cgGradient else { return }
            context.saveGState()
            context.addPath(path)
            context.clip()
            context.concatenate(transform.cg)
            let c = CGPoint(x: center.x, y: center.y)
            context.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [.drawsAfterEndLocation])
            context.restoreGState()
        case .pattern:
            // Pas de motif dans un motif, dans aucun des décors.
            break
        }
    }
}
