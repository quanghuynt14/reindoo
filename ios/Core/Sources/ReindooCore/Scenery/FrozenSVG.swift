import Foundation

/// Un peintre qui écrit du SVG sans animation ni héritage : chaque forme porte
/// ses valeurs résolues. Il montre exactement ce que l'app reçoit, et un
/// navigateur sous Linux peut le comparer au décor d'origine.
public struct FrozenSVG: ScenePainter {
    private var defs = ""
    private var stack: [Frame] = [Frame()]
    private var counter = 0
    private let scene: Scene
    private let time: Double

    private struct Frame {
        var layer = Layer()
        var body = ""
        var mask = ""
        var inMask = false
    }

    /// Le décor à l'instant `time`, en un document SVG.
    public static func render(_ scene: Scene, at time: Double) -> String {
        var painter = FrozenSVG(scene: scene, time: time)
        scene.paint(at: time, into: &painter)
        let w = number(scene.width), h = number(scene.height)
        let pw = number(scene.width * scene.pointsPerUnit), ph = number(scene.height * scene.pointsPerUnit)
        return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(w) \(h)\" width=\"\(pw)\" height=\"\(ph)\" font-family=\"ui-monospace,SFMono-Regular,Menlo,Consolas,monospace\">"
            + "<defs>\(painter.defs)</defs>\(painter.stack[0].body)</svg>"
    }

    private init(scene: Scene, time: Double) {
        self.scene = scene
        self.time = time
    }

    private mutating func emit(_ text: String) {
        let last = stack.count - 1
        if stack[last].inMask { stack[last].mask += text } else { stack[last].body += text }
    }

    private mutating func nextId(_ prefix: String) -> String {
        counter += 1
        return "\(prefix)\(counter)"
    }

    public mutating func push(_ layer: Layer) {
        var frame = Frame()
        frame.layer = layer
        stack.append(frame)
    }

    public mutating func beginMask() {
        stack[stack.count - 1].inMask = true
    }

    public mutating func pop() {
        let frame = stack.removeLast()
        let layer = frame.layer
        var outer = "<g"
        if !layer.transform.isIdentity { outer += " transform=\"\(Self.matrix(layer.transform))\"" }
        if layer.opacity < 1 { outer += " opacity=\"\(Self.number(layer.opacity))\"" }
        if layer.blend != .normal { outer += " style=\"mix-blend-mode:\(layer.blend.rawValue)\"" }
        outer += ">"
        var inner = frame.body
        if let clip = layer.clip {
            let id = nextId("c")
            defs += "<clipPath id=\"\(id)\" clipPathUnits=\"userSpaceOnUse\">"
                + clip.map { "<path d=\"\(Self.path($0))\"/>" }.joined() + "</clipPath>"
            inner = "<g clip-path=\"url(#\(id))\">\(inner)</g>"
        }
        if layer.isMasked {
            let id = nextId("m")
            let region = layer.maskRegion ?? Rect(-100_000, -100_000, 200_000, 200_000)
            defs += "<mask id=\"\(id)\" maskUnits=\"userSpaceOnUse\" x=\"\(Self.number(region.x))\" y=\"\(Self.number(region.y))\" "
                + "width=\"\(Self.number(region.width))\" height=\"\(Self.number(region.height))\">\(frame.mask)</mask>"
            inner = "<g mask=\"url(#\(id))\">\(inner)</g>"
        }
        emit(outer + inner + "</g>")
    }

    public mutating func fill(_ path: PathData, _ paint: ResolvedPaint, evenOdd: Bool) {
        let rule = evenOdd ? " fill-rule=\"evenodd\"" : ""
        emit("<path d=\"\(Self.path(path))\" \(attribute("fill", paint))\(rule)/>")
    }

    public mutating func stroke(_ path: PathData, _ paint: ResolvedPaint, _ style: StrokeStyle) {
        var text = "<path d=\"\(Self.path(path))\" fill=\"none\" \(attribute("stroke", paint)) stroke-width=\"\(Self.number(style.width))\""
        if style.cap != .butt { text += " stroke-linecap=\"\(style.cap.rawValue)\"" }
        if !style.dash.isEmpty {
            text += " stroke-dasharray=\"\(style.dash.map(Self.number).joined(separator: " "))\""
            text += " stroke-dashoffset=\"\(Self.number(style.dashOffset))\""
        }
        emit(text + "/>")
    }

    public mutating func glyphs(_ glyphs: Glyphs, _ paint: ResolvedPaint, size: Double, weight: Int) {
        let xs = glyphs.xs.map(Self.number).joined(separator: " ")
        let ys = glyphs.ys.map(Self.number).joined(separator: " ")
        let text = String(glyphs.text).replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
        let anchor = glyphs.centered ? " text-anchor=\"middle\"" : ""
        emit("<text x=\"\(xs)\" y=\"\(ys)\" \(attribute("fill", paint)) font-size=\"\(Self.number(size))\" font-weight=\"\(weight)\"\(anchor) xml:space=\"preserve\">\(text)</text>")
    }

    private mutating func attribute(_ name: String, _ paint: ResolvedPaint) -> String {
        switch paint {
        case .color(let color):
            return color.a < 1 ? "\(name)=\"\(color.hex)\" \(name)-opacity=\"\(Self.number(color.a))\"" : "\(name)=\"\(color.hex)\""
        case .linear(let start, let end, let stops):
            let id = nextId("l")
            defs += "<linearGradient id=\"\(id)\" gradientUnits=\"userSpaceOnUse\" x1=\"\(Self.number(start.x))\" y1=\"\(Self.number(start.y))\" "
                + "x2=\"\(Self.number(end.x))\" y2=\"\(Self.number(end.y))\">\(Self.stops(stops))</linearGradient>"
            return "\(name)=\"url(#\(id))\""
        case .radial(let center, let radius, let transform, let stops):
            let id = nextId("r")
            defs += "<radialGradient id=\"\(id)\" gradientUnits=\"userSpaceOnUse\" cx=\"\(Self.number(center.x))\" cy=\"\(Self.number(center.y))\" "
                + "r=\"\(Self.number(radius))\" gradientTransform=\"\(Self.matrix(transform))\">\(Self.stops(stops))</radialGradient>"
            return "\(name)=\"url(#\(id))\""
        case .pattern(_, let pattern, let opacity):
            let id = nextId("p")
            var tile = FrozenSVG(scene: scene, time: time)
            tile.counter = counter + 1000
            scene.paint(pattern.nodes, at: time, into: &tile)
            counter = tile.counter
            defs += tile.defs
            defs += "<pattern id=\"\(id)\" patternUnits=\"userSpaceOnUse\" x=\"\(Self.number(pattern.x))\" y=\"\(Self.number(pattern.y))\" "
                + "width=\"\(Self.number(pattern.width))\" height=\"\(Self.number(pattern.height))\">\(tile.stack[0].body)</pattern>"
            return opacity < 1 ? "\(name)=\"url(#\(id))\" \(name)-opacity=\"\(Self.number(opacity))\"" : "\(name)=\"url(#\(id))\""
        }
    }

    static func stops(_ stops: [Stop]) -> String {
        stops.map { "<stop offset=\"\(number($0.offset))\" stop-color=\"\($0.color.hex)\" stop-opacity=\"\(number($0.color.a))\"/>" }.joined()
    }

    static func matrix(_ m: Affine) -> String {
        "matrix(\([m.a, m.b, m.c, m.d, m.tx, m.ty].map(number).joined(separator: " ")))"
    }

    static func number(_ value: Double) -> String {
        let rounded = (value * 1000).rounded() / 1000
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(rounded)
    }

    static func path(_ path: PathData) -> String {
        var text = ""
        for command in path.commands {
            switch command {
            case .move(let x, let y): text += "M\(number(x)) \(number(y))"
            case .line(let x, let y): text += "L\(number(x)) \(number(y))"
            case .quad(let a, let b, let x, let y): text += "Q\(number(a)) \(number(b)) \(number(x)) \(number(y))"
            case .cubic(let a, let b, let c, let d, let x, let y):
                text += "C\(number(a)) \(number(b)) \(number(c)) \(number(d)) \(number(x)) \(number(y))"
            case .close: text += "Z"
            }
        }
        return text
    }
}
