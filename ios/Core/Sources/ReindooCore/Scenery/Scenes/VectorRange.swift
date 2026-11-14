import Foundation

// Vector Range : un écran vectoriel en fil de fer. Des montagnes de phosphore
// aux deux bords, une grille au sol qui avance vers nous, un petit croissant.
// Le faisceau repasse sans cesse les crêtes : un éclat ambre en tête, une
// longue traîne verte qui s'éteint derrière.
// D'après theme-examples (Anthropic, Apache 2.0), scenes/vector-range.ts.

struct VectorRange {
    static let skyTop = "#030a08", skyLow = "#071a15", groundFar = "#051210", groundNear = "#030a08"
    static let hot = "#9ff0dc", warm = "#3fb89a", cold = "#237a68", amber = "#ffb454"
    static let longestTail = 0.42
    static let travel = 1 + longestTail
    static let restAt = 0.62
    static let cycle = 120.0
    static let farStep = 78.0
    static let farCount = 21
    static let nearDepth = 1.5
    static let crossLines = 11
    static let creepSeconds = 12.0

    struct Part {
        var name: String
        var length, width, opacity: Double
        var colour: String
    }

    static let parts = [
        Part(name: "tailLong", length: longestTail, width: 1.8, opacity: 0.4, colour: hot),
        Part(name: "tailMiddle", length: 0.24, width: 2, opacity: 0.6, colour: hot),
        Part(name: "tailShort", length: 0.12, width: 2.2, opacity: 0.85, colour: "#d6f2b0"),
        Part(name: "halo", length: 0.07, width: 10, opacity: 0.2, colour: amber),
        Part(name: "head", length: 0.07, width: 2.6, opacity: 1, colour: amber),
    ]

    struct Massif {
        var salt: Int
        var step, maximumHeight, leftCentre, leftHalfWidth, leftScale, rightCentre, rightHalfWidth, fallLineAbove, fallLineOpacity: Double
        var colour: String
        var width, opacity: Double
        var dots: Bool
        var traceDelays: [Double]
        var restBeamSide: Int
        var seconds, delay, reach: Double
    }

    struct Layout {
        var horizon: Double
        var vanishX: Double
        var moon: (Double, Double, Double)
        var middle: Massif
        var near: Massif
        var star: @Sendable (Int) -> (Double, Double)
        /// La part gardée du sol et de l'horizon sous le texte.
        var columnLow: (floor: Double, horizon: Double)
        var tube: (Double, Double, Double, Double)

        static let original = Layout(
            horizon: 745, vanishX: 1230, moon: (1268, 306, 30),
            middle: Massif(salt: 11, step: 62, maximumHeight: 345, leftCentre: 350, leftHalfWidth: 200, leftScale: 0.4, rightCentre: 1420, rightHalfWidth: 330, fallLineAbove: 60, fallLineOpacity: 0.7, colour: warm, width: 1.2, opacity: 0.36, dots: false, traceDelays: [42, 102], restBeamSide: -1, seconds: 120, delay: 70, reach: 15),
            near: Massif(salt: 29, step: 50, maximumHeight: 200, leftCentre: 60, leftHalfWidth: 340, leftScale: 0.6, rightCentre: 1590, rightHalfWidth: 310, fallLineAbove: 40, fallLineOpacity: 0.6, colour: hot, width: 1.3, opacity: 0.5, dots: true, traceDelays: [72, 12], restBeamSide: 1, seconds: 120, delay: 5, reach: 40),
            star: { index in
                let onLeft = index % 2 == 0
                return (round(onLeft ? 20 + hash(index, 101) * 400 : 1205 + hash(index, 101) * 375), round(16 + hash(index, 103) * 470))
            },
            columnLow: (0.13, 0.12), tube: (800, 480, 1180, 760)
        )

        /// L'horizon descend aux quatre cinquièmes ; les massifs montent aux deux
        /// bords jusque sous le texte ; la lune et les étoiles vont en haut.
        static func portrait(_ w: Double, _ h: Double) -> Layout {
            Layout(
                horizon: h * 0.82, vanishX: w * 0.62, moon: (w * 0.8, h * 0.075, 26),
                middle: Massif(salt: 11, step: 62, maximumHeight: h * 0.15, leftCentre: w * 0.12, leftHalfWidth: w * 0.36, leftScale: 0.55, rightCentre: w * 0.92, rightHalfWidth: w * 0.42, fallLineAbove: 50, fallLineOpacity: 0.7, colour: warm, width: 1.2, opacity: 0.36, dots: false, traceDelays: [42, 102], restBeamSide: -1, seconds: 120, delay: 70, reach: 15),
                near: Massif(salt: 29, step: 50, maximumHeight: h * 0.09, leftCentre: -w * 0.02, leftHalfWidth: w * 0.42, leftScale: 0.7, rightCentre: w * 1.02, rightHalfWidth: w * 0.4, fallLineAbove: 34, fallLineOpacity: 0.6, colour: hot, width: 1.3, opacity: 0.5, dots: true, traceDelays: [72, 12], restBeamSide: 1, seconds: 120, delay: 5, reach: 30),
                star: { index in (round(16 + hash(index, 101) * (w - 32)), round(12 + hash(index, 103) * h * 0.17)) },
                columnLow: (0.7, 0.7), tube: (w * 0.5, h * 0.42, w * 1.1, h * 0.5)
            )
        }
    }

    let width: Double
    let height: Double
    let layout: Layout
    var horizon: Double { layout.horizon }

    static func hash(_ index: Int, _ salt: Int) -> Double {
        var value = (Int32(truncatingIfNeeded: index) &* 374_761_393) &+ (Int32(truncatingIfNeeded: salt) &* 668_265_263)
        value = (value ^ Int32(bitPattern: UInt32(bitPattern: value) >> 13)) &* 1_274_126_177
        value ^= Int32(bitPattern: UInt32(bitPattern: value) >> 16)
        return Double(UInt32(bitPattern: value)) / 4_294_967_296
    }

    static func round(_ value: Double) -> Double { JS.round(value * 10) / 10 }

    static func lobe(_ x: Double, _ centre: Double, _ half: Double) -> Double {
        let distance = abs(x - centre) / half
        if distance >= 1 { return 0 }
        let inner = 1 - distance * distance
        return inner * inner
    }

    /// Une ligne tracée trois fois, la plus large et la plus pâle d'abord : tout
    /// le halo, sans filtre.
    static func glow(_ path: PathData, _ colour: Paint, _ width: Double, _ opacity: Double) -> [Node] {
        [
            Node.path(path).stroke(colour, width: round(width * 8), opacity: JS.round(opacity * 7) / 100),
            Node.path(path).stroke(colour, width: round(width * 3.2), opacity: JS.round(opacity * 20) / 100),
            Node.path(path).stroke(colour, width: width, opacity: opacity),
        ]
    }

    static func trace(_ path: PathData, delay: Double, shownAtRest: Bool) -> [Node] {
        parts.map { part in
            let end = round((part.length - travel) * 1000) / 1000
            let run = Animation([
                .init(0, [.dashOffset: .n(part.length)]), .init(0.25, [.dashOffset: .n(end)]), .init(1, [.dashOffset: .n(end)]),
            ], duration: cycle, delay: -delay, timing: .cubic(0.3, 0.1, 0.7, 0.9))
            let rest = JS.round((part.length - (shownAtRest ? restAt : travel)) * 1000) / 1000
            return Node.path(path).pathLength(1).stroke(Paint(part.colour), width: part.width, opacity: part.opacity, cap: .round)
                .dash([part.length, 3], offset: rest).animate(run)
        }
    }

    /// Un massif : haut sur un bord ou les deux, plus rien vers le milieu.
    func massif(_ layer: Massif) -> Node {
        struct Vertex {
            var x, height: Double
            var summit: Bool
        }
        var vertices: [Vertex] = []
        var index = 0
        var x = -260.0
        while x <= width + 260 {
            let jittered = x + (Self.hash(index, layer.salt) - 0.5) * layer.step * 0.5
            let envelope = Self.lobe(jittered, layer.leftCentre, layer.leftHalfWidth) * layer.leftScale + Self.lobe(jittered, layer.rightCentre, layer.rightHalfWidth)
            let saddle = index % 2 == 1 ? 0.6 : 1
            let roughness = 0.55 + 0.45 * Self.hash(index, layer.salt + 7)
            let h = envelope * layer.maximumHeight * saddle * roughness
            vertices.append(Vertex(x: Self.round(jittered), height: Self.round(h < 6 ? 0 : h), summit: index % 2 == 0))
            index += 1
            x += layer.step
        }
        let top = vertices.map { (x: $0.x, y: Self.round(horizon - $0.height)) }
        var cover: [PathData.Command] = top.enumerated().map { $0.offset == 0 ? .move($0.element.x, $0.element.y) : .line($0.element.x, $0.element.y) }
        cover += [.line(width + 400, horizon), .line(-400, horizon), .close]

        var ridge: [PathData.Command] = []
        var penDown = false
        for (position, vertex) in vertices.enumerated() {
            let next = position + 1 < vertices.count ? vertices[position + 1] : nil
            let flat = vertex.height == 0 && (next == nil || next!.height == 0)
            if flat && !penDown { continue }
            ridge.append(penDown ? .line(top[position].x, top[position].y) : .move(top[position].x, top[position].y))
            penDown = !flat
        }
        var traced: [[PathData.Command]] = []
        penDown = false
        for (position, vertex) in vertices.enumerated() {
            let next = position + 1 < vertices.count ? vertices[position + 1] : nil
            let flat = vertex.height == 0 && (next == nil || next!.height == 0)
            let outside = vertex.x < -90 || vertex.x > width + 90
            if outside || (flat && !penDown) {
                penDown = false
                continue
            }
            if penDown { traced[traced.count - 1].append(.line(top[position].x, top[position].y)) } else { traced.append([.move(top[position].x, top[position].y)]) }
            penDown = !flat
        }

        var falls: [PathData.Command] = [], dots: [PathData.Command] = [], lit: [PathData.Command] = []
        for (position, vertex) in vertices.enumerated() where vertex.summit && vertex.height >= layer.fallLineAbove {
            let side = Self.hash(position, layer.salt + 13) < 0.5 ? -1.0 : 1.0
            let lean = side * (0.55 + 0.4 * Self.hash(position, layer.salt + 19)) * layer.step
            let shoulderX = Self.round(vertex.x + lean * 0.5)
            let shoulderY = Self.round(horizon - vertex.height * (0.38 + 0.2 * Self.hash(position, layer.salt + 17)))
            let footX = Self.round(vertex.x + lean * 1.25)
            let summit = top[position]
            falls += [.move(summit.x, summit.y), .line(shoulderX, shoulderY), .line(footX, horizon)]
            dots += [.move(summit.x, summit.y), .line(summit.x, summit.y)]
            if position + 1 < vertices.count {
                let saddle = vertices[position + 1]
                lit += [.move(summit.x, summit.y), .line(top[position + 1].x, top[position + 1].y), .line(min(footX, saddle.x), horizon), .line(min(shoulderX, saddle.x), shoulderY), .close]
            }
        }
        var nodes: [Node] = [
            Node.path(PathData(cover)).fill("url(#sky)").stroke(.none),
            Node.path(PathData(lit)).fill("#9fe8cf", opacity: 0.055).stroke(.none),
            Node.path(PathData(falls)).stroke(Paint(Self.cold), width: 1, opacity: layer.fallLineOpacity),
        ]
        nodes += Self.glow(PathData(ridge), Paint(layer.colour), layer.width, layer.opacity)
        if layer.dots { nodes.append(Node.path(PathData(dots)).stroke(Paint(Self.hot), width: 2.6, opacity: 0.6, cap: .round)) }
        // Les tirets repartent à chaque sous-chemin : chaque côté a son faisceau.
        for (side, part) in traced.enumerated() {
            nodes += Self.trace(PathData(part), delay: side < layer.traceDelays.count ? layer.traceDelays[side] : 0, shownAtRest: side == layer.restBeamSide)
        }
        let sway = Animation.between([.transform: .t(.translate(-layer.reach, 0))], [.transform: .t(.translate(layer.reach, 0))], duration: layer.seconds, delay: -layer.delay, direction: .alternate, timing: .easeInOut)
        return Node.group(nodes).animate(sway)
    }

    /// La chaîne lointaine : des collines basses tout le long de l'horizon, qui
    /// se répètent exactement, pour dériver sans fin.
    func farRange() -> Node {
        let tile = Self.farStep * Double(Self.farCount)
        var ridge: [PathData.Command] = []
        var index = 0
        while Double(index) * Self.farStep <= width + tile + 200 {
            let wrapped = index % Self.farCount
            let x = Self.round(-100 + Double(index) * Self.farStep + (Self.hash(wrapped, 3) - 0.5) * Self.farStep * 0.4)
            let h = Self.round((wrapped % 2 == 1 ? 8 : 20) + Self.hash(wrapped, 5) * 20)
            ridge.append(index == 0 ? .move(x, horizon - h) : .line(x, horizon - h))
            index += 1
        }
        let cover = PathData(ridge + [.line(width + tile + 300, horizon), .line(-100, horizon), .close])
        let drift = Animation.between([.transform: .t(.translate(0, 0))], [.transform: .t(.translate(-tile, 0))], duration: 520, timing: .linear)
        return Node.group([
            Node.path(cover).fill("url(#sky)").stroke(.none),
            Node.path(PathData(ridge)).stroke(Paint(Self.cold), width: 1.1, opacity: 0.4),
        ]).animate(drift)
    }

    func crossY(_ depth: Double) -> Double { Self.round(horizon + (height - horizon) * Self.nearDepth / depth) }

    func groundGrid() -> [Node] {
        var rays: [PathData.Command] = []
        let scale = width / 1600
        var foot = -2200.0
        while foot <= 3400 {
            rays += [.move(layout.vanishX, horizon), .line(Self.round(layout.vanishX + foot * scale * 1.2), Self.round(horizon + (height - horizon) * 1.2))]
            foot += 400
        }
        let total = Double(Self.crossLines + 1)
        var frames: [Animation.Keyframe] = []
        for step in 0...(Self.crossLines + 1) * 4 {
            let travelled = Double(step) / 4
            let depth = Self.nearDepth + Double(Self.crossLines) - travelled
            if depth >= 5 && step % 4 != 0 { continue }
            frames.append(.init(Self.round(travelled / total * 100) / 100, [.transform: .t(.translate(0, crossY(depth)))]))
        }
        let creep = Animation(frames, duration: total * Self.creepSeconds, timing: .linear)
        var nodes: [Node] = [Node.path(PathData(rays)).strokeOpacity(0.85)]
        for line in 0...Self.crossLines {
            let y = crossY(Self.nearDepth + Double(line))
            nodes.append(Node.path(PathData([.move(-100, 0), .line(width + 100, 0)])).translate(0, y).animate(creep.delayed(-Double(Self.crossLines - line) * Self.creepSeconds)))
        }
        return [Node.group(nodes).stroke("url(#floorStroke)", width: 1.2), Node.rect(0, horizon, width, 170).fill("url(#haze)")]
    }

    func crescent() -> [Node] {
        let (cx, cy, r) = layout.moon
        let topX = Self.round(cx - r * 0.5), topY = Self.round(cy - r * 0.866)
        let bottomX = Self.round(cx + r * 0.866), bottomY = Self.round(cy + r * 0.5)
        let inner = Self.round(r * 1.55)
        return Self.glow(PathData(svg: "M\(topX) \(topY)A\(r) \(r) 0 0 1 \(bottomX) \(bottomY)A\(inner) \(inner) 0 0 0 \(topX) \(topY)Z"), Paint(Self.amber), 1.25, 0.5)
    }

    func stars() -> Node {
        var small: [PathData.Command] = [], large: [PathData.Command] = [], middling: [PathData.Command] = []
        var breathing: [Node] = []
        let breathe = Animation([.init(0, [.strokeOpacity: .n(0.12)]), .init(0.5, [.strokeOpacity: .n(1)]), .init(1, [.strokeOpacity: .n(0.12)])], duration: 9, timing: .easeInOut)
        for index in 0..<64 {
            let (x, y) = layout.star(index)
            if hypot(x - layout.moon.0, y - layout.moon.1) < layout.moon.2 + 60 { continue }
            let dot: [PathData.Command] = [.move(x, y), .line(x, y)]
            if index % 4 == 1 {
                breathing.append(Node.path(PathData(dot)).strokeOpacity(0.55)
                    .animate(breathe.lasting(7 + Double((index % 5) * 3)).delayed(-Self.round(Self.hash(index, 113) * 9))))
            } else if index % 3 == 0 {
                large += dot
            } else if index % 3 == 2 {
                middling += dot
            } else {
                small += dot
            }
        }
        return Node.group([
            Node.path(PathData(small)).strokeWidth(1.9).strokeOpacity(0.45),
            Node.path(PathData(middling)).strokeWidth(2.4).strokeOpacity(0.6),
            Node.path(PathData(large)).strokeWidth(3).strokeOpacity(0.75),
            Node.group(breathing).strokeWidth(3.2),
        ]).stroke(Paint(Self.warm)).lineCap(.round)
    }

    func fadeStroke(_ scene: inout Scene, _ name: String, _ colour: String, _ low: Double) {
        let half = Self.round((1 + low) / 2)
        scene.linear(name, x1: 0, y1: 0, x2: width, y2: 0, units: .user, [
            (0, colour, 1), (0.12, colour, 1), (0.24, colour, half), (0.36, colour, low), (0.64, colour, low), (0.76, colour, half), (0.88, colour, 1), (1, colour, 1),
        ])
    }

    static func build(width: Double, height: Double) -> Scene {
        VectorRange(width: width, height: height, layout: .portrait(width, height)).scene()
    }

    static func original() -> Scene {
        VectorRange(width: 1600, height: 1000, layout: .original).scene()
    }

    func scene() -> Scene {
        var scene = Scene(width: width, height: height)
        scene.linear("sky", x1: 0, y1: 0, x2: 0, y2: horizon, units: .user, [(0, Self.skyTop, 1), (1, Self.skyLow, 1)])
        scene.linear("ground", [(0, Self.groundFar, 1), (1, Self.groundNear, 1)])
        scene.linear("afterglow", [(0, "#16473a", 0), (0.35, "#16473a", 0.06), (0.65, "#16473a", 0.2), (0.85, "#16473a", 0.36), (1, "#16473a", 0.5)])
        scene.linear("haze", [(0, Self.groundFar, 1), (0.25, Self.groundFar, 0.95), (0.6, Self.groundFar, 0.5), (1, Self.groundFar, 0)])
        scene.radial("tube", [(0, "#1f5547", 0.34), (0.4, "#1f5547", 0.28), (0.75, "#1f5547", 0.16), (1, "#1f5547", 0)])
        fadeStroke(&scene, "floorStroke", "#2f9a82", layout.columnLow.floor)
        fadeStroke(&scene, "horizonStroke", Self.warm, layout.columnLow.horizon)

        scene.add(.rect(0, 0, width, horizon).fill("url(#sky)"))
        scene.add(.rect(0, horizon, width, height - horizon).fill("url(#ground)"))
        scene.add(stars())
        scene.add(crescent())
        scene.add(.rect(0, horizon - 270, width, 270).fill("url(#afterglow)"))
        scene.add(groundGrid())
        scene.add(farRange())
        scene.add(Self.glow(PathData([.move(-100, horizon), .line(width + 100, horizon)]), "url(#horizonStroke)", 1, 0.28))
        scene.add(massif(layout.middle))
        scene.add(massif(layout.near))
        let t = layout.tube
        scene.add(.ellipse(t.0, t.1, t.2, t.3).fill("url(#tube)"))
        // `path{fill:none}` : seuls les fonds qui le disent se remplissent.
        scene.nodes = [Node.group(scene.nodes).fill(.none)]
        return scene
    }
}
