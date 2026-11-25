import Foundation

/// Le décor d'une histoire, dessiné au crayon comme les animaux. Le ciel en
/// haut, la terre en bas ; le milieu reste calme, c'est là que vont les cartes.
public enum Motif: String, Codable, Sendable, CaseIterable {
    case dawn, night, garden, rain, roofs, rails, party, sea, peaks

    /// Chaque histoire garde le décor qu'elle avait dans les Reels, traduit au crayon.
    public init(scene: String?) {
        self = switch scene {
        case "halftone-dawn": .dawn
        case "night-reef", "braille-stars": .night
        case "paper-garden", "paper-garden-kraft": .garden
        case "koi-mosaic": .rain
        case "blueprint": .roofs
        case "departure-board": .rails
        case "aurora-snow": .party
        case "honu-lagoon": .sea
        case "vector-range": .peaks
        default: .dawn
        }
    }
}

/// Les petits signes de l'écran, tracés à la main : pas une icône de système.
public enum Glyph: String, Sendable, CaseIterable {
    case talk, check, cross, up, speaker, again, skip, right, wrong
}

private enum Ground {
    static let green = RGBA("#a9d68e"), deep = RGBA("#86c07a"), leaf = RGBA("#8cc47a"), bush = RGBA("#7fb56f")
    static let cloud = RGBA("#fbf7f2"), sun = RGBA("#f6c445"), sea = RGBA("#7fb4e0"), sand = RGBA("#f2d4a0")
    static let hill = RGBA("#8a84c4"), dusk = RGBA("#6e68ab"), stone = RGBA("#a8a6d6"), snow = RGBA("#fbf7f2")
    static let peach = RGBA("#ffc49a"), lilac = RGBA("#c8bff0"), gold = RGBA("#f6dc98"), mint = RGBA("#bfe3cf"), sky = RGBA("#bcd6f0")
    static let night = RGBA("#b9b0e4"), pink = RGBA("#f8c8d4"), roof = RGBA("#c0613a"), wood = RGBA("#a8683e")
}

extension Figures {
    private static func flat(_ c: RGBA, gap: Double = 2.4, alpha: Double = 0.85) -> [Hatch] { [Hatch(color: c, gap: gap, alpha: alpha)] }

    private static func cloud(_ x: Double, _ y: Double, _ w: Double, _ seed: Int) -> Piece {
        Piece(shape: Shape.ellipse(x, y, w, w * 0.4, 0, 0.16, seed), fills: flat(Ground.cloud, alpha: 0.7), width: 1.1, lineAlpha: 0.5)
    }

    private static func land(_ d: String, _ c: RGBA, shade: Bool = true) -> Piece {
        Piece(shape: Shape.path(d), fills: [Hatch(color: c), Hatch(color: c, angle: 32, gap: 5, alpha: 0.35, width: 1.2)], shade: shade ? (0, 8, 0.35) : nil, width: 1.3, lineAlpha: 0.7)
    }

    private static func marks(_ paths: [String], width: Double = 1.1, alpha: Double = 0.55) -> [Stroke] {
        paths.map { Stroke(points: Shape.path($0), width: width, alpha: alpha) }
    }

    /// Un décor dans son espace de 200 × 420, à peu près un téléphone debout.
    /// `head` : la bande qu'une ligne de la liste montre.
    static func backdrop(_ motif: Motif) -> Figure {
        typealias S = Shape
        var f = Figure(ink: Palette.sepia, shadeTone: Palette.gShade, parts: [], lines: [], darks: [], pastels: [], glints: [], sparkles: [],
                       feet: (Pt(100, 900), 1), back: Ground.peach, box: (Pt(0, 0), Pt(200, 420)), head: (Pt(0, 228), Pt(200, 310)))
        switch motif {
        case .dawn:
            f.parts = [
                cloud(50, 60, 26, 1), cloud(156, 40, 20, 2),
                Piece(shape: S.ellipse(140, 262, 34, 34, 0, 0.03, 3), fills: [Hatch(color: Ground.sun), Hatch(color: Palette.gApricot, angle: 32, gap: 5, alpha: 0.35)], width: 1.2, lineAlpha: 0.7),
                land("M-20 290 C30 262 80 262 120 282 C150 268 190 262 230 272 L230 450 L-20 450 Z", Ground.green),
                land("M-20 332 C40 304 120 310 230 340 L230 450 L-20 450 Z", Ground.deep),
            ]
            f.lines = marks(["M140 214 L140 204", "M108 228 L100 221", "M172 228 L180 221", "M96 256 L86 254", "M184 256 L194 254"], width: 1.4, alpha: 0.6)
                + marks(["M30 352 L33 344 L36 352", "M150 368 L153 360 L156 368", "M90 390 L93 382 L96 390"])
        case .night:
            f.back = Ground.night
            f.head = (Pt(0, 30), Pt(200, 112))
            f.parts = [
                Piece(shape: S.path("M150 40 C172 40 188 58 188 80 C188 102 170 120 148 120 C162 110 168 96 168 80 C168 64 162 50 150 40 Z"),
                      fills: flat(Ground.sun), width: 1.2),
                land("M-20 336 C40 304 110 304 230 330 L230 450 L-20 450 Z", Ground.hill),
                land("M-20 366 C60 344 140 352 230 372 L230 450 L-20 450 Z", Ground.dusk),
            ]
            for s in [(40.0, 50.0, 6.0), (92, 30, 4), (112, 96, 5), (26, 120, 4), (178, 150, 5), (70, 84, 3), (128, 160, 3), (20, 210, 3)] {
                f.parts.append(Piece(shape: S.sparkle(s.0, s.1, s.2), fills: flat(Palette.glow, gap: 1.2), width: 0.8, lineAlpha: 0.6))
            }
        case .garden:
            f.back = Ground.mint
            f.head = (Pt(0, 290), Pt(200, 372))
            let branch = S.tube("M-10 22 Q60 44 116 26", 5, 2)
            f.parts = [
                Piece(shape: branch.shape, fills: flat(Ground.wood), width: 1),
                land("M-20 338 C60 324 140 326 230 336 L230 450 L-20 450 Z", Ground.green),
                Piece(shape: S.ellipse(26, 334, 42, 28, 0, 0.12, 4), fills: [Hatch(color: Ground.bush)], shade: (0, 6, 0.35), width: 1.2, lineAlpha: 0.7),
                Piece(shape: S.ellipse(176, 330, 44, 30, 0, 0.12, 5), fills: [Hatch(color: Ground.bush)], shade: (0, 6, 0.35), width: 1.2, lineAlpha: 0.7),
            ]
            let leaves: [(Double, Double, Double)] = [(20, 30, 30), (46, 40, -20), (70, 40, 35), (96, 34, -25), (110, 28, 40)]
            f.parts += leaves.enumerated().map { i, l in Piece(shape: S.ellipse(l.0, l.1 + 8, 4, 9, l.2, 0.05, 10 + i), fills: flat(Ground.leaf, gap: 1.8), width: 0.9) }
            let berries: [(Double, Double)] = [(14, 322), (34, 316), (40, 340), (166, 314), (186, 322), (174, 342), (196, 336)]
            f.parts += berries.enumerated().map { i, b in Piece(shape: S.ellipse(b.0, b.1, 3.5, 3.5, 0, 0.05, 20 + i), fills: flat(Palette.gApricot, gap: 1.4), width: 0.8) }
            f.lines = marks(["M80 352 L82 342 L85 352", "M120 360 L122 350 L125 360", "M100 392 L102 384 L104 392", "M60 400 L62 392 L64 400"])
        case .rain:
            f.back = Ground.sky
            f.head = (Pt(0, 20), Pt(200, 102))
            f.parts = [
                Piece(shape: S.ellipse(60, 52, 54, 22, 0, 0.16, 1), fills: flat(RGBA("#e2e4f2")), shade: (0, 5, 0.35), width: 1.2, lineAlpha: 0.6),
                Piece(shape: S.ellipse(150, 72, 46, 19, 0, 0.16, 2), fills: flat(RGBA("#e2e4f2")), shade: (0, 5, 0.35), width: 1.2, lineAlpha: 0.6),
                land("M-20 352 C60 340 140 344 230 354 L230 450 L-20 450 Z", RGBA("#a9c2a0")),
                Piece(shape: S.ellipse(120, 382, 40, 8, 0, 0.06, 3), fills: flat(Ground.sea), width: 1, lineAlpha: 0.6),
            ]
            var drops: [String] = []
            for k in 0..<24 {
                let x = Double((k * 37) % 200) + 4, y = 96 + Double((k * 53) % 230)
                if (60...300).contains(y) && (40...160).contains(x) { continue } // pas de pluie sur les cartes
                drops.append("M\(x) \(y) L\(x - 3) \(y + 9)")
            }
            f.lines = marks(drops, width: 1, alpha: 0.45) + marks(["M92 382 Q120 376 148 382", "M104 386 Q120 383 136 386"], width: 0.9, alpha: 0.5)
        case .roofs:
            f.back = Ground.lilac
            f.head = (Pt(0, 262), Pt(200, 344))
            f.parts = [cloud(40, 50, 24, 1), cloud(160, 80, 18, 2)]
            let colours = [Ground.peach, Ground.gold, Ground.sky, Ground.mint]
            var x = -16.0, k = 0
            while x < 210 {
                let w = 34 + Double((k * 13) % 14), top = 300 + Double((k * 17) % 22)
                f.parts.append(Piece(shape: S.path("M\(x) 450 L\(x) \(top) L\(x + w) \(top) L\(x + w) 450 Z"), fills: flat(colours[k % 4]), shade: (5, 0, 0.3), width: 1.2, lineAlpha: 0.7))
                f.parts.append(Piece(shape: S.path("M\(x - 3) \(top) L\(x + w / 2) \(top - 20) L\(x + w + 3) \(top) Z"), fills: flat(Ground.roof, gap: 2), width: 1.2, lineAlpha: 0.7))
                f.parts.append(Piece(shape: S.path("M\(x + w / 2 - 5) \(top + 12) L\(x + w / 2 + 5) \(top + 12) L\(x + w / 2 + 5) \(top + 22) L\(x + w / 2 - 5) \(top + 22) Z"), fills: flat(Ground.sun, gap: 1.6), width: 0.9, lineAlpha: 0.7))
                x += w + 4; k += 1
            }
        case .rails:
            f.back = Ground.gold
            f.head = (Pt(0, 270), Pt(200, 352))
            f.parts = [
                cloud(150, 54, 24, 1),
                land("M-20 304 C40 284 120 288 230 300 L230 450 L-20 450 Z", Ground.green),
                Piece(shape: S.path("M30 450 L92 304 L108 304 L170 450 Z"), fills: flat(RGBA("#d8c0a0")), line: false),
            ]
            var lines = ["M36 450 L95 304", "M164 450 L105 304"]
            for k in 0..<9 {
                let t = Double(k) / 9, y = 310 + 140 * t * t, half = 6 + 60 * t * t
                lines.append("M\(100 - half) \(y) L\(100 + half) \(y)")
            }
            f.lines = marks(lines, width: 1.3, alpha: 0.7)
                + marks(["M170 310 L170 250", "M162 258 L178 258", "M30 316 L30 262", "M22 270 L38 270", "M38 270 Q100 286 162 258"], width: 1.2, alpha: 0.6)
        case .party:
            f.back = Ground.pink
            f.head = (Pt(0, 20), Pt(200, 102))
            f.parts = [
                Piece(shape: S.ellipse(38, 104, 17, 21, 0, 0.03, 1), fills: flat(Palette.blush), shade: (4, 4, 0.3), width: 1.2),
                Piece(shape: S.ellipse(168, 92, 15, 19, 0, 0.03, 2), fills: flat(Ground.sky), shade: (4, 4, 0.3), width: 1.2),
            ]
            let flags = [Ground.sun, Ground.sky, Palette.blush, Ground.mint, Palette.gApricot, Ground.lilac]
            for k in 0..<7 {
                let x = 12 + Double(k) * 28, y = 34 + 10 * sin(Double(k) / 6 * .pi)
                f.parts.append(Piece(shape: S.path("M\(x - 9) \(y) L\(x + 9) \(y + 1) L\(x) \(y + 18) Z"), fills: flat(flags[k % flags.count], gap: 1.8), width: 1))
            }
            let bits: [(Double, Double, Double)] = [(70, 140, 20), (120, 120, -30), (24, 190, 50), (184, 200, -10), (60, 352, 30), (140, 370, -40), (24, 396, 10), (176, 344, 60), (100, 404, -20)]
            f.parts += bits.enumerated().map { i, b in
                Piece(shape: S.ellipse(b.0, b.1, 5, 2.2, b.2, 0.05, 30 + i), fills: flat(flags[i % flags.count], gap: 1.4), overlay: true, line: false)
            }
            f.lines = marks(["M-4 30 Q100 52 204 30"], width: 1.2, alpha: 0.7) + marks(["M38 125 Q34 150 42 176", "M168 111 Q174 140 166 166"], width: 1, alpha: 0.6)
        case .sea:
            f.back = Ground.sky
            f.head = (Pt(0, 250), Pt(200, 332))
            f.parts = [
                Piece(shape: S.ellipse(150, 60, 22, 22, 0, 0.03, 1), fills: flat(Ground.sun), width: 1.2, lineAlpha: 0.7),
                cloud(54, 84, 26, 2),
                land("M-20 302 C30 294 60 306 100 300 C140 294 170 306 230 300 L230 450 L-20 450 Z", Ground.sea),
                land("M-20 384 C60 372 140 376 230 386 L230 450 L-20 450 Z", Ground.sand, shade: false),
            ]
            f.lines = marks(["M20 322 Q30 316 40 322", "M120 330 Q130 324 140 330", "M70 346 Q80 340 90 346", "M160 352 Q170 346 180 352", "M30 362 Q40 356 50 362"], width: 1.1, alpha: 0.6)
                + marks(["M90 140 Q96 134 102 140 Q108 134 114 140", "M120 164 Q124 160 128 164 Q132 160 136 164"], width: 1.2, alpha: 0.6)
        case .peaks:
            f.back = Ground.sky
            f.head = (Pt(0, 184), Pt(200, 266))
            f.parts = [
                cloud(40, 64, 24, 1),
                land("M-20 330 L50 210 L84 262 L130 186 L230 330 Z", Ground.stone),
                Piece(shape: S.path("M50 210 L39 232 L48 228 L55 236 L62 228 Z"), fills: flat(Ground.snow), overlay: true, width: 1, lineAlpha: 0.6),
                Piece(shape: S.path("M130 186 L116 210 L126 205 L133 214 L142 204 Z"), fills: flat(Ground.snow), overlay: true, width: 1, lineAlpha: 0.6),
                land("M-20 340 C60 322 140 326 230 342 L230 450 L-20 450 Z", Ground.green),
            ]
            let pines: [(Double, Double, Double)] = [(18, 336, 1), (40, 344, 0.8), (160, 338, 1.1), (184, 346, 0.85)]
            f.parts += pines.enumerated().map { i, p in
                Piece(shape: S.path("M\(p.0) \(p.1 - 34 * p.2) L\(p.0 + 11 * p.2) \(p.1) L\(p.0 - 11 * p.2) \(p.1) Z"), fills: flat(Ground.bush, gap: 1.8), width: 1)
            }
        }
        return f
    }

    /// Un signe dans son carré de 24 : rien que du crayon.
    static func glyph(_ glyph: Glyph) -> Figure {
        let strokes: [String] = switch glyph {
        case .talk: ["M3 5 C3 3 4 2 6 2 L14 2 C16 2 17 3 17 5 L17 10 C17 12 16 13 14 13 L8 13 L4 16.5 L5 13 C4 13 3 12 3 10 Z",
                     "M19.5 8 C21 8 22 9 22 11 L22 15 C22 17 21 18 19 18 L19 21.5 L15 18 L12 18 C10.5 18 9.5 17.4 9.2 16"]
        case .check: ["M5 12.5 L10 17.5 L19 6.5"]
        case .cross: ["M6.5 6.5 L17.5 17.5", "M17.5 6.5 L6.5 17.5"]
        case .up: ["M5 15 L12 8 L19 15"]
        case .speaker: ["M3 9 L7 9 L12 4.5 L12 19.5 L7 15 L3 15 Z", "M15.5 8.5 Q18 12 15.5 15.5", "M18.5 5.5 Q23 12 18.5 18.5"]
        case .again: ["M5 12 C5 7.5 8.5 4.5 12.5 4.5 C16.5 4.5 19.5 7.5 19.5 12 C19.5 16.5 16 19.5 12 19.5", "M2 8.8 L5 12.6 L8.4 9.2"]
        case .skip: ["M12 2.5 C17.5 2.5 21.5 6.5 21.5 12 C21.5 17.5 17.5 21.5 12 21.5 C6.5 21.5 2.5 17.5 2.5 12 C2.5 6.5 6.5 2.5 12.4 2.6", "M12 7 L12 16.5", "M8 13 L12 17 L16 13"]
        case .right: ["M12 2.5 C17.5 2.5 21.5 6.5 21.5 12 C21.5 17.5 17.5 21.5 12 21.5 C6.5 21.5 2.5 17.5 2.5 12 C2.5 6.5 6.5 2.5 12.4 2.6", "M7.5 12.5 L10.8 15.8 L16.5 8.5"]
        case .wrong: ["M12 2.5 C17.5 2.5 21.5 6.5 21.5 12 C21.5 17.5 17.5 21.5 12 21.5 C6.5 21.5 2.5 17.5 2.5 12 C2.5 6.5 6.5 2.5 12.4 2.6", "M8.5 8.5 L15.5 15.5", "M15.5 8.5 L8.5 15.5"]
        }
        return Figure(ink: RGBA("#000000"), shadeTone: Palette.gShade, parts: [], lines: strokes.map { Stroke(points: Shape.path($0), width: 4.2, alpha: 1) },
                      darks: [], pastels: [], glints: [], sparkles: [], feet: (Pt(12, 900), 0.1), back: Ground.peach,
                      box: (Pt(0, 0), Pt(24, 24)), head: (Pt(0, 0), Pt(24, 24)))
    }
}
