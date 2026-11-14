import Foundation

// Night Reef : le lagon de Honu après la nuit tombée. Une grande tortue et une
// raie manta, en mosaïque, font des tours au-dessus de leur halo. L'idée unique
// est la bioluminescence : le bord de la carapace et l'aile de la raie
// brillent, le cœur de la carapace couve en violet, le plancton laisse un
// sillage lumineux.
// D'après theme-examples (Anthropic, Apache 2.0), scenes/night-reef.ts.

struct NightReef {
    static let cell = 20.0
    static let glyphs = Array("$%tSX:;t$%S")
    static let teal = "#4fe6cf", tealInk = "#35c4ae"
    static let violet = "#7a6cff", violetInk = "#9488ff"
    static let warm = "#e0a060", warmInk = "#c98a4c"

    enum Heading { case up, down, left, right }

    struct Cell {
        var x: Int
        var y: Int
        var kind: Character
    }

    struct Kind {
        var tile: String
        var glyph: String
        var opacity: Double?
    }

    struct Swarm {
        var cx, cy, rx, ry: Double
        var count: Int
        var seed: Int
        var drift: Double
        var dx, dy: Double
    }

    /// Un tour : descendre (ou monter) de `y0` à `y1`, glisser de `dx`, revenir.
    struct Lap {
        var x: Double
        var y0: Double
        var y1: Double
        var dx: Double
    }

    struct Layout {
        var water: (Double, Double, Double)
        var caustics: [(Double, Double, Double, Double)]
        var deep: (Double, Double, Double, Double)
        var gridFade: (Double, Double)
        var swarms: [Swarm]
        var scatter: (Double, Double, Double, Double)
        var reef: (Int, Int)
        var ray: Lap
        var turtle: Lap

        static let original = Layout(
            water: (720, 420, 1050), caustics: [(170, -20, 280, 1040), (1420, -20, 320, 1040)], deep: (1640, 1040, 900, 640), gridFade: (1, 0),
            swarms: [
                Swarm(cx: 1330, cy: 700, rx: 190, ry: 120, count: 48, seed: 1, drift: 61, dx: -70, dy: 30),
                Swarm(cx: 1480, cy: 880, rx: 110, ry: 90, count: 36, seed: 2, drift: 47, dx: 60, dy: -40),
                Swarm(cx: 1180, cy: 950, rx: 150, ry: 40, count: 30, seed: 6, drift: 67, dx: 80, dy: -14),
                Swarm(cx: 210, cy: 880, rx: 210, ry: 90, count: 46, seed: 5, drift: 53, dx: 76, dy: -30),
            ],
            scatter: (470, 60, 700, 860), reef: (64, 44),
            ray: Lap(x: 3 * 20, y0: 700, y1: 420, dx: 40), turtle: Lap(x: 62 * 20, y0: 290, y1: 570, dx: -40)
        )

        /// Les deux bêtes font leurs tours en bas, la raie à gauche, la tortue à
        /// droite, sous les boutons ; le plancton et la lumière de lune en haut.
        static func portrait(_ w: Double, _ h: Double) -> Layout {
            Layout(
                water: (w * 0.5, h * 0.4, h * 0.75), caustics: [(w * 0.05, -20, w * 0.3, h * 0.3), (w * 0.62, -20, w * 0.34, h * 0.26)],
                deep: (w * 1.02, h * 1.02, w * 0.9, h * 0.32), gridFade: (0, 1),
                swarms: [
                    Swarm(cx: w * 0.78, cy: h * 0.1, rx: 170, ry: 110, count: 44, seed: 1, drift: 61, dx: -70, dy: 30),
                    Swarm(cx: w * 0.22, cy: h * 0.06, rx: 150, ry: 70, count: 36, seed: 2, drift: 47, dx: 60, dy: -20),
                    Swarm(cx: w * 0.5, cy: h * 0.96, rx: 220, ry: 40, count: 30, seed: 6, drift: 67, dx: 80, dy: -14),
                    Swarm(cx: w * 0.3, cy: h * 0.66, rx: 210, ry: 70, count: 40, seed: 5, drift: 53, dx: 76, dy: -30),
                ],
                scatter: (w * 0.05, h * 0.2, w * 0.9, h * 0.42),
                reef: (Int(w / 20) - 30, Int(h / 20) - 6),
                ray: Lap(x: 20, y0: h * 0.86, y1: h * 0.7, dx: 40), turtle: Lap(x: w - 400, y0: h * 0.62, y1: h * 0.78, dx: -40)
            )
        }
    }

    let width: Double
    let height: Double
    let layout: Layout

    static let kinds: [Character: Kind] = [
        "h": Kind(tile: "#1d7f80", glyph: "#2a9a98"), "H": Kind(tile: "#27958f", glyph: "#38b0a6"),
        "f": Kind(tile: "#176a70", glyph: "#22838a"), "s": Kind(tile: "#124a56", glyph: "#1b6270"),
        "p": Kind(tile: "#4338b0", glyph: "#5247c4"), "q": Kind(tile: "#5a4de0", glyph: "#6b5ff0"),
        "a": Kind(tile: "#a87645", glyph: "#bd8852"), "r": Kind(tile: "#3a3099", glyph: "#483eae"),
        "k": Kind(tile: "#2c2580", glyph: "#3a3296"), "t": Kind(tile: "#176a70", glyph: "#22838a"),
        "m": Kind(tile: "#1d6672", glyph: "#247482"), "M": Kind(tile: "#258291", glyph: "#2f96a4"),
        "u": Kind(tile: "#176a70", glyph: "#22838a", opacity: 0.7), "v": Kind(tile: "#176a70", glyph: "#22838a", opacity: 0.45),
        "w": Kind(tile: "#176a70", glyph: "#22838a", opacity: 0.25), "x": Kind(tile: "#16305c", glyph: "#1e3c6c"),
        "y": Kind(tile: "#1c4468", glyph: "#255478"),
    ]

    static let turtleBody = """
    ........hHh........
    ........HHH........
    ........hHh........
    .........h.........
    ........sss........
    .......sspss.......
    ......sspppss......
    .....sspqpapss.....
    .....spprkrpps.....
    .....spqkqkqps.....
    .....spprkrpps.....
    .....sspapqpss.....
    ......sspppss......
    .......sspss.......
    ........sss........
    """
    static let flippers = [
        ",\n,\n,\n,\n,\n,\n...fff\nfffff\nff\n,\n,\n,\n.....f\n.....ff",
        ",\n,\n,\n,\n,\n,\n....ff\n..fff\nffff\nff\n,\n,\n.....f\n.....ff",
        ",\n,\n,\n,\n,\n,\n.....f\n...ff\n..ff\n.ff\nff\nf\n.....f\n.....ff",
    ]
    static let manta = [
        """
        ......m......
        .....mmm.....
        ...mmmMmmm...
        .mmmmMMMmmmm.
        mmmmmMMMmmmmm
        mmm.mmMmm.mmm
        m....mmm....m
        ......m......
        ......t......
        ......t......
        .....u.......
        .....u.......
        ....v........
        ....w........
        """,
        """
        ......m......
        .....mmm.....
        ..mmmmMmmmm..
        mmmmmMMMmmmmm
        mmmmmMMMmmmmm
        .mm.mmMmm.mm.
        .....mmm.....
        ......m......
        ......t......
        .....t.......
        .....u.......
        ....u........
        ....v........
        ...w.........
        """,
    ]
    static let coral = """
    ....................yy......
    .....yy............yyyy..y..
    ....yyyy....y.....yyxyyyyyy.
    .y.yyxyy...yyy..yyyxxyyxxyy.
    yyyyxxyyy.yyxyy.yxyxxyxxxyyy
    yxyxxxxyyyyxxxyyyxxxxxxxxxyx
    xxxxxxxxxxxxxxxxxxxxxxxxxxxx
    """

    static func hash(_ a: Int, _ b: Int) -> Double {
        var h = UInt32(bitPattern: Int32(truncatingIfNeeded: a) &* 374_761_393) &+ UInt32(bitPattern: Int32(truncatingIfNeeded: b) &* 668_265_263)
        h = UInt32(bitPattern: Int32(bitPattern: h ^ (h >> 13)) &* 1_274_126_177)
        return Double(h ^ (h >> 16)) / 4_294_967_296
    }

    static func cells(_ map: String) -> [Cell] {
        var out: [Cell] = []
        let lines = map.split(separator: "\n", omittingEmptySubsequences: true).map { $0 == "," ? "" : String($0) }
        for (y, line) in lines.enumerated() {
            for (x, kind) in line.enumerated() where kind != "." { out.append(Cell(x: x, y: y, kind: kind)) }
        }
        return out
    }

    /// Les cartes sont dessinées tête en haut ; on tourne les cases, pas les
    /// glyphes, qui restent droits.
    static func facing(_ cells: [Cell], _ heading: Heading, _ height: Int) -> [Cell] {
        cells.map { c in
            switch heading {
            case .down: return Cell(x: c.x, y: height - 1 - c.y, kind: c.kind)
            case .left: return Cell(x: c.y, y: c.x, kind: c.kind)
            case .right: return Cell(x: height - 1 - c.y, y: c.x, kind: c.kind)
            case .up: return c
            }
        }
    }

    static func glyph(_ x: Int, _ y: Int) -> Character {
        let index = (x * 7 + y * 13 + ((x * y) % 3) + 22) % glyphs.count
        return glyphs[(index + glyphs.count) % glyphs.count]
    }

    static func tilePath(_ list: [Cell]) -> PathData {
        list.reduce(PathData()) { $0 + .rect(Double($1.x) * cell + 1, Double($1.y) * cell + 1, 18, 18) }
    }

    static func glyphRows(_ list: [Cell], _ fill: String) -> [Node] {
        var order: [Int] = []
        var rows: [Int: [Cell]] = [:]
        for c in list {
            if rows[c.y] == nil { order.append(c.y) }
            rows[c.y, default: []].append(c)
        }
        return order.map { y in
            let row = rows[y]!
            return Node.glyphs(row.map { glyph($0.x, y) }, xs: row.map { Double($0.x) * cell + 10 }, ys: Array(repeating: Double(y) * cell + 15, count: row.count))
                .fill(Paint(fill))
        }
    }

    static func mosaic(_ cells: [Cell]) -> [Node] {
        var order: [Character] = []
        var byKind: [Character: [Cell]] = [:]
        for c in cells {
            if byKind[c.kind] == nil { order.append(c.kind) }
            byKind[c.kind, default: []].append(c)
        }
        return order.compactMap { kind in
            guard let paint = kinds[kind] else { return nil }
            let list = byKind[kind]!
            let group = Node.group([Node.path(tilePath(list)).fill(Paint(paint.tile)).stroke("#aab8ff", opacity: 0.06)] + glyphRows(list, paint.glyph))
            return paint.opacity.map { group.opacity($0) } ?? group
        }
    }

    static func edgeCells(_ cells: [Cell]) -> [Cell] {
        let filled = Set(cells.map { $0.x * 10_000 + $0.y })
        return cells.filter { c in
            !filled.contains((c.x + 1) * 10_000 + c.y) || !filled.contains((c.x - 1) * 10_000 + c.y)
                || !filled.contains(c.x * 10_000 + c.y + 1) || !filled.contains(c.x * 10_000 + c.y - 1)
        }
    }

    static let rim = Animation([.init(0, [.opacity: .n(0.14)]), .init(0.5, [.opacity: .n(0.95)]), .init(1, [.opacity: .n(0.14)])], duration: 12, timing: .easeInOut)
    static let ember = Animation([.init(0, [.opacity: .n(0.35)]), .init(0.5, [.opacity: .n(0.9)]), .init(1, [.opacity: .n(0.35)])], duration: 17, timing: .easeInOut)
    static let speck = Animation([.init(0, [.opacity: .n(0.28)]), .init(0.5, [.opacity: .n(1)]), .init(1, [.opacity: .n(0.28)])], duration: 9, timing: .easeInOut)
    static let halo = Animation([.init(0, [.opacity: .n(0.5)]), .init(0.5, [.opacity: .n(1)]), .init(1, [.opacity: .n(0.5)])], duration: 9, timing: .easeInOut)

    /// Des carreaux qui brillent ensemble, sur une horloge lente.
    static func lit(_ list: [Cell], ember isEmber: Bool, _ colour: String, _ ink: String, seconds: Double, delay: Double) -> Node? {
        if list.isEmpty { return nil }
        let clock = (isEmber ? ember : rim).lasting(seconds).delayed(-(delay * 10).rounded() / 10)
        return Node.group([Node.path(tilePath(list)).fill(Paint(colour))] + glyphRows(list, ink)).opacity(isEmber ? 0.7 : 0.5).animate(clock)
    }

    /// Du turquoise le long d'un bord : des groupes dont les horloges se
    /// répartissent sur le cycle, pour qu'une part soit toujours allumée.
    static func tealEdge(_ cells: [Cell], share: Double, seconds: Double, seed: Int, groups count: Int) -> [Node] {
        var groups = Array(repeating: [Cell](), count: count)
        for c in cells {
            let pick = hash(Int((Double(c.x) / 2).rounded(.down)) + seed, Int((Double(c.y) / 2).rounded(.down)) * 3) * 0.7 + hash(c.x + seed, c.y) * 0.3
            if pick < share { groups[Int((pick / share * Double(count)).rounded(.down))].append(c) }
        }
        return groups.enumerated().compactMap { i, list in lit(list, ember: false, teal, tealInk, seconds: seconds, delay: Double(i) * seconds / Double(count)) }
    }

    static func violetHeart(_ cells: [Cell], _ cx: Int, _ cy: Int) -> [Node] {
        let scutes = cells.filter { $0.kind == "q" }
        let inner = scutes.filter { abs($0.x - cx) + abs($0.y - cy) <= 1 }
        let outer = scutes.filter { abs($0.x - cx) + abs($0.y - cy) > 1 }
        let spine = cells.filter { $0.kind == "a" }
        return [
            lit(inner, ember: true, violet, violetInk, seconds: 17, delay: 0), lit(outer, ember: true, violet, violetInk, seconds: 23, delay: 9),
            lit(spine, ember: true, warm, warmInk, seconds: 19, delay: 3),
        ].compactMap { $0 }
    }

    /// Le sillage : du plancton remué derrière une bête, en trois bandes de
    /// plus en plus pâles.
    static func wake(_ widthCells: Int, _ heightCells: Int, _ length: Int, _ heading: Heading, _ seed: Int, delay inherited: Double?) -> [Node] {
        var bands = [PathData(), PathData(), PathData()]
        let centre = Double(widthCells) * cell / 2
        for i in 0..<(length * 6) {
            let along = pow(hash(seed, i), 1.4)
            let spread = (0.2 + along * 0.4) * Double(widthCells) * cell
            let px = JS.round(centre + (hash(seed + 1, i) - 0.5) * spread)
            let py = JS.round(Double(heightCells) * cell - 30 + along * Double(length) * cell)
            let size = hash(seed + 2, i) < 0.3 ? 3.0 : 2.0
            let x = heading == .left ? py : px
            let y = heading == .down ? Double(heightCells) * cell - py : heading == .left ? px : py
            bands[min(2, Int((along * 3).rounded(.down)))] = bands[min(2, Int((along * 3).rounded(.down)))] + .rect(x, y, size, size)
        }
        let strength = [0.85, 0.55, 0.3]
        return bands.enumerated().map { i, d in
            Node.path(d).fill(Paint(teal), opacity: strength[i]).opacity(0.6).animate(speck.lasting(7 + Double(i) * 2).delayed(-Double(i) * 2.7))
        }
    }

    /// Des poses montrées une à une. Avec trois poses, l'ordre est 0 1 2 1.
    static func posed(_ poses: [[Node]], seconds: Double, delay: Double) -> [Node] {
        let three: [[(Double, Double)]] = [
            [(0, 1), (0.2, 1), (0.25, 0), (0.95, 0), (1, 1)],
            [(0, 0), (0.2, 0), (0.25, 1), (0.45, 1), (0.5, 0), (0.7, 0), (0.75, 1), (0.95, 1), (1, 0)],
            [(0, 0), (0.45, 0), (0.5, 1), (0.7, 1), (0.75, 0), (1, 0)],
        ]
        let two: [[(Double, Double)]] = [
            [(0, 1), (0.45, 1), (0.5, 0), (0.95, 0), (1, 1)],
            [(0, 0), (0.45, 0), (0.5, 1), (0.95, 1), (1, 0)],
        ]
        let tracks = poses.count == 3 ? three : two
        return poses.enumerated().map { i, body in
            let frames = tracks[i].map { Animation.Keyframe($0.0, [.opacity: .n($0.1)]) }
            // Sans animation, une seule pose se voit : la deuxième sur trois, la première sur deux.
            let still = (poses.count == 3 ? [0.0, 1, 0] : [1.0, 0])[i]
            return Node.group(body).opacity(still).animate(Animation(frames, duration: seconds, delay: delay, timing: .linear))
        }
    }

    static func strokePhase(_ left: Int, _ right: Int) -> [Cell] {
        cells(flippers[left]) + cells(flippers[right]).map { Cell(x: 18 - $0.x, y: $0.y, kind: $0.kind) }
    }

    static func nearRipples(_ width: Double, _ height: Double, _ count: Int, _ seed: Int) -> Node {
        var path = PathData()
        for i in 0..<count {
            let x = JS.round((-90 + hash(seed, i) * (width + 180)) / 20) * 20 + 6
            let y = JS.round((-70 + hash(seed + 1, i) * (height + 140)) / 20) * 20 + 9
            path = path + .rect(x, y, 8, 2)
        }
        return Node.path(path).fill("#5fd0c8", opacity: 0.4).opacity(0.6).animate(speck.lasting(11))
    }

    static func bigTurtle(_ heading: Heading, full: Bool) -> [Node] {
        let height = 15
        let body = facing(cells(turtleBody), heading, height)
        let strokes = [strokePhase(0, 2), strokePhase(1, 1), strokePhase(2, 0)].map { facing($0, heading, height) }
        if !full { return [Node.group(mosaic(strokes[1]) + mosaic(body)).translate(40, -40)] }
        let shellRim = body.filter { $0.kind == "s" }
        return wake(19, height, 11, heading, 500, delay: nil) + posed(strokes.map(mosaic), seconds: 7, delay: 0) + mosaic(body)
            + violetHeart(body, 9, 9) + tealEdge(shellRim, share: 0.7, seconds: 12, seed: 0, groups: 6)
    }

    static func legs(_ delay: Double) -> [Animation] {
        let tracks: [[(Double, Double)]] = [
            [(0, 1), (0.4359, 1), (0.4391, 0), (0.997, 0), (1, 1)],
            [(0, 0), (0.4359, 0), (0.4391, 1), (0.4984, 1), (0.5016, 0), (1, 0)],
            [(0, 0), (0.4984, 0), (0.5016, 1), (0.9359, 1), (0.9391, 0), (1, 0)],
            [(0, 0), (0.9359, 0), (0.9391, 1), (0.997, 1), (1, 0)],
        ]
        return tracks.map { track in Animation(track.map { Animation.Keyframe($0.0, [.opacity: .n($0.1)]) }, duration: 128, delay: delay, timing: .linear) }
    }

    static func way(_ lap: Lap, delay: Double) -> Animation {
        Animation([
            .init(0, [.transform: .t(.translate(0, lap.y0))]), .init(0.4375, [.transform: .t(.translate(0, lap.y1))]),
            .init(0.5, [.transform: .t(.translate(lap.dx, lap.y1))]), .init(0.9375, [.transform: .t(.translate(lap.dx, lap.y0))]),
            .init(1, [.transform: .t(.translate(0, lap.y0))]),
        ], duration: 128, delay: delay, timing: .linear)
    }

    func turtleLap() -> Node {
        let legs = Self.legs(-78)
        let content: [Node] = [
            Node.ellipse(190, 160, 300, 300).fill("url(#tealglow)").animate(Self.halo),
            Node.ellipse(190, 150, 170, 180).fill("url(#violetglow)").animate(Self.halo.delayed(-4)),
            Self.nearRipples(380, 300, 16, 801),
            Node.group(Self.bigTurtle(.down, full: true)).opacity(0).animate(legs[0]),
            Node.group(Self.bigTurtle(.left, full: false)).opacity(0).animate(legs[1]),
            Node.group(Self.bigTurtle(.up, full: true)).animate(legs[2]),
            Node.group(Self.bigTurtle(.right, full: false)).opacity(0).animate(legs[3]),
        ]
        return Node.group([Node.group(content).translate(layout.turtle.x, 0)]).animate(Self.way(layout.turtle, delay: -78))
    }

    /// La raie, tournée vers un côté. `.raylegs g` impose un retard de -30 s à
    /// chaque groupe animé de son tour, poses comprises.
    static func manta(_ heading: Heading, full: Bool) -> [Node] {
        let height = 14
        let poses = Self.manta.map { facing(cells($0), heading, height) }
        if !full { return [Node.group(mosaic(poses[0])).translate(-10, 10)] }
        let tiles = poses.map { mosaic($0) + tealEdge(edgeCells($0).filter { "mM".contains($0.kind) }, share: 0.9, seconds: 14, seed: 70, groups: 2) }
        return wake(13, height, 6, heading, 600, delay: nil) + posed(tiles, seconds: 9, delay: -30)
    }

    func rayLap() -> Node {
        let legs = Self.legs(-30)
        let content: [Node] = [
            Node.ellipse(130, 110, 280, 240).fill("url(#tealglow)").animate(Self.halo.delayed(-5)),
            Self.nearRipples(260, 180, 12, 811),
            Node.group(Self.manta(.up, full: true)).opacity(0).animate(legs[0]),
            Node.group(Self.manta(.right, full: false)).opacity(0).animate(legs[1]),
            Node.group(Self.manta(.down, full: true)).animate(legs[2]),
            Node.group(Self.manta(.left, full: false)).opacity(0).animate(legs[3]),
        ]
        return Node.group([Node.group(content).translate(layout.ray.x, 0)]).animate(Self.way(layout.ray, delay: -30))
    }

    func reefBand() -> [Node] {
        let (column, row) = layout.reef
        let cells = Self.cells(Self.coral).map { Cell(x: $0.x + column, y: $0.y + row, kind: $0.kind) }
        let filled = Set(cells.map { $0.x * 10_000 + $0.y })
        let anemones = cells.filter { $0.y > row + 2 && Self.hash($0.x * 3 + 9, $0.y * 11) < 0.08 }
        let tips = Array(cells.filter { !filled.contains($0.x * 10_000 + $0.y - 1) && (($0.x % 6) + 6) % 6 == 2 }.prefix(4))
        return Self.mosaic(cells) + [
            Self.lit(anemones, ember: false, Self.teal, Self.tealInk, seconds: 12, delay: 2),
            Self.lit(tips, ember: true, Self.warm, Self.warmInk, seconds: 19, delay: 5),
        ].compactMap { $0 }
    }

    /// Le plancton : un essaim de grains qui dérive d'un bloc.
    static func swarm(_ s: Swarm) -> Node {
        var parts = [PathData(), PathData(), PathData()]
        var violetPath = PathData(), bright = PathData()
        var halos: [Node] = []
        for i in 0..<s.count {
            let angle = hash(s.seed, i * 2) * .pi * 2
            let reach = pow(hash(s.seed, i * 2 + 1), 0.8)
            let x = JS.round(s.cx + cos(angle) * s.rx * reach)
            let y = JS.round(s.cy + sin(angle) * s.ry * reach)
            let roll = hash(s.seed + 7, i)
            if roll < 0.1 {
                halos.append(Node.circle(x + 2, y + 2, 11).fill("url(#speckhalo)"))
                bright = bright + .rect(x, y, 4, 4)
            } else if roll < 0.36 {
                violetPath = violetPath + .rect(x, y, 3, 3)
            } else {
                let size = roll < 0.6 ? 3.0 : roll < 0.85 ? 2 : 1.5
                parts[i % 3] = parts[i % 3] + .rect(x, y, size, size)
            }
        }
        func tenth(_ v: Double) -> Double { (v * 10).rounded() / 10 }
        var nodes = parts.enumerated().map { i, d in
            Node.path(d).fill(Paint(teal)).opacity(0.6).animate(speck.lasting(7 + Double(i) * 2).delayed(-tenth(hash(s.seed, 90 + i) * 9)))
        }
        nodes.append(Node.path(violetPath).fill("#8b7bff").opacity(0.6).animate(speck.lasting(10).delayed(-tenth(hash(s.seed, 95) * 9))))
        nodes.append(Node.group(halos + [Node.path(bright).fill("#b8fff0")]).opacity(0.6).animate(speck.lasting(11).delayed(-tenth(hash(s.seed, 99) * 11))))
        let drift = Animation.between([.transform: .t(.translate(0, 0))], [.transform: .t(.translate(s.dx, s.dy))], duration: s.drift,
                                      delay: -JS.round(hash(s.seed, 77) * s.drift), direction: .alternate, timing: .easeInOut)
        return Node.group(nodes).animate(drift)
    }

    func middleScatter() -> Node {
        var path = PathData()
        let (x, y, w, h) = layout.scatter
        for i in 0..<18 { path = path + .rect(JS.round(x + Self.hash(51, i) * w), JS.round(y + Self.hash(52, i) * h), 1.5, 1.5) }
        return Node.path(path).fill(Paint(Self.teal), opacity: 0.3).opacity(0.6).animate(Self.speck.lasting(13))
    }

    static func grain() -> Pattern {
        var light = PathData(), dark = PathData()
        for i in 0..<150 {
            let x = (hash(11, i) * 48).rounded(.down) * 2, y = (hash(12, i) * 48).rounded(.down) * 2
            if i % 2 == 0 { light = light + .rect(x, y, 2, 2) } else { dark = dark + .rect(x, y, 2, 2) }
        }
        return Pattern(width: 96, height: 96, nodes: [Node.path(light).fill("#9db4ff", opacity: 0.022), Node.path(dark).fill("#000", opacity: 0.09)])
    }

    static func build(width: Double, height: Double) -> Scene {
        NightReef(width: width, height: height, layout: .portrait(width, height)).scene()
    }

    static func original() -> Scene {
        NightReef(width: 1600, height: 1000, layout: .original).scene()
    }

    func scene() -> Scene {
        var scene = Scene(width: width, height: height)
        scene.radial("water", cx: layout.water.0, cy: layout.water.1, r: layout.water.2, units: .user,
                     [(0, "#1b2d5a", 1), (0.3, "#13224a", 1), (0.6, "#0a1430", 1), (0.85, "#060c1f", 1), (1, "#040816", 1)])
        scene.linear("caustic", x1: 0, y1: 0, x2: 1, y2: 0, [(0, "#6f8fd6", 0), (0.5, "#6f8fd6", 0.085), (1, "#6f8fd6", 0)])
        scene.radial("deep", [(0, "#0d3a56", 0.6), (0.35, "#0d3a56", 0.34), (0.7, "#0d3a56", 0.1), (1, "#0d3a56", 0)])
        scene.define("grid", .pattern(Pattern(width: 20, height: 20, nodes: [Node.path("M0 0.5h20M0.5 0v20").fill(.none).stroke("#9db4ff", opacity: 0.045)])))
        scene.linear("edgeward", x1: 0, y1: 0, x2: layout.gridFade.0, y2: layout.gridFade.1, [(0, "#fff", 0.9), (0.24, "#fff", 0), (0.74, "#fff", 0), (1, "#fff", 1)])
        scene.define("edges", .mask(Mask(region: Rect(0, 0, width, height), nodes: [.rect(0, 0, width, height).fill("url(#edgeward)")])))
        scene.radial("tealglow", [(0, Self.teal, 0.24), (0.25, Self.teal, 0.15), (0.5, Self.teal, 0.07), (0.75, Self.teal, 0.02), (1, Self.teal, 0)])
        scene.radial("violetglow", [(0, Self.violet, 0.2), (0.3, Self.violet, 0.11), (0.6, Self.violet, 0.04), (1, Self.violet, 0)])
        scene.radial("speckhalo", [(0, Self.teal, 0.5), (0.4, Self.teal, 0.14), (1, Self.teal, 0)])
        scene.define("grain", .pattern(Self.grain()))

        let caustic = Animation.between([.transform: .t(.translate(-90, 0))], [.transform: .t(.translate(90, 0))], duration: 110, direction: .alternate, timing: .easeInOut)
        let c0 = layout.caustics[0], c1 = layout.caustics[1]
        scene.add(.rect(0, 0, width, height).fill("url(#water)"))
        scene.add(Node.group([
            Node.rect(c0.0, c0.1, c0.2, c0.3).fill("url(#caustic)").animate(caustic),
            Node.rect(c1.0, c1.1, c1.2, c1.3).fill("url(#caustic)").animate(caustic.lasting(95).delayed(-20).directed(.alternateReverse)),
        ]).transform(.skewX(-28)))
        scene.add(.ellipse(layout.deep.0, layout.deep.1, layout.deep.2, layout.deep.3).fill("url(#deep)"))
        scene.add(Node.rect(0, 0, width, height).fill("url(#grid)").opacity(0.35))
        scene.add(Node.rect(0, 0, width, height).fill("url(#grid)").mask("edges"))
        scene.add(.rect(0, 0, width, height).fill("url(#grain)"))
        scene.add(layout.swarms.map(Self.swarm))
        scene.add(middleScatter())
        scene.add(reefBand())
        scene.add(rayLap())
        scene.add(turtleLap())
        return scene.withFont(size: 13, weight: 700)
    }
}
