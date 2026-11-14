import Foundation

// Les trois décors doux, recomposés pour un téléphone tenu droit. Sur un
// ordinateur, l'intérêt vivait à gauche et à droite du texte ; ici le texte
// occupe la largeur, et l'intérêt passe en haut (sous l'heure) et en bas (sous
// les boutons). Le milieu, de 22 à 65 % de la hauteur, reste calme.

extension Classic {
    // MARK: Aurora

    static func aurora(width w: Double, height h: Double) -> Scene {
        var scene = Scene(width: w, height: h)
        scene.linear("night", [(0, "#0c1136", 1), (0.55, "#090b22", 1), (1, "#05060f", 1)])
        soft(&scene, "green", "#5dffb5", 0.3)
        soft(&scene, "violet", "#9f7bff", 0.26)
        soft(&scene, "glow", "#3affc0", 0.2)
        soft(&scene, "dusk", "#7a5cff", 0.18)

        let reach = w * 0.08
        let wave = Animation.between(
            [.transform: .t(.translate(-reach, 0), .skewX(-7), .scale(1, 0.94))],
            [.transform: .t(.translate(reach, 0), .skewX(7), .scale(1, 1.08))],
            duration: 44, direction: .alternate, timing: .easeInOut
        )
        let breathe = Animation.between([.opacity: .n(0.55)], [.opacity: .n(1)], duration: 30, direction: .alternate, timing: .easeInOut)

        scene.add(.rect(0, 0, w, h).fill("url(#night)"))
        scene.add(.ellipse(w * 0.2, h * 0.05, w * 0.75, h * 0.22).fill("url(#glow)").animate(breathe))
        scene.add(.ellipse(w * 0.85, h * 0.03, w * 0.7, h * 0.2).fill("url(#dusk)").animate(breathe.delayed(-12)))
        // Deux rideaux de lumière en travers du haut de l'écran.
        let green: [(Double, Double)] = [(-0.08, 0.17), (0.25, 0.12), (0.55, 0.17), (0.85, 0.1), (1.1, 0.14)]
        scene.add(.group(green.map { .ellipse(w * $0.0, h * $0.1, w * 0.4, h * 0.11).fill("url(#green)") }).animate(wave).origin(w / 2, 0))
        let violet: [(Double, Double)] = [(0.05, 0.08), (0.4, 0.05), (0.75, 0.2), (1.05, 0.07)]
        scene.add(.group(violet.map { .ellipse(w * $0.0, h * $0.1, w * 0.4, h * 0.09).fill("url(#violet)") })
            .animate(wave.lasting(63).directed(.alternateReverse)).origin(w / 2, 0))
        // Ce qui, sur l'ordinateur, montait des côtés devient une lueur au ras
        // de l'horizon, et le bas du rideau.
        scene.add(.group([
            .ellipse(w * 0.1, h * 0.84, w * 0.55, h * 0.14).fill("url(#green)"),
            .ellipse(w * 0.92, h * 0.86, w * 0.5, h * 0.13).fill("url(#violet)"),
            .ellipse(w * 0.5, h * 0.24, w * 0.9, h * 0.07).fill("url(#green)").opacity(0.5),
        ]).animate(wave.lasting(90)).origin(w / 2, h / 2))
        scene.add(ridge(w, h, "#03040b"))
        calm(&scene)
        return scene
    }

    /// Une crête basse, en dents de scie, le long du bas de l'écran.
    static func ridge(_ w: Double, _ h: Double, _ colour: String) -> Node {
        let peaks: [(Double, Double)] = [(0, 0.93), (0.12, 0.895), (0.24, 0.925), (0.38, 0.885), (0.52, 0.93), (0.64, 0.9), (0.78, 0.935), (0.9, 0.89), (1, 0.915)]
        var commands: [PathData.Command] = [.move(0, h)]
        for (x, y) in peaks { commands.append(.line(w * x, h * y)) }
        commands += [.line(w, h), .close]
        return Node.path(PathData(commands)).fill(Paint(colour))
    }

    // MARK: Deep Water

    static func deepWater(width w: Double, height h: Double) -> Scene {
        var scene = Scene(width: w, height: h)
        scene.linear("deep", [(0, "#0f6f86", 1), (0.45, "#0a4660", 1), (1, "#041c30", 1)])
        scene.linear("ray", x1: 0, y1: 0, x2: 1, y2: 0, [(0, "#bff3ff", 0), (0.5, "#bff3ff", 0.3), (1, "#bff3ff", 0)])
        scene.linear("down", [(0, "#fff", 1), (0.92, "#000", 1)])
        let region = Rect(-w, -40, w * 3, h * 0.72)
        scene.define("fade", .mask(Mask(region: region, nodes: [.rect(region.x, region.y, region.width, region.height).fill("url(#down)")])))
        soft(&scene, "caustic", "#9fe9f5", 0.2)
        soft(&scene, "orb", "#c9f6ff", 0.22)
        soft(&scene, "glint", "#e8fdff", 0.3)

        let sway = Animation.between([.transform: .t(.skewX(-5))], [.transform: .t(.skewX(6))], duration: 38, direction: .alternate, timing: .easeInOut)
        let swayB = sway.lasting(52).directed(.alternateReverse)
        let drift = Animation.between([.transform: .t(.translate(-w * 0.12, 0))], [.transform: .t(.translate(w * 0.12, 0))], duration: 70, direction: .alternate, timing: .easeInOut)
        let driftB = drift.lasting(95).directed(.alternateReverse)
        let rise = Animation([
            .init(0, [.transform: .t(.translate(0, 0)), .opacity: .n(0)]),
            .init(0.12, [.opacity: .n(1)]),
            .init(0.85, [.opacity: .n(1)]),
            .init(1, [.transform: .t(.translate(0, -(h + 150))), .opacity: .n(0)]),
        ], duration: 46, timing: .linear)
        let glide = Animation.between(
            [.transform: .t(.translate(0, 0), .rotate(-4))], [.transform: .t(.translate(-w * 0.1, -20), .rotate(3))],
            duration: 80, direction: .alternate, timing: .easeInOut
        )

        let shaft = h * 0.72
        scene.add(.rect(0, 0, w, h).fill("url(#deep)"))
        scene.add(.group([
            .group([.rect(0, -40, w * 0.42, shaft).fill("url(#ray)").animate(sway).origin(w / 2, 0)]).transform(.translate(-w * 0.08, 0), .skewX(-14)),
            .group([.rect(0, -40, w * 0.46, shaft).fill("url(#ray)").animate(swayB).origin(w / 2, 0)]).transform(.translate(w * 0.62, 0), .skewX(11)),
            .group([.rect(0, -40, w * 0.36, shaft).fill("url(#ray)").opacity(0.55).animate(swayB).origin(w / 2, 0)]).transform(.translate(w * 0.24, 0), .skewX(-20)),
        ]).mask("fade"))
        scene.add(.group([
            .ellipse(w * 0.2, h * 0.08, w * 0.8, h * 0.05).fill("url(#caustic)"), .ellipse(w * 0.85, h * 0.13, w * 0.7, h * 0.04).fill("url(#caustic)"),
        ]).animate(drift))
        scene.add(.group([
            .ellipse(w * 0.15, h * 0.86, w * 0.85, h * 0.06).fill("url(#caustic)"), .ellipse(w * 0.9, h * 0.8, w * 0.7, h * 0.05).fill("url(#caustic)"),
        ]).animate(driftB))
        // Les bulles montent le long des bords, là où le texte ne va pas.
        scene.add(.group([.circle(w * 0.07, h + 60, 34).fill("url(#orb)")]).animate(rise.delayed(-4)))
        scene.add(.group([.circle(w * 0.93, h + 80, 46).fill("url(#orb)"), .circle(w * 0.93 - 13, h + 65, 11).fill("url(#glint)")]).animate(rise.delayed(-21)))
        scene.add(.group([.circle(w * 0.86, h + 50, 22).fill("url(#orb)")]).animate(rise.delayed(-33)))
        scene.add(.group([.circle(w * 0.16, h + 70, 20).fill("url(#orb)")]).animate(rise.delayed(-14)))
        scene.add(.group([honu().animate(glide).opacity(0.5)]).transform(.translate(w * 0.74, h * 0.9), .scale(0.7, 0.7)))
        calm(&scene)
        return scene
    }

    // MARK: Ember

    static func ember(width w: Double, height h: Double) -> Scene {
        var scene = Scene(width: w, height: h)
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
            .init(1, [.transform: .t(.translate(w * 0.06, -(h + 100))), .opacity: .n(0)]),
        ], duration: 34, timing: .linear)

        scene.add(.rect(0, 0, w, h).fill("url(#dusk2)"))
        scene.add(.ellipse(w * 0.9, h * 0.02, w * 0.8, h * 0.18).fill("url(#coal)").opacity(0.28).animate(pulseB))
        scene.add(.group([.ellipse(w * 0.1, h + 10, w * 0.95, h * 0.36).fill("url(#fire)")]).animate(pulse).origin(w * 0.1, h))
        scene.add(.group([.ellipse(w * 0.95, h + 20, w, h * 0.38).fill("url(#coal)")]).animate(pulseB).origin(w * 0.95, h))
        scene.add(.ellipse(w * 0.5, h + 60, w * 1.1, h * 0.14).fill("url(#coal)").opacity(0.5))
        let motes: [(Double, Double, Double, String, Double)] = [
            (0.1, 40, 12, "mote", -3), (0.22, 60, 9, "mote", -17), (0.86, 50, 14, "mote", -9),
            (0.94, 40, 10, "mote", -25), (0.76, 70, 8, "mote", -30), (0.04, 80, 14, "dim", -22),
        ]
        for mote in motes {
            scene.add(.circle(w * mote.0, h + mote.1, mote.2).fill(Paint("url(#\(mote.3))")).animate(lift.delayed(mote.4)))
        }
        calm(&scene)
        return scene
    }
}
