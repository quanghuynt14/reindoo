import Foundation

// De quoi écrire un décor comme on écrirait son SVG : des formes, des groupes,
// et des modificateurs qui rendent une copie.

extension Node {
    public static func group(_ children: [Node]) -> Node { Node(.group(children)) }
    public static func path(_ path: PathData) -> Node { Node(.path(path)) }
    public static func path(_ d: String) -> Node { Node(.path(PathData(svg: d))) }
    public static func use(_ name: String) -> Node { Node(.use(name)) }

    public static func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double, radius: Double = 0) -> Node {
        .path(PathData.rect(x, y, width, height, radius: radius))
    }

    public static func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> Node {
        .path(PathData.ellipse(cx, cy, rx, ry))
    }

    public static func circle(_ cx: Double, _ cy: Double, _ r: Double) -> Node {
        .path(PathData.circle(cx, cy, r))
    }

    public static func line(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Node {
        .path(PathData.line(x1, y1, x2, y2))
    }

    public static func glyphs(_ text: [Character], xs: [Double], ys: [Double], centered: Bool = true) -> Node {
        Node(.glyphs(Glyphs(text: text, xs: xs, ys: ys, centered: centered)))
    }

    private func with(_ change: (inout Attributes) -> Void) -> Node {
        var copy = self
        change(&copy.attributes)
        return copy
    }

    public func fill(_ paint: Paint, opacity: Double? = nil) -> Node {
        with {
            $0.style.fill = paint
            if let opacity { $0.style.fillOpacity = opacity }
        }
    }

    public func fillOpacity(_ value: Double) -> Node { with { $0.style.fillOpacity = value } }
    public func evenOdd() -> Node { with { $0.style.evenOdd = true } }

    public func stroke(_ paint: Paint, width: Double? = nil, opacity: Double? = nil, cap: LineCap? = nil) -> Node {
        with {
            $0.style.stroke = paint
            if let width { $0.style.strokeWidth = width }
            if let opacity { $0.style.strokeOpacity = opacity }
            if let cap { $0.style.lineCap = cap }
        }
    }

    public func strokeWidth(_ value: Double) -> Node { with { $0.style.strokeWidth = value } }
    public func lineCap(_ cap: LineCap) -> Node { with { $0.style.lineCap = cap } }
    public func pathLength(_ length: Double) -> Node { with { $0.pathLength = length } }
    public func strokeOpacity(_ value: Double) -> Node { with { $0.style.strokeOpacity = value } }

    public func dash(_ pattern: [Double], offset: Double = 0) -> Node {
        with {
            $0.style.dash = pattern
            $0.style.dashOffset = offset
        }
    }

    public func font(size: Double, weight: Int? = nil) -> Node {
        with {
            $0.style.fontSize = size
            if let weight { $0.style.fontWeight = weight }
        }
    }

    public func transform(_ ops: TransformOp...) -> Node { with { $0.transform += ops } }
    public func transform(_ ops: [TransformOp]) -> Node { with { $0.transform += ops } }
    public func translate(_ x: Double, _ y: Double) -> Node { with { $0.transform += [.translate(x, y)] } }
    public func opacity(_ value: Double) -> Node { with { $0.opacity = value } }
    public func origin(_ x: Double, _ y: Double) -> Node { with { $0.origin = Point(x, y) } }
    public func clip(_ name: String) -> Node { with { $0.clip = name } }
    public func mask(_ name: String) -> Node { with { $0.mask = name } }
    public func blend(_ mode: SceneBlend) -> Node { with { $0.blend = mode } }
    public func animate(_ animation: SceneAnimation) -> Node { with { $0.animations.append(animation) } }

    public func animate(_ animations: [SceneAnimation]) -> Node { with { $0.animations += animations } }
}

extension SceneAnimation {
    /// `@keyframes x { from {…} to {…} }`.
    public static func between(
        _ from: [Property: Value], _ to: [Property: Value], duration: Double, delay: Double = 0,
        direction: Direction = .normal, timing: Timing = .ease
    ) -> SceneAnimation {
        SceneAnimation([Keyframe(0, from), Keyframe(1, to)], duration: duration, delay: delay, direction: direction, timing: timing)
    }

    /// La même animation, décalée : `animation-delay`.
    public func delayed(_ seconds: Double) -> SceneAnimation {
        var copy = self
        copy.delay = seconds
        return copy
    }

    public func lasting(_ seconds: Double) -> SceneAnimation {
        var copy = self
        copy.duration = seconds
        return copy
    }

    public func directed(_ direction: Direction) -> SceneAnimation {
        var copy = self
        copy.direction = direction
        return copy
    }
}

extension SceneAnimation.Value {
    public static func n(_ value: Double) -> SceneAnimation.Value { .number(value) }
    public static func t(_ ops: TransformOp...) -> SceneAnimation.Value { .ops(ops) }
}

extension SceneGraph {
    public mutating func define(_ name: String, _ def: Def) { defs[name] = def }

    public mutating func linear(_ name: String, x1: Double = 0, y1: Double = 0, x2: Double = 0, y2: Double = 1, units: Units = .box, _ stops: [(Double, String, Double)]) {
        defs[name] = .linear(LinearGradientDef(x1: x1, y1: y1, x2: x2, y2: y2, units: units, stops: stops.map(SceneGraph.stop)))
    }

    public mutating func radial(_ name: String, cx: Double = 0.5, cy: Double = 0.5, r: Double = 0.5, units: Units = .box, _ stops: [(Double, String, Double)]) {
        defs[name] = .radial(RadialGradientDef(cx: cx, cy: cy, r: r, units: units, stops: stops.map(SceneGraph.stop)))
    }

    static func stop(_ entry: (Double, String, Double)) -> Stop {
        var color = RGBA(entry.1)
        color.a = entry.2
        return Stop(entry.0, color)
    }

    public mutating func add(_ node: Node) { nodes.append(node) }
    public mutating func add(_ list: [Node]) { nodes += list }
}
