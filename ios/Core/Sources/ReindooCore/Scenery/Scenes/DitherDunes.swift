import Foundation

// Dither Dunes : un désert en tramage ordonné, un soleil terre cuite. Deux
// papiers : sable le jour, terre d'ombre la nuit. La forme des dunes glisse sur
// une trame immobile, comme dans un jeu à un bit : seuls les points de la crête
// changent.
// D'après theme-examples (Anthropic, Apache 2.0), scenes/dither-dunes.ts.

struct DitherDunes {
    static let cell = 5.0
    static let matrix = 8
    static let tile = cell * Double(matrix)
    static let tones = matrix * matrix
    static let margin = 3 * tile
    static let softCeiling = 0.34
    static let darkCeiling = 0.28
    static let darkFloor = 0.1
    static let sunRadius = 34.0
    static let bayer = bayerMatrix(matrix)

    struct Stock {
        var paper, haze, lee, soft, strong, sun: String
        var sands: [String]
    }

    static let day = Stock(paper: "#ece2cd", haze: "#e3d8c2", lee: "#d3c5a8", soft: "#bfad8b", strong: "#6f5d49", sun: "#c8573a", sands: ["#e8ddc7", "#e4d8c0", "#e0d3ba", "#dccfb4"])
    static let night = Stock(paper: "#231d17", haze: "#2a231c", lee: "#40362a", soft: "#6b5c47", strong: "#988462", sun: "#c8573a", sands: ["#27211a", "#2b241c", "#2f271f", "#332b21"])

    struct Dune {
        var crest: [(Double, Double, Bool)]
        var tone: Double
        var reach: Double
        var seconds: Double
        var driftUnits: Double
        var driftSeconds: Double
        var glint: (Double, Double)?
    }

    enum Kind { case haze, sun, soft, strong }

    static let originalDunes = [
        Dune(crest: [(0, 566, false), (250, 532, true), (560, 592, false), (900, 604, false), (1200, 574, false), (1430, 524, true), (1600, 552, false)], tone: 0.34, reach: 150, seconds: 104, driftUnits: 40, driftSeconds: 200, glint: nil),
        Dune(crest: [(0, 676, false), (330, 640, true), (700, 724, false), (1000, 734, false), (1290, 644, true), (1600, 706, false)], tone: 0.42, reach: 190, seconds: 88, driftUnits: -60, driftSeconds: 150, glint: nil),
        Dune(crest: [(0, 806, false), (200, 764, true), (520, 864, false), (820, 904, false), (1100, 844, false), (1390, 724, true), (1600, 794, false)], tone: 0.48, reach: 220, seconds: 96, driftUnits: 80, driftSeconds: 120, glint: (1230, 1600)),
        Dune(crest: [(0, 934, false), (300, 904, false), (640, 962, false), (900, 972, false), (1250, 930, true), (1600, 902, false)], tone: 0.5, reach: 160, seconds: 80, driftUnits: -100, driftSeconds: 100, glint: nil),
    ]

    struct Layout {
        var dunes: [Dune]
        var sun: (Double, Double)
        var riseSteps: Int
        var edge: @Sendable (Double) -> Double
        var haze: @Sendable (Double, Double) -> Double
        var lee: (Double, Double)
        var grainsRight: Double
        var grainsLeft: Double

        static var original: Layout {
            Layout(
                dunes: originalDunes, sun: (1376, 446), riseSteps: 38,
                edge: { x in
                    let u = x / 1600
                    return max(1 - smoothstep(0.06, 0.24, u), smoothstep(0.76, 0.93, u))
                },
                haze: { x, y in
                    let sides = max(1 - smoothstep(0.08, 0.27, x / 1600), smoothstep(0.73, 0.92, x / 1600))
                    return 0.2 * smoothstep(0, 620, y + 50 * sin(x / 210)) * sides
                },
                lee: (240, 1360), grainsRight: 1260, grainsLeft: 40
            )
        }

        /// Les dunes remplissent le tiers du bas, sous le texte ; le soleil se
        /// lève bas, au bord droit.
        static func portrait(_ w: Double, _ h: Double) -> Layout {
            let dunes = originalDunes.map { dune -> Dune in
                var copy = dune
                copy.crest = dune.crest.map { ($0.0 / 1600 * w, h * 0.64 + ($0.1 - 524) / 448 * h * 0.31, $0.2) }
                copy.glint = dune.glint.map { _ in (w * 0.6, w) }
                return copy
            }
            return Layout(
                dunes: dunes, sun: (w * 0.84, h * 0.6), riseSteps: 18,
                // Comme sur l'ordinateur, les points restent sur les côtés : au
                // milieu, la trame dessinerait des croix, et la couture des deux
                // piles se verrait.
                edge: { x in
                    let u = x / w
                    return max(1 - smoothstep(0.08, 0.4, u), smoothstep(0.6, 0.92, u))
                },
                haze: { x, y in
                    let sides = max(1 - smoothstep(0.04, 0.2, x / w), smoothstep(0.8, 0.96, x / w))
                    return 0.2 * smoothstep(h * 0.3, h * 0.64, y + 30 * sin(x / 210)) * sides
                },
                lee: (w * 0.15, w * 0.85), grainsRight: w * 0.66, grainsLeft: 10
            )
        }
    }

    let width: Double
    let height: Double
    let layout: Layout
    let stock: Stock
    var tileColumns: Int { Int((width / Self.tile).rounded(.up)) }
    var tileRows: Int { Int((height / Self.tile).rounded(.up)) }

    static func bayerMatrix(_ size: Int) -> [[Int]] {
        if size == 1 { return [[0]] }
        let half = bayerMatrix(size / 2)
        return (0..<size).map { y in
            (0..<size).map { x in
                let top = y < size / 2, left = x < size / 2
                let quarter = top ? (left ? 0 : 2) : left ? 3 : 1
                return 4 * half[y % (size / 2)][x % (size / 2)] + quarter
            }
        }
    }

    static func threshold(_ x: Double, _ y: Double) -> Double {
        let row = ((Int(y / cell) % matrix) + matrix) % matrix, column = ((Int(x / cell) % matrix) + matrix) % matrix
        return (Double(bayer[row][column]) + 0.5) / Double(tones)
    }

    static func smoothstep(_ low: Double, _ high: Double, _ value: Double) -> Double {
        let t = min(1, max(0, (value - low) / (high - low)))
        return t * t * (3 - 2 * t)
    }

    /// La hauteur d'une crête en x : en cosinus entre deux points simples, en
    /// pente raide et creuse vers un sommet, comme se couche le sable.
    static func crest(_ points: [(Double, Double, Bool)], _ x: Double) -> Double {
        var last = 0.0
        for index in points.indices {
            let to = points[index]
            last = to.1
            if x > to.0 { continue }
            if index == 0 { return to.1 }
            let from = points[index - 1]
            let t = (x - from.0) / (to.0 - from.0)
            var eased = (1 - cos(.pi * t)) / 2
            if to.2 && !from.2 { eased = pow(t, 1.7) }
            if from.2 && !to.2 { eased = 1 - pow(1 - t, 1.7) }
            return from.1 + (to.1 - from.1) * eased
        }
        return last
    }

    static func crestRow(_ dune: Dune, _ x: Double) -> Double {
        JS.round(crest(dune.crest, x + cell / 2) / cell) * cell
    }

    static func duneTone(_ dune: Dune, _ index: Int, _ x: Double, _ y: Double) -> Double {
        let depth = max(0, y - crest(dune.crest, x))
        let swell = 0.86 + 0.14 * sin(x / 120 + Double(index) * 2.3)
        return dune.tone * swell * pow(max(0, 1 - depth / dune.reach), 1.4)
    }

    func fieldTone(_ kind: Kind, _ dune: Dune?, _ index: Int, _ x: Double, _ y: Double) -> Double {
        switch kind {
        case .haze:
            return layout.haze(x, y)
        case .sun:
            let distance = hypot(x - layout.sun.0, y - layout.sun.1)
            if distance <= Self.sunRadius { return 1 }
            if distance <= Self.sunRadius * 1.45 { return 0.5 }
            return distance <= Self.sunRadius * 1.9 ? 0.25 : 0
        case .soft, .strong:
            guard let dune, y - Self.crest(dune.crest, x) > -Self.margin else { return 0 }
            let tone = Self.duneTone(dune, index, x, y)
            if kind == .soft { return min(Self.softCeiling, tone * layout.edge(x)) }
            return min(Self.darkCeiling, 1.4 * max(0, tone * Self.smoothstep(0.82, 0.97, x / width) - Self.darkFloor))
        }
    }

    /// Un seuil de la matrice, en unités de tuile : toutes les tuiles dont le
    /// pixel à ce seuil passe le ton du champ. Des suites de tuiles par rangée ;
    /// les suites identiques de rangées voisines deviennent des boîtes.
    func levelPath(_ level: Int, _ first: Int, _ last: Int, _ kind: Kind, _ dune: Dune?, _ index: Int) -> PathData {
        var pixelColumn = 0, pixelRow = 0
        for y in 0..<Self.matrix {
            for x in 0..<Self.matrix where Self.bayer[y][x] == level {
                pixelColumn = x
                pixelRow = y
            }
        }
        let threshold = (Double(level) + 0.5) / Double(Self.tones)
        var open: [(key: (Int, Int), row: Int)] = []
        var path = PathData()
        for row in 0...tileRows {
            var seen = Set<Int>()
            var runStart = -1
            var column = first
            while column <= last && row < tileRows {
                let inked = column < last && fieldTone(kind, dune, index, Double(column) * Self.tile + (Double(pixelColumn) + 0.5) * Self.cell,
                                                        Double(row) * Self.tile + (Double(pixelRow) + 0.5) * Self.cell) > threshold
                if inked && runStart < 0 { runStart = column }
                if !inked && runStart >= 0 {
                    let key = (runStart, column - runStart)
                    seen.insert(key.0 * 100_000 + key.1)
                    if !open.contains(where: { $0.key == key }) { open.append((key, row)) }
                    runStart = -1
                }
                column += 1
            }
            for entry in open where !seen.contains(entry.key.0 * 100_000 + entry.key.1) {
                path = path + .rect(Double(entry.key.0), Double(entry.row), Double(entry.key.1), Double(row - entry.row))
            }
            open.removeAll { !seen.contains($0.key.0 * 100_000 + $0.key.1) }
        }
        return path
    }

    /// Une pile de couches de seuil pour un champ, dans une encre. Chaque couche
    /// glisse d'une tuile à la fois, trois tuiles aller et retour.
    func layerStack(_ ink: String, _ first: Int, _ last: Int, _ kind: Kind, _ dune: Dune?, _ index: Int, creep: (x: Double, y: Double, seconds: Double, phase: Double)?) -> [Node] {
        var layers: [Node] = []
        for level in 0..<Self.tones {
            let path = levelPath(level, first, last, kind, dune, index)
            if path.isEmpty { continue }
            var node = Node.path(path).fill(Paint("url(#\(ink)\(level))"))
            if let creep {
                let delay = ((creep.phase + Double(level) * 2.9).truncatingRemainder(dividingBy: creep.seconds) * 10).rounded() / 10
                node = node.animate(SceneAnimation.between([.transform: .t(.translate(0, 0))], [.transform: .t(.translate(creep.x * 3, creep.y * 3))],
                                                      duration: creep.seconds, delay: -delay, direction: .alternate, timing: .steps(3)))
            }
            layers.append(node)
        }
        return layers
    }

    func outline(_ dune: Dune) -> PathData {
        let spare = 120.0
        var commands: [PathData.Command] = [.move(-spare, height)]
        var previous = -1.0, cursor = (-spare, height)
        var x = -spare
        while x < width + spare {
            let top = Self.crestRow(dune, x)
            if top != previous {
                if previous >= 0 { cursor = (x, cursor.1); commands.append(.line(x, cursor.1)) }
                cursor = (cursor.0, top)
                commands.append(.line(cursor.0, top))
                previous = top
            }
            x += Self.cell
        }
        commands += [.line(width + spare, cursor.1), .line(width + spare, height), .close]
        return PathData(commands)
    }

    func glint(_ dune: Dune) -> Node? {
        guard let (from, to) = dune.glint else { return nil }
        var path = PathData()
        var x = from
        while x < to {
            let ends = min(Self.smoothstep(from, from + 120, x), 1 - Self.smoothstep(to - 60, to + 60, x))
            for deep in 0..<6 {
                let y = Self.crestRow(dune, x) + Double(deep) * Self.cell
                let tone = deep < 2 ? 0.9 : 0.55 * pow(1 - Double(deep - 2) / 4, 1.5)
                if tone * ends > Self.threshold(x, y) { path = path + .rect(x, y, Self.cell, Self.cell) }
            }
            x += Self.cell
        }
        return Node.path(path).fill(Paint(stock.sun))
    }

    func lee(_ dune: Dune) -> Node {
        var path = PathData()
        var x = layout.lee.0
        while x < layout.lee.1 {
            let middle = 1 - layout.edge(x)
            for deep in 0..<2 {
                let y = Self.crestRow(dune, x) + Double(deep) * Self.cell
                if (deep == 0 ? 0.5 : 0.25) * middle > Self.threshold(x, y) { path = path + .rect(x, y, Self.cell, Self.cell) }
            }
            x += Self.cell
        }
        return Node.path(path).fill(Paint(stock.lee))
    }

    func dune(_ dune: Dune, _ index: Int, into scene: inout SceneGraph) -> Node {
        let shape = outline(dune)
        let half = tileColumns / 2
        let i = Double(index)
        let soft = layerStack("soft", 0, half, .soft, dune, index, creep: (-1, 1, dune.seconds * 1.3, i * 19))
            + layerStack("soft", half, tileColumns, .soft, dune, index, creep: (1, 1, dune.seconds * 1.3, i * 23))
            + layerStack("strong", half, tileColumns, .strong, dune, index, creep: (1, 1, dune.seconds, i * 29))
        let steps = Int(abs(dune.driftUnits) / Self.cell)
        let delay = -(Double(index) * 31).truncatingRemainder(dividingBy: dune.driftSeconds)
        let drift = SceneAnimation.between([.transform: .t(.translate(0, 0))], [.transform: .t(.translate(dune.driftUnits, 0))], duration: dune.driftSeconds, delay: delay, direction: .alternate, timing: .steps(steps))
        let undrift = SceneAnimation.between([.transform: .t(.translate(0, 0))], [.transform: .t(.translate(-dune.driftUnits, 0))], duration: dune.driftSeconds, delay: delay, direction: .alternate, timing: .steps(steps))
        scene.define("c\(index)", .clip(Clip([shape])))
        let sand = index < stock.sands.count ? stock.sands[index] : stock.paper
        return Node.group([
            Node.path(shape).fill(Paint(sand)),
            Node.group([Node.group([Node.group(soft).transform(.scale(Self.tile, Self.tile))]).animate(undrift)]).clip("c\(index)"),
            lee(dune),
        ] + [glint(dune)].compactMap { $0 }).animate(drift)
    }

    func grains() -> [Node] {
        let move = SceneAnimation([
            .init(0, [.transform: .t(.translate(0, 0)), .opacity: .n(0)]), .init(0.08, [.opacity: .n(1)]), .init(0.8, [.opacity: .n(1)]),
            .init(1, [.transform: .t(.translate(44 * Self.cell, 0)), .opacity: .n(0)]),
        ], duration: 50, timing: .steps(44))
        return (0..<22).map { grain in
            let right = grain % 3 != 0
            let startX = right ? layout.grainsRight + Double((grain * 29) % 120) : layout.grainsLeft + Double((grain * 31) % 120)
            let dune = right ? layout.dunes[2] : layout.dunes[1]
            let y = Self.crestRow(dune, startX + 110) - Self.cell * Double(2 + (grain * 37) % 5)
            let x = startX - startX.truncatingRemainder(dividingBy: Self.cell)
            return Node.rect(x, y, Self.cell, Self.cell).fill(Paint(stock.soft))
                .animate(move.lasting(34 + Double((grain * 13) % 25)).delayed(-(Double(grain) * 6.1 * 10).rounded() / 10))
        }
    }

    static func patterns(_ scene: inout SceneGraph, _ name: String, _ colour: String, _ levels: Int) {
        let m = Double(matrix)
        for y in 0..<matrix {
            for x in 0..<matrix where bayer[y][x] < levels {
                scene.define("\(name)\(bayer[y][x])", .pattern(Pattern(width: 1, height: 1, nodes: [Node.rect(Double(x) / m, Double(y) / m, 1 / m, 1 / m).fill(Paint(colour))])))
            }
        }
    }

    static func build(_ stock: Stock) -> @Sendable (Double, Double) -> SceneGraph {
        { width, height in DitherDunes(width: width, height: height, layout: .portrait(width, height), stock: stock).scene() }
    }

    static func original(_ stock: Stock) -> @Sendable () -> SceneGraph {
        { DitherDunes(width: 1600, height: 1000, layout: .original, stock: stock).scene() }
    }

    func scene() -> SceneGraph {
        var scene = SceneGraph(width: width, height: height)
        let inked = Int((Self.softCeiling * Double(Self.tones)).rounded(.up))
        Self.patterns(&scene, "haze", stock.haze, inked)
        Self.patterns(&scene, "soft", stock.soft, inked)
        Self.patterns(&scene, "strong", stock.strong, inked)
        Self.patterns(&scene, "sun", stock.sun, Self.tones)
        let rise = SceneAnimation.between([.transform: .t(.translate(0, 0))], [.transform: .t(.translate(0, -Double(layout.riseSteps) * Self.cell))], duration: 200, direction: .alternate, timing: .steps(layout.riseSteps))
        let veer = SceneAnimation.between([.transform: .t(.translate(0, 0))], [.transform: .t(.translate(-19 * Self.cell, 0))], duration: 200, direction: .alternate, timing: .steps(19))

        scene.add(.rect(0, 0, width, height).fill(Paint(stock.paper)))
        scene.add(Node.group(layerStack("haze", 0, tileColumns, .haze, nil, 0, creep: nil)).transform(.scale(Self.tile, Self.tile)))
        scene.add(Node.group([Node.group([Node.group(layerStack("sun", 0, tileColumns, .sun, nil, 0, creep: nil)).transform(.scale(Self.tile, Self.tile))]).animate(veer)]).animate(rise))
        for (index, dune) in layout.dunes.enumerated() { scene.add(self.dune(dune, index, into: &scene)) }
        scene.add(grains())
        return scene
    }
}
