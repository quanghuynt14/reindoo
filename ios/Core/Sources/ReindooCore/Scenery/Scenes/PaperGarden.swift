import Foundation

// Paper Garden : des feuilles de papier découpé posées depuis les coins d'une
// feuille blanc chaud, et la même scène sur du kraft sombre. Chaque morceau est
// un contour coupé aux ciseaux, dessiné quatre fois : ombre lointaine, ombre
// proche, une lèvre claire en haut à gauche, puis le papier.
// D'après theme-examples (Anthropic, Apache 2.0), scenes/paper-garden.ts.

struct PaperGarden {
    typealias P = (Double, Double)

    /// 0 : le crème ; 1 : le kraft.
    let stock: Int
    let width: Double
    let height: Double
    let layout: Layout

    static let paints: [String: [String]] = [
        "ground": ["#efe8d8", "#24211d"], "page": ["#f8f3e9", "#2e2b26"], "fleck": ["#8f7c50", "#b8ad8c"],
        "shadow": ["#5c4a26", "#000000"], "lip": ["#ffffff", "#f3ecd9"], "pale": ["#d3dbc1", "#39432f"],
        "sage": ["#b4c29f", "#4b5f45"], "mid": ["#8ba274", "#5d7455"], "fern": ["#7f9b6c", "#62795a"],
        "olive": ["#6f8a5c", "#6f8566"], "coral": ["#dc6549", "#c9604a"], "coralLight": ["#e58267", "#e4846a"],
        "coralDark": ["#c65a42", "#b5503a"], "seed": ["#8a3a2c", "#6e2c21"],
    ]
    /// Les ombres et la lèvre, par papier : le papier sombre veut des ombres plus lourdes.
    static let tones: [[String: Double]] = [["far": 0.05, "near": 0.11, "edge": 0.38], ["far": 0.2, "near": 0.35, "edge": 0.14]]

    struct Motion {
        var name: String
        var lifting: Bool
        var seconds: Double
        var delay: Double
        var noLip: Bool
        static let still = Motion(name: "", lifting: false, seconds: 0, delay: 0, noLip: false)
    }

    enum Item {
        case single(shape: String, x: Double, y: Double, turn: Double, fill: String, lift: Double, seconds: Double, sway: String, lifting: Bool)
        case sprig(Sprig)
        case bloom
    }

    struct Sprig {
        var id, leaflet: String
        var length, bend, thick: Double
        var pairs: Int
        var bare, spread: Double
        var segments: Int
        var seed: Double
        var x, y, turn: Double
        var fill: String
        var lift, seconds: Double
        var sway: String
    }

    struct Layout {
        /// La feuille : debout (`vertical`, bords gauche et droit) ou couchée.
        var page: (vertical: Bool, from: Double, to: Double)
        var items: [Item]
        var bloom: (x: Double, y: Double)

        static let original = Layout(
            page: (true, 422, 1196),
            items: [
                .single(shape: "page", x: 0, y: 0, turn: 0, fill: "page", lift: 3, seconds: 0, sway: "sway", lifting: false),
                .single(shape: "leafGreat", x: 20, y: 1190, turn: 14, fill: "pale", lift: 4, seconds: 61, sway: "sway", lifting: true),
                .sprig(Sprig(id: "fern", leaflet: "paddle", length: 520, bend: 0.1, thick: 6, pairs: 4, bare: 0.26, spread: 56, segments: 3, seed: 11, x: 190, y: 1130, turn: -10, fill: "sage", lift: 5, seconds: 38, sway: "sway")),
                .single(shape: "leafMid", x: 1720, y: 330, turn: 244, fill: "pale", lift: 4, seconds: 23, sway: "swayBack", lifting: true),
                .sprig(Sprig(id: "under", leaflet: "coin", length: 300, bend: 0.14, thick: 4, pairs: 2, bare: 0.34, spread: 60, segments: 2, seed: 53, x: 1680, y: 318, turn: 222, fill: "sage", lift: 4, seconds: 19, sway: "swayWide")),
                .sprig(Sprig(id: "vine", leaflet: "coin", length: 390, bend: -0.1, thick: 4, pairs: 2, bare: 0.3, spread: 64, segments: 3, seed: 29, x: 1672, y: 282, turn: 203, fill: "fern", lift: 6, seconds: 14, sway: "swayWide")),
                .single(shape: "leafMid", x: 1600, y: 1150, turn: -12, fill: "pale", lift: 4, seconds: 29, sway: "swayBack", lifting: true),
                .single(shape: "bladeShort", x: 1630, y: 1060, turn: -26, fill: "fern", lift: 7, seconds: 11, sway: "swayWide", lifting: true),
                .single(shape: "bladeLong", x: 1680, y: 1090, turn: -44, fill: "mid", lift: 6, seconds: 17, sway: "swayWide", lifting: true),
                .bloom,
            ],
            bloom: (1440, 832)
        )

        /// La feuille est couchée derrière le texte, coupée en haut et en bas ;
        /// les branches pendent du coin en haut à droite, les herbes et la fleur
        /// montent des coins du bas.
        static func portrait(_ w: Double, _ h: Double) -> Layout {
            Layout(
                page: (false, h * 0.165, h * 0.69),
                items: [
                    .single(shape: "page", x: 0, y: 0, turn: 0, fill: "page", lift: 3, seconds: 0, sway: "sway", lifting: false),
                    .single(shape: "leafGreat", x: 10, y: h + 200, turn: 14, fill: "pale", lift: 4, seconds: 61, sway: "sway", lifting: true),
                    .sprig(Sprig(id: "fern", leaflet: "paddle", length: 480, bend: 0.1, thick: 6, pairs: 4, bare: 0.26, spread: 56, segments: 3, seed: 11, x: 170, y: h + 120, turn: -10, fill: "sage", lift: 5, seconds: 38, sway: "sway")),
                    .single(shape: "leafMid", x: w + 130, y: 110, turn: 244, fill: "pale", lift: 4, seconds: 23, sway: "swayBack", lifting: true),
                    .sprig(Sprig(id: "under", leaflet: "coin", length: 280, bend: 0.14, thick: 4, pairs: 2, bare: 0.34, spread: 60, segments: 2, seed: 53, x: w + 80, y: 90, turn: 222, fill: "sage", lift: 4, seconds: 19, sway: "swayWide")),
                    .sprig(Sprig(id: "vine", leaflet: "coin", length: 360, bend: -0.1, thick: 4, pairs: 2, bare: 0.3, spread: 64, segments: 3, seed: 29, x: w + 72, y: 50, turn: 203, fill: "fern", lift: 6, seconds: 14, sway: "swayWide")),
                    .single(shape: "leafMid", x: w, y: h + 150, turn: -12, fill: "pale", lift: 4, seconds: 29, sway: "swayBack", lifting: true),
                    .single(shape: "bladeShort", x: w + 30, y: h + 60, turn: -26, fill: "fern", lift: 7, seconds: 11, sway: "swayWide", lifting: true),
                    .single(shape: "bladeLong", x: w + 80, y: h + 90, turn: -44, fill: "mid", lift: 6, seconds: 17, sway: "swayWide", lifting: true),
                    .bloom,
                ],
                bloom: (w - 160, h - 210)
            )
        }
    }

    // MARK: Géométrie

    static func hash(_ a: Double, _ b: Double) -> Double {
        var h = Double(JS.uint32(JS.round(a) * 374_761_393 + JS.round(b) * 668_265_263))
        h = Double(JS.uint32(JS.xor(h, JS.ushr(h, 13)) * 1_274_126_177))
        return Double(JS.uint32(JS.xor(h, JS.ushr(h, 16)))) / 4_294_967_296
    }

    static func jitter(_ seed: Double, _ index: Double, _ spread: Double) -> Double {
        1 + (hash(seed, index) - 0.5) * 2 * spread
    }

    static func bend(_ p: P, _ length: Double, _ amount: Double) -> P {
        let height = max(0, -p.1 / length)
        return (p.0 + amount * length * height * height, p.1 + abs(amount) * length * height * height * 0.18)
    }

    static func cubic(_ p0: P, _ p1: P, _ p2: P, _ p3: P, _ t: Double) -> P {
        let u = 1 - t
        return (
            u * u * u * p0.0 + 3 * u * u * t * p1.0 + 3 * u * t * t * p2.0 + t * t * t * p3.0,
            u * u * u * p0.1 + 3 * u * u * t * p1.1 + 3 * u * t * t * p2.1 + t * t * t * p3.1
        )
    }

    static func polygon(_ corners: [P]) -> PathData {
        var commands: [PathData.Command] = []
        for (i, p) in corners.enumerated() {
            commands.append(i == 0 ? .move(JS.round(p.0), JS.round(p.1)) : .line(JS.round(p.0), JS.round(p.1)))
        }
        return PathData(commands + [.close])
    }

    /// Coupe un contour doux en petits coups de ciseaux droits.
    static func facet(_ points: [P], _ snip: Double, _ seed: Double) -> PathData {
        var corners: [P] = [points[0]]
        var i = 1
        while i + 2 < points.count {
            let p0 = points[i - 1], p1 = points[i], p2 = points[i + 1], p3 = points[i + 2]
            let span = hypot(p3.0 - p0.0, p3.1 - p0.1) + hypot(p1.0 - p0.0, p1.1 - p0.1) * 0.5
            let cuts = max(1, Int(JS.round(span / snip)))
            for k in 1...cuts {
                let p = cubic(p0, p1, p2, p3, Double(k) / Double(cuts))
                let wobble = k < cuts ? (hash(seed + Double(i), Double(k)) - 0.5) * snip * 0.07 : 0
                corners.append((p.0 + wobble, p.1 - wobble))
            }
            i += 3
        }
        return polygon(corners)
    }

    static func broadLeaf(_ length: Double, _ width: Double, _ amount: Double, _ seed: Double, _ veins: Int) -> PathData {
        let fat = jitter(seed, 1, 0.1)
        let outline: [P] = [
            (-4, 0), (-4, 0), (-4, -length * 0.1), (-3, -length * 0.16),
            (-width * 1.02 * fat, -length * 0.24), (-width * 0.74, -length * 0.8), (0, -length),
            (width * 0.7, -length * 0.78), (width * 1.06 / fat, -length * 0.3), (3, -length * 0.16),
            (4, -length * 0.1), (4, 0), (4, 0),
        ]
        var d = facet(outline.map { bend($0, length, amount) }, length / 9, seed)
        for i in 0..<veins {
            for side in [-1.0, 1.0] {
                let fi = Double(i), v = Double(veins)
                let from = -length * (0.3 + 0.5 * (fi + (side > 0 ? 0.5 : 0)) / v)
                let span = width * (0.56 - 0.24 * (fi / v)) * jitter(seed, fi * 2 + side + 5, 0.1)
                let rise = length * 0.12
                let gap = 5 + width * 0.03
                let cut: [P] = [
                    (side * 9, from),
                    (side * (9 + span * 0.4), from - rise * 0.2 - gap), (side * (9 + span * 0.8), from - rise * 0.7 - gap), (side * (9 + span), from - rise),
                    (side * (9 + span * 0.85), from - rise * 0.6 + gap), (side * (9 + span * 0.4), from - rise * 0.1 + gap), (side * 9, from),
                ]
                d = d + facet(cut.map { bend($0, length, amount) }, span / 2.5, seed + fi)
            }
        }
        return d
    }

    static func blade(_ length: Double, _ width: Double, _ amount: Double, _ seed: Double) -> PathData {
        let outline: [P] = [
            (-width * 0.25, 0), (-width * 0.7, -length * 0.2), (-width * 0.6, -length * 0.7), (0, -length),
            (width * 0.5, -length * 0.66), (width * 0.75, -length * 0.22), (width * 0.25, 0),
            (width * 0.25, 0), (-width * 0.25, 0), (-width * 0.25, 0),
        ]
        return facet(outline.map { bend($0, length, amount) }, length / 7, seed)
    }

    static func paddle(_ reach: Double, _ thickness: Double, _ seed: Double) -> PathData {
        let outline: [P] = [
            (0, thickness * 0.3),
            (reach * 0.3, thickness * 0.35), (reach * 0.96, thickness * 1.5), (reach, 0),
            (reach * 1.02, -thickness * 1.35), (reach * 0.34, -thickness * 0.45), (0, -thickness * 0.3),
            (0, -thickness * 0.3), (0, thickness * 0.3), (0, thickness * 0.3),
        ]
        return facet(outline, reach / 8, seed)
    }

    static func coin(_ radius: Double, _ seed: Double) -> PathData {
        let sides = 22
        var corners: [P] = [(0, 2), (radius * 0.35, 2)]
        for i in 1..<sides {
            let angle = .pi - Double(i) / Double(sides) * .pi * 2
            let reach = radius * jitter(seed, Double(i), 0.035)
            corners.append((radius * 1.3 + cos(angle) * reach, -sin(angle) * reach * 0.92))
        }
        corners += [(radius * 0.35, -2), (0, -2)]
        return polygon(corners)
    }

    /// La grande feuille : deux bords coupés à la main, un peu errants ; les
    /// deux autres hors du cadre.
    func page(_ seed: Double) -> PathData {
        let steps = 30
        var corners: [P] = []
        let (vertical, from, to) = layout.page
        let span = vertical ? 1080.0 : width + 80
        for i in 0...steps {
            let wander = (Self.hash(seed, Double(i)) - 0.5) * 7 + sin(Double(i) * 0.45 + seed) * 6
            let along = -40 + span * Double(i) / Double(steps)
            corners.append(vertical ? (from + wander, along) : (along, from + wander))
        }
        for i in stride(from: steps, through: 0, by: -1) {
            let wander = (Self.hash(seed + 5, Double(i)) - 0.5) * 6 + sin(Double(i) * 0.4 + seed) * 5
            let along = -40 + span * Double(i) / Double(steps)
            corners.append(vertical ? (to + wander, along) : (along, to + wander))
        }
        return Self.polygon(corners)
    }

    static func disc(_ radius: Double, _ scallops: Int, _ seed: Double) -> PathData {
        let sides = scallops * 4
        return polygon((0..<sides).map { i in
            let angle = Double(i) / Double(sides) * .pi * 2
            let reach = radius * (1 + 0.09 * cos(angle * Double(scallops) + seed)) * jitter(seed, Double(i), 0.035)
            return (cos(angle) * reach, sin(angle) * reach)
        })
    }

    static func fixed(_ value: Double) -> Double { (value * 10).rounded() / 10 }

    static func turned(_ x: Double, _ y: Double, _ degrees: Double) -> P {
        let a = degrees * .pi / 180
        return (fixed(x * cos(a) - y * sin(a)), fixed(x * sin(a) + y * cos(a)))
    }

    // MARK: Le papier

    func fill(_ name: String) -> Paint { Paint(Self.paints[name]![stock]) }

    func use(_ shape: String, _ offset: P, _ paint: String, _ tone: String?) -> Node {
        let node = Node.use(shape).translate(offset.0, offset.1).fill(fill(paint))
        return tone.map { node.opacity(Self.tones[stock][$0]!) } ?? node
    }

    static let animations: [String: SceneAnimation] = [
        "sway": .between([.transform: .t(.rotate(-2.4))], [.transform: .t(.rotate(2.8))], duration: 40, direction: .alternate, timing: .easeInOut),
        "swayWide": .between([.transform: .t(.rotate(-4))], [.transform: .t(.rotate(4.5))], duration: 20, direction: .alternate, timing: .easeInOut),
        "stir": .between([.transform: .t(.rotate(-7))], [.transform: .t(.rotate(8))], duration: 12, direction: .alternate, timing: .easeInOut),
        "open": .between([.transform: .t(.scale(0.95, 0.95), .rotate(-4))], [.transform: .t(.scale(1.05, 1.05), .rotate(5))], duration: 19, direction: .alternate, timing: .easeInOut),
        "openBack": .between([.transform: .t(.scale(0.98, 0.98), .rotate(3))], [.transform: .t(.scale(1.03, 1.03), .rotate(-3))], duration: 19, direction: .alternate, timing: .easeInOut),
        "swayBack": .between([.transform: .t(.translate(-5, 3), .rotate(1.6))], [.transform: .t(.translate(4, -4), .rotate(-1.8))], duration: 23, direction: .alternate, timing: .easeInOut),
        "flex": .between([.transform: .t(.rotate(-3))], [.transform: .t(.rotate(3.6))], duration: 17, direction: .alternate, timing: .easeInOut),
        "nod": .between([.transform: .t(.rotate(-9))], [.transform: .t(.rotate(7))], duration: 11, direction: .alternate, timing: .easeInOut),
    ]

    /// Un morceau de papier. `facing` dit de combien son repère est tourné, pour
    /// que l'ombre tombe toujours en bas à droite de la page.
    func paper(_ shape: String, _ place: [TransformOp], _ facing: Double, _ paint: String, _ lift: Double, _ motion: Motion) -> Node {
        let far = Self.turned(lift * 1.9, lift * 2.4, -facing)
        let near = Self.turned(lift * 0.9, lift * 1.15, -facing)
        let lip = Self.turned(-1.2, -1.2, -facing)
        var shadows = [use(shape, far, "shadow", "far"), use(shape, near, "shadow", "near")]
        if motion.lifting {
            let more = Self.turned(lift * 1.3, lift * 1.6, -facing)
            var lifting = SceneAnimation.between([.transform: .t(.translate(0, 0))], [.transform: .t(.translate(more.0, more.1))], duration: 14, direction: .alternate, timing: .easeInOut)
            if motion.seconds > 0 { lifting = lifting.lasting(motion.seconds) }
            shadows = [Node.group(shadows).animate(lifting.delayed(-motion.delay))]
        }
        let body = shadows + (motion.noLip ? [] : [use(shape, lip, "lip", "edge")]) + [use(shape, (0, 0), paint, nil)]
        var moving = Node.group(body)
        if !motion.name.isEmpty, let animation = Self.animations[motion.name] {
            moving = moving.animate(animation.lasting(motion.seconds).delayed(-motion.delay))
        }
        return Node.group([moving]).transform(place)
    }

    func stemPiece(_ item: Sprig, _ from: Double, _ to: Double) -> PathData {
        var left: [P] = [], right: [P] = []
        for k in 0...3 {
            let along = from + (to - from) * Double(k) / 3
            let half = item.thick * (1 - 0.8 * along) + 1
            left.append(Self.bend((-half, -along * item.length), item.length, item.bend))
            right.insert(Self.bend((half, -along * item.length), item.length, item.bend), at: 0)
        }
        return Self.polygon(left + right)
    }

    /// Une tige avec des folioles des deux côtés. La tige est coupée en segments
    /// qui plient chacun à leur jointure : le balancement s'ajoute vers la pointe.
    func sprig(_ item: Sprig, _ index: Int, into scene: inout SceneGraph) -> Node {
        let count = item.pairs * 2
        var pieces = Array(repeating: [Node](), count: item.segments)
        for i in 0...count {
            let fi = Double(i)
            let isTip = i == count
            let side = i % 2 == 0 ? -1.0 : 1.0
            let along = isTip ? 0.985 : item.bare + (1 - item.bare) * ((fi + 0.6) / (Double(count) + 1.4))
            let root = Self.bend((0, -along * item.length), item.length, item.bend)
            let lean = atan(2 * item.bend * along) * 180 / .pi
            let spread = (item.spread - 14 * along) * Self.jitter(item.seed, fi, 0.1)
            let angle = isTip ? lean - 90 : lean - 90 + side * spread
            let envelope = isTip ? 0.8 : 0.62 + 0.38 * sin(.pi * (0.12 + 0.7 * (fi / Double(count))))
            let scale = Self.fixed(envelope * Self.jitter(item.seed, fi + 30, item.leaflet == "coin" ? 0.22 : 0.08))
            let place: [TransformOp] = [.translate(JS.round(root.0), JS.round(root.1)), .rotate(Self.fixed(angle)), .scale(scale, scale)]
            let motion = Motion(name: "stir", lifting: true, seconds: 7 + 2 * JS.round(Self.hash(item.seed, fi + 50) * 3),
                                delay: Self.fixed(fi * 1.3 + Self.hash(item.seed, fi + 70) * 3), noLip: false)
            let segment = min(item.segments - 1, Int((along * Double(item.segments)).rounded(.down)))
            pieces[segment].append(paper(item.leaflet, place, item.turn + angle, item.fill, item.lift / scale, motion))
        }
        var body: [Node] = []
        for k in stride(from: item.segments - 1, through: 0, by: -1) {
            let from = Double(k) / Double(item.segments), to = Double(k + 1) / Double(item.segments)
            let id = "\(item.id)Stem\(k)"
            scene.define(id, .symbol(Node.path(stemPiece(item, from, min(1, to + 0.01))).evenOdd()))
            let joint = Self.bend((0, -from * item.length), item.length, item.bend)
            let inner = [paper(id, [], item.turn, item.fill, item.lift * 0.6, .still)] + pieces[k] + body
            if k == 0 {
                body = inner
            } else {
                let flex = Self.animations["flex"]!.lasting(11 + Double(k) * 6).delayed(-Self.fixed(Self.hash(item.seed, Double(k)) * 20))
                body = [Node.group(inner).origin(JS.round(joint.0), JS.round(joint.1)).animate(flex)]
            }
        }
        let sway = Self.animations[item.sway]!.lasting(item.seconds).delayed(-Self.fixed(Self.hash(Double(index), 7) * item.seconds))
        return Node.group([Node.group(body).transform(.translate(item.x, item.y), .rotate(item.turn))]).origin(item.x, item.y).animate(sway)
    }

    func single(_ item: Item, _ index: Int) -> Node {
        guard case let .single(shape, x, y, turn, paint, lift, seconds, sway, lifting) = item else { return .group([]) }
        let motion = Motion(name: "", lifting: lifting, seconds: 0, delay: Self.fixed(Self.hash(Double(index), 3) * 14), noLip: paint == "pale")
        let inner = paper(shape, [.translate(x, y), .rotate(turn)], turn, paint, lift, motion)
        if seconds == 0 { return inner }
        let animation = Self.animations[sway]!.lasting(seconds).delayed(-Self.fixed(Self.hash(Double(index), 7) * seconds))
        return Node.group([inner]).origin(x, y).animate(animation)
    }

    /// Trois disques découpés sur une tige effilée : la seule chose chaude de la feuille.
    func bloom() -> Node {
        let (x, y) = layout.bloom
        let rootX = x + 130, rootY = y + 268
        let stem = PathData([
            .move(rootX - 6, rootY), .line(x + 90, y + 168), .line(x + 44, y + 68), .line(x - 2, y), .line(x + 3, y),
            .line(x + 52, y + 64), .line(x + 100, y + 164), .line(rootX + 6, rootY), .close,
        ])
        let head = Node.group([
            paper("discBack", [.translate(-5, 4), .rotate(8)], 8, "coralDark", 4, Motion(name: "openBack", lifting: false, seconds: 19, delay: 3, noLip: false)),
            paper("discMiddle", [.translate(4, -3), .rotate(-14)], -14, "coral", 4, Motion(name: "open", lifting: false, seconds: 19, delay: 3, noLip: false)),
            paper("discFront", [.translate(-2, 2), .rotate(20)], 20, "coralLight", 3, Motion(name: "open", lifting: false, seconds: 19, delay: 1, noLip: false)),
            Node.circle(0, 0, 13).fill(fill("coralDark")), Node.circle(0, 0, 6).fill(fill("seed")),
        ]).transform(.scale(0.9, 0.9))
        let swayWide = Self.animations["swayWide"]!.lasting(23).delayed(-4)
        return Node.group([
            Node.path(stem).translate(4, 5).fill(fill("shadow")).opacity(Self.tones[stock]["near"]!),
            Node.path(stem).fill(fill("olive")),
            Node.group([Node.group([head]).animate(Self.animations["nod"]!)]).translate(x, y),
        ]).origin(rootX, rootY).animate(swayWide)
    }

    static func flecks() -> PathData {
        var d = ""
        for i in 0..<26 {
            let fi = Double(i)
            let x = JS.round(hash(fi, 1) * 168), y = JS.round(hash(fi, 2) * 206)
            let angle = hash(fi, 3) * .pi
            let reach = 2 + hash(fi, 4) * 3
            d += "M\(x) \(y)l\(fixed(cos(angle) * reach)) \(fixed(sin(angle) * reach))l1 1z"
        }
        return PathData(svg: d)
    }

    static func build(_ stock: Int) -> @Sendable (Double, Double) -> SceneGraph {
        { width, height in PaperGarden(stock: stock, width: width, height: height, layout: .portrait(width, height)).scene() }
    }

    static func original(_ stock: Int) -> @Sendable () -> SceneGraph {
        { PaperGarden(stock: stock, width: 1600, height: 1000, layout: .original).scene() }
    }

    func scene() -> SceneGraph {
        var scene = SceneGraph(width: width, height: height)
        let shapes: [(String, PathData)] = [
            ("leafGreat", Self.broadLeaf(660, 150, 0.16, 5, 4)), ("leafMid", Self.broadLeaf(440, 108, -0.2, 8, 3)),
            ("bladeLong", Self.blade(430, 30, 0.2, 4)), ("bladeShort", Self.blade(300, 24, -0.26, 6)),
            ("paddle", Self.paddle(150, 30, 12)), ("coin", Self.coin(31, 21)), ("page", page(7)),
            ("discBack", Self.disc(58, 5, 2)), ("discMiddle", Self.disc(45, 6, 5)), ("discFront", Self.disc(30, 5, 9)),
        ]
        for (id, path) in shapes { scene.define(id, .symbol(Node.path(path).evenOdd())) }
        scene.define("flecks", .pattern(Pattern(width: 173, height: 211, nodes: [Node.path(Self.flecks()).fill(fill("fleck")).opacity(0.09)])))
        scene.add(.rect(0, 0, width, height).fill(fill("ground")))
        scene.add(.rect(0, 0, width, height).fill("url(#flecks)"))
        for (index, item) in layout.items.enumerated() {
            switch item {
            case .bloom: scene.add(bloom())
            case .sprig(let sprig): scene.add(self.sprig(sprig, index, into: &scene))
            case .single: scene.add(single(item, index))
            }
        }
        return scene
    }
}
