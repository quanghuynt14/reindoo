import Foundation

// Departure Board : un grand panneau à LED. Un treillis de points éteints, une
// houle lente de lumière en diagonale, et un tableau d'une écriture inventée,
// allumé en ambre. Toutes les seize secondes, une rangée change de lettres.
// D'après theme-examples (Anthropic, Apache 2.0), scenes/departure-board.ts.

struct DepartureBoard {
    static let pitch = 10.0
    static let rowPitch = 10
    static let rows = 10
    static let ground = "#1f1710"
    static let lettersPerRow = 7
    static let letterAdvance = 7
    static let flipSeconds = 320.0
    static let swellSeconds = 120.0
    static let alphabetSize = 28

    struct Cell: Hashable {
        var column: Int
        var row: Int
    }

    /// Une rangée du tableau : son numéro (qui fixe ses lettres et son tour) et
    /// la rangée de points où elle s'écrit.
    struct Placement {
        var index: Int
        var row: Int
        /// La première rangée de son bloc : pas de filet au-dessus.
        var leads: Bool
        /// Plus pâle au bord d'un bloc.
        var edge: Double
    }

    struct Layout {
        var boardColumn: Int
        var placements: [Placement]
        var swellStripes: Int
        var swellParts: [(Double, Double, Double)]
        /// La part du treillis gardée, selon la position le long du voile.
        var level: @Sendable (Double) -> Double
        var veil: (x2: Double, y2: Double)

        static var original: Layout {
            Layout(
                boardColumn: 118,
                placements: (2...8).map { index in
                    Placement(index: index, row: 12 + index * 10, leads: index == 2, edge: index == 2 ? 0.6 : index == 8 ? 0.55 : 1)
                },
                swellStripes: 16, swellParts: [(0, 290, 1), (290, 360, 0.6), (360, 420, 0.25)],
                level: { x in 0.55 + 0.45 * smooth((0.34 - min(x, 1 - x)) / 0.2) },
                veil: (1, 0)
            )
        }

        /// Deux rangées en haut, comme un panneau au-dessus d'un quai, trois en
        /// bas ; le milieu ne garde que le treillis, voilé.
        static func portrait(_ w: Double, _ h: Double) -> Layout {
            let top = Int((h * 0.035 / pitch).rounded()), bottom = Int((h * 0.68 / pitch).rounded())
            return Layout(
                boardColumn: Int((w * 0.08 / pitch).rounded()),
                placements: [
                    Placement(index: 0, row: top, leads: true, edge: 1), Placement(index: 1, row: top + 10, leads: false, edge: 0.6),
                    Placement(index: 6, row: bottom, leads: true, edge: 0.6), Placement(index: 7, row: bottom + 10, leads: false, edge: 1),
                    Placement(index: 8, row: bottom + 20, leads: false, edge: 1),
                ],
                swellStripes: Int(((w + h / 2) / 150).rounded(.up)) + 1,
                swellParts: [(0, w * 0.5, 1), (w * 0.5, w * 0.68, 0.6), (w * 0.68, w * 0.8, 0.25)],
                level: { y in
                    let middle = min(smooth((y - 0.2) / 0.08), smooth((0.66 - y) / 0.08))
                    return 1 - 0.45 * middle
                },
                veil: (0, 1)
            )
        }
    }

    let width: Double
    let height: Double
    let layout: Layout

    static func smooth(_ value: Double) -> Double {
        let t = max(0, min(1, value))
        return t * t * (3 - 2 * t)
    }

    /// Un retard négatif fait partir l'animation à ce point de son cycle.
    static func delay(_ base: Double, _ period: Double) -> Double {
        let phase = (base.truncatingRemainder(dividingBy: period) + period).truncatingRemainder(dividingBy: period)
        return -(phase * 100).rounded() / 100
    }

    static func hash(_ seed: Int) -> Double {
        var value = (Double(seed) * 2_654_435_761).truncatingRemainder(dividingBy: 4_294_967_296)
        value = Double(JS.uint32(JS.xor(value, JS.ushr(value, 13))))
        value = (value * 1_274_126_177).truncatingRemainder(dividingBy: 4_294_967_296)
        return Double(JS.uint32(JS.xor(value, JS.ushr(value, 16)))) / 4_294_967_296
    }

    static func cellPath(_ cells: [Cell]) -> PathData {
        var order: [Int] = []
        var rows: [Int: [Int]] = [:]
        for cell in cells {
            if rows[cell.row] == nil { order.append(cell.row) }
            rows[cell.row, default: []].append(cell.column)
        }
        var path = PathData()
        for row in order {
            let sorted = rows[row]!.sorted()
            var start = sorted[0], previous = sorted[0]
            for column in sorted.dropFirst() {
                if column == previous + 1 {
                    previous = column
                    continue
                }
                path = path + run(start, previous, row)
                start = column
                previous = column
            }
            path = path + run(start, previous, row)
        }
        return path
    }

    static func run(_ start: Int, _ end: Int, _ row: Int) -> PathData {
        .rect(Double(start) * pitch, Double(row) * pitch, Double(end - start + 1) * pitch, pitch)
    }

    /// L'alphabet inventé, d'un seul jeu de traits brisés : un fût coupé, une
    /// diagonale de trois points, une coche de deux, un point seul.
    static func alphabet() -> [[Cell]] {
        var letters: [[Cell]] = []
        var seen = Set<String>()
        var seed = 1
        while letters.count < alphabetSize {
            seed += 1
            let stem = 1 + Int((hash(seed * 3) * 3).rounded(.down))
            let gapAt = 1 + Int((hash(seed * 5) * 4).rounded(.down))
            let side = hash(seed * 7) > 0.5 ? 1 : -1
            if (stem == 1 && side < 0) || (stem == 3 && side > 0) { continue }
            let diagonalRow = hash(seed * 11) > 0.5 ? 0 : 6
            let tickRow = 2 + Int((hash(seed * 13) * 3).rounded(.down))
            var cells: [Cell] = []
            for row in 0..<7 where row != gapAt + 1 { cells.append(Cell(column: stem, row: row)) }
            for step in 1...3 {
                let column = stem + side * step
                let row = diagonalRow == 0 ? step - 1 : 7 - step
                if column >= 0 && column <= 4 { cells.append(Cell(column: column, row: row)) }
            }
            let tick = side > 0 ? stem - 2 : stem + 2
            if tick >= 0 && tick + 1 <= 4 && tick - 1 != stem && tick + 2 != stem {
                cells += [Cell(column: tick, row: tickRow), Cell(column: tick + 1, row: tickRow)]
            } else {
                cells.append(Cell(column: side > 0 ? 0 : 4, row: tickRow))
            }
            cells.append(Cell(column: side > 0 ? 4 : 0, row: diagonalRow == 0 ? 6 : 0))
            let key = cells.map { "\($0.column),\($0.row)" }.sorted().joined(separator: " ")
            if !seen.insert(key).inserted { continue }
            letters.append(cells)
        }
        return letters
    }

    static func fixed(_ value: Double, _ digits: Double) -> Double { (value * digits).rounded() / digits }

    static func flips() -> (was: SceneAnimation, next: SceneAnimation) {
        let fade = 1.2 / flipSeconds * 100
        let a = fixed(50 - fade, 100) / 100, b = fixed(100 - fade, 100) / 100
        let was = SceneAnimation([.init(0, [.opacity: .n(1)]), .init(a, [.opacity: .n(1)]), .init(0.5, [.opacity: .n(0)]), .init(b, [.opacity: .n(0)]), .init(1, [.opacity: .n(1)])], duration: flipSeconds, timing: .linear)
        let next = SceneAnimation([.init(0, [.opacity: .n(0)]), .init(a, [.opacity: .n(0)]), .init(0.5, [.opacity: .n(1)]), .init(b, [.opacity: .n(1)]), .init(1, [.opacity: .n(0)])], duration: flipSeconds, timing: .linear)
        return (was, next)
    }

    /// Une lueur qui monte au changement et retombe en vingt secondes, en
    /// marches : deux fois par tour, comme les images clés d'origine.
    static func settle(peak: Double, rest: Double) -> SceneAnimation {
        let fade = 1.2 / flipSeconds * 100, settle = 20 / flipSeconds * 100
        let gentle = Timing.steps(24)
        return SceneAnimation([
            .init(0, [.fillOpacity: .n(peak)], timing: gentle), .init(fixed(settle, 100) / 100, [.fillOpacity: .n(rest)]),
            .init(fixed(50 - 2 * fade, 100) / 100, [.fillOpacity: .n(rest)]), .init(0.5, [.fillOpacity: .n(peak)], timing: gentle),
            .init(fixed(50 + settle, 100) / 100, [.fillOpacity: .n(rest)]), .init(fixed(100 - 2 * fade, 100) / 100, [.fillOpacity: .n(rest)]),
            .init(1, [.fillOpacity: .n(peak)]),
        ], duration: flipSeconds, timing: .linear)
    }

    func board() -> [Node] {
        let x = Double(layout.boardColumn) * Self.pitch
        let (was, next) = Self.flips()
        var rows: [Node] = []
        var rules = PathData()
        for placement in layout.placements {
            let index = placement.index, row = placement.row
            let order = (index * 3 + 1) % Self.rows
            let flipAt = 13 + Double(order) * (Self.flipSeconds / 2 / Double(Self.rows))
            let freshDelay = Self.delay(Self.flipSeconds / 2 - flipAt - 1, Self.flipSeconds)
            var letters: [Node] = []
            for position in 0..<Self.lettersPerRow {
                let gap = position >= 2 ? 1 : 0
                if Self.hash(900 + index * 17 + position) < 0.24 { continue }
                let seed = 500 + index * 13 + position
                let first = Int((Self.hash(seed) * Double(Self.alphabetSize)).rounded(.down))
                let second = (first + 1 + Int((Self.hash(seed + 101) * Double(Self.alphabetSize - 1)).rounded(.down))) % Self.alphabetSize
                let lx = x + Double(position * Self.letterAdvance + gap) * Self.pitch, ly = Double(row) * Self.pitch
                let delay = Self.delay(Self.flipSeconds / 2 - (flipAt + Double(position) * 0.4), Self.flipSeconds)
                letters.append(Node.use("letter\(first)").translate(lx, ly).animate(was.delayed(delay)))
                letters.append(Node.use("letter\(second)").translate(lx, ly).opacity(0).animate(next.delayed(delay)))
            }
            let level = (0.55 + 0.45 * Self.hash(700 + index)) * placement.edge
            let rest = Self.fixed(level * 0.74, 1000), peak = Self.fixed(level * 0.98, 1000)
            rows.append(Node.group(letters).fillOpacity(rest).animate(Self.settle(peak: peak, rest: rest).delayed(freshDelay)))
            let lamp = [2, 3, 4].map { Cell(column: layout.boardColumn - 2, row: row + $0) }
            rows.append(Node.path(Self.cellPath(lamp)).fill("url(#dotTeal)").fillOpacity(0).animate(Self.settle(peak: 0.9, rest: 0).delayed(freshDelay)))
            if !placement.leads { rules = rules + .rect(x - 30, Double(row - 1) * Self.pitch, max(520, width - x + 30), Self.pitch) }
        }
        return [Node.path(rules).fill("url(#rule)"), Node.group(rows).fill("url(#dotAmber)")]
    }

    /// Une tranche horizontale d'une bande penchée, gardée dans sa part.
    func stripeSlice(_ left: Double, _ width: Double, _ from: Double, _ to: Double) -> PathData {
        var path = PathData()
        var y = 0.0
        while y < height {
            let start = JS.round(max(from, left - y / 2)), end = JS.round(min(to, left + width - y / 2))
            if end > start { path = path + .rect(start, y, end - start, 50) }
            y += 50
        }
        return path
    }

    /// La houle : des bandes de points plus clairs qui montent et descendent tour à tour.
    func swell() -> Node {
        var out: [Node] = []
        for stripe in 0..<layout.swellStripes {
            let left = Double(stripe) * 150
            let delay = Self.delay(30 - Double(stripe) * Self.swellSeconds / 16, Self.swellSeconds)
            for (from, to, level) in layout.swellParts {
                let path = stripeSlice(left, 150, from, to)
                if path.isEmpty { continue }
                let rise = SceneAnimation([
                    .init(0, [.fillOpacity: .n(0)]), .init(0.16, [.fillOpacity: .n(level)]), .init(0.32, [.fillOpacity: .n(0)]), .init(1, [.fillOpacity: .n(0)]),
                ], duration: Self.swellSeconds, delay: delay, timing: .steps(20))
                out.append(Node.path(path).fillOpacity(0).animate(rise))
            }
        }
        return Node.group(out).fill("url(#swellDot)")
    }

    static func dotPattern(_ scene: inout SceneGraph, _ id: String, halo: String, core: String, glint: String) {
        scene.radial("\(id)Halo", [(0, halo, 0.5), (0.5, halo, 0.18), (1, halo, 0)])
        scene.define(id, .pattern(Pattern(width: pitch, height: pitch, nodes: [
            Node.rect(0, 0, pitch, pitch).fill(Paint("url(#\(id)Halo)")), Node.circle(5, 5, 2.5).fill(Paint(core)), Node.circle(5, 5, 1.05).fill(Paint(glint)),
        ])))
    }

    static func unlit(_ scene: inout SceneGraph, _ id: String, _ radius: Double, _ colour: String) {
        scene.define(id, .pattern(Pattern(width: pitch, height: pitch, nodes: [Node.circle(5, 5, radius).fill(Paint(colour))])))
    }

    static func build(width: Double, height: Double) -> SceneGraph {
        DepartureBoard(width: width, height: height, layout: .portrait(width, height)).scene()
    }

    static func original() -> SceneGraph {
        DepartureBoard(width: 1600, height: 1000, layout: .original).scene()
    }

    func scene() -> SceneGraph {
        var scene = SceneGraph(width: width, height: height)
        Self.unlit(&scene, "unlit", 1.5, "#3a2b1d")
        Self.unlit(&scene, "rule", 1.6, "#523c1e")
        Self.unlit(&scene, "swellDot", 1.9, "#7a5526")
        Self.dotPattern(&scene, "dotAmber", halo: "#ee8f1c", core: "#f2a53a", glint: "#ffe0aa")
        Self.dotPattern(&scene, "dotTeal", halo: "#2fb89c", core: "#5fd0b8", glint: "#d8fff5")
        // Le voile peint par-dessus dans la couleur du fond : ce que faisait un masque.
        let stops = (0...24).map { step -> (Double, String, Double) in
            let t = Double(step) / 24
            return (Self.fixed(t, 1000), Self.ground, Self.fixed(1 - layout.level(t), 1000))
        }
        scene.linear("middleVeil", x1: 0, y1: 0, x2: layout.veil.x2, y2: layout.veil.y2, stops)
        for (index, cells) in Self.alphabet().enumerated() { scene.define("letter\(index)", .symbol(Node.path(Self.cellPath(cells)))) }

        scene.add(.rect(0, 0, width, height).fill(Paint(Self.ground)))
        scene.add(.rect(0, 0, width, height).fill("url(#unlit)"))
        scene.add(swell())
        scene.add(.rect(0, 0, width, height).fill("url(#middleVeil)"))
        scene.add(board())
        return scene
    }
}
