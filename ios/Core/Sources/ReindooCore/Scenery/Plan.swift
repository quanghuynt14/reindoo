import Foundation

/// Un geste de peinture, déjà résolu. L'app les rejoue dans un `Canvas`.
public indirect enum DrawOp: Sendable {
    /// Ce qui est peint dans une couche, puis, s'il y en a un, son masque.
    case layer(Layer, [DrawOp], mask: [DrawOp]?)
    case fill(PathData, ResolvedPaint, evenOdd: Bool)
    case stroke(PathData, ResolvedPaint, StrokeSpec)
    case glyphs(Glyphs, ResolvedPaint, size: Double, weight: Int)

    /// Le nombre de gestes, couches comprises.
    public var count: Int {
        switch self {
        case .layer(_, let inner, let mask): 1 + inner.reduce(0) { $0 + $1.count } + (mask ?? []).reduce(0) { $0 + $1.count }
        default: 1
        }
    }
}

/// Un peintre qui garde les gestes au lieu de les faire.
public struct OpRecorder: ScenePainter {
    private struct Frame {
        var layer: Layer
        var ops: [DrawOp] = []
        var mask: [DrawOp]?
    }

    private var stack: [Frame] = [Frame(layer: Layer())]
    public init() {}

    public var ops: [DrawOp] { stack[0].ops }

    private mutating func emit(_ op: DrawOp) {
        let last = stack.count - 1
        if stack[last].mask != nil { stack[last].mask!.append(op) } else { stack[last].ops.append(op) }
    }

    public mutating func push(_ layer: Layer) { stack.append(Frame(layer: layer)) }
    public mutating func beginMask() { stack[stack.count - 1].mask = [] }

    public mutating func pop() {
        let frame = stack.removeLast()
        emit(.layer(frame.layer, frame.ops, mask: frame.mask))
    }

    public mutating func fill(_ path: PathData, _ paint: ResolvedPaint, evenOdd: Bool) { emit(.fill(path, paint, evenOdd: evenOdd)) }
    public mutating func stroke(_ path: PathData, _ paint: ResolvedPaint, _ style: StrokeSpec) { emit(.stroke(path, paint, style)) }
    public mutating func glyphs(_ glyphs: Glyphs, _ paint: ResolvedPaint, size: Double, weight: Int) {
        emit(.glyphs(glyphs, paint, size: size, weight: weight))
    }
}

/// Le style hérité d'un nœud, pour le peindre seul, hors de son arbre.
public struct SceneStyle: Sendable {
    var inherited: Inherited
}

/// Le décor découpé pour être peint vite : ce qui ne bouge jamais est résolu
/// une fois ; seul ce qui bouge est rejoué à chaque image. L'ordre de peinture
/// est gardé.
public struct ScenePlan: Sendable {
    public enum Part: Sendable {
        case still([DrawOp])
        case live([Node], SceneStyle)
    }

    public var parts: [Part]

    /// Le nombre de gestes immobiles et de nœuds vivants, pour juger du coût.
    public var summary: (stillOps: Int, stillParts: Int, liveNodes: Int) {
        parts.reduce(into: (0, 0, 0)) { total, part in
            switch part {
            case .still(let ops):
                total.0 += ops.reduce(0) { $0 + $1.count }
                total.1 += 1
            case .live(let nodes, _): total.2 += nodes.count
            }
        }
    }
}

extension SceneGraph {
    /// Découpe le décor. Sans mouvement, tout est immobile : une seule partie,
    /// peinte comme si aucune animation n'existait.
    public func plan(motion: Bool) -> ScenePlan {
        if !motion {
            var recorder = OpRecorder()
            paint(at: nil, into: &recorder)
            return ScenePlan(parts: [.still(recorder.ops)])
        }
        var parts: [ScenePlan.Part] = []
        var still = OpRecorder()
        var stillCount = 0
        func flush() {
            if stillCount > 0 { parts.append(.still(still.ops)) }
            still = OpRecorder()
            stillCount = 0
        }
        func walk(_ nodes: [Node], _ inherited: Inherited) {
            for node in nodes {
                if node.isStill(in: self) {
                    paint(node, inherited, at: nil, into: &still)
                    stillCount += 1
                } else if case .group(let children) = node.content, node.attributes.isPlain {
                    // Un groupe qui ne fait que passer un style : on entre dedans.
                    walk(children, inherited.applying(node.attributes, at: nil))
                } else {
                    flush()
                    if case .live(var live, let style)? = parts.last, style.matches(inherited) {
                        live.append(node)
                        parts[parts.count - 1] = .live(live, style)
                    } else {
                        parts.append(.live([node], SceneStyle(inherited: inherited)))
                    }
                }
            }
        }
        walk(nodes, Inherited())
        flush()
        return ScenePlan(parts: parts)
    }

    /// Les nœuds vivants d'une partie, à l'instant `time`.
    public func record(_ nodes: [Node], _ style: SceneStyle, at time: Double?) -> [DrawOp] {
        var recorder = OpRecorder()
        for node in nodes { paint(node, style.inherited, at: time, into: &recorder) }
        return recorder.ops
    }
}

extension Attributes {
    /// Rien d'autre qu'un style à passer : ni transformation, ni opacité, ni
    /// découpe, ni masque, ni animation.
    var isPlain: Bool {
        animations.isEmpty && transform.isEmpty && opacity == 1 && clip == nil && mask == nil && blend == .normal
    }
}

extension SceneStyle {
    /// Deux nœuds vivants voisins sous le même style se rejouent ensemble.
    func matches(_ other: Inherited) -> Bool {
        let a = inherited, b = other
        return a.fill == b.fill && a.fillOpacity == b.fillOpacity && a.evenOdd == b.evenOdd && a.stroke == b.stroke
            && a.strokeWidth == b.strokeWidth && a.strokeOpacity == b.strokeOpacity && a.lineCap == b.lineCap
            && a.dash == b.dash && a.dashOffset == b.dashOffset && a.fontSize == b.fontSize && a.fontWeight == b.fontWeight
    }
}
