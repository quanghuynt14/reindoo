import Foundation

// Blueprint : une feuille de cyanotype avec un seul dessin vivant. L'orbite
// d'une comète autour d'un soleil, dans un arc gradué ouvert. La comète la
// parcourt vite près du soleil, lentement au loin (le temps de Kepler), sa
// queue à l'opposé du soleil, une traînée d'encre derrière elle.
// D'après theme-examples (Anthropic, Apache 2.0), scenes/blueprint.ts.

struct Blueprint {
    static let chalk = "#cfe0f5"
    static let gold = "#f2c14e"
    static let nearest = 66.0
    static let farthest = 300.0
    static let period = 180.0
    static let trailLongest = 0.18

    struct Layout {
        var sun: (Double, Double)
        var pools: [(Double, Double, Double, Double)]
        var ramp: (x2: Double, y2: Double, stops: [Double])

        static let original = Layout(
            sun: (1440, 830),
            pools: [(-40, -40, 720, 520), (1660, -60, 640, 460), (1700, 1080, 600, 480), (-80, 1080, 560, 420)],
            ramp: (1, 0, [0, 0.1, 0.32, 0.7, 0.92, 1])
        )

        /// Le dessin entier sous les boutons, en bas à droite ; la grille ne
        /// garde qu'un fantôme dans la bande du texte.
        static func portrait(_ w: Double, _ h: Double) -> Layout {
            Layout(
                sun: (w - 160, h - 170),
                pools: [(-40, -40, w * 0.9, h * 0.25), (w + 60, -60, w * 0.8, h * 0.22), (w + 100, h + 80, w * 0.75, h * 0.28), (-80, h + 80, w * 0.7, h * 0.25)],
                ramp: (0, 1, [0, 0.1, 0.2, 0.64, 0.76, 1])
            )
        }
    }

    let width: Double
    let height: Double
    let layout: Layout
    var sunX: Double { layout.sun.0 }
    var sunY: Double { layout.sun.1 }

    static func round(_ value: Double) -> Double { JS.round(value * 10) / 10 }

    static func hash(_ seed: Double) -> Double {
        let value = sin(seed * 127.1 + 311.7) * 43_758.5453
        return value - value.rounded(.down)
    }

    static func pointAt(_ cx: Double, _ cy: Double, _ r: Double, _ degrees: Double) -> (Double, Double) {
        let a = degrees * .pi / 180
        return (round(cx + r * cos(a)), round(cy + r * sin(a)))
    }

    static func arc(_ cx: Double, _ cy: Double, _ r: Double, _ from: Double, _ to: Double) -> String {
        let a = pointAt(cx, cy, r, from), b = pointAt(cx, cy, r, to)
        return "M\(a.0) \(a.1)A\(r) \(r) 0 0 \(to > from ? 1 : 0) \(b.0) \(b.1)"
    }

    static func circle(_ cx: Double, _ cy: Double, _ r: Double) -> String {
        "M\(cx - r) \(cy)a\(r) \(r) 0 1 0 \(r * 2) 0a\(r) \(r) 0 1 0 \(-r * 2) 0"
    }

    static func ticks(_ cx: Double, _ cy: Double, _ inner: Double, _ longInner: Double, _ outer: Double, _ step: Double, _ longEvery: Int, _ from: Double, _ to: Double) -> String {
        var path = ""
        var degrees = from
        while degrees <= to {
            let start = Int(degrees / step) % longEvery == 0 ? longInner : inner
            let a = pointAt(cx, cy, start, degrees), b = pointAt(cx, cy, outer, degrees)
            path += "M\(a.0) \(a.1)L\(b.0) \(b.1)"
            degrees += step
        }
        return path
    }

    /// Un point de l'ellipse de la comète. Le soleil en est un foyer ; le bout
    /// lointain pointe en haut à gauche.
    func cometPoint(_ turn: Double, _ stretch: Double) -> (Double, Double) {
        let semiMajor = (Self.nearest + Self.farthest) / 2
        let focus = semiMajor - Self.nearest
        let semiMinor = (semiMajor * semiMajor - focus * focus).squareRoot()
        let alongX = cos(225 * Double.pi / 180), alongY = sin(225 * Double.pi / 180)
        let acrossX = cos(315 * Double.pi / 180), acrossY = sin(315 * Double.pi / 180)
        let angle = turn * .pi / 180
        let along = focus + semiMajor * cos(angle) * stretch
        let across = semiMinor * sin(angle) * stretch
        return (sunX + along * alongX + across * acrossX, sunY + along * alongY + across * acrossY)
    }

    func cometEllipse() -> String {
        var path = ""
        var turn = 0.0
        while turn < 360 {
            let p = cometPoint(turn, 1)
            path += "\(path.isEmpty ? "M" : "L")\(Self.round(p.0)) \(Self.round(p.1))"
            turn += 4
        }
        return path + "z"
    }

    /// Où est la comète après une part de sa période : l'équation de Kepler,
    /// résolue par la méthode de Newton.
    static func turnAtTime(_ share: Double) -> Double {
        let semiMajor = (nearest + farthest) / 2
        let e = (semiMajor - nearest) / semiMajor
        let mean = 2 * Double.pi * share
        var anomaly = mean
        for _ in 0..<10 { anomaly -= (anomaly - e * sin(anomaly) - mean) / (1 - e * cos(anomaly)) }
        return anomaly * 180 / .pi + 180
    }

    func equalTimeMarks(_ count: Int) -> String {
        var path = ""
        for index in 0..<count {
            let turn = Self.turnAtTime(Double(index) / Double(count))
            let a = cometPoint(turn, 0.965), b = cometPoint(turn, 1.035)
            path += "M\(Self.round(a.0)) \(Self.round(a.1))L\(Self.round(b.0)) \(Self.round(b.1))"
        }
        return path
    }

    func shares() -> [Double] {
        var lengths = [0.0]
        var last = cometPoint(180, 1)
        for step in 1...360 {
            let p = cometPoint(180 + Double(step), 1)
            lengths.append(lengths[step - 1] + hypot(p.0 - last.0, p.1 - last.1))
            last = p
        }
        let whole = lengths[360]
        return lengths.map { $0 / whole }
    }

    static func share(_ shares: [Double], _ turn: Double) -> Double {
        let steps = turn - 180
        let whole = min(359, Int(steps.rounded(.down)))
        let before = whole >= 0 && whole < shares.count ? shares[whole] : 0
        let after = whole + 1 >= 0 && whole + 1 < shares.count ? shares[whole + 1] : 1
        return before + (after - before) * (steps - Double(whole))
    }

    func twoLapOrbit() -> String {
        var path = ""
        var turn = 180.0
        while turn <= 900 {
            let p = cometPoint(turn, 1)
            path += "\(path.isEmpty ? "M" : "L")\(Self.round(p.0)) \(Self.round(p.1))"
            turn += 4
        }
        return path
    }

    /// La course de la comète en images clés, à pas de temps égaux : chaque pose
    /// tourne un repère autour du soleil vers la comète.
    func cometAnimations(_ count: Int) -> (run: Animation, radius: Animation, bearing: Animation, trail: Animation) {
        var run: [Animation.Keyframe] = [], radius: [Animation.Keyframe] = [], bearing: [Animation.Keyframe] = [], trail: [Animation.Keyframe] = []
        var previous = 0.0
        let lap = shares()
        for index in 0...count {
            let p = cometPoint(Self.turnAtTime(Double(index) / Double(count)), 1)
            let distance = hypot(p.0 - sunX, p.1 - sunY)
            var degrees = atan2(p.1 - sunY, p.0 - sunX) * 180 / .pi
            while degrees < previous - 180 { degrees += 360 }
            while degrees > previous + 180 { degrees -= 360 }
            previous = degrees
            let offset = Self.round(Double(index) / Double(count) * 100) / 100
            let size = ((0.72 + 58 / distance) * 100).rounded() / 100
            let d = Self.round(degrees), r = Self.round(distance)
            run.append(.init(offset, [.transform: .t(.rotate(d), .translate(r, 0), .scale(size, size))]))
            radius.append(.init(offset, [.transform: .t(.rotate(d), .scale(r, 1))]))
            bearing.append(.init(offset, [.transform: .t(.rotate(d))]))
            let share = index == count ? 1 : Self.share(lap, Self.turnAtTime(Double(index) / Double(count)))
            trail.append(.init(offset, [.dashOffset: .n(((Self.trailLongest - 1 - share) * 10000).rounded() / 10000)]))
        }
        func make(_ frames: [Animation.Keyframe]) -> Animation {
            Animation(frames, duration: Self.period, delay: -JS.round(Self.period * 0.36), timing: .linear)
        }
        return (make(run), make(radius), make(bearing), make(trail))
    }

    func paper() -> [Node] {
        var nodes: [Node] = [Node.rect(0, 0, width, height).fill("#22508e")]
        nodes += layout.pools.map { Node.ellipse($0.0, $0.1, $0.2, $0.3).fill("url(#washDeep)") }
        nodes.append(.rect(0, 0, width, height).fill("url(#tooth)"))
        nodes.append(Node.rect(0, 0, width, height).fill("url(#minorGrid)").mask("notInColumn"))
        nodes.append(Node.rect(0, 0, width, height).fill("url(#oddMajorGrid)").mask("notInColumn"))
        nodes.append(Node.rect(0, 0, width, height).fill("url(#evenMajorGrid)").mask("fainterInColumn"))
        return nodes
    }

    static func tooth() -> [Node] {
        (0..<46).map { index in
            let i = Double(index)
            let x = round(hash(i + 3) * 160), y = round(hash(i + 71) * 160)
            let light = hash(i + 131) > 0.45
            return Node.rect(x, y, light ? 1.2 : 1.6, 1.2).fill(Paint(light ? "#dce8f7" : "#0b2347")).opacity(light ? 0.07 : 0.1)
        }
    }

    func drawing() -> [Node] {
        let (x, y) = (sunX, sunY)
        let scale = Self.arc(x, y, 318, 160, 290) + Self.arc(x, y, 330, 160, 290) + Self.ticks(x, y, 322, 313, 330, 5, 3, 160, 290)
        let fine = Node.path("").fill(.none).stroke(Paint(Self.chalk), width: 0.8).opacity(0.2)
        func withPath(_ node: Node, _ d: String) -> Node {
            var copy = node
            copy.content = .path(PathData(svg: d))
            return copy
        }
        let orbit = Animation.between([.transform: .t(.rotate(0))], [.transform: .t(.rotate(-360))], duration: 600, delay: Self.round(-((360 - 250) / 360) * 120), timing: .linear)
        return [
            withPath(fine, "M\(x - 346) \(y)H\(x + 96)M\(x) \(y - 346)V\(y + 96)").dash([26, 5, 4, 5]),
            Node.path(Self.circle(x, y, 66)).fill(.none).stroke(Paint(Self.chalk), width: 1.1).opacity(0.26),
            Node.path(scale).fill(.none).stroke("url(#scaleFade)", width: 1.4).opacity(0.46),
            Node.path(cometEllipse()).fill(.none).stroke(Paint(Self.chalk), width: 1.4).opacity(0.5),
            withPath(fine, equalTimeMarks(12)),
            Node.circle(x, y, 11).fill(.none).stroke(Paint(Self.chalk), width: 1.5).opacity(0.7),
            Node.circle(x, y, 4).fill("#dce8f7").opacity(0.9),
            Node.group([Node.group([Node.circle(x + 66, y, 4.5).fill("#dce8f7")]).origin(x, y).animate(orbit.lasting(120))]).opacity(0.85),
        ]
    }

    func comet() -> [Node] {
        let (run, radius, bearing, trail) = cometAnimations(120)
        let orbitTwice = twoLapOrbit()
        let rest = cometPoint(Self.turnAtTime(0.42), 1)
        let restShare = Self.share(shares(), Self.turnAtTime(0.42))
        func layer(_ share: Double, _ width: Double, _ opacity: Double) -> Node {
            let gap = ((Self.trailLongest - share) * 100).rounded() / 100
            return Node.path(PathData(svg: orbitTwice)).pathLength(2).fill(.none).stroke(Paint(Self.gold), width: width).opacity(opacity)
                .dash([0, gap, share, 3], offset: ((Self.trailLongest - 1 - restShare) * 1000).rounded() / 1000).animate(trail)
        }
        let restDistance = Self.round(hypot(rest.0 - sunX, rest.1 - sunY))
        let restDegrees = Self.round(atan2(rest.1 - sunY, rest.0 - sunX) * 180 / .pi)
        return [
            layer(0.18, 1.6, 0.2), layer(0.11, 2, 0.25), layer(0.05, 2.6, 0.35),
            Node.path("M\(sunX) \(sunY)h1").fill(.none).stroke(Paint(Self.chalk), width: 1).opacity(0.16)
                .transform(.rotate(restDegrees), .scale(restDistance, 1)).origin(sunX, sunY).animate(radius),
            Node.path("M\(sunX + 311) \(sunY)h16").fill(.none).stroke(Paint(Self.gold), width: 2).opacity(0.75)
                .transform(.rotate(restDegrees)).origin(sunX, sunY).animate(bearing),
            Node.group([
                Node.path("M\(sunX + 2) \(sunY - 3.4)L\(sunX + 58) \(sunY)L\(sunX + 2) \(sunY + 3.4)z").fill("url(#tailFade)"),
                Node.circle(sunX, sunY, 5).fill("#ffe08a"),
            ]).transform(.rotate(restDegrees), .translate(restDistance, 0)).origin(sunX, sunY).animate(run),
        ]
    }

    static func build(width: Double, height: Double) -> Scene {
        Blueprint(width: width, height: height, layout: .portrait(width, height)).scene()
    }

    static func original() -> Scene {
        Blueprint(width: 1600, height: 1000, layout: .original).scene()
    }

    func scene() -> Scene {
        var scene = Scene(width: width, height: height)
        let c = Self.chalk
        scene.radial("washDeep", [(0, "#0e2c58", 0.78), (0.4, "#0e2c58", 0.46), (0.72, "#0e2c58", 0.15), (1, "#0e2c58", 0)])
        let from = Self.pointAt(sunX, sunY, 324, 160), to = Self.pointAt(sunX, sunY, 324, 290)
        scene.linear("scaleFade", x1: from.0, y1: from.1, x2: to.0, y2: to.1, units: .user, [(0, c, 0), (0.16, c, 1), (0.84, c, 1), (1, c, 0)])
        scene.linear("tailFade", x1: 0, y1: 0, x2: 1, y2: 0, [(0, Self.gold, 0.95), (0.5, Self.gold, 0.45), (1, Self.gold, 0)])
        scene.define("tooth", .pattern(Pattern(width: 160, height: 160, nodes: Self.tooth())))
        scene.define("minorGrid", .pattern(Pattern(width: 100, height: 100, nodes: [
            Node.path("M20.5 0v100M40.5 0v100M60.5 0v100M80.5 0v100M0 20.5h100M0 40.5h100M0 60.5h100M0 80.5h100").fill(.none).stroke(Paint(c), opacity: 0.07),
        ])))
        scene.define("oddMajorGrid", .pattern(Pattern(width: 200, height: 200, nodes: [Node.path("M100.5 0v200M0 100.5h200").fill(.none).stroke(Paint(c), opacity: 0.14)])))
        scene.define("evenMajorGrid", .pattern(Pattern(width: 200, height: 200, nodes: [Node.path("M.5 0v200M0 .5h200").fill(.none).stroke(Paint(c), opacity: 0.14)])))
        for (name, inside) in [("notInColumnRamp", 0.0), ("fainterInColumnRamp", 0.35)] {
            let s = layout.ramp.stops
            scene.linear(name, x1: 0, y1: 0, x2: layout.ramp.x2, y2: layout.ramp.y2, [(s[0], "#fff", 1), (s[1], "#fff", 1), (s[2], "#fff", inside), (s[3], "#fff", inside), (s[4], "#fff", 1), (s[5], "#fff", 1)])
        }
        scene.define("notInColumn", .mask(Mask(region: Rect(0, 0, width, height), nodes: [.rect(0, 0, width, height).fill("url(#notInColumnRamp)")])))
        scene.define("fainterInColumn", .mask(Mask(region: Rect(0, 0, width, height), nodes: [.rect(0, 0, width, height).fill("url(#fainterInColumnRamp)")])))
        scene.add(paper())
        scene.add(drawing())
        scene.add(comet())
        return scene
    }
}
