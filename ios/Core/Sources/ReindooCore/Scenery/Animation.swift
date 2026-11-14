import Foundation

/// Une transformation élémentaire, en unités de l'utilisateur et en degrés.
public enum TransformOp: Sendable, Equatable {
    case translate(Double, Double)
    case rotate(Double)
    case scale(Double, Double)
    case skewX(Double)
    case skewY(Double)
    /// `rotate(a cx cy)` de l'attribut SVG.
    case rotateAbout(Double, Double, Double)

    var affine: Affine {
        switch self {
        case .translate(let x, let y): return Affine(tx: x, ty: y)
        case .rotate(let degrees):
            let r = degrees * .pi / 180
            return Affine(a: cos(r), b: sin(r), c: -sin(r), d: cos(r))
        case .scale(let x, let y): return Affine(a: x, d: y)
        case .skewX(let degrees): return Affine(c: tan(degrees * .pi / 180))
        case .skewY(let degrees): return Affine(b: tan(degrees * .pi / 180))
        case .rotateAbout(let degrees, let x, let y):
            return Affine(tx: x, ty: y) * TransformOp.rotate(degrees).affine * Affine(tx: -x, ty: -y)
        }
    }

    /// L'opération neutre du même genre, pour interpoler depuis `none`.
    var identity: TransformOp {
        switch self {
        case .translate: return .translate(0, 0)
        case .rotate: return .rotate(0)
        case .scale: return .scale(1, 1)
        case .skewX: return .skewX(0)
        case .skewY: return .skewY(0)
        case .rotateAbout(_, let x, let y): return .rotateAbout(0, x, y)
        }
    }

    static func blend(_ from: TransformOp, _ to: TransformOp, _ u: Double) -> TransformOp? {
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * u }
        switch (from, to) {
        case let (.translate(a, b), .translate(c, d)): return .translate(mix(a, c), mix(b, d))
        case let (.rotate(a), .rotate(b)): return .rotate(mix(a, b))
        case let (.scale(a, b), .scale(c, d)): return .scale(mix(a, c), mix(b, d))
        case let (.skewX(a), .skewX(b)): return .skewX(mix(a, b))
        case let (.skewY(a), .skewY(b)): return .skewY(mix(a, b))
        case let (.rotateAbout(a, x, y), .rotateAbout(b, _, _)): return .rotateAbout(mix(a, b), x, y)
        default: return nil
        }
    }
}

/// Une matrice affine, dans l'ordre de SVG : `[a c tx; b d ty]`.
public struct Affine: Sendable, Equatable {
    public var a = 1.0, b = 0.0, c = 0.0, d = 1.0, tx = 0.0, ty = 0.0
    public init(a: Double = 1, b: Double = 0, c: Double = 0, d: Double = 1, tx: Double = 0, ty: Double = 0) {
        (self.a, self.b, self.c, self.d, self.tx, self.ty) = (a, b, c, d, tx, ty)
    }

    public static let identity = Affine()
    public var isIdentity: Bool { self == .identity }

    public static func * (l: Affine, r: Affine) -> Affine {
        Affine(
            a: l.a * r.a + l.c * r.b, b: l.b * r.a + l.d * r.b,
            c: l.a * r.c + l.c * r.d, d: l.b * r.c + l.d * r.d,
            tx: l.a * r.tx + l.c * r.ty + l.tx, ty: l.b * r.tx + l.d * r.ty + l.ty
        )
    }

    public static func of(_ ops: [TransformOp]) -> Affine {
        ops.reduce(Affine.identity) { $0 * $1.affine }
    }

    public func apply(_ point: Point) -> Point {
        Point(a * point.x + c * point.y + tx, b * point.x + d * point.y + ty)
    }
}

/// Le rythme d'un segment d'animation, comme `animation-timing-function`.
public enum Timing: Sendable, Equatable {
    case linear
    case ease, easeIn, easeOut, easeInOut
    case cubic(Double, Double, Double, Double)
    /// `steps(n)` : `jump-end` par défaut, `jump-start` si `start`.
    case steps(Int, start: Bool = false)

    public func apply(_ u: Double) -> Double {
        switch self {
        case .linear: return u
        case .ease: return Timing.bezier(0.25, 0.1, 0.25, 1, u)
        case .easeIn: return Timing.bezier(0.42, 0, 1, 1, u)
        case .easeOut: return Timing.bezier(0, 0, 0.58, 1, u)
        case .easeInOut: return Timing.bezier(0.42, 0, 0.58, 1, u)
        case .cubic(let x1, let y1, let x2, let y2): return Timing.bezier(x1, y1, x2, y2, u)
        case .steps(let count, let start):
            let n = Double(max(1, count))
            let stepped = start ? (u * n).rounded(.down) + 1 : (u * n).rounded(.down)
            return min(1, max(0, stepped / n))
        }
    }

    /// La courbe de Bézier de CSS : on cherche le t dont l'abscisse vaut `u`.
    static func bezier(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ u: Double) -> Double {
        if u <= 0 { return 0 }
        if u >= 1 { return 1 }
        func coordinate(_ t: Double, _ p1: Double, _ p2: Double) -> Double {
            let v = 1 - t
            return 3 * v * v * t * p1 + 3 * v * t * t * p2 + t * t * t
        }
        var low = 0.0, high = 1.0, t = u
        for _ in 0..<40 {
            let x = coordinate(t, x1, x2)
            if abs(x - u) < 1e-7 { break }
            if x < u { low = t } else { high = t }
            t = (low + high) / 2
        }
        return coordinate(t, y1, y2)
    }
}

/// Une animation CSS sur un nœud : des images clés, une durée, un retard (négatif :
/// déjà commencée), un sens, un rythme. Elle tourne sans fin, comme toutes celles
/// des décors.
public struct SceneAnimation: Sendable {
    public enum Property: Hashable, Sendable {
        /// La propriété `transform`. Elle remplace la transformation fixe du nœud.
        case transform
        /// La propriété CSS `translate`, appliquée avant `transform`.
        case translate
        case opacity
        case fillOpacity
        case strokeOpacity
        case dashOffset
        /// Un facteur sur l'épaisseur du trait (`calc(var(--w) * k)`).
        case strokeScale
    }

    public enum Value: Sendable, Equatable {
        case number(Double)
        case ops([TransformOp])
    }

    public enum Direction: Sendable { case normal, reverse, alternate, alternateReverse }

    public struct Keyframe: Sendable {
        public var offset: Double
        public var values: [Property: Value]
        /// Le rythme du segment qui part de cette image, s'il diffère de celui de l'animation.
        public var timing: Timing?
        public init(_ offset: Double, _ values: [Property: Value], timing: Timing? = nil) {
            self.offset = offset
            self.values = values
            self.timing = timing
        }
    }

    public var keyframes: [Keyframe] { didSet { tracks = Self.tracks(of: keyframes) } }
    /// Pour chaque propriété, ses images clés seules, triées : tirées une fois,
    /// pas à chaque image. Le koï en a 125 par tranche, et 78 tranches.
    private var tracks: [Property: [Track]] = [:]
    public var duration: Double
    public var delay: Double
    public var direction: Direction
    public var timing: Timing
    /// Garder la première image avant le départ (`animation-fill-mode: backwards`).
    public var fillsBackwards: Bool

    public init(
        _ keyframes: [Keyframe], duration: Double, delay: Double = 0, direction: Direction = .normal,
        timing: Timing = .ease, fillsBackwards: Bool = false
    ) {
        self.keyframes = keyframes.sorted { $0.offset < $1.offset }
        tracks = Self.tracks(of: self.keyframes)
        self.duration = duration
        self.delay = delay
        self.direction = direction
        self.timing = timing
        self.fillsBackwards = fillsBackwards
    }

    public var properties: Set<Property> { Set(tracks.keys) }

    struct Track: Sendable {
        var offset: Double
        var value: Value
        var timing: Timing?
    }

    static func tracks(of keyframes: [Keyframe]) -> [Property: [Track]] {
        var tracks: [Property: [Track]] = [:]
        for frame in keyframes {
            for (property, value) in frame.values { tracks[property, default: []].append(Track(offset: frame.offset, value: value, timing: frame.timing)) }
        }
        return tracks
    }

    /// La progression dans l'itération en cours, sens compris. `nil` avant le départ.
    func progress(at time: Double) -> Double? {
        guard duration > 0 else { return nil }
        var local = time - delay
        if local < 0 {
            guard fillsBackwards else { return nil }
            local = 0
        }
        let iterations = local / duration
        let iteration = iterations.rounded(.down)
        var p = iterations - iteration
        let odd = Int(iteration) % 2 == 1
        switch direction {
        case .normal: break
        case .reverse: p = 1 - p
        case .alternate: if odd { p = 1 - p }
        case .alternateReverse: if !odd { p = 1 - p }
        }
        return p
    }

    /// La valeur de `property` à l'instant `time`, ou `nil` si l'animation ne la
    /// touche pas maintenant. `base` est la valeur du nœud sans animation : les
    /// images clés qui manquent la prennent, comme en CSS.
    public func value(of property: Property, at time: Double, base: Value) -> Value? {
        guard let track = tracks[property], !track.isEmpty, let p = progress(at: time) else { return nil }
        // Une image clé qui manque à 0 % ou à 100 % prend la valeur du nœud,
        // comme en CSS, et le rythme de l'animation.
        let first = track[0], last = track[track.count - 1]
        let from: Track, to: Track
        if p < first.offset {
            from = Track(offset: 0, value: base, timing: nil)
            to = first
        } else if p >= last.offset {
            if last.offset >= 1 || track.count == 1 && last.offset >= 1 { return last.value }
            from = last
            to = Track(offset: 1, value: base, timing: nil)
        } else {
            // La dernière image dont le début est atteint : une recherche par moitiés.
            var low = 0, high = track.count - 1
            while high - low > 1 {
                let middle = (low + high) / 2
                if track[middle].offset <= p { low = middle } else { high = middle }
            }
            from = track[low]
            to = track[high]
        }
        let span = to.offset - from.offset
        let u = span > 0 ? min(1, max(0, (p - from.offset) / span)) : 1
        return Self.mix(from.value, to.value, (from.timing ?? timing).apply(u))
    }

    static func mix(_ a: Value, _ b: Value, _ u: Double) -> Value {
        switch (a, b) {
        case let (.number(x), .number(y)):
            return .number(x + (y - x) * u)
        case let (.ops(x), .ops(y)):
            // Deux listes de même forme s'interpolent opération par opération ;
            // une liste vide vaut l'identité de l'autre.
            let left = x.isEmpty ? y.map(\.identity) : x
            let right = y.isEmpty ? x.map(\.identity) : y
            if left.count == right.count {
                let mixed = zip(left, right).compactMap { TransformOp.blend($0, $1, u) }
                if mixed.count == left.count { return .ops(mixed) }
            }
            return u < 0.5 ? a : b
        default:
            return u < 0.5 ? a : b
        }
    }
}

extension Attributes {
    /// La dernière animation qui touche `property` l'emporte, comme en CSS.
    /// Sans instant (`nil`), rien ne bouge : c'est le décor quand l'utilisateur
    /// demande moins de mouvement.
    private func animated(_ property: SceneAnimation.Property, at time: Double?, base: SceneAnimation.Value) -> SceneAnimation.Value? {
        guard let time else { return nil }
        for animation in animations.reversed() {
            if let value = animation.value(of: property, at: time, base: base) { return value }
        }
        return nil
    }

    /// La transformation du nœud à l'instant `time`, `transform-origin` compris.
    public func matrix(at time: Double?) -> Affine {
        var ops = transform
        if case .ops(let moving)? = animated(.transform, at: time, base: .ops(transform)) { ops = moving }
        var individual: [TransformOp] = []
        if case .ops(let moving)? = animated(.translate, at: time, base: .ops([])) { individual = moving }
        let inner = Affine.of(individual + ops)
        if inner.isIdentity || origin == .zero { return inner }
        return Affine(tx: origin.x, ty: origin.y) * inner * Affine(tx: -origin.x, ty: -origin.y)
    }

    public func opacity(at time: Double?) -> Double {
        number(.opacity, at: time, base: opacity)
    }

    /// Une valeur numérique animée, ou `base` si rien ne la touche.
    public func number(_ property: SceneAnimation.Property, at time: Double?, base: Double) -> Double {
        if case .number(let value)? = animated(property, at: time, base: .number(base)) { return value }
        return base
    }

    public func animates(_ property: SceneAnimation.Property) -> Bool {
        animations.contains { $0.properties.contains(property) }
    }
}
