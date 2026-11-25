import Foundation

/// Les animaux des histoires, en buste : la tête et les épaules, pour une
/// pastille. Même crayon que la girafe et le chacal, même papier.
public enum Species: String, Sendable, CaseIterable {
    case bear, hedgehog, rabbit, raccoon, owl, fox, koala, dog
    case turtle, beaver, cat, panda, seal, penguin, elephant, goat
}

public extension Sketch {
    enum AnimalMood: String, Sendable, CaseIterable { case calm, happy }
}

private enum Tone {
    static let light = RGBA("#fbf1e2"), pink = RGBA("#ee8c9b"), nose = RGBA("#3a2a3e"), white = RGBA("#fbf7f2")
    static let peach = RGBA("#ffc49a"), lilac = RGBA("#c8bff0"), gold = RGBA("#f6dc98"), mint = RGBA("#bfe3cf"), sky = RGBA("#bcd6f0")
    static let violet = RGBA("#8463b8"), blue = RGBA("#5d78c0")
}

extension Figures {
    // Tout se dessine dans un carré de 140 autour de (100, 100) : la tête au
    // milieu, les épaules qui sortent par le bas.
    private static let frame = (Pt(30, 30), Pt(170, 170))

    private static func fur(_ a: RGBA, _ b: RGBA, gap: Double = 2.3) -> [Hatch] {
        [Hatch(color: a, gap: gap), Hatch(color: b, angle: 32, gap: 4.8, alpha: 0.45, width: 1.2)]
    }

    private static func flat(_ c: RGBA, gap: Double = 2.2) -> [Hatch] { [Hatch(color: c, gap: gap)] }

    private static func shoulders(_ fills: [Hatch]) -> Piece {
        Piece(shape: Shape.path("M38 182 C40 152 66 136 100 136 C134 136 160 152 162 182 Z"), fills: fills, shade: (8, 6, 0.5))
    }

    /// Le visage : les yeux, la bouche, les joues. Calme : des yeux ouverts et
    /// brillants. Content : les yeux plissés, la bouche ouverte.
    private struct Face {
        var eyeY = 98.0, apart = 17.0, eye = 1.0
        var mouthY: Double? = 121
        var eyeColor = Palette.plum
        var blush = true, blushY: Double? = nil, blushApart = 30.0
    }

    private static func face(_ f: Face, _ mood: Sketch.AnimalMood, into figure: inout Figure) {
        let l = 100 - f.apart, r = 100 + f.apart, y = f.eyeY, s = f.eye
        if mood == .calm {
            figure.darks += [(Shape.ellipse(l, y, 4.6 * s, 5.8 * s, 0, 0.05, 40), f.eyeColor), (Shape.ellipse(r, y, 4.6 * s, 5.8 * s, 0, 0.05, 41), f.eyeColor)]
            figure.glints += [Pt(l + 1.6 * s, y - 2.4 * s), Pt(r + 1.6 * s, y - 2.4 * s)]
        } else {
            let w = 6.5 * s, h = 8 * s
            figure.lines += [Stroke(points: Shape.path("M\(l - w) \(y + 3) Q\(l) \(y - h) \(l + w) \(y + 3)"), width: 2.3),
                             Stroke(points: Shape.path("M\(r - w) \(y + 3) Q\(r) \(y - h) \(r + w) \(y + 3)"), width: 2.3)]
        }
        if let m = f.mouthY {
            if mood == .happy {
                figure.darks.append((Shape.path("M92 \(m - 1) Q100 \(m + 12) 108 \(m - 1) Z"), Palette.mouth))
            } else {
                figure.lines.append(Stroke(points: Shape.path("M93 \(m) Q100 \(m + 5) 107 \(m)"), width: 1.7))
            }
        }
        if f.blush {
            let by = f.blushY ?? y + 14
            let a = mood == .happy ? 0.8 : 0.55
            figure.pastels += [Dab(shape: Shape.ellipse(100 - f.blushApart, by, 8, 5.5, 0, 0.1, 80), color: Palette.blush, alpha: a, density: 1.6),
                               Dab(shape: Shape.ellipse(100 + f.blushApart, by, 8, 5.5, 0, 0.1, 81), color: Palette.blush, alpha: a, density: 1.6)]
        }
        if mood == .happy { figure.sparkles += [(Pt(48, 52), 6), (Pt(154, 48), 5)] }
    }

    static func animal(_ species: Species, _ mood: Sketch.AnimalMood) -> Figure {
        typealias S = Shape
        var f = Figure(ink: Palette.sepia, shadeTone: Tone.violet, parts: [], lines: [], darks: [], pastels: [], glints: [], sparkles: [],
                       feet: (Pt(100, 400), 1), back: Tone.peach, box: frame, head: frame)
        var look = Face()

        switch species {
        case .bear:
            let fur = fur(RGBA("#cf9160"), RGBA("#a86a46"))
            f.parts = [
                shoulders(fur),
                Piece(shape: S.ellipse(64, 66, 15, 14, 0, 0.05, 2), fills: fur),
                Piece(shape: S.ellipse(136, 66, 15, 14, 0, 0.05, 3), fills: fur),
                Piece(shape: S.ellipse(65, 68, 8, 7, 0, 0.08, 4), fills: flat(RGBA("#f0b89a")), line: false),
                Piece(shape: S.ellipse(135, 68, 8, 7, 0, 0.08, 5), fills: flat(RGBA("#f0b89a")), line: false),
                Piece(shape: S.ellipse(100, 100, 44, 40, 0, 0.03, 1), fills: fur, shade: (7, 8, 0.5), width: 1.5),
                Piece(shape: S.ellipse(100, 117, 18, 13, 0, 0.04, 6), fills: flat(RGBA("#f6dcb4")), shade: (3, 5, 0.3), width: 1.1, lineAlpha: 0.7),
            ]
            f.darks.append((S.ellipse(100, 110, 6.5, 4.6, 0, 0.08, 7), Tone.nose))
            f.lines.append(Stroke(points: S.path("M100 114 L100 120"), width: 1.4))
            f.glints.append(Pt(98, 108.6))
            look.eyeY = 94; look.apart = 19; look.mouthY = 121
        case .hedgehog:
            // Une couronne de piquants, du côté gauche au côté droit, par-dessus la tête.
            var crown: [Pt] = []
            for k in 0...22 {
                let a = (-205 + Double(k) * 230 / 22) * .pi / 180
                let r = k % 2 == 0 ? 47.0 : 63.0
                crown.append(Pt(100 + cos(a) * r, 104 + sin(a) * r))
            }
            crown.append(Pt(100, 128))
            f.back = Tone.gold
            f.parts = [
                shoulders(fur(RGBA("#e9c79a"), RGBA("#d2a878"))),
                Piece(shape: crown, fills: fur(RGBA("#9a7090"), RGBA("#6f557a"), gap: 1.9), shade: (6, 6, 0.5), width: 1.2),
                Piece(shape: S.ellipse(70, 80, 7, 6, 0, 0.06, 2), fills: flat(RGBA("#e7b49a"))),
                Piece(shape: S.ellipse(130, 80, 7, 6, 0, 0.06, 3), fills: flat(RGBA("#e7b49a"))),
                Piece(shape: S.ellipse(100, 106, 36, 32, 0, 0.03, 1), fills: fur(RGBA("#f2d4a8"), RGBA("#e3b886")), shade: (6, 7, 0.45), width: 1.4),
                Piece(shape: S.ellipse(100, 121, 10, 7, 0, 0.05, 4), fills: flat(RGBA("#f8e4c4")), width: 1, lineAlpha: 0.7),
            ]
            f.darks.append((S.ellipse(100, 117, 4.6, 3.6, 0, 0.08, 7), Tone.nose))
            f.glints.append(Pt(98.6, 115.8))
            look.eyeY = 102; look.apart = 14; look.mouthY = 127; look.blushApart = 26
        case .rabbit:
            let fur = fur(RGBA("#f4eef6"), RGBA("#d9cfea"))
            f.back = Tone.lilac
            f.shadeTone = Tone.blue
            f.parts = [
                shoulders(fur),
                Piece(shape: S.ellipse(84, 64, 10, 30, -8, 0.04, 2), fills: fur, shade: (4, 0, 0.4)),
                Piece(shape: S.ellipse(116, 64, 10, 30, 8, 0.04, 3), fills: fur, shade: (4, 0, 0.4)),
                Piece(shape: S.ellipse(84, 66, 5, 21, -8, 0.06, 4), fills: flat(Tone.pink, gap: 1.8), line: false),
                Piece(shape: S.ellipse(116, 66, 5, 21, 8, 0.06, 5), fills: flat(Tone.pink, gap: 1.8), line: false),
                Piece(shape: S.ellipse(100, 110, 40, 35, 0, 0.03, 1), fills: fur, shade: (6, 7, 0.5), width: 1.5),
                Piece(shape: S.ellipse(100, 126, 12, 8, 0, 0.05, 6), fills: flat(Tone.white), width: 0.9, lineAlpha: 0.55),
            ]
            f.darks.append((S.path("M96 119 L104 119 L100 124 Z"), RGBA("#d86a80")))
            look.eyeY = 106; look.apart = 16; look.mouthY = 128; look.blushApart = 27
        case .raccoon:
            let fur = fur(RGBA("#b2b2c8"), RGBA("#8f8fae"))
            f.back = Tone.gold
            f.shadeTone = Tone.blue
            f.ink = Palette.plum
            f.parts = [
                shoulders(fur),
                Piece(shape: S.path("M60 88 L64 52 L92 72 Z"), fills: fur),
                Piece(shape: S.path("M140 88 L136 52 L108 72 Z"), fills: fur),
                Piece(shape: S.path("M66 80 L67 60 L84 72 Z"), fills: flat(Palette.jTip, gap: 1.6), line: false),
                Piece(shape: S.path("M134 80 L133 60 L116 72 Z"), fills: flat(Palette.jTip, gap: 1.6), line: false),
                Piece(shape: S.ellipse(100, 102, 44, 38, 0, 0.03, 1), fills: fur, shade: (7, 8, 0.5), width: 1.5),
                Piece(shape: S.path("M58 98 C64 84 88 86 100 95 C112 86 136 84 142 98 C136 110 116 112 100 104 C84 112 64 110 58 98 Z"),
                      fills: flat(RGBA("#5a5280"), gap: 1.5), overlay: true, line: false),
                Piece(shape: S.ellipse(100, 120, 16, 12, 0, 0.04, 6), fills: flat(Palette.jLight), width: 1.1, lineAlpha: 0.7),
            ]
            // Les yeux dans le masque : un rond clair, et la pupille dedans.
            if mood == .calm {
                f.parts += [Piece(shape: S.ellipse(82, 98, 6, 6.5, 0, 0.05, 30), fills: flat(Tone.white), width: 0.9),
                            Piece(shape: S.ellipse(118, 98, 6, 6.5, 0, 0.05, 31), fills: flat(Tone.white), width: 0.9)]
            }
            f.darks.append((S.ellipse(100, 113, 5.5, 4, 0, 0.08, 7), Tone.nose))
            f.glints.append(Pt(98.4, 111.8))
            look.eyeY = 99; look.apart = 18; look.eye = 0.75; look.mouthY = 124; look.blushY = 116; look.blushApart = 32
            if mood == .happy {
                f.parts += [Piece(shape: S.path("M74 101 Q82 89 90 101 Q82 95 74 101 Z"), fills: flat(Tone.white), line: false),
                            Piece(shape: S.path("M110 101 Q118 89 126 101 Q118 95 110 101 Z"), fills: flat(Tone.white), line: false)]
            }
        case .owl:
            let fur = fur(RGBA("#c4936e"), RGBA("#9a6c56"))
            f.back = Tone.lilac
            f.parts = [
                shoulders(fur),
                Piece(shape: S.path("M64 76 L58 46 L84 64 Z"), fills: fur),
                Piece(shape: S.path("M136 76 L142 46 L116 64 Z"), fills: fur),
                Piece(shape: S.ellipse(100, 104, 46, 42, 0, 0.03, 1), fills: fur, shade: (7, 8, 0.5), width: 1.5),
                Piece(shape: S.ellipse(81, 99, 18, 17, 0, 0.04, 2), fills: flat(RGBA("#f4dfc0")), width: 1, lineAlpha: 0.6),
                Piece(shape: S.ellipse(119, 99, 18, 17, 0, 0.04, 3), fills: flat(RGBA("#f4dfc0")), width: 1, lineAlpha: 0.6),
            ]
            if mood == .calm {
                f.parts += [Piece(shape: S.ellipse(81, 99, 9.5, 9.5, 0, 0.04, 4), fills: flat(RGBA("#f6c445"), gap: 1.8), width: 1),
                            Piece(shape: S.ellipse(119, 99, 9.5, 9.5, 0, 0.04, 5), fills: flat(RGBA("#f6c445"), gap: 1.8), width: 1)]
            }
            f.parts.append(Piece(shape: S.path("M93 110 L107 110 L100 124 Z"), fills: flat(RGBA("#ec944a"), gap: 1.8), width: 1.1))
            f.lines += ["M84 148 Q88 152 92 148", "M100 152 Q104 156 108 152", "M116 148 Q120 152 124 148", "M92 160 Q96 164 100 160", "M108 160 Q112 164 116 160"]
                .map { Stroke(points: S.path($0), width: 1.1, alpha: 0.6) }
            look.eyeY = 99; look.apart = 19; look.eye = 0.9; look.mouthY = nil; look.blushY = 118; look.blushApart = 34
        case .fox:
            let fur = fur(RGBA("#ef8d4c"), RGBA("#d46c34"))
            f.back = Tone.lilac
            f.parts = [
                shoulders(fur),
                Piece(shape: S.path("M58 90 L60 46 L92 68 Z"), fills: fur),
                Piece(shape: S.path("M142 90 L140 46 L108 68 Z"), fills: fur),
                Piece(shape: S.path("M60 58 L60 46 L72 54 Z"), fills: flat(Palette.sepia, gap: 1.4), line: false),
                Piece(shape: S.path("M140 58 L140 46 L128 54 Z"), fills: flat(Palette.sepia, gap: 1.4), line: false),
                Piece(shape: S.path("M66 80 L66 62 L82 72 Z"), fills: flat(Tone.light), line: false),
                Piece(shape: S.path("M134 80 L134 62 L118 72 Z"), fills: flat(Tone.light), line: false),
                Piece(shape: S.path("M100 64 C130 64 144 82 144 100 C144 108 150 114 152 118 C140 132 120 140 100 140 C80 140 60 132 48 118 C50 114 56 108 56 100 C56 82 70 64 100 64 Z"),
                      fills: fur, shade: (7, 8, 0.5), width: 1.5),
                Piece(shape: S.path("M50 118 C64 110 84 110 100 122 C116 110 136 110 150 118 C138 132 120 140 100 140 C80 140 62 132 50 118 Z"),
                      fills: flat(Tone.light), width: 1, lineAlpha: 0.6),
            ]
            f.darks.append((S.ellipse(100, 121, 5.5, 4, 0, 0.08, 7), Tone.nose))
            f.glints.append(Pt(98.4, 119.8))
            look.eyeY = 98; look.apart = 19; look.mouthY = 129; look.blushY = 112; look.blushApart = 33
        case .koala:
            let fur = fur(RGBA("#aeb4cc"), RGBA("#8d95b4"))
            f.back = Tone.peach
            f.shadeTone = Tone.blue
            f.ink = Palette.plum
            f.parts = [
                shoulders(fur),
                Piece(shape: S.ellipse(57, 78, 22, 20, 0, 0.06, 2), fills: fur, shade: (5, 5, 0.4)),
                Piece(shape: S.ellipse(143, 78, 22, 20, 0, 0.06, 3), fills: fur, shade: (5, 5, 0.4)),
                Piece(shape: S.ellipse(59, 80, 12, 11, 0, 0.1, 4), fills: flat(Palette.jLight), line: false),
                Piece(shape: S.ellipse(141, 80, 12, 11, 0, 0.1, 5), fills: flat(Palette.jLight), line: false),
                Piece(shape: S.ellipse(100, 104, 42, 38, 0, 0.03, 1), fills: fur, shade: (7, 8, 0.5), width: 1.5),
            ]
            f.darks.append((S.path("M100 98 C108 98 110 106 110 112 C110 120 106 124 100 124 C94 124 90 120 90 112 C90 106 92 98 100 98 Z"), Tone.nose))
            f.glints.append(Pt(96, 104))
            look.eyeY = 100; look.apart = 23; look.eye = 0.85; look.mouthY = 130; look.blushY = 116; look.blushApart = 30
        case .dog:
            let fur = fur(RGBA("#ecc38e"), RGBA("#d6a46a"))
            let ear = Figures.fur(RGBA("#a8683e"), RGBA("#8a5030"))
            f.back = Tone.sky
            f.parts = [
                shoulders(fur),
                Piece(shape: S.ellipse(100, 100, 40, 38, 0, 0.03, 1), fills: fur, shade: (7, 8, 0.5), width: 1.5),
                Piece(shape: S.ellipse(118, 89, 11, 9, 10, 0.2, 9), fills: flat(RGBA("#c8844e"), gap: 1.8), overlay: true, line: false),
                Piece(shape: S.path("M68 70 C52 70 44 98 48 122 C56 130 66 120 72 104 C74 92 74 78 68 70 Z"), fills: ear, shade: (4, 4, 0.4)),
                Piece(shape: S.path("M132 70 C148 70 156 98 152 122 C144 130 134 120 128 104 C126 92 126 78 132 70 Z"), fills: ear, shade: (4, 4, 0.4)),
                Piece(shape: S.ellipse(100, 117, 17, 12, 0, 0.04, 6), fills: flat(RGBA("#f8e4c4")), width: 1.1, lineAlpha: 0.7),
            ]
            f.darks.append((S.ellipse(100, 109, 7, 5, 0, 0.08, 7), Tone.nose))
            f.lines.append(Stroke(points: S.path("M100 113 L100 119"), width: 1.4))
            f.glints.append(Pt(97.6, 107.4))
            look.eyeY = 94; look.apart = 16; look.mouthY = 120; look.blushApart = 26
        case .turtle:
            let skin = fur(RGBA("#a4d48e"), RGBA("#7fb56f"))
            f.back = Tone.sky
            f.parts = [
                Piece(shape: S.path("M84 108 L82 146 L118 146 L116 108 Z"), fills: skin, shade: (6, 0, 0.45)),
                Piece(shape: S.path("M34 182 C34 146 62 128 100 128 C138 128 166 146 166 182 Z"), fills: fur(RGBA("#c09456"), RGBA("#94703c")), shade: (8, 6, 0.5), width: 1.5),
                Piece(shape: S.ellipse(100, 90, 34, 31, 0, 0.03, 1), fills: skin, shade: (6, 7, 0.5), width: 1.5),
                Piece(shape: S.ellipse(80, 74, 4, 3, 20, 0.2, 2), fills: flat(RGBA("#6aa05a"), gap: 1.6), overlay: true, line: false),
                Piece(shape: S.ellipse(122, 72, 3.5, 3, -20, 0.2, 3), fills: flat(RGBA("#6aa05a"), gap: 1.6), overlay: true, line: false),
            ]
            f.lines += ["M58 160 L74 146 L100 150 L126 146 L142 160", "M74 146 L72 132", "M126 146 L128 132", "M100 150 L100 172", "M74 146 L70 176", "M126 146 L130 176"]
                .map { Stroke(points: S.path($0), width: 1.1, alpha: 0.6) }
            look.eyeY = 88; look.apart = 15; look.mouthY = 104; look.blushY = 100; look.blushApart = 24
        case .beaver:
            let fur = fur(RGBA("#b98058"), RGBA("#8f5c3c"))
            f.back = Tone.mint
            f.parts = [
                shoulders(fur),
                Piece(shape: S.ellipse(64, 70, 8, 7, 0, 0.06, 2), fills: fur),
                Piece(shape: S.ellipse(136, 70, 8, 7, 0, 0.06, 3), fills: fur),
                Piece(shape: S.ellipse(100, 102, 42, 38, 0, 0.03, 1), fills: fur, shade: (7, 8, 0.5), width: 1.5),
                Piece(shape: S.ellipse(100, 116, 20, 13, 0, 0.04, 6), fills: flat(RGBA("#ecd0a6")), width: 1.1, lineAlpha: 0.7),
                Piece(shape: S.path("M93 123 L93 136 L107 136 L107 123 Z"), fills: flat(Tone.white), width: 1.1),
            ]
            f.darks.append((S.ellipse(100, 108, 6.5, 4.6, 0, 0.08, 7), Tone.nose))
            f.lines.append(Stroke(points: S.path("M100 124 L100 135"), width: 1))
            f.glints.append(Pt(98, 106.6))
            look.eyeY = 94; look.apart = 17; look.mouthY = nil; look.blushApart = 30
        case .cat:
            let fur = fur(RGBA("#f2b066"), RGBA("#e09048"))
            f.back = Tone.sky
            f.parts = [
                shoulders(fur),
                Piece(shape: S.path("M60 88 L62 50 L92 70 Z"), fills: fur),
                Piece(shape: S.path("M140 88 L138 50 L108 70 Z"), fills: fur),
                Piece(shape: S.path("M66 80 L67 60 L84 72 Z"), fills: flat(Tone.pink, gap: 1.8), line: false),
                Piece(shape: S.path("M134 80 L133 60 L116 72 Z"), fills: flat(Tone.pink, gap: 1.8), line: false),
                Piece(shape: S.ellipse(100, 102, 43, 36, 0, 0.03, 1), fills: fur, shade: (7, 8, 0.5), width: 1.5),
                Piece(shape: S.ellipse(100, 76, 3, 8, 0, 0.2, 2), fills: flat(Palette.gSpot, gap: 1.6), overlay: true, line: false),
                Piece(shape: S.ellipse(88, 78, 2.5, 6, -20, 0.2, 3), fills: flat(Palette.gSpot, gap: 1.6), overlay: true, line: false),
                Piece(shape: S.ellipse(112, 78, 2.5, 6, 20, 0.2, 4), fills: flat(Palette.gSpot, gap: 1.6), overlay: true, line: false),
                Piece(shape: S.ellipse(100, 116, 13, 9, 0, 0.04, 6), fills: flat(Tone.light), width: 1, lineAlpha: 0.6),
            ]
            f.darks.append((S.path("M95.5 110 L104.5 110 L100 115 Z"), RGBA("#d86a80")))
            f.lines += ["M60 112 L80 115", "M60 121 L80 119", "M140 112 L120 115", "M140 121 L120 119"].map { Stroke(points: S.path($0), width: 0.9, alpha: 0.7) }
            look.eyeY = 98; look.apart = 18; look.mouthY = 120; look.blushY = 110; look.blushApart = 30
        case .panda:
            let white = fur(RGBA("#f8f4f0"), RGBA("#e2dbe8"))
            let black = fur(RGBA("#4a4258"), RGBA("#2e2838"), gap: 1.7)
            f.back = Tone.mint
            f.shadeTone = Tone.blue
            f.ink = Palette.plum
            f.parts = [
                shoulders(black),
                Piece(shape: S.ellipse(63, 66, 14, 13, 0, 0.06, 2), fills: black),
                Piece(shape: S.ellipse(137, 66, 14, 13, 0, 0.06, 3), fills: black),
                Piece(shape: S.ellipse(100, 102, 44, 40, 0, 0.03, 1), fills: white, shade: (7, 8, 0.45), width: 1.5),
                Piece(shape: S.ellipse(82, 100, 10, 13, 30, 0.08, 4), fills: black, overlay: true, line: false),
                Piece(shape: S.ellipse(118, 100, 10, 13, -30, 0.08, 5), fills: black, overlay: true, line: false),
            ]
            if mood == .calm {
                f.parts += [Piece(shape: S.ellipse(83, 99, 4.6, 5, 0, 0.05, 30), fills: flat(Tone.white), line: false),
                            Piece(shape: S.ellipse(117, 99, 4.6, 5, 0, 0.05, 31), fills: flat(Tone.white), line: false)]
            } else {
                f.parts += [Piece(shape: S.path("M76 102 Q83 91 90 102 Q83 96 76 102 Z"), fills: flat(Tone.white), line: false),
                            Piece(shape: S.path("M110 102 Q117 91 124 102 Q117 96 110 102 Z"), fills: flat(Tone.white), line: false)]
            }
            f.parts.append(Piece(shape: S.ellipse(100, 120, 14, 10, 0, 0.04, 6), fills: flat(Tone.white), width: 1, lineAlpha: 0.6))
            f.darks.append((S.ellipse(100, 114, 6, 4.4, 0, 0.08, 7), Tone.nose))
            f.glints.append(Pt(98.4, 112.8))
            look.eyeY = 99; look.apart = 17; look.eye = 0.6; look.mouthY = 123; look.blushY = 116; look.blushApart = 32
        case .seal:
            let fur = fur(RGBA("#bcc6da"), RGBA("#98a6c4"))
            f.back = Tone.sky
            f.shadeTone = Tone.blue
            f.ink = Palette.plum
            f.parts = [
                shoulders(fur),
                Piece(shape: S.ellipse(100, 100, 42, 40, 0, 0.03, 1), fills: fur, shade: (7, 8, 0.5), width: 1.5),
                Piece(shape: S.ellipse(74, 76, 3.5, 2.6, 10, 0.2, 2), fills: flat(RGBA("#8592b4"), gap: 1.6), overlay: true, line: false),
                Piece(shape: S.ellipse(128, 72, 4, 3, -15, 0.2, 3), fills: flat(RGBA("#8592b4"), gap: 1.6), overlay: true, line: false),
                Piece(shape: S.ellipse(91, 119, 11, 9, 0, 0.05, 4), fills: flat(RGBA("#e8ecf4")), width: 1, lineAlpha: 0.6),
                Piece(shape: S.ellipse(109, 119, 11, 9, 0, 0.05, 5), fills: flat(RGBA("#e8ecf4")), width: 1, lineAlpha: 0.6),
            ]
            f.darks.append((S.ellipse(100, 111, 6, 4.4, 0, 0.08, 7), Tone.nose))
            f.darks += [(86.0, 118.0), (92, 122), (108, 122), (114, 118)].enumerated().map { i, p -> (shape: [Pt], color: RGBA) in (S.ellipse(p.0, p.1, 1.2, 1.2, 0, 0, 50 + i), Palette.plum) }
            f.lines += ["M80 120 L64 116", "M80 124 L64 126", "M120 120 L136 116", "M120 124 L136 126"].map { Stroke(points: S.path($0), width: 0.8, alpha: 0.6) }
            f.glints.append(Pt(98.4, 109.8))
            look.eyeY = 95; look.apart = 18; look.eye = 1.2; look.mouthY = nil; look.blushY = 108; look.blushApart = 30
        case .penguin:
            let dark = fur(RGBA("#4a5478"), RGBA("#323a5c"), gap: 1.9)
            f.back = Tone.peach
            f.shadeTone = Tone.blue
            f.ink = Palette.plum
            f.parts = [
                shoulders(dark),
                Piece(shape: S.ellipse(100, 172, 30, 34, 0, 0.04, 8), fills: flat(Tone.white), width: 1, lineAlpha: 0.6),
                Piece(shape: S.ellipse(100, 100, 44, 42, 0, 0.03, 1), fills: dark, shade: (7, 8, 0.5), width: 1.5),
                Piece(shape: S.ellipse(100, 110, 32, 26, 0, 0.04, 2), fills: flat(Tone.white), width: 1, lineAlpha: 0.6),
                Piece(shape: S.path("M92 108 L108 108 L100 121 Z"), fills: flat(RGBA("#f3a24a"), gap: 1.8), width: 1.1),
            ]
            look.eyeY = 102; look.apart = 16; look.eye = 0.85; look.mouthY = nil; look.blushY = 116; look.blushApart = 22
        case .elephant:
            let skin = fur(RGBA("#b8b2d4"), RGBA("#9a93bc"))
            f.back = Tone.gold
            f.ink = Palette.plum
            f.parts = [
                shoulders(skin),
                Piece(shape: S.ellipse(54, 98, 26, 31, -10, 0.05, 2), fills: skin, shade: (5, 5, 0.4)),
                Piece(shape: S.ellipse(146, 98, 26, 31, 10, 0.05, 3), fills: skin, shade: (5, 5, 0.4)),
                Piece(shape: S.ellipse(56, 100, 15, 20, -10, 0.08, 4), fills: flat(RGBA("#f0b0be")), line: false),
                Piece(shape: S.ellipse(144, 100, 15, 20, 10, 0.08, 5), fills: flat(RGBA("#f0b0be")), line: false),
                Piece(shape: S.ellipse(100, 94, 37, 35, 0, 0.03, 1), fills: skin, shade: (7, 8, 0.5), width: 1.5),
            ]
            let trunk = S.tube("M100 104 C100 124 96 140 106 154", 15, 10)
            f.parts.append(Piece(shape: trunk.shape, fills: skin, open: trunk.shape, shade: (4, 4, 0.4)))
            f.lines += ["M94 126 L105 126", "M94 134 L104 135", "M96 142 L106 143"].map { Stroke(points: S.path($0), width: 1, alpha: 0.6) }
            look.eyeY = 92; look.apart = 19; look.eye = 0.9; look.mouthY = nil; look.blushY = 110; look.blushApart = 25
        case .goat:
            let fur = fur(RGBA("#f6eddc"), RGBA("#e2d4bc"))
            f.back = Tone.mint
            let hornL = S.tube("M86 70 C82 50 68 40 56 46", 8, 3), hornR = S.tube("M114 70 C118 50 132 40 144 46", 8, 3)
            f.parts = [
                shoulders(fur),
                Piece(shape: hornL.shape, fills: flat(RGBA("#b89c7c"), gap: 1.8), width: 1.1),
                Piece(shape: hornR.shape, fills: flat(RGBA("#b89c7c"), gap: 1.8), width: 1.1),
                Piece(shape: S.ellipse(60, 90, 17, 7, 20, 0.05, 2), fills: fur),
                Piece(shape: S.ellipse(140, 90, 17, 7, -20, 0.05, 3), fills: fur),
                Piece(shape: S.ellipse(100, 100, 34, 40, 0, 0.03, 1), fills: fur, shade: (6, 8, 0.5), width: 1.5),
                Piece(shape: S.ellipse(100, 124, 16, 12, 0, 0.04, 6), fills: flat(RGBA("#f4d8c8")), width: 1, lineAlpha: 0.6),
                Piece(shape: S.path("M94 135 C94 146 98 152 100 158 C102 152 106 146 106 135 Z"), fills: flat(RGBA("#e8e0d4")), width: 1),
            ]
            f.darks += [(S.ellipse(95, 121, 1.8, 1.4, 0, 0, 50), Palette.sepia), (S.ellipse(105, 121, 1.8, 1.4, 0, 0, 51), Palette.sepia)]
            look.eyeY = 96; look.apart = 16; look.mouthY = 128; look.blushY = 110; look.blushApart = 26
        }

        face(look, mood, into: &f)
        return f
    }
}
