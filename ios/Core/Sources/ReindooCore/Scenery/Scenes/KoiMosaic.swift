import Foundation

// Koi Mosaic : un bassin vu d'en haut. Les koïs sont des mosaïques qui nagent
// d'une case par pas, en descendant un côté et en remontant l'autre ; leur
// ombre en escalier est posée au fond, en bas à droite.
// D'après theme-examples (Anthropic, Apache 2.0), scenes/koi-mosaic.ts.

struct KoiMosaic {
    static let cell = 20.0

    let width: Double
    let height: Double
    let layout: Layout

    struct Cell {
        var x: Int
        var y: Int
        var kind: Character
    }

    struct Tile {
        var across: Int
        var kind: Character
    }

    struct Step: Equatable {
        var x: Int
        var y: Int
    }

    struct Kind {
        var tile: String
        var glyph: String
        var glyphOpacity: Double
        var glyphs: [Character]
    }

    struct Layout {
        var columns: Int
        var rows: Int
        var water: (Double, Double)
        var swell: [(Double, Double, Double, Double, Double)]
        var stairs: [(x: Double, y: Double, radii: [Double], squash: Double, opacity: Double, fill: String)]
        var gridFade: (Double, Double)
        var rightLane: [(Int, Int)]
        var leftLane: [(Int, Int)]
        /// Le pas de la nage où naît un sillage, en part du tour, et son écart.
        var wakes: [(Double, Int)]
        var ripples: [(Int, Int, Double, Double)]
        var pads: [(x: Int, y: Int, radius: Double, notch: Double, bloom: (Int, Int)?)]
        var bank: (Int, Int)

        static let original = Layout(
            columns: 80, rows: 50, water: (1, 0.62),
            swell: [(1440, 820, 560, 460, 1), (40, 60, 440, 360, 0.7)],
            stairs: [
                (86, 56, [28, 24, 20, 16, 12], 1.1, 0.045, "#0f6a73"), (-4, -4, [27, 23, 19, 15, 11], 1.3, 0.04, "#0f6a73"),
                (84, -6, [18], 1.2, 0.05, "#12767f"),
            ],
            gridFade: (1, 0),
            rightLane: [(70, -6), (69, 14), (69, 30), (64, 56)], leftLane: [(9, 56), (11, 36), (10, 18), (12, -6)],
            wakes: [(40.0 / 124, 5), (82.0 / 124, -4)],
            ripples: [(73, 29, 29, 4), (11, 14, 37, 20), (72, 46, 43, 31), (11, 43, 31, 9)],
            pads: [(73, 20, 3.6, 150, (0, -1)), (75, 37, 2.6, 300, nil), (7, 30, 3.6, 60, nil)],
            bank: (80, 50)
        )

        /// Les deux couloirs longent les bords, de haut en bas ; les nénuphars
        /// et les pierres vont dans les coins.
        static func portrait(_ w: Double, _ h: Double) -> Layout {
            let c = Int((w / KoiMosaic.cell).rounded(.up)), r = Int((h / KoiMosaic.cell).rounded(.up))
            let cc = Double(c), rr = Double(r)
            return Layout(
                columns: c, rows: r, water: (0.62, 1),
                swell: [(w * 0.9, h * 0.9, w * 0.7, h * 0.3, 1), (w * 0.05, h * 0.04, w * 0.6, h * 0.22, 0.7)],
                stairs: [
                    (cc + 6, rr + 6, [26, 22, 18, 14, 10], 1.1, 0.045, "#0f6a73"), (-4, -4, [22, 18, 14, 10], 1.3, 0.04, "#0f6a73"),
                    (cc + 4, -6, [14], 1.2, 0.05, "#12767f"),
                ],
                gridFade: (0, 1),
                rightLane: [(c - 6, -6), (c - 7, Int(rr * 0.25)), (c - 6, Int(rr * 0.6)), (c - 9, r + 6)],
                leftLane: [(5, r + 6), (7, Int(rr * 0.62)), (6, Int(rr * 0.3)), (7, -6)],
                wakes: [(0.32, 5), (0.66, -4)],
                ripples: [(c - 6, Int(rr * 0.2), 29, 4), (6, 8, 37, 20), (c - 7, r - 14, 43, 31), (8, r - 20, 31, 9)],
                pads: [(c - 6, 10, 3.6, 150, (0, -1)), (c - 4, r - 24, 2.6, 300, nil), (6, r - 11, 3.6, 60, nil)],
                bank: (c, r)
            )
        }
    }

    static let kinds: [Character: Kind] = [
        "a": Kind(tile: "#2f8552", glyph: "#8fd09f", glyphOpacity: 0.5, glyphs: Array("o:o;")),
        "b": Kind(tile: "#57b56f", glyph: "#1f6b45", glyphOpacity: 0.3, glyphs: Array(":;o")),
        "c": Kind(tile: "#267a50", glyph: "#8fd09f", glyphOpacity: 0.25, glyphs: Array(":;")),
        "p": Kind(tile: "#edb4cc", glyph: "#ffffff", glyphOpacity: 0.7, glyphs: Array("o")),
        "q": Kind(tile: "#eec25a", glyph: "#d9a93a", glyphOpacity: 0.8, glyphs: Array("*")),
        "s": Kind(tile: "#c9bf9a", glyph: "#6f8378", glyphOpacity: 0, glyphs: Array(":.;.")),
        "t": Kind(tile: "#8ea398", glyph: "#64796e", glyphOpacity: 0.4, glyphs: Array(".:;")),
        "u": Kind(tile: "#d9cfa8", glyph: "#7d9085", glyphOpacity: 0, glyphs: Array(".;:.")),
        "v": Kind(tile: "#7d968c", glyph: "#b9c8bd", glyphOpacity: 0.35, glyphs: Array(":.")),
    ]

    static let koiFills: [Character: [String]] = [
        "O": ["#ec7c3c", "#e06c2e", "#d55f25"], "W": ["#f5f1e6", "#ece7d9", "#f8f5ec"], "C": ["#d14a3a", "#c03d2e", "#d85544"],
        "K": ["#48545b", "#3b464c", "#55626b"], "E": ["#26343c", "#26343c", "#26343c"], "f": ["#f5f1e6", "#ece7d9", "#f8f5ec"],
        "t": ["#f5f1e6", "#ece7d9", "#f8f5ec"], "T": ["#f5f1e6", "#ece7d9", "#f8f5ec"],
    ]
    static let koiOpacity: [Character: Double] = ["f": 0.85, "t": 0.74, "T": 0.95]

    static let kohaku = """
    ....ff..............
    ...fff..............
    ..WOOO..............
    .EOOOOOWWW..........
    WOOOOOOWWWOOOWW.....
    WWOOOOOWWOOOOOW.....
    WOOOOOWWWWOOOWW.....
    .EWOOOOWWW..........
    ..WWWO..............
    ...fff..............
    ....ff..............
    """
    static let tancho = """
    ....ff..............
    ...fff..............
    ..WWWW..............
    .EWWWWKKWW..........
    WWCWWWKKKWWWWWW.....
    WCCCWWWKWWWKKWW.....
    WWCWWWWWWWKKWWW.....
    .EWWWWWWWW..........
    ..WWWW..............
    ...fff..............
    ....ff..............
    """
    static let tailUp = """
    ....................
    ..................Tt
    ................TTTt
    ................TTT.
    ...............TTTT.
    ...............TTTTt
    ...............TTT..
    ....................
    ....................
    ....................
    ....................
    """
    static let tailDown = """
    ....................
    ....................
    ....................
    ....................
    ...............TTT..
    ...............TTTTt
    ...............TTTT.
    ................TTT.
    ................TTTt
    ..................Tt
    ....................
    """

    static let ringTracks: [[(Double, Double)]] = [
        [(0, 0), (2, 0.16), (6, 0.12), (12, 0.06), (18, 0)],
        [(0, 0), (9, 0.15), (15, 0.11), (21, 0.06), (27, 0)],
        [(0, 0), (18, 0.13), (24, 0.09), (30, 0.05), (36, 0)],
        [(0, 0), (27, 0.11), (33, 0.08), (39, 0.04), (45, 0)],
    ]

    static func hash(_ x: Int, _ y: Int, _ salt: Int) -> Double {
        var h = (Int32(truncatingIfNeeded: x + 11) &* 374_761_393) ^ (Int32(truncatingIfNeeded: y + 7) &* 668_265_263) ^ (Int32(truncatingIfNeeded: salt + 3) &* 1_274_126_177)
        h = (h ^ Int32(bitPattern: UInt32(bitPattern: h) >> 13)) &* 1_274_126_177
        h = h ^ Int32(bitPattern: UInt32(bitPattern: h) >> 16)
        return Double(UInt32(bitPattern: h)) / 4_294_967_296
    }

    /// Des cases entières en un chemin, les voisines d'une rangée fondues en un
    /// rectangle.
    static func blocks(_ keys: [(Int, Int)], _ size: Double) -> PathData {
        var rowOrder: [Int] = []
        var rows: [Int: [Int]] = [:]
        for (x, y) in keys {
            if rows[y] == nil { rowOrder.append(y) }
            rows[y, default: []].append(x)
        }
        var path = PathData()
        for y in rowOrder {
            let list = rows[y]!.sorted()
            var from = list[0]
            for i in 1...list.count {
                let previous = list[i - 1]
                if i < list.count, list[i] == previous + 1 { continue }
                let width = Double(previous - from + 1) * size
                path = path + .rect(Double(from) * size, Double(y) * size, width, size)
                if i < list.count { from = list[i] }
            }
        }
        return path
    }

    /// Des cases sans doublon, dans l'ordre où elles arrivent.
    struct CellSet {
        private var seen = Set<Int>()
        private(set) var keys: [(Int, Int)] = []
        mutating func add(_ x: Int, _ y: Int) {
            if seen.insert((x + 50_000) * 100_000 + y + 50_000).inserted { keys.append((x, y)) }
        }
    }

    static func lines(_ map: String) -> [[Character]] {
        map.split(separator: "\n").map { Array($0) }.filter { !$0.isEmpty }
    }

    static func slices(_ map: String) -> [[Tile]] {
        let rows = lines(map)
        let spine = Double(rows.count - 1) / 2
        let length = rows.first?.count ?? 0
        return (0..<length).map { k in
            rows.enumerated().compactMap { row, line in
                let kind = line[k]
                return kind == "." ? nil : Tile(across: Int(Double(row) - spine), kind: kind)
            }
        }
    }

    /// Un couloir de la nage, une rangée par pas, avec un balancement de deux
    /// cases : le corps, qui suit la tête case à case, est toujours en S.
    static func walk(_ points: [(Int, Int)]) -> [Step] {
        var steps: [Step] = []
        for i in 0..<(points.count - 1) {
            let from = points[i], to = points[i + 1]
            let count = abs(to.1 - from.1)
            let sign = to.1 > from.1 ? 1 : to.1 < from.1 ? -1 : 0
            for n in 0..<count {
                let y = from.1 + sign * n
                let weave = 1.9 * sin(Double(y - 8) * 2 * .pi / 21)
                steps.append(Step(x: Int(JS.round(Double(from.0) + Double(to.0 - from.0) * Double(n) / Double(count) + weave)), y: y))
            }
        }
        return steps
    }

    static func place(_ steps: [Step], _ index: Int) -> Point {
        let i = ((index % steps.count) + steps.count) % steps.count
        return Point(Double(steps[i].x) * cell + 10, Double(steps[i].y) * cell + 10)
    }

    /// La place de la tête, une image par pas. Là où le pas suivant est loin
    /// (le saut d'un couloir à l'autre, hors de l'écran), l'image tient puis saute.
    static func swim(_ steps: [Step], seconds: Double) -> Animation {
        var frames: [Animation.Keyframe] = []
        for i in 0...steps.count {
            let at = place(steps, i), next = place(steps, i + 1)
            let jumps = i < steps.count && abs(next.x - at.x) + abs(next.y - at.y) > 2 * cell
            let percent = i == steps.count ? 100 : (Double(i) * 100 / Double(steps.count) * 1000).rounded() / 1000
            frames.append(.init(percent / 100, [.transform: .t(.translate(at.x, at.y))], timing: jumps ? .steps(1) : nil))
        }
        return Animation(frames, duration: seconds, timing: .linear)
    }

    static func sliceTiles(_ tiles: [Tile], _ index: Int) -> [Node] {
        var order: [String] = []
        var byShade: [String: PathData] = [:]
        var shadeKind: [String: (Character, Int)] = [:]
        for tile in tiles {
            let shadeIndex = Int((hash(index, tile.across + 9, 61) * 3).rounded(.down))
            let shade = "\(tile.kind)\(shadeIndex)"
            if byShade[shade] == nil {
                order.append(shade)
                shadeKind[shade] = (tile.kind, shadeIndex)
            }
            byShade[shade, default: PathData()] = byShade[shade, default: PathData()] + .rect(Double(tile.across) * cell - 9, -9, 18, 18)
        }
        var out: [Node] = order.map { shade in
            let (kind, i) = shadeKind[shade]!
            let node = Node.path(byShade[shade]!).fill(Paint(koiFills[kind]![i]))
            return koiOpacity[kind].map { node.opacity($0) } ?? node
        }
        for (kinds, fill, opacity) in [("OCK", "#fff1dc", 0.5), ("WT", "#b7c3bd", 0.8)] {
            let marked = tiles.filter { kinds.contains($0.kind) }
            if marked.isEmpty { continue }
            let glyphs = marked.map { Array("S%t:$;tS")[Int((hash(index, $0.across + 9, 62) * 8).rounded(.down))] }
            out.append(Node.glyphs(glyphs, xs: marked.map { Double($0.across) * cell }, ys: Array(repeating: 4.5, count: marked.count))
                .fill(Paint(fill)).opacity(opacity))
        }
        return out
    }

    static func sliceShadow(_ tiles: [Tile]) -> Node {
        let list = tiles.map(\.across).sorted()
        var path = PathData()
        var from = list[0]
        for i in 1...list.count {
            let previous = list[i - 1]
            if i < list.count, list[i] == previous + 1 { continue }
            path = path + .rect(Double(from) * cell - 10, -10, Double(previous - from + 1) * cell, 20)
            if i < list.count { from = list[i] }
        }
        return .path(path)
    }

    static func paintSlice(_ tiles: [Tile], _ index: Int, shadow: Bool) -> [Node] {
        if tiles.isEmpty { return [] }
        return shadow ? [sliceShadow(tiles)] : sliceTiles(tiles, index)
    }

    /// Un koï est un train de tranches qui suivent toutes la tête, chacune un pas
    /// plus tard : le corps se plie le long du chemin.
    static func koi(_ map: String, steps: [Step], seconds: Double, start: Int, shadow: Bool) -> [Node] {
        let body = slices(map), up = slices(tailUp), down = slices(tailDown)
        let stepSeconds = seconds / Double(steps.count)
        let swimming = swim(steps, seconds: seconds)
        let flipA = Animation([
            .init(0, [.opacity: .n(1)]), .init(0.375, [.opacity: .n(1)]), .init(0.5, [.opacity: .n(0)]),
            .init(0.875, [.opacity: .n(0)]), .init(1, [.opacity: .n(1)]),
        ], duration: 3.2, timing: .linear)
        let flipB = Animation([
            .init(0, [.opacity: .n(0)]), .init(0.375, [.opacity: .n(0)]), .init(0.5, [.opacity: .n(1)]),
            .init(0.875, [.opacity: .n(1)]), .init(1, [.opacity: .n(0)]),
        ], duration: 3.2, timing: .linear)
        var out: [Node] = []
        for k in stride(from: body.count - 1, through: 0, by: -1) {
            let at = place(steps, start - k)
            var inner = paintSlice(body[k], k, shadow: shadow)
            if !up[k].isEmpty || !down[k].isEmpty {
                inner.append(Node.group(paintSlice(up[k], k, shadow: shadow)).animate(flipA))
                inner.append(Node.group(paintSlice(down[k], k, shadow: shadow)).animate(flipB))
            }
            let delay = (Double(start - k) * stepSeconds * 100).rounded() / 100
            out.append(Node.group(inner).translate(at.x, at.y).animate(swimming.delayed(-delay)))
        }
        return out
    }

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
            for c in list { path = path + .rect(Double(c.x) * cell + 1, Double(c.y) * cell + 1, 18, 18) }
            out.append(Node.path(path).fill(Paint(paint.tile)).stroke("#fff", opacity: 0.22))
            var rowOrder: [Int] = []
            var rows: [Int: [Cell]] = [:]
            for c in list {
                if rows[c.y] == nil { rowOrder.append(c.y) }
                rows[c.y, default: []].append(c)
            }
            for y in rowOrder {
                let row = rows[y]!
                let text = row.map { paint.glyphs[Int((hash($0.x, $0.y, 5) * Double(paint.glyphs.count)).rounded(.down))] }
                out.append(Node.glyphs(text, xs: row.map { Double($0.x) * cell + 10 }, ys: Array(repeating: Double(y) * cell + 14.5, count: row.count))
                    .fill(Paint(paint.glyph)).opacity(paint.glyphOpacity))
            }
        }
        return out
    }

    /// De l'eau plus sombre autour d'une chose : son empreinte élargie et décalée.
    static func halo(_ cells: [Cell], reach: Int, shift: (Int, Int), opacity: Double) -> Node {
        var seen = CellSet()
        for c in cells {
            for dx in -reach...reach {
                for dy in -reach...reach where abs(dx) + abs(dy) <= reach + (reach > 1 ? 1 : 0) {
                    seen.add(c.x + dx + shift.0, c.y + dy + shift.1)
                }
            }
        }
        return Node.path(blocks(seen.keys, cell)).fill("#0d5a66").opacity(opacity)
    }

    static func lilyPad(_ cx: Int, _ cy: Int, _ radius: Double, _ notchDegrees: Double, _ bloom: (Int, Int)?) -> [Cell] {
        var cells: [Cell] = []
        let notch = notchDegrees * .pi / 180
        let reach = Int(radius.rounded(.up))
        for dy in -reach...reach {
            for dx in -reach...reach {
                let distance = hypot(Double(dx), Double(dy))
                if distance > radius { continue }
                var off = atan2(Double(dy), Double(dx)) - notch
                while off > .pi { off -= 2 * .pi }
                while off < -.pi { off += 2 * .pi }
                if distance > 0.6 && abs(off) < 0.24 + 0.28 / max(distance, 1) { continue }
                var kind: Character = "a"
                if distance > radius - 0.85 { kind = "c" } else if radius > 3 && abs(distance - radius * 0.5) < 0.5 { kind = "b" }
                cells.append(Cell(x: cx + dx, y: cy + dy, kind: kind))
            }
        }
        if let bloom {
            for i in cells.indices {
                let dx = cells[i].x - (cx + bloom.0), dy = cells[i].y - (cy + bloom.1)
                if dx == 0 && dy == 0 { cells[i].kind = "q" } else if abs(dx) <= 1 && abs(dy) <= 1 { cells[i].kind = "p" }
            }
        }
        return cells
    }

    /// Le bord de pierres dans le coin en bas à droite : un quart d'anneau de
    /// galets, un ton par galet, un peu de mousse.
    func stoneBank() -> [Cell] {
        let (cx, cy) = layout.bank
        var seeds: [(Double, Double, Character)] = []
        for n in 0..<40 {
            seeds.append((Double(cx - 18) + Self.hash(n, 1, 31) * 20, Double(cy - 16) + Self.hash(n, 2, 32) * 18, Array("su")[Int((Self.hash(n, 3, 33) * 2).rounded(.down))]))
        }
        var cells: [Cell] = []
        for y in (cy - 20)..<layout.rows {
            for x in (cx - 20)..<layout.columns {
                let floorX = Int((Double(x) / 2).rounded(.down)), floorY = Int((Double(y) / 2).rounded(.down))
                let fromCorner = hypot((Double(x) + 0.5 - Double(cx)) / 1.3, Double(y) + 0.5 - Double(cy)) + (Self.hash(floorX, floorY, 34) - 0.5) * 0.9
                if fromCorner < 4.4 || fromCorner > 6.9 { continue }
                var tone: Character = "s"
                var best = Double.infinity
                for seed in seeds {
                    let d = hypot(seed.0 - Double(x), seed.1 - Double(y))
                    if d < best {
                        best = d
                        tone = seed.2
                    }
                }
                cells.append(Cell(x: x, y: y, kind: Self.hash(x, y, 35) < 0.06 ? "c" : tone))
            }
        }
        return cells
    }

    /// De l'eau profonde en terrasses autour d'un coin ; le bord de chaque
    /// terrasse est un damier d'une case.
    func stairZone(_ cx: Double, _ cy: Double, _ radius: Double, _ squash: Double, _ opacity: Double, _ fill: String) -> Node {
        var seen = CellSet()
        for y in 0..<layout.rows {
            for x in 0..<layout.columns {
                let distance = hypot(Double(x) + 0.5 - cx, (Double(y) + 0.5 - cy) * squash)
                let coarse = sin(Double(x) * 0.45 + cy) * 1.2 + sin(Double(y) * 0.6 + cx) * 1.2
                let dither = (x + y) % 2 == 0 ? 1.1 : -1.1
                if distance < radius + coarse + dither { seen.add(x, y) }
            }
        }
        return Node.path(Self.blocks(seen.keys, Self.cell)).fill(Paint(fill)).opacity(opacity)
    }

    static func ringOutline(_ cx: Int, _ cy: Int, _ radius: Double) -> PathData {
        var seen = CellSet()
        let reach = Int(radius.rounded(.up)) + 1
        for dy in -reach...reach {
            for dx in -reach...reach where abs(hypot(Double(dx), Double(dy)) - radius) < 0.62 {
                seen.add(cx + dx, cy + dy)
            }
        }
        return blocks(seen.keys, cell)
    }

    /// Quatre anneaux qui se montrent l'un après l'autre, puis plus rien
    /// jusqu'à la fin de la période.
    static func ripple(_ cx: Int, _ cy: Int, seconds: Double, delay: Double, fraction: Double) -> [Node] {
        [1.8, 3.6, 5.3, 7].enumerated().map { i, radius in
            var frames = ringTracks[i].map { percent, opacity in
                Animation.Keyframe((percent * fraction * 100).rounded() / 100 / 100, [.opacity: .n(opacity)])
            }
            frames.append(.init(1, [.opacity: .n(0)]))
            let ring = Animation(frames, duration: seconds, delay: -(delay * 100).rounded() / 100, timing: .linear)
            return Node.path(ringOutline(cx, cy, radius)).fill("#f2fffb").opacity(0).animate(ring)
        }
    }

    static func wake(_ steps: [Step], seconds: Double, wakeStep: Int, start: Int, shift: Int) -> [Node] {
        let stepSeconds = seconds / Double(steps.count)
        let delay = Double((((start - wakeStep) % steps.count) + steps.count) % steps.count) * stepSeconds
        let at = steps[wakeStep]
        return ripple(at.x + shift, at.y, seconds: seconds, delay: delay, fraction: 50 / seconds)
    }

    static func floatingPad(_ cells: [Cell], _ rock: Animation, seconds: Double, delay: Double) -> Node {
        Node.group([halo(cells, reach: 0, shift: (1, 1), opacity: 0.3)] + mosaic(cells)).animate(rock.lasting(seconds).delayed(-delay))
    }

    static func build(width: Double, height: Double) -> Scene {
        KoiMosaic(width: width, height: height, layout: .portrait(width, height)).scene()
    }

    static func original() -> Scene {
        KoiMosaic(width: 1600, height: 1000, layout: .original).scene()
    }

    func scene() -> Scene {
        var scene = Scene(width: width, height: height)
        // Le bassin est plus grand que l'écran : un koï descend un côté, sort par
        // le bas, et remonte par l'autre côté.
        let steps = Self.walk(layout.rightLane) + Self.walk(layout.leftLane)
        let seconds = JS.round(Double(steps.count) * 2.2)
        let kohakuStart = 34
        let tanchoStart = 34 + Int((Double(steps.count) * 49 / 124).rounded())

        scene.linear("water", x1: 0, y1: 0, x2: layout.water.0, y2: layout.water.1, [(0, "#6fc3bb", 1), (0.2, "#90d5ca", 1), (0.52, "#93d6cb", 1), (0.74, "#4fb1b1", 1), (1, "#17697d", 1)])
        scene.radial("deep", [(0, "#17838c", 0.5), (1, "#17838c", 0)])
        scene.define("grid", .pattern(Pattern(width: 20, height: 20, nodes: [Node.path("M0 0.5h20M0.5 0v20").fill(.none).stroke("#f1fbf5", opacity: 0.16)])))
        scene.linear("sides", x1: 0, y1: 0, x2: layout.gridFade.0, y2: layout.gridFade.1, [(0, "#fff", 1), (0.24, "#fff", 0.18), (0.76, "#fff", 0.18), (0.97, "#fff", 1)])
        scene.define("outward", .mask(Mask(region: Rect(0, 0, width, height), nodes: [.rect(0, 0, width, height).fill("url(#sides)")])))

        let swell = Animation.between([.transform: .t(.translate(-50, -16))], [.transform: .t(.translate(60, 22))], duration: 67, direction: .alternateReverse, timing: .easeInOut)
        let rockX = Animation([
            .init(0, [.transform: .t(.translate(0, 0))]), .init(0.3, [.transform: .t(.translate(20, 0))]), .init(0.55, [.transform: .t(.translate(20, 20))]),
            .init(0.8, [.transform: .t(.translate(0, 20))]), .init(1, [.transform: .t(.translate(0, 0))]),
        ], duration: 37, timing: .easeInOut)
        let rockY = Animation([
            .init(0, [.transform: .t(.translate(0, 0))]), .init(0.35, [.transform: .t(.translate(0, 20))]), .init(0.6, [.transform: .t(.translate(-20, 20))]),
            .init(0.85, [.transform: .t(.translate(-20, 0))]), .init(1, [.transform: .t(.translate(0, 0))]),
        ], duration: 41, timing: .easeInOut)

        scene.add(.rect(0, 0, width, height).fill("url(#water)"))
        scene.add(Node.group(layout.swell.map { e in
            let node = Node.ellipse(e.0, e.1, e.2, e.3).fill("url(#deep)")
            return e.4 < 1 ? node.opacity(e.4) : node
        }).animate(swell))
        for zone in layout.stairs {
            for radius in zone.radii { scene.add(stairZone(zone.x, zone.y, radius, zone.squash, zone.opacity, zone.fill)) }
        }
        scene.add(Node.rect(0, 0, width, height).fill("url(#grid)").mask("outward"))
        for (share, shift) in layout.wakes {
            let step = Int((share * Double(steps.count)).rounded())
            scene.add(Self.wake(steps, seconds: seconds, wakeStep: step, start: kohakuStart, shift: shift))
            scene.add(Self.wake(steps, seconds: seconds, wakeStep: step, start: tanchoStart, shift: shift))
        }
        for (x, y, period, delay) in layout.ripples { scene.add(Self.ripple(x, y, seconds: period, delay: delay, fraction: 1)) }
        func fish(shadow: Bool) -> [Node] {
            Self.koi(Self.kohaku, steps: steps, seconds: seconds, start: kohakuStart, shadow: shadow)
                + Self.koi(Self.tancho, steps: steps, seconds: seconds, start: tanchoStart, shadow: shadow)
        }
        scene.add(Node.group(fish(shadow: true)).translate(40, 40).fill("#0d5a66").opacity(0.07))
        scene.add(Node.group(fish(shadow: true)).translate(20, 20).fill("#0d5a66").opacity(0.16))
        scene.add(Node.group(fish(shadow: false)).stroke("#0d5a66", opacity: 0.3))
        let stones = stoneBank()
        scene.add(Self.halo(stones, reach: 1, shift: (0, 0), opacity: 0.22))
        scene.add(Self.mosaic(stones))
        let rocks: [(Animation, Double, Double)] = [(rockX, 37, 5), (rockY, 53, 21), (rockY, 47, 30)]
        for (pad, rock) in zip(layout.pads, rocks) {
            scene.add(Self.floatingPad(Self.lilyPad(pad.x, pad.y, pad.radius, pad.notch, pad.bloom), rock.0, seconds: rock.1, delay: rock.2))
        }
        return scene.withFont(size: 12, weight: 700)
    }
}

extension Scene {
    /// Tous les glyphes du décor dans une police, comme une règle `text{}` de CSS.
    func withFont(size: Double, weight: Int) -> Scene {
        var copy = self
        copy.nodes = [Node.group(nodes).font(size: size, weight: weight)]
        return copy
    }
}
