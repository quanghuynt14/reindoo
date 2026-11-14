import Foundation

// Plotter Tide : une table traçante dessine une côte de carte marine. La terre,
// dans les coins du bas, est hachurée à la plume rouille ; la mer est faite de
// lignes de marée à la plume ardoise, serrées contre le rivage. La plume
// reprend chaque ligne ; les plus vieilles s'effacent et sont redessinées.
// D'après theme-examples (Anthropic, Apache 2.0), scenes/plotter-tide.ts.

struct PlotterTide {
    struct Stock {
        var paper, land, ink, rust: String
    }

    static let day = Stock(paper: "#f3eee3", land: "#e8d6bd", ink: "#1f2a48", rust: "#c4552d")
    static let night = Stock(paper: "#141a27", land: "#1c2333", ink: "#aab6d0", rust: "#e98a5e")

    struct Coast {
        var seed: Double
        var isIslet: Bool
        var centreX, centreY, landRadius, bayDepth: Double
        var lineCount: Int
        var firstGap, gapGrowth, fullUntil, keepToward, angleFrom, angleTo, hatchLean: Double
    }

    struct Job {
        var name: String
        var ink: String
        var width: Double
        var opacity: Double
        var opacityFade: Double
        var cycleSeconds: Double
        var cycleStart: Double
        var absentShare: Double
        var drawShare: Double
        var farFrom: Int
        var coastWidth: Double
        var hidePen: Bool
    }

    struct Layout {
        var east: Coast
        var west: Coast
        var islet: Coast
        /// Vrai là où la plume a le droit d'aller ; `shy` recule chaque ligne
        /// d'une longueur à elle.
        var outside: @Sendable (Point, Double) -> Bool

        static var original: Layout {
            Layout(
                east: Coast(seed: 1, isIslet: false, centreX: 1650, centreY: 1050, landRadius: 300, bayDepth: 62, lineCount: 14, firstGap: 11, gapGrowth: 1.062, fullUntil: 0.5, keepToward: 0.7, angleFrom: .pi * 0.95, angleTo: .pi * 1.55, hatchLean: 1),
                west: Coast(seed: 2, isIslet: false, centreX: -50, centreY: 1070, landRadius: 300, bayDepth: 56, lineCount: 17, firstGap: 11, gapGrowth: 1.058, fullUntil: 0.5, keepToward: 0.3, angleFrom: -.pi * 0.58, angleTo: .pi * 0.05, hatchLean: 1),
                islet: Coast(seed: 5, isIslet: true, centreX: 1436, centreY: 334, landRadius: 26, bayDepth: 7, lineCount: 5, firstGap: 7.5, gapGrowth: 1.2, fullUntil: 1, keepToward: 0.5, angleFrom: 0, angleTo: .pi * 2, hatchLean: 1),
                outside: { point, shy in point.x < 432 - shy || point.x > 1200 + shy }
            )
        }

        /// Trop étroit pour deux côtes sur un même bord : leurs lignes se
        /// croiseraient. La grande côte descend du coin en haut à droite, la
        /// flèche monte du coin en bas à gauche, l'îlot est en haut à gauche.
        /// Aucune encre dans la bande du texte.
        static func portrait(_ w: Double, _ h: Double) -> Layout {
            Layout(
                east: Coast(seed: 1, isIslet: false, centreX: w + 40, centreY: -50, landRadius: 150, bayDepth: 40, lineCount: 9, firstGap: 10, gapGrowth: 1.062, fullUntil: 0.5, keepToward: 0.3, angleFrom: .pi * 0.45, angleTo: .pi * 1.05, hatchLean: 1),
                west: Coast(seed: 2, isIslet: false, centreX: -40, centreY: h + 60, landRadius: 210, bayDepth: 48, lineCount: 15, firstGap: 10, gapGrowth: 1.058, fullUntil: 0.5, keepToward: 0.3, angleFrom: -.pi * 0.58, angleTo: .pi * 0.05, hatchLean: 1),
                islet: Coast(seed: 5, isIslet: true, centreX: w * 0.18, centreY: h * 0.085, landRadius: 22, bayDepth: 6, lineCount: 5, firstGap: 7, gapGrowth: 1.2, fullUntil: 1, keepToward: 0.5, angleFrom: 0, angleTo: .pi * 2, hatchLean: 1),
                outside: { point, shy in point.y < h * 0.19 - shy * 0.5 || point.y > h * 0.66 + shy * 0.5 }
            )
        }
    }

    let width: Double
    let height: Double
    let layout: Layout
    let stock: Stock

    static func hash(_ number: Double) -> Double {
        let value = sin(number * 127.1 + 311.7) * 43_758.5453
        return value - value.rounded(.down)
    }

    static func round(_ value: Double) -> Double { JS.round(value * 10) / 10 }

    static func bays(_ along: Double, _ coast: Coast, _ calm: Double) -> Double {
        let turn = along / coast.landRadius
        let wide = coast.isIslet ? sin(turn * 2 + coast.seed) : sin(along / 97 + coast.seed * 1.7)
        let middle = (coast.isIslet ? sin(turn * 3 + coast.seed * 2) : sin(along / 41 + coast.seed * 3.1)) * (1 - calm)
        let small = (coast.isIslet ? sin(turn * 5 + coast.seed * 3) : sin(along / 17 + coast.seed * 5.3)) * (1 - calm) * (1 - calm)
        return (wide + 0.55 * middle + 0.25 * small) / 1.8
    }

    static func radius(_ angle: Double, _ line: Int, _ coast: Coast) -> Double {
        let along = angle * coast.landRadius
        var radius = coast.landRadius + coast.bayDepth * bays(along, coast, 0)
        var gap = coast.firstGap
        if line >= 1 {
            for step in 1...line {
                let calm = min(1, Double(step) / (Double(coast.lineCount) * 0.8))
                radius += gap * (1 - 0.36 * bays(along, coast, calm))
                gap *= coast.gapGrowth
            }
        }
        return radius
    }

    static func point(_ angle: Double, _ line: Int, _ coast: Coast) -> Point {
        let r = radius(angle, line, coast)
        return Point(coast.centreX + r * cos(angle), coast.centreY + r * sin(angle))
    }

    func onSheet(_ p: Point) -> Bool { p.x > -30 && p.x < width + 30 && p.y > -30 && p.y < height + 30 }

    func outside(_ p: Point, _ line: Int, _ coast: Coast) -> Bool {
        layout.outside(p, 80 * Self.hash(Double(line * 17) + coast.seed * 7))
    }

    static func onLand(_ p: Point, _ coast: Coast) -> Bool {
        let dx = p.x - coast.centreX, dy = p.y - coast.centreY
        var angle = atan2(dy, dx)
        if !coast.isIslet && angle < coast.angleFrom - 0.5 { angle += .pi * 2 }
        return hypot(dx, dy) < radius(angle, 0, coast) - 5
    }

    static func mid(_ a: Point, _ b: Point) -> (Double, Double) { (round((a.x + b.x) / 2), round((a.y + b.y) / 2)) }

    /// Un chemin doux par les milieux des points : un point par segment.
    static func smoothPath(_ points: [Point]) -> PathData? {
        guard points.count >= 4 else { return nil }
        var d = "M\(round(points[0].x)) \(round(points[0].y))Q\(round(points[1].x)) \(round(points[1].y)) \(mid(points[1], points[2]).0) \(mid(points[1], points[2]).1)"
        for index in 2..<(points.count - 1) {
            let m = mid(points[index], points[index + 1])
            d += "T\(m.0) \(m.1)"
        }
        d += "T\(round(points[points.count - 1].x)) \(round(points[points.count - 1].y))"
        return PathData(svg: d)
    }

    static func smoothRing(_ points: [Point]) -> PathData {
        let closing = points[points.count - 1]
        var d = ""
        for index in points.indices {
            let here = points[index], next = points[(index + 1) % points.count]
            let m = mid(here, next)
            if index == 0 {
                let start = mid(closing, here)
                d = "M\(start.0) \(start.1)Q\(round(here.x)) \(round(here.y)) \(m.0) \(m.1)"
            } else {
                d += "T\(m.0) \(m.1)"
            }
        }
        return PathData(svg: d + "Z")
    }

    static func longestRun(_ samples: [(Point, Bool)]) -> [Point] {
        var best: [Point] = [], run: [Point] = []
        for (point, inked) in samples {
            if inked {
                run.append(point)
            } else {
                if run.count > best.count { best = run }
                run = []
            }
        }
        return run.count > best.count ? run : best
    }

    /// La côte et ses lignes de marée, le rivage d'abord.
    func tideLines(_ coast: Coast) -> [PathData] {
        var paths: [PathData] = []
        for line in 0...coast.lineCount {
            let step = 16 / Self.radius((coast.angleFrom + coast.angleTo) / 2, line, coast)
            var samples: [(Point, Bool)] = []
            var angle = coast.angleFrom
            while angle <= coast.angleTo {
                let p = Self.point(angle, line, coast)
                samples.append((p, onSheet(p) && outside(p, line, coast)))
                angle += step
            }
            let points = Self.longestRun(samples)
            let share = Double(line) / Double(coast.lineCount)
            let fade = max(0, (share - coast.fullUntil) / (1 - coast.fullUntil))
            let keep = max(4, Int((Double(points.count) * (1 - fade * (0.35 + 0.3 * Self.hash(Double(line) + coast.seed * 31)))).rounded(.down)))
            let slack = max(points.count - keep, 0)
            let start = min(max(Int((Double(slack) * (coast.keepToward + (Self.hash(Double(line * 11) + coast.seed) - 0.5) * 0.4)).rounded(.down)), 0), slack)
            var kept = Array(points[min(start, points.count)..<min(start + keep, points.count)])
            // La plume part le long d'une ligne et revient le long de la suivante.
            if line % 2 == 1 { kept.reverse() }
            if let path = Self.smoothPath(kept) { paths.append(path) }
        }
        return paths
    }

    static func isletRings(_ coast: Coast) -> [PathData] {
        (0...coast.lineCount).map { line in
            let count = max(12, Int(JS.round(radius(0, line, coast) * 6.3 / 14)))
            let points = (0..<count).map { point(Double($0) / Double(count) * .pi * 2 + Double(line) * 0.9, line, coast) }
            return smoothRing(points)
        }
    }

    func landShape(_ coast: Coast) -> Node {
        var commands: [PathData.Command] = []
        var angle = coast.angleFrom
        while angle <= coast.angleTo {
            let p = Self.point(angle, 0, coast)
            commands.append(commands.isEmpty ? .move(Self.round(p.x), Self.round(p.y)) : .line(Self.round(p.x), Self.round(p.y)))
            angle += 0.04
        }
        if !coast.isIslet { commands.append(.line(coast.centreX, coast.centreY)) }
        commands.append(.close)
        return Node.path(PathData(commands)).fill(Paint(stock.land), opacity: 0.6)
    }

    /// Des hachures droites sur la terre, dans l'ordre où une plume les prendrait.
    func landHatch(_ coast: Coast) -> [PathData] {
        var paths: [PathData] = []
        var stroke = 0
        var offset = -height
        while offset < width + height {
            defer { offset += 15 }
            var first: Point?, last: Point?
            var step = 0.0
            while step < height + 60 {
                let p = Point(offset - step * coast.hatchLean, step)
                if onSheet(p) && Self.onLand(p, coast) {
                    if first == nil { first = p }
                    last = p
                } else if first != nil {
                    break
                }
                step += 4
            }
            guard let a = first, let b = last, hypot(b.x - a.x, b.y - a.y) >= 14 else { continue }
            let (from, to) = stroke % 2 == 0 ? (a, b) : (b, a)
            paths.append(PathData([.move(Self.round(from.x), Self.round(from.y)), .line(Self.round(to.x), Self.round(to.y))]))
            stroke += 1
        }
        return paths
    }

    /// Le travail d'une plume : les chemins tracés l'un après l'autre sur un
    /// cycle commun, chacun effacé avant son tour suivant.
    func penJob(_ paths: [PathData], _ job: Job, into scene: inout Scene) -> (near: Node, far: Node) {
        let count = Double(paths.count)
        let stepSeconds = job.cycleSeconds / count
        let drawnAt = job.drawShare > 0 ? job.drawShare : Self.round(100 / count)
        let restUntil = 100 - job.absentShare - drawnAt
        let ink = Animation([
            .init(0, [.dashOffset: .n(1.01), .opacity: .n(1)]), .init(drawnAt / 100, [.dashOffset: .n(0), .opacity: .n(1)]),
            .init(Self.round(drawnAt * 2.5) / 100, [.dashOffset: .n(0), .opacity: .n(0.74)]), .init(restUntil / 100, [.dashOffset: .n(0), .opacity: .n(0.74)]),
            .init((restUntil + drawnAt) / 100, [.dashOffset: .n(-1.01)]), .init(1, [.dashOffset: .n(-1.01), .opacity: .n(0.74)]),
        ], duration: job.cycleSeconds, timing: .linear)
        let pen = Animation([
            .init(0, [.dashOffset: .n(0), .opacity: .n(1)]), .init(drawnAt / 100, [.dashOffset: .n(-1), .opacity: .n(1)]),
            .init((drawnAt + 0.01) / 100, [.dashOffset: .n(-1), .opacity: .n(0)]), .init(1, [.dashOffset: .n(-1), .opacity: .n(0)]),
        ], duration: job.cycleSeconds, timing: .linear)
        var strokes: [Node] = [], far: [Node] = [], heads: [Node] = [], farHeads: [Node] = []
        for (line, path) in paths.enumerated() {
            let id = "\(job.name)\(line)"
            let phase = ((job.cycleStart - Double(line) * stepSeconds).truncatingRemainder(dividingBy: job.cycleSeconds) + job.cycleSeconds).truncatingRemainder(dividingBy: job.cycleSeconds)
            let delay = Self.round(-phase)
            let opacity = Self.round((job.opacity - job.opacityFade * (Double(line) / count)) * 100) / 100
            scene.define(id, .symbol(Node.path(path).pathLength(1)))
            var stroke = Node.use(id).dash([1, 2]).animate(ink.delayed(delay))
            stroke = line == 0 && job.coastWidth > 0 ? stroke.strokeWidth(job.coastWidth).strokeOpacity(0.9) : stroke.strokeOpacity(opacity)
            let isFar = job.farFrom > 0 && line >= job.farFrom
            if isFar { far.append(stroke) } else { strokes.append(stroke) }
            if !job.hidePen {
                let head = Node.use(id).dash([0.0001, 3]).strokeWidth(8).opacity(0).animate(pen.delayed(delay))
                if isFar { farHeads.append(head) } else { heads.append(head) }
            }
        }
        return (
            Node.group(strokes + heads).stroke(Paint(job.ink), width: job.width),
            Node.group(far + farHeads).stroke(Paint(job.ink), width: job.width)
        )
    }

    static func build(_ stock: Stock) -> @Sendable (Double, Double) -> Scene {
        { width, height in PlotterTide(width: width, height: height, layout: .portrait(width, height), stock: stock).scene() }
    }

    static func original(_ stock: Stock) -> @Sendable () -> Scene {
        { PlotterTide(width: 1600, height: 1000, layout: .original, stock: stock).scene() }
    }

    func scene() -> Scene {
        var scene = Scene(width: width, height: height)
        let (east, west, islet) = (layout.east, layout.west, layout.islet)
        let eastTides = tideLines(east), westTides = tideLines(west), rings = Self.isletRings(islet)
        let eastSea = penJob(Array(eastTides.dropFirst()), Job(name: "e", ink: stock.ink, width: 1.15, opacity: 1, opacityFade: 0.4, cycleSeconds: 136, cycleStart: 30, absentShare: 20, drawShare: 0, farFrom: 7, coastWidth: 0, hidePen: false), into: &scene)
        let westSea = penJob(Array(westTides.dropFirst()), Job(name: "w", ink: stock.ink, width: 1.15, opacity: 1, opacityFade: 0.4, cycleSeconds: 126, cycleStart: 75, absentShare: 20, drawShare: 0, farFrom: 8, coastWidth: 0, hidePen: false), into: &scene)
        let isletSea = penJob(Array(rings.dropFirst()), Job(name: "i", ink: stock.ink, width: 1.1, opacity: 0.8, opacityFade: 0.3, cycleSeconds: 150, cycleStart: 40, absentShare: 14, drawShare: 5, farFrom: 0, coastWidth: 0, hidePen: true), into: &scene)
        let eastLand = penJob(Array(eastTides.prefix(1)) + landHatch(east), Job(name: "f", ink: stock.rust, width: 1, opacity: 0.8, opacityFade: 0, cycleSeconds: 118, cycleStart: 60, absentShare: 4, drawShare: 0, farFrom: 0, coastWidth: 1.3, hidePen: false), into: &scene)
        let westLand = penJob(Array(westTides.prefix(1)) + landHatch(west), Job(name: "g", ink: stock.rust, width: 1, opacity: 0.8, opacityFade: 0, cycleSeconds: 104, cycleStart: 20, absentShare: 4, drawShare: 0, farFrom: 0, coastWidth: 1.3, hidePen: false), into: &scene)
        let isletLand = penJob(Array(rings.prefix(1)), Job(name: "j", ink: stock.rust, width: 1, opacity: 0.8, opacityFade: 0, cycleSeconds: 140, cycleStart: 9, absentShare: 6, drawShare: 6, farFrom: 0, coastWidth: 1.3, hidePen: true), into: &scene)

        func tide(_ node: Node, _ dx: Double, _ dy: Double, delay: Double = 0) -> Node {
            Node.group([node]).animate(Animation.between([.transform: .t(.translate(0, 0))], [.transform: .t(.translate(dx, dy))], duration: 70, delay: delay, direction: .alternate, timing: .easeInOut))
        }
        scene.add(.rect(0, 0, width, height).fill(Paint(stock.paper)))
        scene.add([landShape(east), landShape(west), landShape(islet)])
        scene.add([
            tide(eastSea.near, -5, -5), tide(eastSea.far, -17, -15),
            tide(westSea.near, 5, -5, delay: -35), tide(westSea.far, 16, -16, delay: -35),
            tide(isletSea.near, -3, 3, delay: -36),
            eastLand.near, westLand.near, isletLand.near,
        ])
        // `path{fill:none;stroke-linecap:round}` : seules les terres, qui le
        // disent, se remplissent.
        scene.nodes = [Node.group(scene.nodes).fill(.none).lineCap(.round)]
        return scene
    }
}
