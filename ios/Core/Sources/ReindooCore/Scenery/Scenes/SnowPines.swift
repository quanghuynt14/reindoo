import Foundation

// Snow Pines : une forêt en ASCII sous la neige, au crépuscule. Chaque sapin est
// une pile de cellules, un fond coloré et un glyphe (`^ / \ | :`), comme un
// terminal à couleurs de fond. Trois profondeurs, chacune sa grille.
// D'après theme-examples (Anthropic, Apache 2.0), scenes/snow-pines.ts.

struct SnowPines {
    let width: Double
    let height: Double
    let layout: Layout

    /// Où sont les choses. `original` refait le décor de theme-examples à
    /// l'identique ; `portrait` le recompose pour un téléphone tenu droit.
    struct Layout {
        var crests: [Double]
        var crestEdges: [Double]
        var farWoods: [Wood]
        var middlePines: [(Int, Int)]
        var nearPines: [(Int, Int)]
        var nearBase: Int
        var cabinColumn: Int
        var hillFeather: (Double, Double)
        var dotFeather: (Double, Double)
        var middleNone: Double
        var brightNone: Double
        var faintDensity: Double
        var snowRows: [Int]
        var rose: (Double, Double, Double, Double)
        var dusk: (Double, Double)
        var hush: (Double, Double, Double, Double)

        static let original = Layout(
            crests: [716, 790, 880], crestEdges: [52, 30, 20],
            farWoods: [
                Wood(from: -2, to: 52, tallest: 11, chance: 0.4), Wood(from: 58, to: 74, tallest: 5, chance: 0.34),
                Wood(from: 131, to: 141, tallest: 6, chance: 0.4), Wood(from: 147, to: 180, tallest: 8, chance: 0.4),
            ],
            middlePines: [(3, 13), (12, 16), (20, 11), (121, 14), (113, 10), (98, 13)],
            nearPines: [(1, 25), (9, 19), (-4, 15), (87, 21), (82, 14)], nearBase: 47, cabinColumn: 103,
            hillFeather: (300, 520), dotFeather: (240, 470), middleNone: 600, brightNone: 470, faintDensity: 0.011,
            snowRows: [52, 52, 40], rose: (1040, 760, 760, 240), dusk: (-420, 300), hush: (1370, 150, 260, 170)
        )

        /// Le texte prend toute la largeur : la forêt et le champ descendent
        /// sous les boutons, les arbres proches se serrent aux deux bords.
        static func portrait(_ w: Double, _ h: Double) -> Layout {
            let far = Int(w / SnowPines.far.grid.cellWidth)
            let middle = Int(w / SnowPines.middle.grid.cellWidth)
            let near = Int(w / SnowPines.near.grid.cellWidth)
            func f(_ share: Double, _ columns: Int) -> Int { Int((share * Double(columns)).rounded()) }
            return Layout(
                crests: [h * 0.665, h * 0.725, h * 0.8], crestEdges: [40, 24, 16],
                farWoods: [
                    Wood(from: -2, to: f(0.32, far), tallest: 9, chance: 0.45),
                    Wood(from: f(0.42, far), to: f(0.5, far), tallest: 4, chance: 0.34),
                    Wood(from: f(0.62, far), to: far + 2, tallest: 7, chance: 0.42),
                ],
                middlePines: [(1, 12), (7, 14), (13, 9), (middle - 2, 13), (middle - 7, 10)],
                nearPines: [(1, 17), (6, 12), (-3, 11), (near - 1, 15), (near - 5, 10)],
                nearBase: Int((h / SnowPines.near.grid.cellHeight).rounded(.up)) + 1,
                cabinColumn: f(0.6, middle),
                hillFeather: (w * 0.12, w * 0.34), dotFeather: (w * 0.1, w * 0.28),
                middleNone: w * 0.3, brightNone: w * 0.22, faintDensity: 0.016,
                snowRows: [Int((h / 20).rounded(.up)) + 2, Int((h / 20).rounded(.up)) + 2, Int((h / 26).rounded(.up)) + 2],
                rose: (w * 0.6, h * 0.68, w * 0.95, 170), dusk: (-w * 0.3, w * 0.2), hush: (w * 0.5, -20, w * 0.7, 150)
            )
        }
    }

    enum Tone: Hashable { case shadow, mid, lit, rim, cap }

    struct Mark {
        var x: Int
        var y: Int
        var glyph: Character
    }

    struct Cell {
        var x: Int
        var y: Int
        var glyph: Character
        var tone: Tone
    }

    struct Grid {
        var cellWidth: Double
        var cellHeight: Double
        var fontSize: Double
        var weight: Int
    }

    struct Depth {
        var grid: Grid
        var rimChance: Double
        var tile: [Tone: String]
        var glyph: [Tone: String]
    }

    static let far = Depth(
        grid: Grid(cellWidth: 9, cellHeight: 11, fontSize: 10, weight: 700), rimChance: 0.5,
        tile: [.shadow: "#33336a", .mid: "#3e4079", .lit: "#4c5090", .rim: "#6c70a6", .cap: "#8a8ebe"],
        glyph: [.shadow: "#565a96", .mid: "#6a70a8", .lit: "#8e94c8", .rim: "#bcc1e6", .cap: "#d6daf4"]
    )
    static let middle = Depth(
        grid: Grid(cellWidth: 13, cellHeight: 16, fontSize: 15, weight: 700), rimChance: 0.65,
        tile: [.shadow: "#142d44", .mid: "#1b4358", .lit: "#275e68", .rim: "#5a7396", .cap: "#869fbe"],
        glyph: [.shadow: "#44708a", .mid: "#5a98a6", .lit: "#78b6b0", .rim: "#ccd6f2", .cap: "#e8eeff"]
    )
    static let near = Depth(
        grid: Grid(cellWidth: 18, cellHeight: 22, fontSize: 21, weight: 700), rimChance: 0.75,
        tile: [.shadow: "#0c2832", .mid: "#134048", .lit: "#1a5456", .rim: "#5a7396", .cap: "#869fbe"],
        glyph: [.shadow: "#3a7480", .mid: "#4f9a96", .lit: "#6cb4a6", .rim: "#d0d9f2", .cap: "#eef2ff"]
    )

    /// Un hachage vers 0..1, le même à chaque fois : rien n'est tiré au sort.
    static func hash(_ a: Double, _ b: Double, _ c: Double) -> Double {
        var value = Double(JS.int32(a * 374_761_393 + b * 668_265_263 + c * 2_147_483_647))
        value = JS.xor(value, JS.ushr(value, 13)) * 1_274_126_177
        value = JS.xor(value, JS.ushr(value, 16))
        return Double(JS.uint32(value) % 100_000) / 100_000
    }

    static func hash(_ a: Int, _ b: Int, _ c: Int) -> Double { hash(Double(a), Double(b), Double(c)) }

    /// La demi-largeur d'un sapin à une rangée sous sa pointe : les branches
    /// s'évasent dans un étage et rentrent au suivant.
    static func halfWidth(_ row: Int, _ tierLength: Int) -> Int {
        if row == 0 { return 0 }
        let within = (row - 1) % tierLength
        return max(1, Int(JS.round(Double(row) * 0.25 + Double(within) * 0.55)))
    }

    /// Un sapin, cellule par cellule. La lumière vient de l'horizon, au milieu :
    /// les bouts de branches tournés vers lui sont éclairés, une cellule sans
    /// rien au-dessus porte de la neige.
    func pine(_ cells: inout [Int: Cell], _ order: inout [Int], apex: Int, base: Int, height rows: Int, tier: Int, seed: Int, depth: Depth) {
        let boughRows = rows - (rows > 12 ? 2 : 1)
        let towardLight = (Double(apex) + 0.5) * depth.grid.cellWidth < width / 2 ? 1 : -1
        for row in 0..<rows {
            let y = base - rows + 1 + row
            let isTrunk = row >= boughRows
            let half = isTrunk ? 0 : Self.halfWidth(row, tier)
            let halfAbove = row == 0 ? -1 : Self.halfWidth(row - 1, tier)
            for offset in -half...half {
                let x = apex + offset
                let chance = Self.hash(x, y, seed)
                let isExposed = !isTrunk && abs(offset) > halfAbove
                let facing = offset * towardLight
                let slash: Character = (offset < 0 || (offset == 0 && row % 2 == 0)) ? "/" : "\\"
                var glyph: Character = row == 0 ? "^" : isTrunk ? "|" : slash
                if !isExposed && offset != 0 && abs(offset) < half && Self.hash(x, y, seed + 2) < 0.1 { glyph = ":" }
                let within = (row - 1) % tier
                var tone: Tone = .mid
                if within == 0 && row > 1 { tone = .shadow }
                if half >= 2 && facing <= -half + (half > 4 ? 1 : 0) { tone = .shadow }
                if facing > 0 && facing >= half - 1 && within > 0 { tone = .lit }
                if tone == .shadow && Self.hash(x, y, seed + 1) < 0.15 { tone = .mid }
                if isTrunk { tone = .shadow }
                if isExposed && chance < depth.rimChance { tone = chance < 0.08 || row == 0 ? .cap : .rim }
                let key = x * 100_000 + y
                if cells[key] == nil { order.append(key) }
                cells[key] = Cell(x: x, y: y, glyph: glyph, tone: tone)
            }
        }
    }

    /// Un seul nœud de texte pour toute une liste de glyphes, chacun sur sa
    /// cellule quelle que soit la police.
    static func glyphRows(_ list: [Mark], _ grid: Grid, _ colour: String, _ opacity: Double) -> Node? {
        guard !list.isEmpty else { return nil }
        let sorted = list.sorted { $0.y != $1.y ? $0.y < $1.y : $0.x < $1.x }
        let node = Node.glyphs(
            sorted.map(\.glyph),
            xs: sorted.map { Double($0.x) * grid.cellWidth + grid.cellWidth / 2 },
            ys: sorted.map { Double($0.y) * grid.cellHeight + JS.round(grid.cellHeight * 0.8) }
        ).fill(Paint(colour)).font(size: grid.fontSize, weight: grid.weight)
        return opacity < 1 ? node.fillOpacity(opacity) : node
    }

    /// Le fond derrière des cellules : un rectangle par suite de voisines sur une
    /// rangée, sans jour entre elles, donc sans quadrillage.
    static func tiles(_ list: [Mark], _ grid: Grid, _ colour: String, _ opacity: Double) -> Node {
        var rows: [Int: [Int]] = [:]
        var order: [Int] = []
        for cell in list {
            if rows[cell.y] == nil { order.append(cell.y) }
            rows[cell.y, default: []].append(cell.x)
        }
        var path = PathData()
        for y in order {
            let columns = rows[y, default: []].sorted()
            guard var start = columns.first else { continue }
            var previous = start
            for index in 1...columns.count {
                if index < columns.count, columns[index] == previous + 1 {
                    previous = columns[index]
                    continue
                }
                let w = Double(previous - start + 1) * grid.cellWidth
                path = path + PathData.rect(Double(start) * grid.cellWidth, Double(y) * grid.cellHeight, w, grid.cellHeight)
                guard index < columns.count else { break }
                start = columns[index]
                previous = start
            }
        }
        let node = Node.path(path).fill(Paint(colour))
        return opacity < 1 ? node.fillOpacity(opacity) : node
    }

    static func marks(_ cells: [Cell]) -> [Mark] { cells.map { Mark(x: $0.x, y: $0.y, glyph: $0.glyph) } }

    /// Des sapins d'une profondeur : l'ombre sous tout, puis le milieu et la
    /// lumière, un glyphe par cellule, puis la neige, qui arrive en quatre vagues.
    func forest(_ stands: [(Int, Int, Int)], _ depth: Depth, tier: Int, seed: Int) -> [Node] {
        var cells: [Int: Cell] = [:]
        var order: [Int] = []
        for (column, base, rows) in stands {
            pine(&cells, &order, apex: column, base: base, height: rows, tier: tier, seed: seed, depth: depth)
        }
        let all = order.compactMap { cells[$0] }
        let rims = all.filter { $0.tone == .rim }
        let caps = all.filter { $0.tone == .cap }
        let grid = depth.grid
        func wave(_ cell: Cell) -> Int { Int((Self.hash(cell.x, cell.y, seed + 5) * 4).rounded(.down)) }
        let settle = Animation([
            .init(0, [.fillOpacity: .n(0.1)]), .init(0.12, [.fillOpacity: .n(0.4)]), .init(0.56, [.fillOpacity: .n(1)]),
            .init(0.86, [.fillOpacity: .n(1)]), .init(1, [.fillOpacity: .n(0.1)]),
        ], duration: 160, timing: .linear)
        var frost: [Node] = []
        for which in 0..<4 {
            let rim = Self.marks(rims.filter { wave($0) == which })
            let cap = Self.marks(caps.filter { wave($0) == which })
            let children = [
                Self.tiles(rim, grid, depth.tile[.rim]!, 1), Self.tiles(cap, grid, depth.tile[.cap]!, 1),
                Self.glyphRows(rim, grid, depth.glyph[.rim]!, 1), Self.glyphRows(cap, grid, depth.glyph[.cap]!, 1),
            ].compactMap { $0 }
            frost.append(.group(children).animate(settle.delayed(-Double(which) * 14)))
        }
        // Le fond de chaque cellule est peint une fois, dans sa valeur : les fonds
        // peuvent être pâles sans opacité de groupe.
        let shaded = Self.marks(all.filter { $0.tone == .shadow } + rims + caps)
        var nodes = [
            Self.tiles(shaded, grid, depth.tile[.shadow]!, 0.78),
            Self.tiles(Self.marks(all.filter { $0.tone == .mid }), grid, depth.tile[.mid]!, 0.78),
            Self.tiles(Self.marks(all.filter { $0.tone == .lit }), grid, depth.tile[.lit]!, 0.78),
        ]
        for tone in [Tone.shadow, .mid, .lit] {
            if let node = Self.glyphRows(Self.marks(all.filter { $0.tone == tone }), grid, depth.glyph[tone]!, 1) { nodes.append(node) }
        }
        // Sous le givre, une cellule enneigée est une aiguille comme une autre :
        // une branche n'a jamais de trou pendant que sa neige est partie.
        if let node = Self.glyphRows(Self.marks(rims + caps), grid, depth.glyph[.mid]!, 1) { nodes.append(node) }
        return nodes + frost
    }

    // MARK: Le sol

    /// À quelle distance du milieu : 0 au centre, 1 sur les bords.
    func edgeness(_ x: Double) -> Double {
        let fromCentre = abs(x - width * 0.51) / (width * 0.5)
        return min(1, max(0, (fromCentre - 0.4) / 0.5))
    }

    /// 1 tout à gauche et tout à droite, 0 au bord de la colonne du texte.
    func feather(_ x: Double, _ full: Double, _ none: Double) -> Double {
        let left = (none - x) / (none - full)
        let right = (x - (width - none + 30)) / (none - full)
        return min(1, max(0, left, right))
    }

    func lean(_ x: Double) -> Double { (x - width / 2) * 0.03 }
    func backCrest(_ x: Double) -> Double { layout.crests[0] - edgeness(x) * layout.crestEdges[0] + sin(x * 0.0061 + 0.4) * 9 + lean(x) }
    func middleCrest(_ x: Double) -> Double { layout.crests[1] - edgeness(x) * layout.crestEdges[1] + sin(x * 0.0043 + 2.2) * 13 + lean(x) }
    func frontCrest(_ x: Double) -> Double { layout.crests[2] - edgeness(x) * layout.crestEdges[2] + sin(x * 0.0035 + 4.6) * 12 + lean(x) }

    struct Wood {
        var from: Int
        var to: Int
        var tallest: Int
        var chance: Double
    }

    func farForest() -> [Node] {
        var stands: [(Int, Int, Int)] = []
        let grid = Self.far.grid
        for wood in layout.farWoods {
            for column in wood.from...wood.to {
                if Self.hash(column, 3, 11) > wood.chance { continue }
                let x = Double(column) * grid.cellWidth
                let middle = Double(wood.from + wood.to) / 2
                let taper = 1 - abs(Double(column) - middle) / (Double(wood.to - wood.from) / 2 + 1) * 0.5
                let rows = 3 + Int((Self.hash(column, 5, 11) * Double(wood.tallest - 3) * taper).rounded(.down))
                let base = Int(JS.round(backCrest(x) / grid.cellHeight)) + Int((Self.hash(column, 7, 11) * 2).rounded(.down))
                stands.append((column, base, rows))
            }
        }
        return forest(stands, Self.far, tier: 3, seed: 17)
    }

    func middleForest() -> [Node] {
        let grid = Self.middle.grid
        let stands = layout.middlePines.enumerated().map { index, pine -> (Int, Int, Int) in
            let x = Double(pine.0) * grid.cellWidth
            return (pine.0, Int(JS.round((middleCrest(x) + 34) / grid.cellHeight)) + Int((Self.hash(index, 2, 23) * 2).rounded(.down)), pine.1)
        }
        return forest(stands, Self.middle, tier: 3, seed: 29)
    }

    func nearForest() -> [Node] {
        let stands = layout.nearPines.enumerated().map { index, pine in
            (pine.0, layout.nearBase + Int((Self.hash(index, 9, 31) * 2).rounded(.down)), pine.1)
        }
        return forest(stands, Self.near, tier: 4, seed: 37)
    }

    static let crestGlyphs = Array("_-_~_-")
    static let driftGlyphs = Array("..-,_'")

    /// La neige du champ est faite de caractères : serrés sur la crête, plus
    /// rares dessous, presque absents sous la colonne du texte.
    func hillMarks(_ crest: (Double) -> Double, _ colour: String, _ opacity: Double, rowsDeep: Int, seed: Int) -> Node? {
        var marks: [Mark] = []
        let grid = Self.far.grid
        let columns = Int((width / grid.cellWidth).rounded(.up))
        for column in 0..<columns {
            let x = (Double(column) + 0.5) * grid.cellWidth
            let crestRow = Int((crest(x) / grid.cellHeight).rounded(.up))
            let outside = feather(x, layout.hillFeather.0, layout.hillFeather.1)
            let thin = 0.12 + 0.6 * outside
            for below in 0..<rowsDeep {
                let pick = Self.hash(column, below, seed)
                let limit = (below == 0 ? 0.8 : 0.5 - Double(below) * (0.4 / Double(rowsDeep))) * thin
                if pick > limit || (below > 0 && outside == 0) { continue }
                let which = Int((Self.hash(column, below, seed + 1) * 6).rounded(.down))
                let glyph = below == 0 ? Self.crestGlyphs[which] : Self.driftGlyphs[which]
                marks.append(Mark(x: column, y: crestRow + below, glyph: glyph))
            }
        }
        return Self.glyphRows(marks, grid, colour, opacity)
    }

    func hillBody(_ crest: (Double) -> Double, _ fill: String, _ opacity: Double) -> Node {
        func tenth(_ v: Double) -> Double { (v * 10).rounded() / 10 }
        var commands: [PathData.Command] = [.move(0, height), .line(0, tenth(crest(0)))]
        var x = 20.0, last = 0.0
        while x <= width {
            commands.append(.line(x, tenth(crest(x))))
            last = x
            x += 20
        }
        commands += [.line(last, height), .close]
        let node = Node.path(PathData(commands)).fill(Paint(fill))
        return opacity < 1 ? node.fillOpacity(opacity) : node
    }

    func snowField() -> [Node] {
        [
            hillBody(backCrest, "url(#field)", 1), hillBody(middleCrest, "#433f76", 0.5), hillBody(frontCrest, "#3b386e", 0.5),
            hillMarks(backCrest, "#c6caee", 0.4, rowsDeep: 3, seed: 41),
            hillMarks(middleCrest, "#a9aedc", 0.36, rowsDeep: 4, seed: 43),
            hillMarks(frontCrest, "#8388c0", 0.36, rowsDeep: 5, seed: 47),
        ].compactMap { $0 }
    }

    // MARK: La neige qui tombe

    struct SnowLayer {
        var id: String
        var seed: Int
        var cellWidth: Double
        var cellHeight: Double
        var rows: Int
        var seconds: [Double]
        var swaySeconds: Double
        var density: Double
        var everywhere: Bool
        var full: Double
        var none: Double
        var glyphs: [Character]
        var fontSize: Double
        var colour: String
        var opacity: Double
    }

    static let faint = SnowLayer(id: "a", seed: 51, cellWidth: 14, cellHeight: 20, rows: 52, seconds: [61], swaySeconds: 19, density: 0.011, everywhere: true, full: 0, none: 0, glyphs: Array("*.*'.+"), fontSize: 17, colour: "#b4bcec", opacity: 0.34)
    static let middleSnow = SnowLayer(id: "b", seed: 61, cellWidth: 16, cellHeight: 20, rows: 52, seconds: [43, 53], swaySeconds: 14.5, density: 0.06, everywhere: false, full: 0, none: 600, glyphs: Array(".*.*.+'*"), fontSize: 17, colour: "#c3cbf2", opacity: 0.5)
    static let bright = SnowLayer(id: "c", seed: 71, cellWidth: 22, cellHeight: 26, rows: 40, seconds: [31, 38], swaySeconds: 11.5, density: 0.06, everywhere: false, full: 0, none: 470, glyphs: Array("*.*+"), fontSize: 22, colour: "#d3daf8", opacity: 0.55)

    /// Une couche de neige. Chaque bande de colonnes tombe à sa vitesse ; ses
    /// flocons sont là deux fois, à un écran d'écart, pour boucler sans couture.
    func snowLayer(_ layer: SnowLayer) -> [Node] {
        let columns = Int((width / layer.cellWidth).rounded(.up)) + 3
        let fall = Double(layer.rows) * layer.cellHeight
        var bands = Array(repeating: [(Double, Double, Character)](), count: layer.seconds.count)
        for row in 0..<layer.rows {
            for column in -2..<columns {
                let x = Double(column) * layer.cellWidth
                let density = layer.everywhere ? layer.density : layer.density * feather(x, layer.full, layer.none)
                if Self.hash(column, row, layer.seed) >= density { continue }
                let dotOnly = Self.hash(column, row, layer.seed + 3) >= feather(x, layout.dotFeather.0, layout.dotFeather.1)
                let glyph: Character = dotOnly ? "." : layer.glyphs[Int((Self.hash(column, row, layer.seed + 1) * Double(layer.glyphs.count)).rounded(.down))]
                let which = layer.everywhere
                    ? Int((Self.hash(column, 0, layer.seed + 2) * Double(layer.seconds.count)).rounded(.down))
                    : x < width / 2 ? 0 : 1
                let baseline = Double(row) * layer.cellHeight + JS.round(layer.cellHeight * 0.8)
                let cx = x + layer.cellWidth / 2
                bands[which].append((cx, baseline - fall, glyph))
                bands[which].append((cx, baseline, glyph))
            }
        }
        return bands.enumerated().map { which, flakes in
            let seconds = layer.seconds[which]
            let fallDelay = (seconds * (0.23 + Double(which) * 0.31) * 100).rounded() / 100
            let falling = Animation.between([.transform: .t(.translate(0, 0))], [.transform: .t(.translate(0, fall))], duration: seconds, delay: -fallDelay, timing: .linear)
            let sway = Animation.between([.translate: .t(.translate(-28, 0))], [.translate: .t(.translate(14, 0))], duration: layer.swaySeconds, delay: -Double(which * 7 + layer.seed % 10), direction: .alternate, timing: .easeInOut)
            return Node.glyphs(flakes.map(\.2), xs: flakes.map(\.0), ys: flakes.map(\.1))
                .fill(Paint(layer.colour), opacity: layer.opacity).font(size: layer.fontSize, weight: 400)
                .animate([falling, sway])
        }
    }

    // MARK: La cabane

    static let cabinShape = [" /^\\ ", "/___\\", "|[] |"].map(Array.init)

    /// L'unique accent : une petite cabane entre les sapins de droite, sa
    /// fenêtre allumée en deux glyphes ambre.
    func cabin() -> [Node] {
        let grid = Self.middle.grid
        let column = layout.cabinColumn
        let row = Int(JS.round((middleCrest(Double(column) * grid.cellWidth) + 8) / grid.cellHeight))
        var roof: [Mark] = [], wall: [Mark] = [], pane: [Mark] = []
        for (y, line) in Self.cabinShape.enumerated() {
            for (x, glyph) in line.enumerated() {
                if glyph == " " && y < 2 { continue }
                let cell = Mark(x: column + x, y: row - 2 + y, glyph: glyph)
                if y < 2 { roof.append(cell) } else if glyph == "[" || glyph == "]" { pane.append(cell) } else { wall.append(cell) }
            }
        }
        let left = Double(column) * grid.cellWidth
        let top = Double(row) * grid.cellHeight
        let glow = Animation.between([.fillOpacity: .n(0.7)], [.fillOpacity: .n(1)], duration: 7, direction: .alternate, timing: .easeInOut)
        return [
            Node.ellipse(left + 26, top + 20, 44, 12).fill("url(#lamp)").animate(glow),
            Self.tiles(wall + pane, grid, "#1c1c46", 1), Self.tiles(roof, grid, "#5a5c94", 1),
            Self.glyphRows(roof, grid, "#d0d4f2", 0.9), Self.glyphRows(wall.filter { $0.glyph != " " }, grid, "#3c3f74", 1),
            Self.glyphRows(pane, grid, "#f0a040", 1).map { Node.group([$0]).animate(glow) },
        ].compactMap { $0 }
    }

    // MARK: Le décor

    static func build(width: Double, height: Double) -> Scene {
        SnowPines(width: width, height: height, layout: .portrait(width, height)).scene()
    }

    static func original() -> Scene {
        SnowPines(width: 1600, height: 1000, layout: .original).scene()
    }

    func scene() -> Scene {
        var scene = Scene(width: width, height: height)
        scene.linear("sky", [(0, "#181a46", 1), (0.22, "#1c1d4d", 1), (0.4, "#242253", 1), (0.52, "#30295b", 1), (0.6, "#3c3162", 1), (0.67, "#483967", 1), (0.74, "#52406b", 1)])
        scene.linear("field", [(0.66, "#4b4679", 1), (0.82, "#403c72", 1), (1, "#37346a", 1)])
        scene.radial("rose", [(0, "#a8607a", 0.32), (0.2, "#a45e7a", 0.27), (0.4, "#9e5c7a", 0.2), (0.6, "#985a7a", 0.12), (0.8, "#92587a", 0.05), (1, "#8c567a", 0)])
        scene.radial("lamp", [(0, "#ffb65c", 0.16), (1, "#ffb65c", 0)])
        scene.radial("hush", [(0.55, "#1b1c4b", 0.85), (1, "#1b1c4b", 0)])
        let dusk = Animation.between(
            [.transform: .t(.translate(layout.dusk.0, 0)), .fillOpacity: .n(0.5)], [.transform: .t(.translate(layout.dusk.1, 0)), .fillOpacity: .n(1)],
            duration: 170, direction: .alternate, timing: .easeInOut
        )
        scene.add(.rect(0, 0, width, height).fill("url(#sky)"))
        scene.add(.group([.ellipse(layout.rose.0, layout.rose.1, layout.rose.2, layout.rose.3).fill("url(#rose)")]).animate(dusk))
        scene.add(farForest())
        scene.add(snowField())
        scene.add(cabin())
        var faint = Self.faint
        faint.density = layout.faintDensity
        faint.rows = layout.snowRows[0]
        var middleSnow = Self.middleSnow
        middleSnow.none = layout.middleNone
        middleSnow.rows = layout.snowRows[1]
        var bright = Self.bright
        bright.none = layout.brightNone
        bright.rows = layout.snowRows[2]
        scene.add(snowLayer(faint))
        scene.add(middleForest())
        scene.add(snowLayer(middleSnow))
        scene.add(nearForest())
        scene.add(snowLayer(bright))
        scene.add(.ellipse(layout.hush.0, layout.hush.1, layout.hush.2, layout.hush.3).fill("url(#hush)"))
        return scene
    }
}
