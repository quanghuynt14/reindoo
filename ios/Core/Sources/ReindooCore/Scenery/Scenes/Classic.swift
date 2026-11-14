import Foundation

// Les trois premiers décors : sombres, doux, lents, faits de dégradés. Rien qui
// ressemble à du texte ; de grandes formes floues ; le milieu reste calme.
// D'après theme-examples (Anthropic, Apache 2.0), scenes/classic.ts.

enum Classic {
    static func soft(_ scene: inout Scene, _ name: String, _ color: String, _ peak: Double) {
        scene.radial(name, [(0, color, peak), (1, color, 0)])
    }

    /// Un voile très léger au milieu, pour que le centre ne soit jamais la
    /// partie la plus chargée.
    static func calm(_ scene: inout Scene) {
        scene.radial("calm", cx: 0.5, cy: 0.55, r: 0.6, [(0, "#000", 0.12), (0.6, "#000", 0.05), (1, "#000", 0)])
        scene.add(.rect(0, 0, scene.width, scene.height).fill("url(#calm)"))
    }

    // MARK: Deep Water

    static func deepWaterOriginal() -> Scene {
        let (width, height) = (1600.0, 1000.0)
        var scene = Scene(width: width, height: height)
        scene.linear("deep", [(0, "#0f6f86", 1), (0.45, "#0a4660", 1), (1, "#041c30", 1)])
        scene.linear("ray", x1: 0, y1: 0, x2: 1, y2: 0, [(0, "#bff3ff", 0), (0.5, "#bff3ff", 0.3), (1, "#bff3ff", 0)])
        scene.linear("down", [(0, "#fff", 1), (0.92, "#000", 1)])
        scene.define("fade", .mask(Mask(region: Rect(-400, -40, 2400, 900), nodes: [.rect(-400, -40, 2400, 900).fill("url(#down)")])))
        soft(&scene, "caustic", "#9fe9f5", 0.2)
        soft(&scene, "orb", "#c9f6ff", 0.22)
        soft(&scene, "glint", "#e8fdff", 0.3)

        let sway = Animation.between([.transform: .t(.skewX(-5))], [.transform: .t(.skewX(6))], duration: 38, direction: .alternate, timing: .easeInOut)
        let swayB = sway.lasting(52).directed(.alternateReverse)
        let drift = Animation.between([.transform: .t(.translate(-90, 0))], [.transform: .t(.translate(90, 0))], duration: 70, direction: .alternate, timing: .easeInOut)
        let driftB = drift.lasting(95).directed(.alternateReverse)
        let rise = Animation([
            .init(0, [.transform: .t(.translate(0, 0)), .opacity: .n(0)]),
            .init(0.12, [.opacity: .n(1)]),
            .init(0.85, [.opacity: .n(1)]),
            .init(1, [.transform: .t(.translate(0, -1150)), .opacity: .n(0)]),
        ], duration: 46, timing: .linear)
        let glide = Animation.between(
            [.transform: .t(.translate(0, 0), .rotate(-4))], [.transform: .t(.translate(-70, -26), .rotate(3))],
            duration: 80, direction: .alternate, timing: .easeInOut
        )

        scene.add(.rect(0, 0, 1600, 1000).fill("url(#deep)"))
        scene.add(.group([
            .group([.rect(0, -40, 460, 900).fill("url(#ray)").animate(sway).origin(800, 0)]).transform(.translate(-60, 0), .skewX(-14)),
            .group([.rect(0, -40, 520, 900).fill("url(#ray)").animate(swayB).origin(800, 0)]).transform(.translate(1180, 0), .skewX(11)),
            .group([.rect(0, -40, 420, 900).fill("url(#ray)").opacity(0.55).animate(swayB).origin(800, 0)]).transform(.translate(250, 0), .skewX(-20)),
        ]).mask("fade"))
        scene.add(.group([
            .ellipse(380, 130, 620, 70).fill("url(#caustic)"), .ellipse(1280, 170, 540, 56).fill("url(#caustic)"),
        ]).animate(drift))
        scene.add(.group([
            .ellipse(300, 900, 700, 80).fill("url(#caustic)"), .ellipse(1350, 880, 560, 64).fill("url(#caustic)"),
        ]).animate(driftB))
        scene.add(.group([.circle(70, 1060, 46).fill("url(#orb)")]).animate(rise.delayed(-4)))
        scene.add(.group([.circle(1535, 1080, 62).fill("url(#orb)"), .circle(1518, 1060, 15).fill("url(#glint)")]).animate(rise.delayed(-21)))
        scene.add(.group([.circle(1470, 1050, 30).fill("url(#orb)")]).animate(rise.delayed(-33)))
        scene.add(.group([.circle(150, 1070, 26).fill("url(#orb)")]).animate(rise.delayed(-14)))
        scene.add(.group([honu().animate(glide).opacity(0.5)]).translate(1300, 800))
        calm(&scene)
        return scene
    }

    /// La tortue de Deep Water, en silhouette.
    static func honu() -> Node {
        .group([
            .group([
                .ellipse(0, 0, 92, 62),
                .ellipse(108, -10, 30, 20),
                .path("M40 -52 q60 -64 104 -40 q-44 10 -78 62z"), .path("M36 52 q58 60 96 34 q-40 -6 -70 -54z"),
                .path("M-58 -44 q-52 -30 -70 -6 q38 0 56 34z"), .path("M-58 44 q-50 30 -66 8 q36 -2 54 -34z"),
                .path("M-92 0 l-30 6 l28 6z"),
            ]).fill("#0b3a4d"),
            .ellipse(0, 0, 70, 44).fill("#124d63"),
        ])
    }

    // MARK: Aurora

    static func auroraOriginal() -> Scene {
        let (width, height) = (1600.0, 1000.0)
        var scene = Scene(width: width, height: height)
        scene.linear("night", [(0, "#0c1136", 1), (0.55, "#090b22", 1), (1, "#05060f", 1)])
        soft(&scene, "green", "#5dffb5", 0.3)
        soft(&scene, "violet", "#9f7bff", 0.26)
        soft(&scene, "glow", "#3affc0", 0.2)
        soft(&scene, "dusk", "#7a5cff", 0.18)

        let wave = Animation.between(
            [.transform: .t(.translate(-70, 0), .skewX(-7), .scale(1, 0.94))],
            [.transform: .t(.translate(70, 0), .skewX(7), .scale(1, 1.08))],
            duration: 44, direction: .alternate, timing: .easeInOut
        )
        let breathe = Animation.between([.opacity: .n(0.55)], [.opacity: .n(1)], duration: 30, direction: .alternate, timing: .easeInOut)

        scene.add(.rect(0, 0, 1600, 1000).fill("url(#night)"))
        scene.add(.ellipse(260, 80, 520, 260).fill("url(#glow)").animate(breathe))
        scene.add(.ellipse(1400, 60, 480, 240).fill("url(#dusk)").animate(breathe.delayed(-12)))
        let green: [(Double, Double, Double, Double)] = [(-40, 230, 330, 150), (260, 170, 360, 170), (600, 230, 340, 140), (930, 160, 360, 150), (1270, 110, 340, 140), (1600, 170, 330, 150)]
        scene.add(.group(green.map { .ellipse($0.0, $0.1, $0.2, $0.3).fill("url(#green)") }).animate(wave).origin(800, 0))
        let violet: [(Double, Double, Double, Double)] = [(80, 110, 340, 130), (460, 80, 360, 140), (860, 290, 330, 120), (1220, 270, 350, 130), (1560, 80, 340, 140)]
        scene.add(.group(violet.map { .ellipse($0.0, $0.1, $0.2, $0.3).fill("url(#violet)") }).animate(wave.lasting(63).directed(.alternateReverse)).origin(800, 0))
        scene.add(.group([
            .ellipse(90, 430, 300, 260).fill("url(#green)"), .ellipse(150, 700, 260, 220).fill("url(#violet)"),
            .ellipse(1510, 460, 300, 270).fill("url(#violet)"), .ellipse(1470, 720, 260, 220).fill("url(#green)"),
            .ellipse(800, 330, 520, 150).fill("url(#green)").opacity(0.5),
        ]).animate(wave.lasting(90)).origin(800, 500))
        scene.add(.path("M0 1000 L0 930 L180 880 L330 925 L520 868 L700 930 L900 892 L1080 938 L1260 876 L1430 926 L1600 884 L1600 1000Z").fill("#03040b"))
        calm(&scene)
        return scene
    }

    // MARK: Ember

    static func emberOriginal() -> Scene {
        let (width, height) = (1600.0, 1000.0)
        var scene = Scene(width: width, height: height)
        scene.linear("dusk2", [(0, "#0d0709", 1), (0.6, "#1c0b0e", 1), (1, "#3a1210", 1)])
        soft(&scene, "fire", "#ff7a2a", 0.5)
        soft(&scene, "coal", "#ff3d1a", 0.34)
        soft(&scene, "mote", "#ffc27a", 0.75)
        soft(&scene, "dim", "#ffc27a", 0.22)

        let pulse = Animation.between(
            [.opacity: .n(0.6), .transform: .t(.scale(0.97, 0.97))], [.opacity: .n(1), .transform: .t(.scale(1.04, 1.04))],
            duration: 9, direction: .alternate, timing: .easeInOut
        )
        let pulseB = pulse.lasting(13).directed(.alternateReverse)
        let lift = Animation([
            .init(0, [.transform: .t(.translate(0, 0)), .opacity: .n(0)]),
            .init(0.1, [.opacity: .n(0.9)]),
            .init(0.7, [.opacity: .n(0.5)]),
            .init(1, [.transform: .t(.translate(60, -1100)), .opacity: .n(0)]),
        ], duration: 34, timing: .linear)

        scene.add(.rect(0, 0, 1600, 1000).fill("url(#dusk2)"))
        scene.add(.ellipse(1380, 40, 620, 300).fill("url(#coal)").opacity(0.28).animate(pulseB))
        scene.add(.group([.ellipse(120, 1010, 640, 520).fill("url(#fire)")]).animate(pulse).origin(120, 1000))
        scene.add(.group([.ellipse(1500, 1020, 680, 560).fill("url(#coal)")]).animate(pulseB).origin(1500, 1000))
        scene.add(.ellipse(800, 1060, 900, 160).fill("url(#coal)").opacity(0.5))
        let motes: [(Double, Double, Double, String, Double)] = [
            (470, 1040, 14, "mote", -3), (560, 1060, 10, "mote", -17), (1380, 1050, 18, "mote", -9),
            (1500, 1040, 12, "mote", -25), (1250, 1070, 9, "mote", -30), (120, 1080, 18, "dim", -22),
        ]
        for mote in motes {
            scene.add(.circle(mote.0, mote.1, mote.2).fill(Paint("url(#\(mote.3))")).animate(lift.delayed(mote.4)))
        }
        calm(&scene)
        return scene
    }
}
