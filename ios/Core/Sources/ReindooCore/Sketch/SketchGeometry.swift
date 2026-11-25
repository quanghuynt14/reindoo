import Foundation

// Les dessins de « Giao tiếp » : la girafe et le chacal, tracés trait par trait
// comme à la main — un crayon chaud pour le contour, des crayons de couleur
// hachurés, un peu de pastel, sur un papier qui a du grain.
//
// Rien n'est une image. Core calcule chaque trait à partir d'une graine fixe :
// le dessin est le même sur tous les téléphones, et un test peut le vérifier.
// L'App ne fait que peindre les traits que Core lui donne.
//
// Ce code reprend la maquette publiée pendant la conception (sketch 3) : mêmes
// formes, mêmes outils, mêmes graines.

public typealias Pt = SIMD2<Double>

/// Le hasard des traits, toujours le même pour une même graine.
enum Chance {
    static func hash(_ text: String) -> UInt32 {
        var h: UInt32 = 2_166_136_261
        for unit in text.utf16 { h ^= UInt32(unit); h = h &* 16_777_619 }
        return h
    }

    /// mulberry32 : rapide, et assez irrégulier pour une main.
    struct Generator {
        var state: UInt32
        init(_ seed: UInt32) { state = seed }
        mutating func next() -> Double {
            state = state &+ 0x6D2B_79F5
            var t = (state ^ (state >> 15)) &* (1 | state)
            t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
            return Double(t ^ (t >> 14)) / 4_294_967_296
        }
    }

    static func cell(_ x: Int, _ y: Int, _ s: Int) -> Double {
        let a = UInt32(bitPattern: Int32(truncatingIfNeeded: x)) &* 374_761_393
        let b = UInt32(bitPattern: Int32(truncatingIfNeeded: y)) &* 668_265_263
        let c = UInt32(bitPattern: Int32(truncatingIfNeeded: s)) &* 1_442_695_041
        var h = a &+ b &+ c
        h = (h ^ (h >> 13)) &* 1_274_126_177
        return Double(h ^ (h >> 16)) / 4_294_967_296
    }

    /// Un bruit doux en deux dimensions, de 0 à 1.
    static func noise(_ x: Double, _ y: Double, _ s: Int) -> Double {
        let xi = Int(floor(x)), yi = Int(floor(y)), xf = x - floor(x), yf = y - floor(y)
        let u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf)
        let a = cell(xi, yi, s), b = cell(xi + 1, yi, s), c = cell(xi, yi + 1, s), d = cell(xi + 1, yi + 1, s)
        return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v
    }

    /// Un bruit doux le long d'une ligne, de −1 à 1 : le tremblé d'une main.
    static func wander(_ t: Double, _ s: Int) -> Double {
        let i = Int(floor(t)), f = t - floor(t), u = f * f * (3 - 2 * f)
        let a = cell(i, 0, s), b = cell(i + 1, 0, s)
        return (a + (b - a) * u) * 2 - 1
    }
}

/// Les formes, dans un espace de 200 × 300 par animal.
enum Shape {
    /// Un chemin SVG absolu (M, L, C, Q, Z), échantillonné à peu près tous les
    /// points : assez fin pour qu'un trait s'y appuie.
    static func path(_ d: String) -> [Pt] {
        var tokens: [String] = []
        var current = ""
        for ch in d {
            if "MLCQZ".contains(ch) {
                if !current.isEmpty { tokens.append(current); current = "" }
                tokens.append(String(ch))
            } else if ch == " " || ch == "," {
                if !current.isEmpty { tokens.append(current); current = "" }
            } else if ch == "-" && !current.isEmpty {
                tokens.append(current); current = "-"
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { tokens.append(current) }

        var points: [Pt] = []
        var i = 0, command = "M", cursor = Pt(0, 0), start = Pt(0, 0)
        func number() -> Double { defer { i += 1 }; return Double(tokens[i]) ?? 0 }
        func point() -> Pt { let x = number(); return Pt(x, number()) }
        func line(_ a: Pt, _ b: Pt) {
            let n = max(2, Int(ceil(length(b - a))))
            for k in 1...n { points.append(a + (b - a) * Double(k) / Double(n)) }
        }
        func cubic(_ p0: Pt, _ p1: Pt, _ p2: Pt, _ p3: Pt) {
            let n = max(4, Int(ceil(length(p1 - p0) + length(p2 - p1) + length(p3 - p2))))
            for k in 1...n {
                let t = Double(k) / Double(n), m = 1 - t
                points.append(p0 * (m * m * m) + p1 * (3 * m * m * t) + p2 * (3 * m * t * t) + p3 * (t * t * t))
            }
        }
        while i < tokens.count {
            if "MLCQZ".contains(tokens[i]) { command = tokens[i]; i += 1 }
            switch command {
            case "M":
                cursor = point(); start = cursor; points.append(cursor); command = "L"
            case "L":
                let p = point(); line(cursor, p); cursor = p
            case "C":
                let a = point(), b = point(), p = point(); cubic(cursor, a, b, p); cursor = p
            case "Q":
                let c = point(), p = point()
                cubic(cursor, cursor + (c - cursor) * (2.0 / 3), p + (c - p) * (2.0 / 3), p); cursor = p
            default:
                line(cursor, start); cursor = start
                if i < tokens.count, !"MLCQZ".contains(tokens[i]) { i += 1 }
            }
        }
        return points
    }

    /// Une ellipse, un peu cabossée si `wobble` > 0 : une tache n'est jamais ronde.
    static func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ rotation: Double = 0, _ wobble: Double = 0, _ seed: Int = 1) -> [Pt] {
        let n = max(24, Int(ceil(2 * .pi * max(rx, ry))))
        let c = cos(rotation * .pi / 180), s = sin(rotation * .pi / 180)
        return (0..<n).map { k in
            let a = Double(k) / Double(n) * 2 * .pi
            let w = 1 + wobble * Chance.wander(a * 1.6, seed)
            let x = cos(a) * rx * w, y = sin(a) * ry * w
            return Pt(cx + x * c - y * s, cy + x * s + y * c)
        }
    }

    static func rotate(_ points: [Pt], _ degrees: Double, around center: Pt) -> [Pt] {
        guard degrees != 0 else { return points }
        let c = cos(degrees * .pi / 180), s = sin(degrees * .pi / 180)
        return points.map { p in
            let d = p - center
            return Pt(center.x + d.x * c - d.y * s, center.y + d.x * s + d.y * c)
        }
    }

    static func shift(_ points: [Pt], _ dx: Double, _ dy: Double) -> [Pt] { points.map { $0 + Pt(dx, dy) } }

    /// Un bras, une patte : un tube le long d'une courbe.
    static func tube(_ d: String, _ w0: Double, _ w1: Double) -> (shape: [Pt], end: Pt) {
        let c = path(d)
        var left: [Pt] = [], right: [Pt] = []
        for i in c.indices {
            let a = c[max(0, i - 1)], b = c[min(c.count - 1, i + 1)]
            let d = b - a, l = max(length(d), 1e-9)
            let w = (w0 + (w1 - w0) * Double(i) / Double(max(1, c.count - 1))) / 2
            left.append(Pt(c[i].x - d.y / l * w, c[i].y + d.x / l * w))
            right.append(Pt(c[i].x + d.y / l * w, c[i].y - d.x / l * w))
        }
        return (left + right.reversed(), c.last ?? .zero)
    }

    static func sparkle(_ cx: Double, _ cy: Double, _ r: Double) -> [Pt] {
        let k = r * 0.18
        return path("M\(cx) \(cy - r) Q\(cx + k) \(cy - k) \(cx + r) \(cy) Q\(cx + k) \(cy + k) \(cx) \(cy + r) Q\(cx - k) \(cy + k) \(cx - r) \(cy) Q\(cx - k) \(cy - k) \(cx) \(cy - r) Z")
    }

    static func panel(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ r: Double) -> [Pt] {
        path("M\(x0 + r) \(y0) L\(x1 - r) \(y0) Q\(x1) \(y0) \(x1) \(y0 + r) L\(x1) \(y1 - r) Q\(x1) \(y1) \(x1 - r) \(y1) L\(x0 + r) \(y1) Q\(x0) \(y1) \(x0) \(y1 - r) L\(x0) \(y0 + r) Q\(x0) \(y0) \(x0 + r) \(y0) Z")
    }
}

@inline(__always) func length(_ p: Pt) -> Double { (p.x * p.x + p.y * p.y).squareRoot() }
