import Foundation

// Un décor est un petit SVG typé : des formes, des glyphes, des dégradés,
// des motifs, des masques, et des animations à images clés. Core le construit
// et sait l'évaluer à un instant donné ; l'app ne fait que le peindre. Ainsi
// tout ce qui peut se tromper se teste sous Linux.

public struct Scene: Sendable {
    /// La taille en unités du décor. Elle vaut l'écran fois `unitsPerPoint`.
    public var width: Double
    public var height: Double
    /// Combien de points d'écran fait une unité : l'app peint à cette échelle.
    public var pointsPerUnit = 1.0
    /// Dégradés, motifs, masques, découpes et symboles, par nom.
    public var defs: [String: Def] = [:]
    public var nodes: [Node] = []

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public enum Def: Sendable {
    case linear(LinearGradient)
    case radial(RadialGradient)
    case pattern(Pattern)
    /// Un masque de luminance, comme `<mask>` : le blanc garde, le noir efface.
    case mask(Mask)
    case clip(Clip)
    /// Ce qu'un `<use>` reprend.
    case symbol(Node)
}

public struct Stop: Sendable, Equatable {
    public var offset: Double
    public var color: RGBA
    public init(_ offset: Double, _ color: RGBA) {
        self.offset = offset
        self.color = color
    }
}

public enum Units: Sendable, Equatable { case box, user }

public struct LinearGradient: Sendable {
    public var x1 = 0.0, y1 = 0.0, x2 = 1.0, y2 = 0.0
    public var units: Units = .box
    public var stops: [Stop]
    public init(x1: Double = 0, y1: Double = 0, x2: Double = 1, y2: Double = 0, units: Units = .box, stops: [Stop]) {
        (self.x1, self.y1, self.x2, self.y2, self.units, self.stops) = (x1, y1, x2, y2, units, stops)
    }
}

public struct RadialGradient: Sendable {
    public var cx = 0.5, cy = 0.5, r = 0.5
    public var units: Units = .box
    public var stops: [Stop]
    public init(cx: Double = 0.5, cy: Double = 0.5, r: Double = 0.5, units: Units = .box, stops: [Stop]) {
        (self.cx, self.cy, self.r, self.units, self.stops) = (cx, cy, r, units, stops)
    }
}

/// Un motif en unités de l'utilisateur : une tuile qui se répète.
public struct Pattern: Sendable {
    public var x = 0.0, y = 0.0
    public var width: Double
    public var height: Double
    public var nodes: [Node]
    public init(x: Double = 0, y: Double = 0, width: Double, height: Double, nodes: [Node]) {
        (self.x, self.y, self.width, self.height, self.nodes) = (x, y, width, height, nodes)
    }
}

public struct Mask: Sendable {
    /// La région du masque, en unités de l'utilisateur. Rien n'est peint dehors.
    public var region: Rect?
    /// `.box` : le contenu du masque est dessiné dans la boîte du nœud masqué,
    /// de 0 à 1 (`maskContentUnits="objectBoundingBox"`).
    public var contentUnits: Units
    public var nodes: [Node]
    public init(region: Rect? = nil, contentUnits: Units = .user, nodes: [Node]) {
        self.region = region
        self.contentUnits = contentUnits
        self.nodes = nodes
    }
}

public struct Clip: Sendable {
    public var paths: [PathData]
    public init(_ paths: [PathData]) { self.paths = paths }
}

public struct Rect: Sendable, Equatable {
    public var x, y, width, height: Double
    public init(_ x: Double, _ y: Double, _ width: Double, _ height: Double) {
        (self.x, self.y, self.width, self.height) = (x, y, width, height)
    }
}

/// Une couleur, de 0 à 1 par canal.
public struct RGBA: Sendable, Equatable, Hashable {
    public var r, g, b, a: Double
    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        (self.r, self.g, self.b, self.a) = (r, g, b, a)
    }

    public static let white = RGBA(1, 1, 1)
    public static let black = RGBA(0, 0, 0)

    /// `#rgb`, `#rrggbb`, `white`, `black`.
    public init(_ text: String) {
        switch text {
        case "white": self = .white; return
        case "black": self = .black; return
        default: break
        }
        var hex = Substring(text.hasPrefix("#") ? String(text.dropFirst()) : text)
        if hex.count == 3 { hex = Substring(hex.map { "\($0)\($0)" }.joined()) }
        let value = UInt32(hex, radix: 16) ?? 0
        self.init(Double((value >> 16) & 0xff) / 255, Double((value >> 8) & 0xff) / 255, Double(value & 0xff) / 255)
    }

    public var hex: String {
        func two(_ channel: Double) -> String {
            let value = Int((min(1, max(0, channel)) * 255).rounded())
            let text = String(value, radix: 16)
            return text.count == 1 ? "0" + text : text
        }
        return "#" + two(r) + two(g) + two(b)
    }
}

public enum Paint: Sendable, Equatable {
    case color(RGBA)
    /// Un dégradé ou un motif des `defs`.
    case ref(String)
    case none
}

extension Paint: ExpressibleByStringLiteral {
    /// `"#0b3a4d"`, `"url(#deep)"` ou `"none"`, comme en SVG.
    public init(stringLiteral text: String) { self.init(text) }

    public init(_ text: String) {
        if text == "none" {
            self = .none
        } else if text.hasPrefix("url(#") {
            self = .ref(String(text.dropFirst(5).dropLast()))
        } else {
            self = .color(RGBA(text))
        }
    }
}

public enum LineCap: String, Sendable { case butt, round, square }
public enum BlendMode: String, Sendable { case normal, multiply, screen }

/// Les propriétés qui passent du parent à l'enfant, comme en SVG. `nil` :
/// l'enfant prend celle du parent.
public struct Style: Sendable {
    public var fill: Paint?
    public var fillOpacity: Double?
    public var evenOdd: Bool?
    public var stroke: Paint?
    public var strokeWidth: Double?
    public var strokeOpacity: Double?
    public var lineCap: LineCap?
    public var dash: [Double]?
    public var dashOffset: Double?
    public var fontSize: Double?
    public var fontWeight: Int?
    public init(
        fill: Paint? = nil, fillOpacity: Double? = nil, evenOdd: Bool? = nil, stroke: Paint? = nil,
        strokeWidth: Double? = nil, strokeOpacity: Double? = nil, lineCap: LineCap? = nil,
        dash: [Double]? = nil, dashOffset: Double? = nil, fontSize: Double? = nil, fontWeight: Int? = nil
    ) {
        self.fill = fill
        self.fillOpacity = fillOpacity
        self.evenOdd = evenOdd
        self.stroke = stroke
        self.strokeWidth = strokeWidth
        self.strokeOpacity = strokeOpacity
        self.lineCap = lineCap
        self.dash = dash
        self.dashOffset = dashOffset
        self.fontSize = fontSize
        self.fontWeight = fontWeight
    }
}

/// Ce qu'un nœud porte en plus de son contenu : style, transformation fixe,
/// opacité, animations, découpe, masque.
public struct Attributes: Sendable {
    public var style = Style()
    public var transform: [TransformOp] = []
    public var opacity: Double = 1
    public var animations: [Animation] = []
    /// Le point autour duquel tournent et grandissent les animations, en
    /// unités de l'utilisateur (`transform-origin`).
    public var origin: Point = .zero
    public var clip: String?
    public var mask: String?
    public var blend: BlendMode = .normal
    /// La longueur que le chemin dit avoir (`pathLength`) : ses tirets et leur
    /// décalage se comptent dans cette unité.
    public var pathLength: Double?
    public init() {}
}

public struct Point: Sendable, Equatable {
    public var x, y: Double
    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }
    public static let zero = Point(0, 0)
}

public indirect enum Content: Sendable {
    case group([Node])
    case path(PathData)
    /// Des glyphes, chacun à sa place, centrés sur leur x (`text-anchor:middle`)
    /// ou commencés à leur x.
    case glyphs(Glyphs)
    case use(String)
}

public struct Glyphs: Sendable {
    public var text: [Character]
    public var xs: [Double]
    public var ys: [Double]
    public var centered: Bool
    public init(text: [Character], xs: [Double], ys: [Double], centered: Bool = true) {
        self.text = text
        self.xs = xs
        self.ys = ys
        self.centered = centered
    }
}

public struct Node: Sendable {
    public var content: Content
    public var attributes: Attributes

    public init(_ content: Content, _ attributes: Attributes = Attributes()) {
        self.content = content
        self.attributes = attributes
    }

    /// Vrai si rien ne bouge dans ce nœud ni sous lui : l'app peut le peindre
    /// une fois et garder l'image.
    /// La boîte de ce que le nœud dessine, sans ses transformations.
    public func bounds(in scene: Scene) -> Rect? {
        switch content {
        case .path(let path): return path.bounds
        case .glyphs: return nil
        case .use(let name):
            if case .symbol(let node)? = scene.defs[name] { return node.bounds(in: scene) }
            return nil
        case .group(let children):
            var box: Rect?
            for child in children {
                guard var inner = child.bounds(in: scene) else { continue }
                if !child.attributes.transform.isEmpty {
                    let m = Affine.of(child.attributes.transform)
                    let corners = [Point(inner.x, inner.y), Point(inner.x + inner.width, inner.y), Point(inner.x, inner.y + inner.height), Point(inner.x + inner.width, inner.y + inner.height)].map(m.apply)
                    let xs = corners.map(\.x), ys = corners.map(\.y)
                    inner = Rect(xs.min()!, ys.min()!, xs.max()! - xs.min()!, ys.max()! - ys.min()!)
                }
                if let current = box {
                    let x = min(current.x, inner.x), y = min(current.y, inner.y)
                    box = Rect(x, y, max(current.x + current.width, inner.x + inner.width) - x, max(current.y + current.height, inner.y + inner.height) - y)
                } else {
                    box = inner
                }
            }
            return box
        }
    }

    public func isStill(in scene: Scene) -> Bool {
        if !attributes.animations.isEmpty { return false }
        switch content {
        case .group(let children): return children.allSatisfy { $0.isStill(in: scene) }
        case .use(let name):
            if case .symbol(let node)? = scene.defs[name] { return node.isStill(in: scene) }
            return true
        case .path, .glyphs: return true
        }
    }
}
