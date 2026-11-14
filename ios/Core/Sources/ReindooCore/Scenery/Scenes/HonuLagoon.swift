import Foundation

// Honu Lagoon : un lagon vu d'en haut, sur une grille de cases. Chaque case est
// un carreau avec un glyphe. Une tortue (honu) nage dans son eau claire, un
// petit animal corail passe, une île de sable occupe un coin, un haut-fond
// longe le bas. Décor pour fond clair.
// D'après theme-examples (Anthropic, Apache 2.0), scenes/honu-lagoon.ts.

struct HonuLagoon {
    static let cell = 15.0
    static let glyphs = Array("$%tSX:;t$%S")

    let width: Double
    let height: Double
    let layout: Layout
    var columns: Int { Int((width / Self.cell).rounded(.up)) }
    var rows: Int { Int((height / Self.cell).rounded(.up)) }

    struct Cell {
        var x: Int
        var y: Int
        var kind: Character
        var body = false
    }

    struct Tile {
        var tile: String
        var glyph: String
        var opacity: Double
    }

    /// Où sont les choses. `original` refait le décor à l'identique ; `portrait`
    /// garde l'île en haut, et met la tortue et le haut-fond sous les boutons.
    struct Layout {
        /// L'eau : de clair à profond, dans le sens de ce vecteur de la boîte.
        var water: (Double, Double)
        var glow: (Double, Double, Double, Double)
        var sun: (Double, Double, Double, Double)
        /// Le quadrillage n'apparaît que vers ce côté.
        var gridFade: (x2: Double, y2: Double)
        var islandSpan: Int
        var trails: [(Int, Int, Int, Int)]
        var shoalFrom: Int
        var patches: [(Int, Int, Int, Int)]
        var honuX: (Double, Double)
        var honuY: (Double, Double)
        var coralFrom: (Double, Double)
        var coralTo: (Double, Double)
        var glints: [(Double, Double, Double, Double)]
        var sparkles: [(Double, Double, Double)]
        var drift: (Double, Double)

        static func original(columns c: Int) -> Layout {
            Layout(
                water: (1, 0.03), glow: (576, 400, 448, 420), sun: (1600, 0, 560, 460), gridFade: (1, 0),
                islandSpan: 36, trails: [(c - 30, 4, 7, 3), (c - 13, 5, 19, 9), (c - 4, 5, 11, 5)], shoalFrom: c - 45,
                patches: [(84, 8, 20, 9), (82, 22, 26, 12), (86, 44, 22, 14), (80, 56, 28, 9), (92, 32, 16, 9)],
                honuX: (91, 95), honuY: (32, 44), coralFrom: (10, 30), coralTo: (24, 30),
                glints: [(1400, 330, 170, 110), (180, 150, 170, 80), (1330, 800, 200, 130), (230, 800, 200, 90)],
                sparkles: [(1470, 840, 2.4), (240, 470, 2), (1560, 520, 2), (1290, 300, 1.8), (1140, 900, 2), (110, 150, 1.8), (330, 880, 2.2), (1330, 960, 1.8), (60, 640, 2)],
                drift: (40, 12)
            )
        }

        static func portrait(_ w: Double, _ h: Double, columns c: Int, rows r: Int) -> Layout {
            let rr = Double(r), cc = Double(c)
            return Layout(
                water: (0.03, 1), glow: (w * 0.45, h * 0.42, w * 0.65, h * 0.32), sun: (w, 0, w * 0.7, h * 0.26), gridFade: (0, 1),
                islandSpan: 22, trails: [(c - 18, 4, 5, 2), (c - 8, 5, 11, 6), (c - 2, 5, 8, 4)], shoalFrom: 0,
                patches: [(1, Int(rr * 0.68), 14, 9), (c - 17, Int(rr * 0.6), 15, 10), (5, Int(rr * 0.84), 20, 8), (c - 12, Int(rr * 0.8), 11, 7)],
                honuX: (cc * 0.6, cc * 0.72), honuY: (rr * 0.7, rr * 0.79), coralFrom: (3, rr * 0.13), coralTo: (cc * 0.3, rr * 0.13),
                glints: [(w * 0.8, h * 0.12, 150, 90), (w * 0.15, h * 0.08, 140, 70), (w * 0.78, h * 0.9, 170, 100), (w * 0.2, h * 0.84, 170, 80)],
                sparkles: [(w * 0.9, h * 0.86, 2.4), (w * 0.12, h * 0.7, 2), (w * 0.95, h * 0.62, 2), (w * 0.7, h * 0.14, 1.8), (w * 0.6, h * 0.95, 2), (w * 0.08, h * 0.15, 1.8), (w * 0.2, h * 0.93, 2.2), (w * 0.82, h * 0.98, 1.8), (w * 0.04, h * 0.5, 2)],
                drift: (24, 12)
            )
        }
    }

    static let kinds: [Character: Tile] = [
        "q": Tile(tile: "#ef7f8e", glyph: "#fbc4cb", opacity: 1), "p": Tile(tile: "#e2486c", glyph: "#f6a0b2", opacity: 1),
        "r": Tile(tile: "#d93a63", glyph: "#f28a9f", opacity: 1), "R": Tile(tile: "#c22a52", glyph: "#ee7790", opacity: 1),
        "o": Tile(tile: "#e8873a", glyph: "#fbd3a4", opacity: 1), "k": Tile(tile: "#9c1f3d", glyph: "#de6c86", opacity: 1),
        "a": Tile(tile: "#f2cf3a", glyph: "#b58f1c", opacity: 1), "b": Tile(tile: "#f2d54e", glyph: "#bb9a2c", opacity: 1),
        "c": Tile(tile: "#f3df7a", glyph: "#c2a646", opacity: 0.95), "d": Tile(tile: "#f3e6a0", glyph: "#c8b878", opacity: 0.9),
        "g": Tile(tile: "#8f9a52", glyph: "#c3cc8c", opacity: 1), "w": Tile(tile: "#b8a85a", glyph: "#8a7c3c", opacity: 1),
        "l": Tile(tile: "#e9d28a", glyph: "#b79d52", opacity: 1), "m": Tile(tile: "#d9bd6a", glyph: "#a58a3c", opacity: 1),
        "n": Tile(tile: "#a8923c", glyph: "#75642a", opacity: 1), "v": Tile(tile: "#a8964c", glyph: "#75682e", opacity: 1),
        "f": Tile(tile: "#f5efcf", glyph: "#c9c09a", opacity: 0.6), "u": Tile(tile: "#e9d9a0", glyph: "#a98f4a", opacity: 0.75),
    ]

    static func hash(_ x: Int, _ y: Int) -> Double {
        var h = Double(JS.uint32(Double(x) * 374_761_393 + Double(y) * 668_265_263))
        h = Double(JS.uint32(JS.xor(h, JS.ushr(h, 13)) * 1_274_126_177))
        return Double(JS.uint32(JS.xor(h, JS.ushr(h, 16)))) / 4_294_967_296
    }

    /// La distance d'un point à un segment, et où tombe le point le plus proche.
    static func distanceToSegment(_ px: Double, _ py: Double, _ ax: Double, _ ay: Double, _ bx: Double, _ by: Double) -> (distance: Double, along: Double) {
        let dx = bx - ax, dy = by - ay
        let along = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
        return (hypot(px - ax - along * dx, py - ay - along * dy), along)
    }

    /// Les cases d'une tortue vue d'en haut, dans son propre repère : `a` le long
    /// du cap, `b` en travers. `sweep` dit combien les nageoires avant sont
    /// rabattues, `surge` si la carapace a avancé d'une case.
    static func turtleCells(heading: (Double, Double), size: Double, sweep: Double, surge: Double) -> [Cell] {
        let (ux, uy) = heading
        let vx = uy, vy = -ux
        let reach = Int((19 * size).rounded(.up))
        var cells: [Cell] = []
        let angle = (90 - sweep) * .pi / 180
        for y in -reach...reach {
            for x in -reach...reach {
                let fx = Double(x), fy = Double(y)
                let a = (fx * ux + fy * uy) / size - surge
                let b = (fx * vx + fy * vy) / size
                let shell = pow(a / 5.6, 2) + pow(b / 4.4, 2)
                if shell <= 1 {
                    let pick = hash(x + 91, y + 17)
                    // Une arête d'écailles sombres au milieu donne un axe à la carapace.
                    let spine = abs(b) <= 1.3 && abs(a) <= 4.2
                    if shell > 0.82 && pick < 0.1 { continue }
                    let kind: Character
                    if spine {
                        kind = Int(JS.round(a)) % 2 == 0 ? "k" : "R"
                    } else if shell < 0.5 {
                        kind = pick < 0.14 ? "o" : pick < 0.6 ? "r" : "R"
                    } else if shell < 0.85 {
                        kind = pick < 0.7 ? "r" : "p"
                    } else {
                        kind = pick < 0.3 ? "q" : "p"
                    }
                    cells.append(Cell(x: x, y: y, kind: kind, body: true))
                    continue
                }
                if a > 5.2 && a <= 7.6 && abs(b) <= 1.1 {
                    cells.append(Cell(x: x, y: y, kind: "a", body: true))
                    continue
                }
                if hypot(a + 6.2, b) <= 0.7 {
                    cells.append(Cell(x: x, y: y, kind: "c"))
                    continue
                }
                var limb: Double?
                for side in [1.0, -1.0] {
                    let front = distanceToSegment(a, b, 3.3, side * 4.3, 3.3 - 4.5 * cos(angle), side * (4.3 + 4.5 * sin(angle)))
                    if front.distance <= 1.05 { limb = front.along }
                    let back = distanceToSegment(a, b, -4.3, side * 3.3, -4.3 - 1.6 * cos(0.8), side * (3.3 + 1.6 * sin(0.8)))
                    if back.distance <= 0.75 { limb = 0.3 + back.along * 0.5 }
                }
                if let limb { cells.append(Cell(x: x, y: y, kind: limb < 0.55 ? "a" : limb < 0.85 ? "b" : "c")) }
            }
        }
        return cells
    }

    static func coralCells() -> [Cell] {
        var cells: [Cell] = []
        for y in -5...5 {
            for x in -5...6 {
                let body = pow(Double(x) / 3.1, 2) + pow((Double(y) - 0.3) / 2.6, 2)
                let head = x >= 3 && x <= 4 && abs(y) <= 1
                let fin = (x == -1 || x == 0) && (y == -3 || y == 3 || y == 4)
                if body > 1 && !head && !fin { continue }
                let pick = hash(x + 33, y + 71)
                let kind: Character = head ? "p" : body < 0.2 ? "R" : body < 0.6 ? (pick < 0.5 ? "r" : "p") : pick < 0.55 ? "p" : "q"
                cells.append(Cell(x: x, y: y, kind: kind, body: true))
            }
        }
        return cells
    }

    /// L'île dans le coin en haut à droite, et trois traînées de sable qui
    /// descendent vers l'eau de la tortue.
    func islandCells() -> [Cell] {
        var cells: [Cell] = []
        var taken = Set<Int>()
        let c = columns, span = layout.islandSpan
        func put(_ x: Int, _ y: Int, _ kind: Character) {
            if x < 0 || y < 0 || x >= c || taken.contains(x * 10_000 + y) { return }
            taken.insert(x * 10_000 + y)
            cells.append(Cell(x: x, y: y, kind: kind))
        }
        // L'île d'origine fait 36 cases ; une plus étroite garde ses proportions.
        let scale = Double(span) / 36
        let middle = Double(c) - 15 * scale
        let taper = Double(c) - 30 * scale
        let foam = c - Int((29 * scale).rounded())
        for y in 0..<7 {
            for x in (c - span)..<c {
                let fx = Double(x)
                let depth = 4.4 + sin(fx / 2.7) * 1.2 + (Self.hash(x, 400) - 0.5) * 1.6 - max(0, taper - fx) * 0.5
                if Double(y) > depth { continue }
                let pick = Self.hash(x + 5, y + 900)
                let heart = hypot((fx - middle) / (7 * scale), (Double(y) - 1.5) / 2.2)
                let kind: Character
                if heart < 1 && pick < 0.22 {
                    kind = pick < 0.08 ? "g" : pick < 0.15 ? "w" : "v"
                } else if Double(y) >= depth - 0.9 {
                    kind = x < foam ? "f" : "d"
                } else if y == 0 {
                    kind = pick < 0.5 ? "n" : "m"
                } else {
                    kind = pick < 0.45 ? "a" : pick < 0.8 ? "l" : "m"
                }
                put(x, y, kind)
            }
        }
        for (startX, startY, length, kinkAt) in layout.trails {
            var x = startX
            for step in 0..<length {
                let share = Double(step) / Double(length)
                let kind: Character = share < 0.4 ? "a" : share < 0.75 ? "b" : "c"
                let width = 3 + Int((Self.hash(startX + step, 31) * 2).rounded(.down))
                let shift = Self.hash(startX, step + 9) < 0.4 ? 1 : 0
                for across in 0..<max(1, width) { put(x + across - shift, startY + step, kind) }
                x -= step == kinkAt ? 2 : step % 3 == 2 ? 0 : 1
            }
        }
        return cells
    }

    /// Un banc de sable bas le long du bas.
    func shoalCells() -> [Cell] {
        var cells: [Cell] = []
        let c = columns, r = rows
        for y in (r - 7)..<r {
            for x in max(layout.shoalFrom, -100)..<(c - 1) {
                let height = 3.6 + sin(Double(x) / 3.1) * 1.4 + (Self.hash(x, 77) - 0.5) * 2 - Double(max(0, layout.shoalFrom + 7 - x)) * 0.35
                if Double(r - y) <= height { cells.append(Cell(x: x, y: y - 2, kind: "u")) }
            }
        }
        return cells
    }

    static func glyph(_ x: Int, _ y: Int) -> Character {
        glyphs[Int((hash(x + 7, y + 3) * Double(glyphs.count)).rounded(.down))]
    }

    /// Les carreaux d'une sorte en un chemin ; les glyphes en un texte par rangée.
    static func mosaic(_ cells: [Cell]) -> [Node] {
        var order: [Character] = []
        var byKind: [Character: [Cell]] = [:]
        for cell in cells {
            if byKind[cell.kind] == nil { order.append(cell.kind) }
            byKind[cell.kind, default: []].append(cell)
        }
        var out: [Node] = []
        for kind in order {
            guard let paint = kinds[kind], let list = byKind[kind] else { continue }
            var path = PathData()
            for c in list { path = path + .rect(Double(c.x) * cell + 1, Double(c.y) * cell + 1, cell - 2, cell - 2) }
            var group: [Node] = [Node.path(path).fill(Paint(paint.tile)).stroke("#fff", opacity: 0.24)]
            var rowOrder: [Int] = []
            var rows: [Int: [Cell]] = [:]
            for c in list {
                if rows[c.y] == nil { rowOrder.append(c.y) }
                rows[c.y, default: []].append(c)
            }
            for y in rowOrder {
                let row = rows[y]!
                group.append(.glyphs(row.map { glyph($0.x, y) }, xs: row.map { Double($0.x) * cell + cell / 2 }, ys: Array(repeating: Double(y) * cell + 11, count: row.count)).fill(Paint(paint.glyph)).font(size: cell - 4, weight: 800))
            }
            out.append(paint.opacity == 1 ? .group(group) : Node.group(group).opacity(paint.opacity))
        }
        return out
    }

    static func silhouette(_ cells: [Cell], _ fill: String, _ opacity: Double) -> Node {
        var seen = Set<Int>()
        var path = PathData()
        for c in cells where seen.insert(c.x * 10_000 + c.y).inserted {
            path = path + .rect(Double(c.x) * cell, Double(c.y) * cell, cell, cell)
        }
        return Node.path(path).fill(Paint(fill)).opacity(opacity)
    }

    /// Sous un animal : son ombre, décalée en bas à droite, et un dessous sombre.
    static func under(_ cells: [Cell], _ shadow: Double, _ offset: Double) -> [Node] {
        [
            Node.group([silhouette(cells, "#0a6aa6", shadow)]).translate(cell * offset, cell * offset),
            Node.group([silhouette(cells.filter(\.body), "#7a1230", 0.5)]).translate(0, 2),
        ]
    }

    static let stroke: [(Double, Double)] = [(-45, 0), (20, 1), (85, 1), (20, 0)]

    /// La tortue : quatre poses de nage qui se relaient.
    func turtle(heading: (Double, Double), size: Double, beat: Double) -> Node {
        let turn = Animation([
            .init(0, [.opacity: .n(0)]), .init(0.018, [.opacity: .n(1)]), .init(0.25, [.opacity: .n(1)]),
            .init(0.268, [.opacity: .n(0)]), .init(1, [.opacity: .n(0)]),
        ], duration: beat, timing: .linear)
        let poses = Self.stroke.enumerated().map { index, pose -> Node in
            let cells = Self.turtleCells(heading: heading, size: size, sweep: pose.0, surge: pose.1)
            return Node.group(Self.under(cells, 0.38, 3) + Self.mosaic(cells))
                .opacity(index == 0 ? 1 : 0).animate(turn.delayed(-(beat * Double(4 - index)) / 4))
        }
        let c = Self.cell
        let x = Animation([
            .init(0, [.transform: .t(.translate(layout.honuX.0 * c, 0))], timing: .easeInOut),
            .init(0.45, [.transform: .t(.translate(layout.honuX.1 * c, 0))], timing: .easeInOut),
            .init(1, [.transform: .t(.translate(layout.honuX.0 * c, 0))]),
        ], duration: 170)
        let y = Animation([
            .init(0, [.transform: .t(.translate(0, layout.honuY.0 * c))], timing: .easeInOut),
            .init(0.45, [.transform: .t(.translate(0, layout.honuY.1 * c))], timing: .easeInOut),
            .init(1, [.transform: .t(.translate(0, layout.honuY.0 * c))]),
        ], duration: 170)
        return Node.group([Node.group(poses).translate(0, layout.honuY.0 * c).animate(y)]).translate(layout.honuX.0 * c, 0).animate(x)
    }

    /// Des étendues d'eau plus profonde, en marches, à peine visibles.
    func patches() -> Node {
        var path = PathData()
        let c = Self.cell
        for (column, row, width, height) in layout.patches {
            for y in 0..<height {
                let inset = Int(JS.round(abs(Double(y) - Double(height) / 2) * 0.9 + (Self.hash(column + y, row) - 0.5) * 3))
                let run = Double(max(2, width - inset * 2)) * c
                path = path + .rect(Double(column + inset) * c, Double(row + y) * c, run, c)
            }
        }
        return Node.path(path).fill("#0f7fb8").opacity(0.075)
    }

    /// Quelques carreaux de sable qui pâlissent et reviennent.
    static func twinkle(_ cells: [Cell]) -> [Node] {
        cells.compactMap { c -> Node? in
            let pick = hash(c.x + 61, c.y + 13)
            if pick > 0.055 { return nil }
            let dim = Animation.between([.opacity: .n(0)], [.opacity: .n(0.3)], duration: 9 + (pick * 90).rounded(.down),
                                        delay: -(hash(c.x, c.y + 5) * 12).rounded(.down), direction: .alternate, timing: .easeInOut)
            return Node.rect(Double(c.x) * cell + 1, Double(c.y) * cell + 1, cell - 2, cell - 2).fill("#8fdbe6").opacity(0).animate(dim)
        }
    }

    static func sparkle(_ x: Double, _ y: Double, _ size: Double, delay: Double, seconds: Double) -> Node {
        let twinkle = Animation([.init(0, [.opacity: .n(0)]), .init(0.5, [.opacity: .n(0.8)]), .init(1, [.opacity: .n(0)])],
                                duration: seconds, delay: -delay, timing: .easeInOut)
        return Node.circle(x, y, size).fill("#fff").animate(twinkle)
    }

    static func build(width: Double, height: Double) -> Scene {
        let columns = Int((width / cell).rounded(.up)), rows = Int((height / cell).rounded(.up))
        return HonuLagoon(width: width, height: height, layout: .portrait(width, height, columns: columns, rows: rows)).scene()
    }

    static func original() -> Scene {
        HonuLagoon(width: 1600, height: 1000, layout: .original(columns: Int((1600 / cell).rounded(.up)))).scene()
    }

    func scene() -> Scene {
        var scene = Scene(width: width, height: height)
        let c = Self.cell
        let (wx, wy) = layout.water
        scene.linear("water", x1: 0, y1: 0, x2: wx, y2: wy, [
            (0, "#5cc7d6", 1), (0.05, "#6bcedb", 1), (0.1, "#79d4e0", 1), (0.16, "#86d9e4", 1), (0.24, "#93dde8", 1),
            (0.36, "#9fe0ea", 1), (0.54, "#84d6e5", 1), (0.7, "#4fbbdc", 1), (0.86, "#22a0cf", 1), (1, "#1493c9", 1),
        ])
        scene.radial("glow", [(0, "#d2f8fa", 0.28), (0.35, "#d2f8fa", 0.18), (0.7, "#d2f8fa", 0.06), (1, "#d2f8fa", 0)])
        scene.radial("sun", [(0, "#ffe9a0", 0.8), (0.2, "#ffe9a0", 0.58), (0.4, "#ffe9a0", 0.36), (0.6, "#ffe9a0", 0.18), (0.8, "#ffe9a0", 0.06), (1, "#ffe9a0", 0)])
        scene.radial("soft", [(0, "#fff", 1), (0.3, "#fff", 0.7), (0.65, "#fff", 0.22), (1, "#fff", 0)])
        scene.define("dots", .pattern(Pattern(width: c, height: c, nodes: [Node.rect(5, 6.5, 5, 2, radius: 1).fill("#eaffff", opacity: 0.75)])))
        scene.define("grid", .pattern(Pattern(width: c, height: c, nodes: [Node.path("M0 0.5h\(c)M0.5 0v\(c)").fill(.none).stroke("#dff7ff", opacity: 0.08)])))
        scene.linear("east", x1: 0, y1: 0, x2: layout.gridFade.x2, y2: layout.gridFade.y2, [(0.64, "#fff", 0), (0.82, "#fff", 1)])
        scene.define("eastward", .mask(Mask(region: Rect(0, 0, width, height), nodes: [.rect(0, 0, width, height).fill("url(#east)")])))
        scene.define("soft-mask", .mask(Mask(contentUnits: .box, nodes: [.rect(0, 0, 1, 1).fill("url(#soft)")])))

        let south = (sin(0.26), cos(0.26))
        let breathe = Animation.between([.opacity: .n(0.3)], [.opacity: .n(1)], duration: 20, direction: .alternate, timing: .easeInOut)
        let drift = Animation.between([.transform: .t(.translate(-layout.drift.0, -layout.drift.1))], [.transform: .t(.translate(layout.drift.0, layout.drift.1))],
                                      duration: 52, direction: .alternate, timing: .easeInOut)
        let glintTimes: [(Double, Double)] = [(9, 0), (11, 3), (10, 5), (13, 2)]
        let glints = zip(layout.glints, glintTimes).map { spot, time in
            Node.group([.ellipse(spot.0, spot.1, spot.2, spot.3).fill("url(#dots)").mask("soft-mask")])
                .animate(breathe.lasting(time.0 + 9).delayed(-time.1))
        }
        let coralX = Animation([
            .init(0, [.transform: .t(.translate(layout.coralFrom.0 * c, layout.coralFrom.1 * c))], timing: .easeInOut),
            .init(0.5, [.transform: .t(.translate(layout.coralTo.0 * c, layout.coralTo.1 * c))], timing: .easeInOut),
            .init(1, [.transform: .t(.translate(layout.coralFrom.0 * c, layout.coralFrom.1 * c))]),
        ], duration: 90)
        let island = islandCells(), shoal = shoalCells(), coral = Self.coralCells()
        let sparkleTimes: [(Double, Double)] = [(2.2, 8), (3.6, 9), (6.1, 11), (0.7, 7), (4.9, 10), (7.5, 9), (1.9, 8), (5.5, 11), (8.3, 7)]

        scene.add(.rect(0, 0, width, height).fill("url(#water)"))
        scene.add(.ellipse(layout.glow.0, layout.glow.1, layout.glow.2, layout.glow.3).fill("url(#glow)"))
        scene.add(patches())
        scene.add(.ellipse(layout.sun.0, layout.sun.1, layout.sun.2, layout.sun.3).fill("url(#sun)"))
        scene.add(Node.rect(0, 0, width, height).fill("url(#grid)").mask("eastward"))
        scene.add(Node.group(glints).animate(drift))
        scene.add(Self.mosaic(island) + Self.mosaic(shoal) + Self.twinkle(island) + Self.twinkle(shoal))
        scene.add(Node.group(Self.under(coral, 0.2, 2) + Self.mosaic(coral)).translate(layout.coralFrom.0 * c, layout.coralFrom.1 * c).animate(coralX))
        scene.add(turtle(heading: south, size: 1.1, beat: 22))
        scene.add(zip(layout.sparkles, sparkleTimes).map { Self.sparkle($0.0, $0.1, $0.2, delay: $1.0, seconds: $1.1) })
        return scene
    }
}
