import Foundation

// Braille Stars : un ciel de nuit rendu comme un terminal rend une image en
// braille. L'écran est une grille de cellules de 2 sur 4 points ; chaque
// cellule a une luminosité, et autant de ses points sont levés.
// D'après theme-examples (Anthropic, Apache 2.0), scenes/braille-stars.ts.

struct BrailleStars {
    static let pitch = 7.0
    static let cellWidth = 19.0
    static let cellHeight = 33.0
    static let inset = 3.0
    static let shimmerGroups = 8
    static let shimmerSeconds = 40.0
    static let skyBase = "#0d1536"
    static let landBase = "#070b1f"

    enum PaintName: CaseIterable { case dust, haze, cloud, star, warm, orchid, amber, figure, ridgeCrest }

    struct Dot: Hashable {
        var x: Double
        var y: Double
    }

    /// Les points par peinture, dans l'ordre où les peintures arrivent.
    struct Layer {
        var order: [PaintName] = []
        var dots: [PaintName: [Dot]] = [:]
        mutating func add(_ paint: PaintName, _ x: Double, _ y: Double) {
            if dots[paint] == nil { order.append(paint) }
            dots[paint, default: []].append(Dot(x: x, y: y))
        }
    }

    struct Sample {
        var x, y, t, tangentX, tangentY: Double
    }

    struct Reading {
        var brightness, along, across, underCards: Double
    }

    struct Layout {
        var skyLeft, skyRight, skyTop, skyBottom: Double
        var pole: (Double, Double)
        var spine: [(Double, Double)]
        var bandFrom: Double
        var underCards: @Sendable (Double, Double) -> Double
        var calm: @Sendable (Double, Double) -> Double
        var region: @Sendable (Double, Double) -> Int
        var figureShift: (Double, Double)
        var front: @Sendable (Double) -> Double
        var back: @Sendable (Double) -> Double
        var ridgeTop: Double
        var shoot: (Double, Double)

        static var original: Layout { Layout(
            skyLeft: -110, skyRight: 1730, skyTop: -100, skyBottom: 1000, pole: (-120, -140),
            spine: [(1830, -60), (1430, 470), (1010, 1040)], bandFrom: 900,
            underCards: { x, y in 1 - smoothStep(1150, 1230, x) * (1 - smoothStep(230, 310, y)) },
            calm: { x, y in
                let insideX = smoothStep(330, 470, x) * (1 - smoothStep(1070, 1260, x))
                let insideY = smoothStep(30, 110, y) * (1 - smoothStep(860, 940, y))
                return 1 - 0.8 * insideX * insideY
            },
            region: { x, y in
                if x < 450 { return y < 330 ? 0 : y < 640 ? 1 : 2 }
                if x > 1150 { return y < 480 ? 3 : 4 }
                return y < 500 ? 5 : x < 800 ? 2 : 4
            },
            figureShift: (0, 0),
            front: { x in 990 - 140 * smoothStep(1000, 1640, x) - 180 * (1 - smoothStep(-60, 500, x)) - 10 * sin(x / 173 + 0.6) - 6 * sin(x / 61 + 2.1) },
            back: { x in 968 - 110 * smoothStep(1120, 1520, x) + 50 * smoothStep(1500, 1720, x) - 110 * (1 - smoothStep(60, 640, x)) - 12 * sin(x / 227 + 2.4) - 6 * sin(x / 83 + 0.3) },
            ridgeTop: 720, shoot: (1215, 470)
        ) }

        /// La Voie lactée traverse l'écran en diagonale ; sous le texte elle
        /// n'est plus qu'un fantôme. Le Scorpion est en haut à gauche, les
        /// collines en bas.
        static func portrait(_ w: Double, _ h: Double) -> Layout {
            Layout(
                skyLeft: -110, skyRight: w + 130, skyTop: -100, skyBottom: h, pole: (-120, -140),
                spine: [(w * 1.2, -h * 0.05), (w * 0.85, h * 0.5), (w * 0.25, h * 1.05)], bandFrom: -110,
                underCards: { _, _ in 1 },
                calm: { x, y in
                    let insideX = smoothStep(w * 0.02, w * 0.14, x) * (1 - smoothStep(w * 0.86, w * 0.98, x))
                    let insideY = smoothStep(h * 0.17, h * 0.25, y) * (1 - smoothStep(h * 0.62, h * 0.7, y))
                    return 1 - 0.8 * insideX * insideY
                },
                region: { x, y in
                    if y < h * 0.22 { return x < w / 2 ? 0 : 3 }
                    if y > h * 0.66 { return x < w / 2 ? 2 : 4 }
                    return x < w / 2 ? 1 : 5
                },
                figureShift: (40 - 1192, h * 0.04 - 276),
                front: { x in h - 10 - h * 0.08 * smoothStep(w * 0.55, w * 1.02, x) - h * 0.12 * (1 - smoothStep(-w * 0.04, w * 0.35, x)) - 10 * sin(x / 173 + 0.6) - 6 * sin(x / 61 + 2.1) },
                back: { x in h - 32 - h * 0.1 * smoothStep(w * 0.6, w * 0.95, x) + h * 0.04 * smoothStep(w * 0.95, w * 1.1, x) - h * 0.09 * (1 - smoothStep(w * 0.04, w * 0.4, x)) - 12 * sin(x / 227 + 2.4) - 6 * sin(x / 83 + 0.3) },
                ridgeTop: h * 0.7, shoot: (w * 0.72, h * 0.07)
            )
        }
    }

    static let paints: [PaintName: (String, Double, Double)] = [
        .dust: ("#4c62b4", 0.7, 2.8), .haze: ("#8ea6ff", 0.8, 3.5), .cloud: ("#b4c2ff", 0.95, 4.1),
        .star: ("#dde4ff", 0.95, 4.7), .warm: ("#ffdcae", 0.95, 4.6), .orchid: ("#c890d6", 0.85, 4),
        .amber: ("#e9d3ad", 1, 4.4), .figure: ("#fff1d0", 0.88, 4.4), .ridgeCrest: ("#4a5ca6", 0.7, 4),
    ]
    static let raiseOrder = [2, 5, 0, 7, 3, 4, 1, 6]
    static let tones: [PaintName] = [.dust, .haze, .cloud, .star]

    let width: Double
    let height: Double
    let layout: Layout

    static func hash(_ x: Double, _ y: Double, _ salt: Int) -> Double {
        let a = Int32(truncatingIfNeeded: Int(JS.int32(x))) &* 374_761_393
        let b = Int32(truncatingIfNeeded: Int(JS.int32(y))) &* 668_265_263
        let c = Int32(truncatingIfNeeded: salt) &* 2_147_483_647
        var h = a &+ b &+ c
        h = (h ^ Int32(bitPattern: UInt32(bitPattern: h) >> 15)) &* Int32(bitPattern: 0x85eb_ca6b)
        h = (h ^ Int32(bitPattern: UInt32(bitPattern: h) >> 13)) &* Int32(bitPattern: 0xc2b2_ae35)
        h = h ^ Int32(bitPattern: UInt32(bitPattern: h) >> 16)
        return Double(UInt32(bitPattern: h)) / 4_294_967_296
    }

    static func hash(_ x: Int, _ y: Int, _ salt: Int) -> Double { hash(Double(x), Double(y), salt) }

    static func smoothStep(_ low: Double, _ high: Double, _ value: Double) -> Double {
        let t = min(1, max(0, (value - low) / (high - low)))
        return t * t * (3 - 2 * t)
    }

    static func noise(_ x: Double, _ y: Double, _ scale: Double, _ salt: Int) -> Double {
        let gx = (x / scale).rounded(.down), gy = (y / scale).rounded(.down)
        let fx = smoothStep(0, 1, x / scale - gx), fy = smoothStep(0, 1, y / scale - gy)
        let top = hash(gx, gy, salt) * (1 - fx) + hash(gx + 1, gy, salt) * fx
        let bottom = hash(gx, gy + 1, salt) * (1 - fx) + hash(gx + 1, gy + 1, salt) * fx
        return top * (1 - fy) + bottom * fy
    }

    static func dotX(_ column: Int, _ dot: Int) -> Double { Double(column) * cellWidth + inset + Double(dot) * pitch }
    static func dotY(_ row: Int, _ dot: Int) -> Double { Double(row) * cellHeight + inset + Double(dot) * pitch }

    static func raised(_ column: Int, _ row: Int, _ count: Int, _ variant: Int) -> [Dot] {
        let mirror = hash(column, row, 40 + variant * 2) < 0.5
        let flip = hash(column, row, 41 + variant * 2) < 0.5
        return (0..<max(0, count)).map { rank in
            let dot = raiseOrder[rank]
            let dc = mirror ? 1 - dot % 2 : dot % 2
            let dr = flip ? 3 - (dot >> 1) : dot >> 1
            return Dot(x: dotX(column, dc), y: dotY(row, dr))
        }
    }

    /// Une teinte posée sur le ciel, calculée une fois : une couleur opaque.
    static func blend(_ colour: String, _ opacity: Double, _ base: String) -> RGBA {
        let top = RGBA(colour), under = RGBA(base)
        func mix(_ a: Double, _ b: Double) -> Double { JS.round((a * 255) * opacity + (b * 255) * (1 - opacity)) / 255 }
        return RGBA(mix(top.r, under.r), mix(top.g, under.g), mix(top.b, under.b))
    }

    /// Un chemin par peinture : un trait de longueur nulle aux bouts ronds est un point.
    static func write(_ layer: Layer) -> [Node] {
        layer.order.map { paint in
            let (colour, opacity, width) = paints[paint]!
            let dots = layer.dots[paint]!.sorted { $0.y != $1.y ? $0.y < $1.y : $0.x < $1.x }
            var commands: [PathData.Command] = []
            for dot in dots { commands += [.move(dot.x, dot.y), .line(dot.x, dot.y)] }
            return Node.path(PathData(commands)).stroke(.color(blend(colour, opacity, paint == .ridgeCrest ? landBase : skyBase)), width: width)
        }
    }

    func spine() -> [Sample] {
        let p = layout.spine
        let points = (0...60).map { step -> (Double, Double, Double) in
            let t = Double(step) / 60
            let x = (1 - t) * (1 - t) * p[0].0 + 2 * (1 - t) * t * p[1].0 + t * t * p[2].0
            let y = (1 - t) * (1 - t) * p[0].1 + 2 * (1 - t) * t * p[1].1 + t * t * p[2].1
            return (x, y, t)
        }
        return points.indices.map { i in
            let before = points[max(0, i - 1)], after = points[min(points.count - 1, i + 1)]
            let length = hypot(after.0 - before.0, after.1 - before.1)
            return Sample(x: points[i].0, y: points[i].1, t: points[i].2, tangentX: (after.0 - before.0) / length, tangentY: (after.1 - before.1) / length)
        }
    }

    func milkyWay(_ x: Double, _ y: Double, _ spine: [Sample]) -> Reading {
        var best = Double.infinity
        var nearest = spine[0]
        for sample in spine {
            let d = (sample.x - x) * (sample.x - x) + (sample.y - y) * (sample.y - y)
            if d < best {
                best = d
                nearest = sample
            }
        }
        let s = Self.smoothStep
        let across = (x - nearest.x) * nearest.tangentY - (y - nearest.y) * nearest.tangentX
        let halfWidth = (66 + 80 * s(0.15, 0.85, nearest.t)) * (0.7 + 0.6 * Self.noise(nearest.t * 900, 0, 130, 19))
        let band = exp(-(across * across) / (halfWidth * halfWidth))
        let along = (0.62 + 0.38 * s(0.1, 0.7, nearest.t)) * (1 - s(0.86, 0.98, nearest.t))
        let laneCentre = 4 + 38 * sin(nearest.t * 8) + 16 * sin(nearest.t * 19 + 1)
        let laneWidth = 22 + 12 * nearest.t
        let lane = 1 - 0.93 * exp(-((across - laneCentre) * (across - laneCentre)) / (laneWidth * laneWidth))
        let clump = 0.3 + 2 * Self.noise(x, y, 105, 11) * Self.noise(x, y, 41, 12)
        let underCards = layout.underCards(x, y)
        let brightness = min(1, (0.3 * pow(band, 0.8) + 0.86 * pow(band, 1.2) * clump) * along * lane) * (0.25 + 0.75 * underCards)
        return Reading(brightness: brightness, along: nearest.t, across: across, underCards: underCards)
    }

    static func bandPaint(_ tone: Int, _ warm: Bool, _ orchid: Bool, _ rank: Int, _ count: Int) -> PaintName {
        if warm && rank < 3 { return .warm }
        if orchid && rank < 2 { return .orchid }
        let step = (rank == 0 && count >= 3 ? 1 : 0) - (rank >= count - 1 && count >= 2 ? 1 : 0) - (rank >= count - 2 && count >= 4 ? 1 : 0)
        return tones[min(3, max(0, tone + step))]
    }

    static func stepped(_ track: [(Double, Double)], seconds: Double, delay: Double = 0) -> Animation {
        Animation(track.map { Animation.Keyframe($0.0, [.strokeOpacity: .n($0.1)]) }, duration: seconds, delay: delay, timing: .steps(1))
    }

    static let first: [(Double, Double)] = [(0, 1), (0.4, 0.66), (0.43, 0.33), (0.46, 0), (0.9, 0.33), (0.93, 0.66), (0.96, 1), (1, 1)]
    static let second: [(Double, Double)] = [(0, 0), (0.4, 0.33), (0.43, 0.66), (0.46, 1), (0.9, 0.66), (0.93, 0.33), (0.96, 0), (1, 0)]
    static let pulse: [(Double, Double)] = [(0, 1), (0.3, 0.8), (0.36, 0.65), (0.42, 0.5), (0.48, 0.35), (0.7, 0.5), (0.76, 0.6), (0.82, 0.8), (0.88, 1), (1, 1)]
    static let wink: [(Double, Double)] = [(0, 1), (0.4, 0.8), (0.46, 0.62), (0.52, 0.45), (0.7, 0.62), (0.76, 0.8), (0.82, 1), (1, 1)]
    static let small: [(Double, Double)] = [(0, 1), (0.3, 0.6), (0.36, 0.25), (0.42, 0), (0.92, 0.3), (0.96, 0.7), (1, 1)]
    static let medium: [(Double, Double)] = [(0, 0), (0.3, 0.4), (0.36, 0.75), (0.42, 1), (0.58, 0.6), (0.62, 0.25), (0.66, 0), (0.8, 0.4), (0.84, 1), (0.92, 0.6), (0.96, 0.25), (1, 0)]
    static let large: [(Double, Double)] = [(0, 0), (0.58, 0.4), (0.62, 0.75), (0.66, 1), (0.8, 0.6), (0.84, 0), (1, 0)]
    /// `.p0` à `.p3` : durée et retard des battements et des clins d'œil.
    static let clocks: [(Double, Double)] = [(9, 0), (11, -3), (13, -8), (14, -5)]

    /// La Voie lactée, cellule par cellule. Chaque cellule a deux lettres ; des
    /// groupes de cellules passent de l'une à l'autre à tour de rôle.
    func milkyWayCells(_ spine: [Sample]) -> [Node] {
        var steady = Layer()
        var groups = Array(repeating: (Layer(), Layer()), count: Self.shimmerGroups)
        var pulses = Array(repeating: Layer(), count: 4)
        var row = Int((layout.skyTop / Self.cellHeight).rounded(.down))
        while Double(row) * Self.cellHeight < layout.skyBottom {
            var column = Int((layout.bandFrom / Self.cellWidth).rounded(.down))
            while Double(column) * Self.cellWidth < layout.skyRight {
                defer { column += 1 }
                let cx = Double(column) * Self.cellWidth + Self.cellWidth / 2, cy = Double(row) * Self.cellHeight + Self.cellHeight / 2
                let here = milkyWay(cx, cy, spine)
                let brightness = here.brightness * pow(layout.calm(cx, cy), 1.6)
                let firstCount = min(6, Int((brightness * 7 + Self.hash(column, row, 1) * 1.3 - 0.25).rounded(.down)))
                if firstCount <= 0 { continue }
                let secondCount = min(7, max(1, firstCount + (Self.hash(column, row, 2) < 0.5 ? -1 : 1)))
                let apart = ((column + row) % 2 + 2) % 2 == 0
                let warm = apart && brightness > 0.5 && Self.hash(column, row, 4) < 0.5
                let orchid = !warm && apart && brightness > 0.22 && brightness < 0.6 && Self.hash(column, row, 21) < 0.2
                let tone = brightness < 0.25 || here.underCards < 0.5 ? 0 : brightness < 0.45 ? 1 : brightness < 0.72 ? 2 : 3
                if brightness > 0.22 && Self.hash(column, row, 19) < 0.11 {
                    let index = min(3, Int((Self.smoothStep(0.12, 0.88, here.along) * 4).rounded(.down)))
                    for (rank, dot) in Self.raised(column, row, min(6, firstCount + 1), 0).enumerated() {
                        pulses[index].add(rank < 2 ? (warm ? .warm : .star) : .cloud, dot.x, dot.y)
                    }
                    continue
                }
                let group = Int((here.along * 0.999 * Double(Self.shimmerGroups)).rounded(.down))
                let first = Self.raised(column, row, firstCount, 0), second = Self.raised(column, row, secondCount, 1)
                let firstSet = Set(first), secondSet = Set(second)
                for (rank, dot) in first.enumerated() {
                    let paint = Self.bandPaint(tone, warm, orchid, rank, firstCount)
                    if secondSet.contains(dot) { steady.add(paint, dot.x, dot.y) } else { groups[group].0.add(paint, dot.x, dot.y) }
                }
                for (rank, dot) in second.enumerated() where !firstSet.contains(dot) {
                    groups[group].1.add(Self.bandPaint(tone, warm, orchid, rank, secondCount), dot.x, dot.y)
                }
            }
            row += 1
        }
        var out = Self.write(steady)
        for (index, group) in groups.enumerated() {
            let delay = -((Double(index) * Self.shimmerSeconds / Double(Self.shimmerGroups)) * 10).rounded() / 10
            out.append(Node.group(Self.write(group.0)).animate(Self.stepped(Self.first, seconds: Self.shimmerSeconds, delay: delay)))
            out.append(Node.group(Self.write(group.1)).strokeOpacity(0).animate(Self.stepped(Self.second, seconds: Self.shimmerSeconds, delay: delay)))
        }
        for (index, layer) in pulses.enumerated() {
            out.append(Node.group(Self.write(layer)).animate(Self.stepped(Self.pulse, seconds: Self.clocks[index].0, delay: Self.clocks[index].1)))
        }
        return out
    }

    /// Les étoiles éparses, une cellule chacune. Certaines passent par trois
    /// motifs de points : c'est le scintillement.
    func fieldStars(_ spine: [Sample]) -> [Node] {
        var steady = Layer()
        var twinkle = Array(repeating: (Layer(), Layer(), Layer()), count: 6)
        var row = Int((layout.skyTop / Self.cellHeight).rounded(.down))
        while Double(row) * Self.cellHeight < layout.skyBottom {
            var column = Int((layout.skyLeft / Self.cellWidth).rounded(.down))
            while Double(column) * Self.cellWidth < layout.skyRight {
                defer { column += 1 }
                let cx = Double(column) * Self.cellWidth + Self.cellWidth / 2, cy = Double(row) * Self.cellHeight + Self.cellHeight / 2
                let chance = 0.085 * layout.calm(cx, cy) * (0.5 + Self.noise(cx, cy, 240, 21))
                if Self.hash(column, row, 5) >= chance { continue }
                if milkyWay(cx, cy, spine).brightness > 0.2 { continue }
                let dc = Self.hash(column, row, 6) < 0.5 ? 0 : 1
                let dr = 1 + Int((Self.hash(column, row, 7) * 2).rounded(.down))
                let x = Self.dotX(column, dc), y = Self.dotY(row, dr), otherX = Self.dotX(column, 1 - dc)
                let rank = Self.hash(column, row, 8)
                let calm = layout.calm(cx, cy) < 0.6
                let bright: PaintName = rank < 0.86 ? .star : rank < 0.96 ? .warm : .amber
                if calm || Self.hash(column, row, 9) >= 0.36 {
                    steady.add(calm ? .dust : rank < 0.5 ? .haze : rank < 0.85 ? .cloud : bright, x, y)
                    if !calm && rank > 0.8 { steady.add(.haze, otherX, y) }
                    continue
                }
                let g = layout.region(cx, cy)
                twinkle[g].0.add(.cloud, x, y)
                twinkle[g].1.add(bright, x, y)
                twinkle[g].1.add(.haze, otherX, y)
                twinkle[g].2.add(bright, x, y)
                twinkle[g].2.add(.cloud, otherX, y)
                twinkle[g].2.add(.cloud, x, y - Self.pitch)
                twinkle[g].2.add(.haze, x, y + Self.pitch)
            }
            row += 1
        }
        // `.tw.tN g` : chaque région a sa durée et son retard.
        let clocks: [(Double, Double)] = [(11, 0), (13, -4), (17, -11), (9, -6), (19, -2), (14, -8.5)]
        var out = Self.write(steady)
        for (index, group) in twinkle.enumerated() {
            let (seconds, delay) = clocks[index]
            out.append(.group([
                Node.group(Self.write(group.0)).animate(Self.stepped(Self.small, seconds: seconds, delay: delay)),
                Node.group(Self.write(group.1)).strokeOpacity(0).animate(Self.stepped(Self.medium, seconds: seconds, delay: delay)),
                Node.group(Self.write(group.2)).strokeOpacity(0).animate(Self.stepped(Self.large, seconds: seconds, delay: delay)),
            ]))
        }
        return out
    }

    static let figure: [(Double, Double, Int)] = [(1192, 276, 2), (1213, 305, 3), (1198, 335, 2), (1246, 324, 2), (1278, 348, 4), (1304, 382, 2), (1312, 417, 3), (1336, 439, 2)]
    static let joins = [(0, 1), (1, 2), (1, 3), (3, 4), (4, 5), (5, 6), (6, 7)]

    /// Le Scorpion : chaque étoile est une cellule, les traits sont pointillés au
    /// pas de la grille.
    func figures() -> [Node] {
        var winks = Array(repeating: Layer(), count: 4)
        var lines: [PathData.Command] = []
        var centres: [(Double, Double, Double)] = []
        for (index, star) in Self.figure.enumerated() {
            let column = Int(((star.0 + layout.figureShift.0) / Self.cellWidth).rounded(.down))
            let row = Int(((star.1 + layout.figureShift.1) / Self.cellHeight).rounded(.down))
            let rows = star.2 >= 4 ? 3 : star.2 >= 3 ? 2 : 1
            let columns = star.2 >= 2 ? 2 : 1
            for dr in 0..<rows {
                for dc in 0..<columns { winks[index % 4].add(.figure, Self.dotX(column, dc), Self.dotY(row, 1 + dr)) }
            }
            centres.append((Self.dotX(column, 0) + Double(columns - 1) * Self.pitch / 2, Self.dotY(row, 1) + Double(rows - 1) * Self.pitch / 2, 8 + Double(rows) * 4))
        }
        func tenth(_ v: Double) -> Double { (v * 10).rounded() / 10 }
        for (a, b) in Self.joins {
            let from = centres[a], to = centres[b]
            let length = hypot(to.0 - from.0, to.1 - from.1)
            let ux = (to.0 - from.0) / length, uy = (to.1 - from.1) / length
            lines += [.move(tenth(from.0 + ux * from.2), tenth(from.1 + uy * from.2)), .line(tenth(to.0 - ux * to.2), tenth(to.1 - uy * to.2))]
        }
        var out = [Node.path(PathData(lines)).stroke(.color(Self.blend("#8ea6ff", 0.24, Self.skyBase)), width: 2.2).dash([0, 8])]
        for (index, layer) in winks.enumerated() {
            out.append(Node.group(Self.write(layer)).animate(Self.stepped(Self.wink, seconds: Self.clocks[index].0, delay: Self.clocks[index].1)))
        }
        return out
    }

    func ridgeOutline(_ ridge: (Double) -> Double) -> PathData {
        var commands: [PathData.Command] = [.move(-30, height + 10)]
        var x = -30.0
        while x <= width + 30 {
            commands.append(.line(x, (ridge(x) * 10).rounded() / 10))
            x += 10
        }
        commands += [.line(width + 30, height + 10), .close]
        return PathData(commands)
    }

    func ridgeDots() -> [Node] {
        var layer = Layer()
        var column = -1
        while Double(column) * Self.cellWidth < width + 10 {
            var row = Int((layout.ridgeTop / Self.cellHeight).rounded(.down))
            while Double(row) * Self.cellHeight < height + 10 {
                for dot in 0..<8 {
                    let x = Self.dotX(column, dot % 2), y = Self.dotY(row, dot >> 1)
                    let depth = y - layout.front(x) - 4
                    if depth >= 0 && depth < 8 && Self.hash(x, y, 13) < 0.94 { layer.add(.ridgeCrest, x, y) }
                }
                row += 1
            }
            column += 1
        }
        return Self.write(layer)
    }

    func bandGlow(_ spine: [Sample]) -> [Node] {
        let spots: [(Int, Double, Double, String)] = [(14, 300, 110, "glowBlue"), (32, 330, 150, "glowCore"), (47, 280, 130, "glowBlue")]
        let breath = Animation.between([.fillOpacity: .n(0.7)], [.fillOpacity: .n(1)], duration: 74, direction: .alternate, timing: .steps(12))
        return spots.enumerated().map { index, spot in
            let sample = spine[spot.0]
            let angle = (atan2(sample.tangentY, sample.tangentX) * 180 / .pi * 10).rounded() / 10
            let cx = JS.round(sample.x), cy = JS.round(sample.y)
            return Node.ellipse(cx, cy, spot.1, spot.2).fill(Paint("url(#\(spot.3))")).transform(.rotateAbout(angle, cx, cy))
                .animate(breath.delayed(-Double(index) * 25))
        }
    }

    func shootingStar() -> Node {
        let (sx, sy) = layout.shoot
        let dots = (0..<20).map { index -> Node in
            let opacity = (pow(0.84, Double(index)) * 100).rounded() / 100
            let x = ((sx - Double(index) * 9.6) * 10).rounded() / 10, y = ((sy - Double(index) * 6) * 10).rounded() / 10
            return Node.path(PathData([.move(x, y), .line(x, y)]))
                .stroke(.color(Self.blend(index < 3 ? "#fff6d0" : "#e6ebff", opacity, Self.skyBase)), width: index == 0 ? 5.4 : index < 4 ? 4.2 : 3.4)
        }
        let shoot = Animation([
            .init(0, [.strokeOpacity: .n(0), .transform: .t(.translate(0, 0))]), .init(0.95, [.strokeOpacity: .n(0), .transform: .t(.translate(0, 0))]),
            .init(0.955, [.strokeOpacity: .n(1)]), .init(0.992, [.strokeOpacity: .n(0.9)]),
            .init(1, [.strokeOpacity: .n(0), .transform: .t(.translate(260, 162))]),
        ], duration: 46, delay: -37.9, timing: .linear)
        return Node.group(dots).strokeOpacity(0).animate(shoot)
    }

    static func build(width: Double, height: Double) -> Scene {
        BrailleStars(width: width, height: height, layout: .portrait(width, height)).scene()
    }

    static func original() -> Scene {
        BrailleStars(width: 1600, height: 1000, layout: .original).scene()
    }

    func scene() -> Scene {
        var scene = Scene(width: width, height: height)
        scene.linear("night", [(0, "#080d26", 1), (0.4, "#0b1230", 1), (0.75, "#0f183e", 1), (1, "#121c48", 1)])
        scene.radial("glowBlue", [(0, "#2b3676", 0.32), (0.35, "#2b3676", 0.2), (0.7, "#2b3676", 0.07), (1, "#2b3676", 0)])
        scene.radial("glowCore", [(0, "#3d3a7c", 0.42), (0.4, "#30367a", 0.22), (0.72, "#2b3676", 0.07), (1, "#2b3676", 0)])
        let spine = spine()
        let turn = Animation.between([.transform: .t(.rotate(-3))], [.transform: .t(.rotate(3))], duration: 280, delay: -140, direction: .alternate, timing: .steps(560))
        scene.add(.rect(0, 0, width, height).fill("url(#night)"))
        scene.add(Node.group(bandGlow(spine) + milkyWayCells(spine) + fieldStars(spine) + figures()).origin(layout.pole.0, layout.pole.1).animate(turn))
        scene.add(shootingStar())
        scene.add(Node.path(ridgeOutline(layout.back)).fill("#0a1030"))
        scene.add(Node.path(ridgeOutline(layout.front)).fill("#070b1f"))
        scene.add(ridgeDots())
        // `path{fill:none;stroke-linecap:round}` : les chemins sans remplissage
        // à eux ne remplissent rien.
        scene.nodes = [Node.group(scene.nodes).fill(.none).lineCap(.round)]
        return scene
    }
}
