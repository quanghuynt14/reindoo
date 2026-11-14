import Foundation

// Halftone Dawn et Halftone Dusk : un lever de soleil en risographie, deux
// encres, sur deux papiers. Chaque marque est un point rond sur une trame
// penchée ; la taille du point est le seul outil de dessin.
// D'après theme-examples (Anthropic, Apache 2.0), scenes/halftone-dawn.ts.

struct Halftone {
    static let pitch = 11.0
    static let screenDegrees = 15.0
    static let band = 12.0

    struct Wave {
        var seconds, length, rest, peak, sharp: Double
    }

    static let sunWave = Wave(seconds: 24, length: 132, rest: 0.8, peak: 1.32, sharp: 1.4)
    static let hillWave = Wave(seconds: 40, length: 560, rest: 1.03, peak: 0.7, sharp: 1.5)

    struct Stock {
        var paperTop, paperFoot, coral: String
        var coralOpacity: Double
        var blue: String
        var blueOpacity: Double
        var blend: BlendMode
    }

    /// Sur le crème, les encres se multiplient comme une vraie surimpression ;
    /// sur le papier sombre, elles se posent dessus.
    static let dawn = Stock(paperTop: "#f6ecdc", paperFoot: "#f2dcc6", coral: "#d45c3d", coralOpacity: 1, blue: "#6283b6", blueOpacity: 1, blend: .multiply)
    static let dusk = Stock(paperTop: "#1b1f30", paperFoot: "#272a3f", coral: "#d9603a", coralOpacity: 0.86, blue: "#7f90ba", blueOpacity: 0.7, blend: .normal)

    struct Layout {
        var sun: (x: Double, y: Double, radius: Double)
        var centre: (Double, Double)
        var reach: Double
        var away: @Sendable (Double) -> Double
        var far: @Sendable (Double) -> Double
        var near: @Sendable (Double) -> Double

        static var original: Layout {
            let away: @Sendable (Double) -> Double = { x in max(1 - smooth(300, 520, x), smooth(1080, 1260, x)) }
            return Layout(
                sun: (1408, 786, 220), centre: (800, 500), reach: 2000, away: away,
                far: { x in 968 - 34 * away(x) - bell(x, 150, 250, 205) - bell(x, 1600, 330, 135) - 13 * sin(x / 150 + 1) - 5 * sin(x / 53) },
                near: { x in 1014 - bell(x, -50, 270, 190) - bell(x, 1340, 250, 100) - 7 * sin(x / 90 + 2) }
            )
        }

        /// Le soleil se lève en bas à droite, derrière les collines ; une longue
        /// chaîne traverse le bas, des contreforts sombres aux deux bords.
        static func portrait(_ w: Double, _ h: Double) -> Layout {
            Layout(
                sun: (w * 0.78, h * 0.84, w * 0.36), centre: (w / 2, h / 2), reach: max(w, h) * 1.3,
                away: { _ in 1 },
                far: { x in h - 40 - bell(x, w * 0.08, w * 0.3, h * 0.17) - bell(x, w, w * 0.32, h * 0.1) - 13 * sin(x / 150 + 1) - 5 * sin(x / 53) },
                near: { x in h + 14 - bell(x, -w * 0.05, w * 0.32, h * 0.14) - bell(x, w * 0.86, w * 0.28, h * 0.07) - 7 * sin(x / 90 + 2) }
            )
        }
    }

    let width: Double
    let height: Double
    let layout: Layout
    let stock: Stock

    static func smooth(_ from: Double, _ to: Double, _ value: Double) -> Double {
        let t = min(1, max(0, (value - from) / (to - from)))
        return t * t * (3 - 2 * t)
    }

    static func bell(_ x: Double, _ peak: Double, _ half: Double, _ height: Double) -> Double {
        let t = (x - peak) / half
        return height * exp(-t * t)
    }

    func hillTone(_ x: Double, _ y: Double) -> Double {
        let near = 0.42 * Self.smooth(0, 36, y - layout.near(x)) - 0.12 * Self.smooth(36, 150, y - layout.near(x))
        let far = 0.21 * Self.smooth(0, 36, y - layout.far(x)) - 0.06 * Self.smooth(36, 160, y - layout.far(x))
        return max(near, far, 0) * (0.3 + 0.7 * layout.away(x))
    }

    func sunTone(_ x: Double, _ y: Double) -> Double {
        let sun = layout.sun
        let d = hypot(x - sun.x, y - sun.y)
        let behindHills = 1 - Self.smooth(2, 38, y - min(layout.far(x), layout.near(x)))
        let body = d < sun.radius ? 0.37 * (1 - pow(d / sun.radius, 4)) : 0
        let glow = 0.06 * pow(1 - Self.smooth(0, 150, d - sun.radius * 0.9), 1.3)
        return max(body, glow) * behindHills
    }

    /// Les points d'une encre, groupés par anneau (pour le retard de la vague) et
    /// par diamètre (une épaisseur de trait par chemin).
    func screen(_ tone: (Double, Double) -> Double, _ bandAt: (Double, Double) -> Double, _ wave: Wave, halfCell: Bool) -> [Node] {
        let turn = Self.screenDegrees * .pi / 180
        let c = cos(turn), s = sin(turn)
        let reach = Int((layout.reach / Self.pitch).rounded(.up))
        let offset = halfCell ? 0.5 : 0
        var order: [String] = []
        var groups: [String: (band: Double, width: Double, commands: [PathData.Command])] = [:]
        for i in -reach...reach {
            for j in -reach...reach {
                let fi = Double(i) + offset, fj = Double(j) + offset
                let x = layout.centre.0 + (fi * c - fj * s) * Self.pitch
                let y = layout.centre.1 + (fi * s + fj * c) * Self.pitch
                if x < -6 || x > width + 6 || y < -6 || y > height + 6 { continue }
                let diameter = 2 * Self.pitch * (tone(x, y) / .pi).squareRoot()
                if diameter < 2.3 { continue }
                let band = bandAt(x, y).rounded(.down)
                let w = JS.round(diameter * 2) / 2
                let key = "\(band)|\(w)"
                if groups[key] == nil {
                    order.append(key)
                    groups[key] = (band, w, [])
                }
                let px = (x * 10).rounded() / 10, py = (y * 10).rounded() / 10
                groups[key]!.commands += [.move(px, py), .line(px, py)]
            }
        }
        var frames: [Animation.Keyframe] = []
        for step in 0...12 {
            let pulse = pow((1 + cos(Double(step) / 12 * 2 * .pi)) / 2, wave.sharp)
            let scale = ((wave.rest + (wave.peak - wave.rest) * pulse) * 1000).rounded() / 1000
            frames.append(.init(((Double(step) * 100 / 12) * 100).rounded() / 100 / 100, [.strokeScale: .n(scale)]))
        }
        return order.map { key in
            let group = groups[key]!
            let lag = ((group.band + 0.5) * Self.band / wave.length).truncatingRemainder(dividingBy: 1)
            let delay = ((lag * wave.seconds - wave.seconds) * 100).rounded() / 100
            return Node.path(PathData(group.commands)).strokeWidth(group.width)
                .animate(Animation(frames, duration: wave.seconds, delay: delay, timing: .steps(4)))
        }
    }

    static func build(_ stock: Stock) -> @Sendable (Double, Double) -> Scene {
        { width, height in Halftone(width: width, height: height, layout: .portrait(width, height), stock: stock).scene() }
    }

    static func original(_ stock: Stock) -> @Sendable () -> Scene {
        { Halftone(width: 1600, height: 1000, layout: .original, stock: stock).scene() }
    }

    func scene() -> Scene {
        var scene = Scene(width: width, height: height)
        scene.linear("paper", [(0, stock.paperTop, 1), (1, stock.paperFoot, 1)])
        let sun = layout.sun
        let dots = screen(sunTone, { x, y in hypot(x - sun.x, y - sun.y) / Self.band }, Self.sunWave, halfCell: false)
        let hills = screen(hillTone, { x, _ in abs(sun.x - x) / Self.band }, Self.hillWave, halfCell: true)
        scene.add(.rect(0, 0, width, height).fill("url(#paper)"))
        scene.add(Node.group(dots).stroke(Paint(stock.coral), opacity: stock.coralOpacity).fill(.none).lineCap(.round).blend(stock.blend))
        scene.add(Node.group(hills).stroke(Paint(stock.blue), opacity: stock.blueOpacity).fill(.none).lineCap(.round).blend(stock.blend))
        return scene
    }
}
