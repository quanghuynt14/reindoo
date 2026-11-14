import Foundation

// Block Clouds : une page météo de télétexte, la nuit, sans le texte. Des bancs
// de nuages en blocs dérivent depuis les bords, un bloc à la fois.
// D'après theme-examples (Anthropic, Apache 2.0), scenes/teletext-clouds.ts.

struct TeletextClouds {
    static let blockWidth = 20.0
    static let blockHeight = 16.0
    static let gap = 0.5

    static let ink: [String: String] = [
        "belly": "#1a2788", "body": "#2636b4", "bodyLight": "#2c3fc6", "bodyHigh": "#3346dc", "top": "#4cc4d8",
        "topLit": "#9af0f8", "rose": "#a84e80", "deck": "#182568", "land": "#111a4c", "landTop": "#27367e",
        "sun": "#f0cf52", "sunShade": "#d2b040", "star": "#cfd8ff",
    ]
    static let humps: [(Double, Double, Double, Double)] = [
        (-430, -22, 430, 40), (-350, -68, 96, 60), (-236, -42, 60, 36), (-150, -54, 72, 50), (-86, -36, 40, 34), (-24, -10, 30, 12),
    ]
    static let starPeriods: [Double] = [7, 11, 13, 17, 19]

    struct Block: Hashable {
        var column: Int
        var row: Int
    }

    /// Un ensemble qui garde l'ordre d'arrivée, comme un `Set` de JavaScript.
    struct Blocks {
        private(set) var order: [Block] = []
        private var members = Set<Block>()
        func has(_ column: Int, _ row: Int) -> Bool { members.contains(Block(column: column, row: row)) }
        mutating func add(_ block: Block) { if members.insert(block).inserted { order.append(block) } }
        mutating func delete(_ block: Block) {
            if members.remove(block) != nil { order.removeAll { $0 == block } }
        }
        var list: [Block] { order }
    }

    struct Bank {
        var tipX: Double
        var baseRow: Int
        var scale: Double
        var direction: Double
    }

    struct Layout {
        var columns: Int
        var rows: Int
        var bankA: Bank
        var bankB: Bank
        var deck: [Bank]
        var fade: (x2: Double, y2: Double, stops: [Double])
        var stars: (Int) -> (Int, Int)
        var moon: (Double, Double)
        var land: (heights: [Int], first: Int)

        static var original: Layout {
            Layout(
                columns: 80, rows: 63,
                bankA: Bank(tipX: 300, baseRow: 44, scale: 1.25, direction: 1), bankB: Bank(tipX: 1340, baseRow: 56, scale: 1.9, direction: -1),
                deck: [Bank(tipX: 1500, baseRow: 47, scale: 1.6, direction: 1), Bank(tipX: 100, baseRow: 47, scale: 1.6, direction: -1)],
                fade: (1, 0, [0.16, 0.255, 0.76, 0.83]),
                stars: { index in
                    (Int((hash(index, 2, 71) * 17).rounded(.down)) + (index % 2 == 0 ? 1 : 62), Int((hash(index, 3, 71) * 26).rounded(.down)))
                },
                moon: (1350, 312), land: ([9, 8, 6, 5, 3, 2], -4)
            )
        }

        /// Les étoiles et la lune en haut, un banc dans le ciel du haut, le
        /// banc rose et la terre en bas ; les deux s'effacent en entrant sous
        /// le texte.
        static func portrait(_ w: Double, _ h: Double) -> Layout {
            let columns = Int((w / blockWidth).rounded(.up)), rows = Int((h / blockHeight).rounded(.up))
            let rr = Double(rows)
            return Layout(
                columns: columns, rows: rows,
                bankA: Bank(tipX: w * 0.62, baseRow: Int(rr * 0.21), scale: 1.05, direction: 1),
                bankB: Bank(tipX: w * 0.3, baseRow: Int(rr * 0.92), scale: 1.5, direction: -1),
                deck: [Bank(tipX: w * 0.95, baseRow: Int(rr * 0.76), scale: 1.2, direction: 1), Bank(tipX: w * 0.05, baseRow: Int(rr * 0.76), scale: 1.2, direction: -1)],
                fade: (0, 1, [0.2, 0.27, 0.62, 0.7]),
                stars: { index in
                    (Int((hash(index, 2, 71) * Double(columns)).rounded(.down)), Int((hash(index, 3, 71) * rr * 0.16).rounded(.down)))
                },
                moon: (w * 0.8, h * 0.075), land: ([7, 6, 5, 4, 3, 2], -2)
            )
        }
    }

    let width: Double
    let height: Double
    let layout: Layout

    static func hash(_ x: Int, _ y: Int, _ seed: Int) -> Double {
        var value = JS.int32(Double(x) * 374_761_393 + Double(y) * 668_265_263 + Double(seed) * 2_147_483_647)
        value = (value ^ Int32(bitPattern: UInt32(bitPattern: value) >> 13)) &* 1_274_126_177
        value = value ^ Int32(bitPattern: UInt32(bitPattern: value) >> 16)
        return Double(UInt32(bitPattern: value)) / 4_294_967_296
    }

    static func floorDiv(_ a: Int, _ b: Int) -> Int { Int((Double(a) / Double(b)).rounded(.down)) }

    static func blockPath(_ list: [Block]) -> PathData {
        let w = blockWidth - gap, h = blockHeight - gap
        return list.reduce(PathData()) { $0 + .rect(Double($1.column) * blockWidth + 1, Double($1.row) * blockHeight + 1, w, h) }
    }

    static func paths(_ layers: [(String, [Block])]) -> [Node] {
        layers.compactMap { name, list in list.isEmpty ? nil : Node.path(blockPath(list)).fill(Paint(ink[name]!)) }
    }

    static func insideSomeHump(_ x: Double, _ y: Double, _ bank: Bank, _ baseY: Double) -> Bool {
        for hump in humps {
            let dx = (x - (bank.tipX + hump.0 * bank.scale * bank.direction)) / (hump.2 * bank.scale)
            let dy = (y - (baseY + hump.1 * bank.scale)) / (hump.3 * bank.scale)
            if dx * dx + dy * dy <= 1 { return true }
        }
        return false
    }

    /// Un banc : une union d'ellipses échantillonnée au centre des blocs, coupée
    /// à sa rangée de base, au ventre bosselé et aux bouts arrondis.
    func bankBlocks(_ bank: Bank) -> Blocks {
        let baseY = Double(bank.baseRow) * Self.blockHeight
        var blocks = Blocks()
        for row in 0..<max(0, bank.baseRow) {
            for column in -34..<(layout.columns + 34) {
                if row == bank.baseRow - 1 && Self.hash(Self.floorDiv(column, 2), 1, bank.baseRow) < 0.35 { continue }
                let x = Double(column) * Self.blockWidth + Self.blockWidth / 2, y = Double(row) * Self.blockHeight + Self.blockHeight / 2
                if Self.insideSomeHump(x, y, bank, baseY) { blocks.add(Block(column: column, row: row)) }
            }
        }
        // Les suppressions comptent pour les blocs suivants, comme dans l'original.
        for block in blocks.list {
            let inset = block.row == bank.baseRow - 1 ? 2 : block.row == bank.baseRow - 2 ? 1 : 0
            if inset == 0 { continue }
            if !blocks.has(block.column - inset, block.row - inset) || !blocks.has(block.column + inset, block.row - inset) { blocks.delete(block) }
        }
        return blocks
    }

    /// Le modelé d'un nuage : un bord haut éclairé, trois tons de corps, un
    /// ventre plus sombre. Une lumière court le long du bord ; quelques blocs du
    /// bord vont et viennent.
    func cloud(_ blocks: Blocks, seed: Int, warm: Bool) -> [Node] {
        var belly: [Block] = [], rose: [Block] = [], body: [Block] = [], bodyLight: [Block] = [], bodyHigh: [Block] = [], top: [Block] = []
        var travelling = Array(repeating: [Block](), count: 5)
        var puffs: [Node] = []
        let puff = Animation([.init(0, [.opacity: .n(1)]), .init(0.55, [.opacity: .n(1)]), .init(0.56, [.opacity: .n(0)]), .init(1, [.opacity: .n(0)])], duration: 16, timing: .steps(1))
        for block in blocks.list {
            let isTop = !blocks.has(block.column, block.row - 1)
            let isBelly = !blocks.has(block.column, block.row + 1)
            let chance = Self.hash(Self.floorDiv(block.column, 2), Self.floorDiv(block.row, 3), seed)
            if isTop {
                top.append(block)
                let group = Int((Double(block.column) / 3 + 400).rounded(.down)) % 5
                travelling[group].append(block)
                if Self.hash(block.column, block.row, seed + 1) < 0.08 {
                    let above = Block(column: block.column, row: block.row - 1)
                    // `%` de JavaScript garde le signe : sous zéro, le retard écrit
                    // « --5s » est rejeté par CSS, et la bouffée part sans retard.
                    let delay = (block.column * 7) % 23
                    puffs.append(Node.group([
                        Node.path(Self.blockPath([block])).fill(Paint(Self.ink["body"]!)), Node.path(Self.blockPath([above])).fill(Paint(Self.ink["top"]!)),
                    ]).animate(puff.lasting(16 + Double((block.column % 5) * 3)).delayed(delay > 0 ? -Double(delay) : 0)))
                }
            } else if isBelly {
                if warm { rose.append(block) } else { belly.append(block) }
            } else if !blocks.has(block.column, block.row - 2) {
                bodyHigh.append(block)
            } else if !blocks.has(block.column, block.row - 4) || chance < 0.15 {
                bodyLight.append(block)
            } else {
                body.append(block)
            }
        }
        let travel = Animation([.init(0, [.opacity: .n(0)]), .init(0.12, [.opacity: .n(1)]), .init(0.3, [.opacity: .n(0)]), .init(1, [.opacity: .n(0)])], duration: 7, timing: .easeInOut)
        let light = travelling.enumerated().compactMap { group, list -> Node? in
            if list.isEmpty { return nil }
            let delay = ((Double(group) * 1.4 + Double(seed % 5)) * 10).rounded() / 10
            return Node.path(Self.blockPath(list)).fill(Paint(Self.ink["topLit"]!)).opacity(0).animate(travel.delayed(-delay))
        }
        return Self.paths([("belly", belly), ("rose", rose), ("body", body), ("bodyLight", bodyLight), ("bodyHigh", bodyHigh), ("top", top)]) + puffs + light
    }

    /// Un banc glisse d'un bloc à la fois entre deux bouts, et revient.
    static func drifting(_ blocksEachWay: Double, _ secondsPerBlock: Double, delay: Double, _ inner: [Node]) -> Node {
        let reach = blocksEachWay * blockWidth
        let steps = Int(blocksEachWay * 2)
        let drift = Animation.between([.transform: .t(.translate(-reach, 0))], [.transform: .t(.translate(reach, 0))],
                                      duration: Double(steps) * secondsPerBlock, delay: -delay, direction: .alternate, timing: .steps(steps))
        return Node.group(inner).animate(drift)
    }

    func stars() -> [Node] {
        let star = Animation([.init(0, [.opacity: .n(1)]), .init(0.5, [.opacity: .n(0.5)]), .init(1, [.opacity: .n(1)])], duration: 9, timing: .steps(2))
        return (0..<26).map { index in
            let (column, row) = layout.stars(index)
            let x = Double(column) * Self.blockWidth, y = Double(row) * Self.blockHeight
            let fill = index % 5 == 2 ? Self.ink["sun"]! : Self.ink["star"]!
            let opacity = index % 2 == 0 ? 0.3 : ((0.5 + Self.hash(index, 4, 71) * 0.4) * 100).rounded() / 100
            let delay = ((Self.hash(index, 5, 71) * 19) * 10).rounded() / 10
            return Node.rect(x + 5, y + 4, 10, 8).fill(Paint(fill)).opacity(opacity)
                .animate(star.lasting(Self.starPeriods[index % 5]).delayed(-delay))
        }
    }

    func land() -> [Node] {
        var body: [Block] = [], top: [Block] = []
        let rows = layout.rows
        for (index, height) in layout.land.heights.enumerated() {
            for dx in 0..<4 {
                for row in (rows - height)..<rows {
                    let block = Block(column: layout.land.first + index * 4 + dx, row: row)
                    if row == rows - height { top.append(block) } else { body.append(block) }
                }
            }
        }
        return Self.paths([("land", body), ("landTop", top)])
    }

    /// La lune : un disque de blocs jaunes, avec une morsure de ciel en haut à gauche.
    func disc() -> [Node] {
        var bright: [Block] = [], shade: [Block] = []
        let (mx, my) = layout.moon
        let firstRow = Int(((my - 70) / Self.blockHeight).rounded(.down)), lastRow = Int(((my + 70) / Self.blockHeight).rounded(.up))
        let firstColumn = Int(((mx - 70) / Self.blockWidth).rounded(.down)), lastColumn = Int(((mx + 70) / Self.blockWidth).rounded(.up))
        for row in firstRow..<lastRow {
            for column in firstColumn..<lastColumn {
                let dx = Double(column) * Self.blockWidth + Self.blockWidth / 2 - mx
                let dy = Double(row) * Self.blockHeight + Self.blockHeight / 2 - my
                let distance = (dx * dx + dy * dy).squareRoot()
                let bitten = ((dx + 44) * (dx + 44) + (dy + 34) * (dy + 34)).squareRoot() <= 56
                if distance <= 60 && !bitten {
                    if dy > 30 { shade.append(Block(column: column, row: row)) } else { bright.append(Block(column: column, row: row)) }
                }
            }
        }
        return Self.paths([("sun", bright), ("sunShade", shade)])
    }

    static func build(width: Double, height: Double) -> Scene {
        TeletextClouds(width: width, height: height, layout: .portrait(width, height)).scene()
    }

    static func original() -> Scene {
        TeletextClouds(width: 1600, height: 1000, layout: .original).scene()
    }

    func scene() -> Scene {
        var scene = Scene(width: width, height: height)
        scene.linear("sky", [(0, "#0a1238", 1), (0.6, "#14225c", 1), (1, "#1b2b6e", 1)])
        let f = layout.fade.stops
        scene.linear("edges", x1: 0, y1: 0, x2: layout.fade.x2, y2: layout.fade.y2, [(f[0], "#fff", 1), (f[1], "#fff", 0), (f[2], "#fff", 0), (f[3], "#fff", 1)])
        scene.define("fade", .mask(Mask(region: Rect(0, 0, width, height), nodes: [.rect(0, 0, width, height).fill("url(#edges)")])))

        var deckBlocks = Blocks()
        for bank in layout.deck { for block in bankBlocks(bank).list { deckBlocks.add(block) } }
        let driftDeck = Animation.between([.transform: .t(.translate(-240, 0))], [.transform: .t(.translate(240, 0))], duration: 360, delay: -90, direction: .alternate, timing: .steps(24))

        scene.add(.rect(0, 0, width, height).fill("url(#sky)"))
        scene.add(stars())
        scene.add(disc())
        scene.add(Node.group([Node.path(Self.blockPath(deckBlocks.list)).fill(Paint(Self.ink["deck"]!))]).animate(driftDeck))
        scene.add(Node.group([
            Self.drifting(7, 8, delay: 112, cloud(bankBlocks(layout.bankA), seed: 5, warm: false)),
            Self.drifting(7, 8, delay: 112, cloud(bankBlocks(layout.bankB), seed: 11, warm: true)),
        ]).mask("fade"))
        scene.add(land())
        return scene
    }
}
