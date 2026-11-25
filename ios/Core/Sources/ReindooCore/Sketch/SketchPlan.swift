import Foundation

/// Ce que l'App doit peindre : des couches, chacune faite de lots de traits
/// coupés par une forme. Tout est en pixels de l'image finale.
public struct SketchPlan: Sendable {
    public enum Blend: Sendable { case multiply, normal }

    /// Une zone : la forme où l'on peint, moins les formes qui passent devant.
    public struct Clip: Sendable {
        public var shape: [Pt]
        public var cuts: [[Pt]]
    }

    public struct Line: Sendable {
        public var points: [Pt]
        public var width: Double
        public var alpha: Double
    }

    /// Un lot : une couleur, une zone, des traits, et parfois un voile uni.
    public struct Batch: Sendable {
        public var clip: Clip?
        public var color: RGBA
        public var lines: [Line] = []
        /// Un voile sous les traits, uni ou en dégradé depuis le centre.
        public var wash: (rect: (Pt, Pt), alpha: Double, radial: Bool)? = nil
        /// Des formes qui effacent ce qui est déjà peint dans la couche.
        public var erase: [[Pt]] = []
    }

    public struct Layer: Sendable {
        public var batches: [Batch]
        /// Le grain du papier mange la couche : un trait léger ne marque que
        /// les sommets du grain, un trait appuyé remplit aussi les creux.
        public var threshold: Double
        public var softness: Double
        public var blend: Blend
    }

    public var width: Int
    public var height: Int
    public var layers: [Layer]
    /// Une goutte de stylo-gel blanc dans les yeux : seule chose que le papier ne mange pas.
    public var glints: [(center: Pt, radius: Double)]
}

extension Sketch {
    var scene: (pieces: [Figure], back: RGBA, box: (Pt, Pt), head: (Pt, Pt), sparkles: [(Pt, Double)]) {
        switch self {
        case .giraffe(let mood):
            let f = Figures.giraffe(mood)
            return ([f], f.back, f.box, f.head, [])
        case .jackal(let mood):
            let f = Figures.jackal(mood)
            return ([f], f.back, f.box, f.head, [])
        case .animal(let species, let mood):
            let f = Figures.animal(species, mood)
            return ([f], f.back, f.box, f.head, [])
        case .backdrop(let motif):
            let f = Figures.backdrop(motif)
            return ([f], f.back, f.box, f.head, [])
        case .glyph(let glyph):
            let f = Figures.glyph(glyph)
            return ([f], f.back, f.box, f.head, [])
        case .together:
            // Le chacal d'abord : le bras de la girafe passe devant son épaule.
            let j = Figures.jackal(.together).placed(at: Pt(150, 44), scale: 0.85)
            let g = Figures.giraffe(.together)
            return ([j, g], Palette.gold, (Pt(-14, 0), Pt(336, 300)), g.head, [(Pt(262, 60), 7), (Pt(300, 120), 5), (Pt(18, 150), 6)])
        }
    }

    /// Le rapport largeur / hauteur du dessin entier.
    public var aspect: Double {
        let box = scene.box
        return (box.1.x - box.0.x) / (box.1.y - box.0.y)
    }

    /// Les traits de ce dessin, pour une image de `width` × `height` pixels.
    /// `head` : seulement la tête, pour un bouton. `frame` : l'une des trois
    /// versions d'un même dessin, qu'on montre tour à tour pour que le trait vive.
    public func plan(width: Int, height: Int, head: Bool = false, frame: Int = 0) -> SketchPlan {
        Planner(sketch: self, width: width, height: height, head: head, frame: frame).plan()
    }
}

private struct Planner {
    let pieces: [Figure]
    let back: RGBA
    let box: (Pt, Pt)
    let sparkles: [(Pt, Double)]
    let width: Int, height: Int, frame: Int
    let scale: Double, origin: Pt
    let covers: Bool

    init(sketch: Sketch, width: Int, height: Int, head: Bool, frame: Int) {
        let scene = sketch.scene
        pieces = scene.pieces; back = scene.back; sparkles = scene.sparkles
        box = head ? scene.head : scene.box
        self.width = width; self.height = height; self.frame = frame
        let w = Double(width), h = Double(height)
        let bw = box.1.x - box.0.x, bh = box.1.y - box.0.y
        // Un décor remplit l'image et déborde ; un animal tient entier dedans.
        covers = sketch.covers
        scale = covers ? max(w / bw, h / bh) : min(w / bw, h / bh)
        origin = Pt((w - bw * scale) / 2 - box.0.x * scale, (h - bh * scale) / 2 - box.0.y * scale)
    }

    func P(_ p: Pt) -> Pt { origin + p * scale }

    /// Le bord d'une zone hachurée n'est jamais le trait : il erre d'un pixel ou deux.
    func rough(_ shape: [Pt], seed: Int, amount: Double) -> [Pt] {
        shape.enumerated().map { i, p in
            let j = amount * scale * 0.5
            return P(p) + Pt(Chance.wander(Double(i) * 0.09, seed) * j, Chance.wander(Double(i) * 0.09 + 50, seed) * j)
        }
    }

    func bounds(_ shape: [Pt]) -> (Pt, Pt) {
        var lo = Pt(.infinity, .infinity), hi = Pt(-.infinity, -.infinity)
        for p in shape { let q = P(p); lo = pointwiseMin(lo, q); hi = pointwiseMax(hi, q) }
        return (lo, hi)
    }

    // MARK: Les outils

    /// Crayon de couleur : des traits parallèles, de droitier, un peu ondulés, avec des trous.
    func hatch(_ shape: [Pt], _ o: Hatch, cuts: [[Pt]], seed name: String) -> SketchPlan.Batch {
        // Les couleurs ne bougent pas d'une version à l'autre : seul le contour bout.
        let seed = Int(Chance.hash(name))
        var R = Chance.Generator(UInt32(truncatingIfNeeded: seed))
        let (lo, hi) = bounds(shape)
        let a = o.angle * .pi / 180, u = Pt(cos(a), sin(a)), n = Pt(-u.y, u.x)
        let c = (lo + hi) / 2, r = length(hi - lo) / 2 + 8
        let gap = o.gap * scale / 2.6, width = o.width * scale / 2.6
        var lines: [SketchPlan.Line] = []
        var t = -r
        while t <= r {
            // Un trait est un geste : il commence et finit au hasard.
            let len = r * (0.5 + R.next() * 0.9), off = (R.next() - 0.5) * r
            let alpha = o.alpha * (0.6 + R.next() * 0.4), w = width * (0.7 + R.next() * 0.6)
            let steps = max(1, Int(ceil(len * 2 / 6)))
            let points = (0...steps).map { k -> Pt in
                let s = off - len + 2 * len * Double(k) / Double(steps)
                let wob = Chance.wander(Double(k) * 0.25 + t, seed) * gap * 0.35
                return c + u * s + n * (t + wob)
            }
            lines.append(.init(points: points, width: w, alpha: alpha))
            t += gap * (0.75 + R.next() * 0.5)
            if R.next() < o.skip { t += gap } // la main saute un rang de temps en temps
        }
        return .init(clip: .init(shape: rough(shape, seed: seed, amount: o.rough), cuts: cuts.map { $0.map(P) }), color: o.color, lines: lines)
    }

    /// Le crayon du contour : tracé deux fois, plus appuyé au milieu qu'aux bouts.
    func pencil(_ points: [Pt], closed: Bool, width: Double, alpha: Double, color: RGBA, cuts: [[Pt]], wander: Double = 0.9, seed name: String) -> SketchPlan.Batch {
        let seed = Int(Chance.hash(name)) &+ frame &* 104_729
        var lines: [SketchPlan.Line] = []
        guard points.count > 1 else { return .init(clip: nil, color: color) }
        for pass in 0..<2 {
            var R = Chance.Generator(UInt32(truncatingIfNeeded: seed &+ pass &* 31))
            var list = points
            if closed {
                // Partir n'importe où sur le contour, et dépasser un peu le départ.
                let start = Int(R.next() * Double(points.count)), over = Int(Double(points.count) * (0.04 + R.next() * 0.05))
                list = (0..<(points.count + over)).map { points[(start + $0) % points.count] }
            }
            let n = list.count, amp = wander * (pass == 1 ? 1.4 : 1)
            var previous: Pt? = nil
            for k in 0..<n {
                let t = Double(k) / Double(max(1, n - 1)), p = P(list[k])
                let q = P(list[min(n - 1, k + 1)]), d = q - p, dl = max(length(d), 1e-9)
                let off = Chance.wander(Double(k) * 0.06 + Double(pass) * 9, seed) * amp * scale * 0.5 + (pass == 1 ? (R.next() - 0.5) * 0.3 : 0)
                let current = Pt(p.x - d.y / dl * off, p.y + d.x / dl * off)
                if let previous {
                    let press = pow(sin(.pi * min(1, max(0, t * 1.1 - 0.05))), 0.6) * (0.75 + 0.25 * Chance.wander(Double(k) * 0.1, seed + 3))
                    let a = alpha * (pass == 1 ? 0.45 : 1) * (0.35 + 0.65 * press)
                    let w = max(0.6, width * scale / 2.6 * (0.45 + 0.75 * press) * (pass == 1 ? 0.7 : 1))
                    lines.append(.init(points: [previous, current], width: w, alpha: a))
                }
                previous = current
            }
        }
        return .init(clip: cuts.isEmpty ? nil : .init(shape: [], cuts: cuts.map { $0.map(P) }), color: color, lines: lines)
    }

    /// Pastel sec : de petits coups poudreux, et une trace de doigt dessous.
    func pastel(_ d: Dab, seed name: String) -> SketchPlan.Batch {
        let seed = Int(Chance.hash(name))
        var R = Chance.Generator(UInt32(truncatingIfNeeded: seed))
        let (lo, hi) = bounds(d.shape)
        let c = (lo + hi) / 2, rr = max(hi.x - lo.x, hi.y - lo.y) / 2
        let count = Int(ceil((hi.x - lo.x) * (hi.y - lo.y) / (scale * scale) * d.density))
        let a0 = d.angle * .pi / 180
        var lines: [SketchPlan.Line] = []
        for _ in 0..<count {
            let x = lo.x + R.next() * (hi.x - lo.x), y = lo.y + R.next() * (hi.y - lo.y)
            let fall = d.even ? 1 : 1 - min(1, length(Pt(x, y) - c) / max(rr, 1e-9))
            let len = scale * (2 + R.next() * 5), a = a0 + (R.next() - 0.5) * 0.6
            let alpha = d.alpha * (0.3 + 0.7 * fall) * (0.4 + R.next() * 0.6)
            let w = scale * d.width * (0.6 + R.next() * 0.8)
            lines.append(.init(points: [Pt(x, y), Pt(x + cos(a) * len, y + sin(a) * len)], width: w, alpha: alpha))
        }
        var batch = SketchPlan.Batch(clip: .init(shape: rough(d.shape, seed: seed, amount: 4), cuts: []), color: d.color, lines: lines)
        batch.wash = ((lo, hi), d.alpha * (d.even ? 0.55 : 0.22), !d.even)
        return batch
    }

    // MARK: Les passes

    func plan() -> SketchPlan {
        // Toutes les parties, du fond vers l'avant, à travers les deux animaux.
        let all: [(part: Piece, figure: Figure)] = pieces.flatMap { f in f.parts.map { ($0, f) } }
        let solid = all.map { !$0.part.overlay }
        // Ce qui passe devant la partie `i` : toutes les parties pleines après elle.
        func later(_ i: Int) -> [[Pt]] { ((i + 1)..<all.count).filter { solid[$0] }.map { all[$0].part.shape } }

        var layers: [SketchPlan.Layer] = []
        // 1. Un aplat de pastel, comme une page, et une ombre au sol. Il s'arrête à l'animal.
        // Un décor couvre toute l'image visible ; un animal a sa page, avec un bord de papier.
        let seen = (Pt(-origin.x / scale - 6, -origin.y / scale - 6), Pt((Double(width) - origin.x) / scale + 6, (Double(height) - origin.y) / scale + 6))
        let page = covers ? Shape.panel(seen.0.x, seen.0.y, seen.1.x, seen.1.y, 2) : Shape.panel(box.0.x + 10, box.0.y + 10, box.1.x - 10, box.1.y - 8, 26)
        var wash: [SketchPlan.Batch] = [
            pastel(Dab(shape: page, color: back, alpha: covers ? 0.75 : 0.6, density: 0.35, width: 5, angle: 64, even: true), seed: "panel"),
        ]
        for (i, f) in pieces.enumerated() {
            wash.append(pastel(Dab(shape: Shape.ellipse(f.feet.0.x, f.feet.0.y + 2, f.feet.1, f.feet.1 * 0.14, 0, 0.1, 200 + i), color: Palette.ground, alpha: 0.7, density: 2, width: 1.8, angle: 4), seed: "ground\(i)"))
        }
        for (i, s) in (sparkles + pieces.flatMap(\.sparkles)).enumerated() {
            wash.append(pastel(Dab(shape: Shape.sparkle(s.0.x, s.0.y, s.1), color: Palette.glow, alpha: 0.95, density: 4, width: 1.3, angle: 30), seed: "spark\(i)"))
        }
        var mask = SketchPlan.Batch(clip: nil, color: back)
        mask.erase = all.enumerated().filter { solid[$0.offset] }.map { i, item in rough(item.part.shape, seed: Int(Chance.hash("sil\(i)")), amount: 2.5) }
        wash.append(mask)
        layers.append(.init(batches: wash, threshold: 0.4, softness: 0.24, blend: .multiply))

        // 2. Les crayons de couleur, couches claires d'abord.
        var fills: [SketchPlan.Batch] = []
        for (i, item) in all.enumerated() {
            for (k, h) in item.part.fills.enumerated() { fills.append(hatch(item.part.shape, h, cuts: later(i), seed: "fill\(i).\(k)")) }
        }
        layers.append(.init(batches: fills, threshold: 0.3, softness: 0.3, blend: .multiply))

        // 3. Les ombres, loin de la lumière qui vient d'en haut à gauche : violet et bleu, jamais gris.
        var shades: [SketchPlan.Batch] = []
        for (i, item) in all.enumerated() {
            guard let s = item.part.shade else { continue }
            let h = Hatch(color: item.figure.shadeTone, angle: 35, gap: 2.4, alpha: s.alpha)
            shades.append(hatch(item.part.shape, h, cuts: [Shape.shift(item.part.shape, -s.dx, -s.dy)] + later(i), seed: "shade\(i)"))
        }
        layers.append(.init(batches: shades, threshold: 0.34, softness: 0.3, blend: .multiply))

        // 4. Les joues et les lumières, au pastel.
        let dabs = pieces.enumerated().flatMap { n, f in f.pastels.enumerated().map { pastel($0.element, seed: "pastel\(n).\($0.offset)") } }
        layers.append(.init(batches: dabs, threshold: 0.38, softness: 0.25, blend: .normal))

        // 5. Le crayon chaud : les accents sombres, puis les contours, cachés derrière ce qui vient après.
        var ink: [SketchPlan.Batch] = []
        for (n, f) in pieces.enumerated() {
            for (i, d) in f.darks.enumerated() {
                ink.append(hatch(d.shape, Hatch(color: d.color, angle: -40, gap: 0.9, alpha: 0.95, width: 1.6, rough: 0.6), cuts: [], seed: "dark\(n).\(i)"))
            }
        }
        for (i, item) in all.enumerated() where item.part.line {
            ink.append(pencil(item.part.open ?? item.part.shape, closed: item.part.open == nil, width: item.part.width, alpha: item.part.lineAlpha, color: item.figure.ink, cuts: later(i), seed: "line\(i)"))
        }
        for (n, f) in pieces.enumerated() {
            for (i, l) in f.lines.enumerated() {
                ink.append(pencil(l.points, closed: false, width: l.width, alpha: l.alpha, color: f.ink, cuts: [], seed: "feature\(n).\(i)"))
            }
        }
        layers.append(.init(batches: ink, threshold: 0.2, softness: 0.3, blend: .multiply))

        let glints = pieces.flatMap(\.glints).enumerated().map { i, g in
            (center: P(g), radius: scale * (1.5 + Double(i % 2) * 0.2))
        }
        return SketchPlan(width: width, height: height, layers: layers, glints: glints)
    }
}

// MARK: Le papier

public enum Paper {
    /// Le grain d'un papier à grain fin : une dent fine, une ondulation plus
    /// large, et quelques fibres couchées. De 0 à 1, un pixel par valeur.
    /// Le grain est un carreau qui se raccorde à lui-même sur ses quatre bords :
    /// calculé une fois, il se pose sur une image de n'importe quelle taille.
    public static func tooth(width: Int, height: Int) -> [Float] {
        let t = tile, grain = Self.grain
        var g = [Float](repeating: 0, count: width * height)
        g.withUnsafeMutableBufferPointer { out in
            grain.withUnsafeBufferPointer { src in
                for y in 0..<height {
                    let row = (y % t) * t
                    for x in 0..<width { out[y * width + x] = src[row + x % t] }
                }
            }
        }
        return g
    }

    static let tile = 680

    /// Chaque bruit fait un nombre entier de cases sur le carreau : 400 cases
    /// de 1,7 pixel, 113 de 6, et des fibres de 31 × 309.
    private static let grain: [Float] = {
        let t = tile
        var g = [Float](repeating: 0, count: t * t)
        for y in 0..<t {
            for x in 0..<t {
                let fx = Double(x) / Double(t), fy = Double(y) / Double(t)
                let fine = looped(fx * 400, fy * 400, 400, 400, 3)
                let mid = looped(fx * 113, fy * 113, 113, 113, 5)
                let fibre = looped(fx * 31, fy * 309, 31, 309, 9)
                g[y * t + x] = Float(0.55 * fine + 0.3 * mid + 0.15 * fibre)
            }
        }
        return g
    }()

    /// Le bruit doux de `Chance`, replié sur lui-même tous les `nx` × `ny`.
    private static func looped(_ x: Double, _ y: Double, _ nx: Int, _ ny: Int, _ s: Int) -> Double {
        let xi = Int(floor(x)), yi = Int(floor(y)), xf = x - floor(x), yf = y - floor(y)
        let u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf)
        let x0 = xi % nx, x1 = (xi + 1) % nx, y0 = yi % ny, y1 = (yi + 1) % ny
        let a = Chance.cell(x0, y0, s), b = Chance.cell(x1, y0, s), c = Chance.cell(x0, y1, s), d = Chance.cell(x1, y1, s)
        return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v
    }

    /// La couleur du papier, pixel par pixel, en RGBA 8 bits : crème, plus
    /// jaune sur les bords, comme une feuille qu'on a tenue.
    public static func sheet(_ tooth: [Float], width: Int, height: Int, into pixels: UnsafeMutableBufferPointer<UInt8>) {
        let short = Double(min(width, height))
        for i in 0..<(width * height) {
            let t = Double(tooth[i]), x = i % width, y = i / width
            let edge = Double(min(x, y, width - x, height - y)) / short
            let age = edge < 0.08 ? (0.08 - edge) * 0.9 : 0
            let shade = (t - 0.5) * 14
            pixels[i * 4] = UInt8(clamping: Int(244 + shade - age * 60))
            pixels[i * 4 + 1] = UInt8(clamping: Int(236 + shade - age * 80))
            pixels[i * 4 + 2] = UInt8(clamping: Int(220 + shade - age * 120))
            pixels[i * 4 + 3] = 255
        }
    }

    /// Le papier mange une couche peinte (RGBA prémultiplié) : là où le grain
    /// est creux, le pigment ne prend pas.
    public static func bite(_ pixels: UnsafeMutableBufferPointer<UInt8>, tooth: [Float], threshold: Double, softness: Double) {
        for i in 0..<tooth.count {
            let a = Double(pixels[i * 4 + 3])
            guard a > 0 else { continue }
            let k = min(1, max(0, (Double(tooth[i]) - threshold * (1 - a / 400)) / softness))
            guard k < 1 else { continue }
            for c in 0..<4 { pixels[i * 4 + c] = UInt8(Double(pixels[i * 4 + c]) * k) }
        }
    }
}
