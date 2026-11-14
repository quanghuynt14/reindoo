import Foundation

/// Une peinture résolue : plus de renvoi aux `defs`, plus d'unités relatives,
/// l'opacité de remplissage déjà appliquée.
public enum ResolvedPaint: Sendable {
    case color(RGBA)
    /// Un dégradé linéaire, de `start` à `end`, puis `transform`. En unités de
    /// la boîte, `transform` étire le carré unité sur la boîte : les bandes du
    /// dégradé restent perpendiculaires dans la boîte, comme en SVG.
    case linear(start: Point, end: Point, transform: Affine, stops: [Stop])
    /// Un dégradé radial : un cercle de centre `center` et de rayon `radius`,
    /// puis `transform`, qui en fait une ellipse quand la boîte n'est pas carrée.
    case radial(center: Point, radius: Double, transform: Affine, stops: [Stop])
    case pattern(name: String, Pattern, opacity: Double)
}

public struct StrokeStyle: Sendable {
    public var width: Double
    public var cap: LineCap
    public var dash: [Double]
    public var dashOffset: Double
}

/// Ce qu'une couche ajoute à ce qui est peint dedans.
public struct Layer: Sendable {
    public var transform: Affine = .identity
    public var opacity: Double = 1
    public var clip: [PathData]?
    /// Vrai : la couche finit par un masque (`beginMask`), peint en alpha.
    public var isMasked = false
    public var maskRegion: Rect?
    public var blend: BlendMode = .normal

    /// Une couche qui ne change rien n'a pas besoin d'exister.
    var isPlain: Bool {
        transform.isIdentity && opacity == 1 && clip == nil && !isMasked && blend == .normal
    }
}

/// Ce que l'app (avec `GraphicsContext`) et le SVG figé de Core savent faire.
/// Les transformations s'empilent avec les couches.
public protocol ScenePainter {
    mutating func push(_ layer: Layer)
    /// Ce qui suit, jusqu'au `pop`, est le masque de la couche : son alpha
    /// garde ou efface ce qui a été peint avant.
    mutating func beginMask()
    mutating func pop()
    mutating func fill(_ path: PathData, _ paint: ResolvedPaint, evenOdd: Bool)
    mutating func stroke(_ path: PathData, _ paint: ResolvedPaint, _ style: StrokeStyle)
    mutating func glyphs(_ glyphs: Glyphs, _ paint: ResolvedPaint, size: Double, weight: Int)
}

/// Ce qui passe d'un nœud à ses enfants, une fois les animations jouées.
struct Inherited {
    var fill: Paint = .color(.black)
    var fillOpacity = 1.0
    var evenOdd = false
    var stroke: Paint = .none
    var strokeWidth = 1.0
    var strokeOpacity = 1.0
    var lineCap: LineCap = .butt
    var dash: [Double] = []
    var dashOffset = 0.0
    var fontSize = 16.0
    var fontWeight = 400
    /// Dans un masque, les couleurs deviennent de l'alpha (leur luminance).
    var inMask = false

    func applying(_ attributes: Attributes, at time: Double) -> Inherited {
        var next = self
        let style = attributes.style
        if let fill = style.fill { next.fill = fill }
        if let evenOdd = style.evenOdd { next.evenOdd = evenOdd }
        if let stroke = style.stroke { next.stroke = stroke }
        if let lineCap = style.lineCap { next.lineCap = lineCap }
        if let dash = style.dash { next.dash = dash }
        if let size = style.fontSize { next.fontSize = size }
        if let weight = style.fontWeight { next.fontWeight = weight }
        // Une animation d'opacité de remplissage sur un groupe passe aux
        // enfants qui n'en fixent pas une à eux : c'est l'héritage de CSS.
        next.fillOpacity = attributes.number(.fillOpacity, at: time, base: style.fillOpacity ?? fillOpacity)
        next.strokeOpacity = attributes.number(.strokeOpacity, at: time, base: style.strokeOpacity ?? strokeOpacity)
        next.dashOffset = attributes.number(.dashOffset, at: time, base: style.dashOffset ?? dashOffset)
        let width = style.strokeWidth ?? strokeWidth
        next.strokeWidth = width * attributes.number(.strokeScale, at: time, base: 1)
        return next
    }
}

extension Scene {
    /// Peint le décor tel qu'il est à l'instant `time`, en secondes.
    public func paint<P: ScenePainter>(at time: Double, into painter: inout P) {
        paint(nodes, at: time, into: &painter)
    }

    /// Peint des nœuds du décor : ceux de la scène, d'un motif ou d'un groupe
    /// que l'app garde en image.
    public func paint<P: ScenePainter>(_ list: [Node], at time: Double, into painter: inout P) {
        let root = Inherited()
        for node in list { paint(node, root, at: time, into: &painter) }
    }

    func paint<P: ScenePainter>(_ node: Node, _ inherited: Inherited, at time: Double, into painter: inout P) {
        let attributes = node.attributes
        let style = inherited.applying(attributes, at: time)
        var layer = Layer()
        layer.transform = attributes.matrix(at: time)
        layer.opacity = attributes.opacity(at: time)
        layer.blend = attributes.blend
        if layer.opacity <= 0 { return }
        if let name = attributes.clip, case .clip(let clip)? = defs[name] { layer.clip = clip.paths }
        var mask: Mask?
        if let name = attributes.mask, case .mask(let found)? = defs[name] {
            mask = found
            layer.isMasked = true
            layer.maskRegion = found.region
        }
        let plain = layer.isPlain
        if !plain { painter.push(layer) }
        switch node.content {
        case .group(let children):
            for child in children { paint(child, style, at: time, into: &painter) }
        case .use(let name):
            if case .symbol(let symbol)? = defs[name] { paint(symbol, style, at: time, into: &painter) }
        case .path(let path):
            draw(path, style, pathLength: attributes.pathLength, into: &painter)
        case .glyphs(let glyphs):
            if let paint = resolve(style.fill, opacity: style.fillOpacity, bounds: nil, mask: style.inMask) {
                painter.glyphs(glyphs, paint, size: style.fontSize, weight: style.fontWeight)
            }
        }
        if let mask {
            painter.beginMask()
            var masking = Inherited()
            masking.inMask = true
            var nodes = mask.nodes
            if mask.contentUnits == .box {
                guard let box = node.bounds(in: self) else {
                    painter.pop()
                    return
                }
                nodes = [Node(.group(nodes)).transform(.translate(box.x, box.y), .scale(box.width, box.height))]
            }
            for child in nodes { paint(child, masking, at: time, into: &painter) }
        }
        if !plain { painter.pop() }
    }

    private func draw<P: ScenePainter>(_ path: PathData, _ style: Inherited, pathLength: Double?, into painter: inout P) {
        let bounds = path.bounds
        if let paint = resolve(style.fill, opacity: style.fillOpacity, bounds: bounds, mask: style.inMask) {
            painter.fill(path, paint, evenOdd: style.evenOdd)
        }
        if style.strokeWidth > 0, let paint = resolve(style.stroke, opacity: style.strokeOpacity, bounds: bounds, mask: style.inMask) {
            var dash = style.dash, offset = style.dashOffset
            if let pathLength, pathLength > 0, !dash.isEmpty {
                let scale = path.length / pathLength
                dash = dash.map { $0 * scale }
                offset *= scale
            }
            painter.stroke(path, paint, StrokeStyle(width: style.strokeWidth, cap: style.lineCap, dash: dash, dashOffset: offset))
        }
    }

    func resolve(_ paint: Paint, opacity: Double, bounds: Rect?, mask: Bool) -> ResolvedPaint? {
        if opacity <= 0 { return nil }
        func tone(_ color: RGBA) -> RGBA {
            var color = color
            color.a *= opacity
            guard mask else { return color }
            // La luminance de SVG (linearRGB non, sRGB oui : c'est ce que font
            // les navigateurs pour `mask-type: luminance`).
            let light = 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b
            return RGBA(1, 1, 1, light * color.a)
        }
        switch paint {
        case .none: return nil
        case .color(let color): return .color(tone(color))
        case .ref(let name):
            switch defs[name] {
            case .linear(let gradient)?:
                let stops = gradient.stops.map { Stop($0.offset, tone($0.color)) }
                let start = Point(gradient.x1, gradient.y1), end = Point(gradient.x2, gradient.y2)
                if gradient.units == .user {
                    return .linear(start: start, end: end, transform: .identity, stops: stops)
                }
                guard let box = bounds, box.width > 0, box.height > 0 else { return nil }
                return .linear(start: start, end: end, transform: Affine(a: box.width, d: box.height, tx: box.x, ty: box.y), stops: stops)
            case .radial(let gradient)?:
                let stops = gradient.stops.map { Stop($0.offset, tone($0.color)) }
                if gradient.units == .user {
                    return .radial(center: Point(gradient.cx, gradient.cy), radius: gradient.r, transform: .identity, stops: stops)
                }
                guard let box = bounds, box.width > 0, box.height > 0 else { return nil }
                // En unités de la boîte, le cercle unité devient la boîte.
                let transform = Affine(a: box.width, d: box.height, tx: box.x, ty: box.y)
                return .radial(center: Point(gradient.cx, gradient.cy), radius: gradient.r, transform: transform, stops: stops)
            case .pattern(let pattern)?:
                return .pattern(name: name, pattern, opacity: opacity)
            default:
                return nil
            }
        }
    }
}

extension PathData {
    /// La boîte du tracé, courbes comprises (sur des points de la courbe, pas
    /// sur ses points de contrôle).
    public var bounds: Rect? {
        var minX = Double.infinity, minY = Double.infinity, maxX = -Double.infinity, maxY = -Double.infinity
        func add(_ x: Double, _ y: Double) {
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
        var current = (0.0, 0.0)
        for command in commands {
            switch command {
            case .move(let x, let y), .line(let x, let y):
                add(x, y)
                current = (x, y)
            case .quad(let x1, let y1, let x, let y):
                for step in 1...16 {
                    let t = Double(step) / 16, u = 1 - t
                    add(u * u * current.0 + 2 * u * t * x1 + t * t * x, u * u * current.1 + 2 * u * t * y1 + t * t * y)
                }
                current = (x, y)
            case .cubic(let x1, let y1, let x2, let y2, let x, let y):
                for step in 1...16 {
                    let t = Double(step) / 16, u = 1 - t
                    let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
                    add(a * current.0 + b * x1 + c * x2 + d * x, a * current.1 + b * y1 + c * y2 + d * y)
                }
                current = (x, y)
            case .close:
                break
            }
        }
        guard minX.isFinite else { return nil }
        return Rect(minX, minY, maxX - minX, maxY - minY)
    }
}
