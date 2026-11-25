import Foundation

/// Une couche de crayon de couleur : des hachures parallèles.
public struct Hatch: Sendable, Equatable {
    var color: RGBA
    var angle: Double = -58
    var gap: Double = 2.4
    var alpha: Double = 0.85
    var width: Double = 1.5
    var rough: Double = 1.6
    var skip: Double = 0.1
}

/// Une partie d'un animal. Les parties vont du fond vers l'avant : chacune
/// cache ce qui est derrière elle, remplissage et contour.
struct Piece: Sendable {
    var shape: [Pt]
    var fills: [Hatch]
    /// Un contour ouvert (un bras sort du corps sans couture).
    var open: [Pt]? = nil
    /// L'ombre, du côté opposé à la lumière : décalage et force.
    var shade: (dx: Double, dy: Double, alpha: Double)? = nil
    /// Une tache posée sur une partie : elle ne cache rien.
    var overlay = false
    var line = true
    var width = 1.3
    var lineAlpha = 0.85
}

struct Dab: Sendable {
    var shape: [Pt]
    var color: RGBA
    var alpha: Double
    var density: Double
    var width = 2.2
    var angle = 60.0
    var even = false
}

struct Stroke: Sendable {
    var points: [Pt]
    var width: Double
    var alpha = 0.85
}

/// Un animal dessiné, dans son espace de 200 × 300.
struct Figure: Sendable {
    var ink: RGBA
    var shadeTone: RGBA
    var parts: [Piece]
    var lines: [Stroke]
    var darks: [(shape: [Pt], color: RGBA)]
    var pastels: [Dab]
    var glints: [Pt]
    var sparkles: [(Pt, Double)]
    var feet: (Pt, Double)
    var back: RGBA
    var box: (Pt, Pt)
    var head: (Pt, Pt)

    func placed(at offset: Pt, scale s: Double) -> Figure {
        let f: ([Pt]) -> [Pt] = { $0.map { offset + $0 * s } }
        var copy = self
        copy.parts = parts.map { p in
            var q = p
            q.shape = f(p.shape); q.open = p.open.map(f)
            q.shade = p.shade.map { ($0.dx * s, $0.dy * s, $0.alpha) }
            return q
        }
        copy.lines = lines.map { Stroke(points: f($0.points), width: $0.width, alpha: $0.alpha) }
        copy.darks = darks.map { (f($0.shape), $0.color) }
        copy.pastels = pastels.map { var d = $0; d.shape = f($0.shape); return d }
        copy.glints = f(glints)
        copy.sparkles = sparkles.map { (offset + $0.0 * s, $0.1 * s) }
        copy.feet = (offset + feet.0 * s, feet.1 * s)
        return copy
    }
}

/// Qui dessiner, et dans quelle humeur.
public enum Sketch: Hashable, Sendable {
    public enum GiraffeMood: String, Sendable, CaseIterable { case calm, listening, happy, together }
    public enum JackalMood: String, Sendable, CaseIterable { case cross, sulky, soft, together }

    case giraffe(GiraffeMood)
    case jackal(JackalMood)
    /// Les deux côte à côte : la dernière carte d'une histoire.
    case together
    /// Un animal des histoires, en buste.
    case animal(Species, AnimalMood)
}

enum Palette {
    static let sepia = RGBA("#5e3324"), plum = RGBA("#3e2c4c")
    static let gGold = RGBA("#f3bd52"), gApricot = RGBA("#ec944a"), gSpot = RGBA("#c0613a"), gCream = RGBA("#f8e0b4")
    static let gTip = RGBA("#8a4a38"), gEar = RGBA("#ee8c9b"), gShade = RGBA("#8463b8")
    static let jFur = RGBA("#9da5dc"), jFur2 = RGBA("#8089c8"), jLight = RGBA("#f2edf6"), jShade = RGBA("#5d78c0")
    static let jEar = RGBA("#ec9ab3"), jNose = RGBA("#3a2a3e"), jTip = RGBA("#4f4a7a")
    static let peach = RGBA("#ffc49a"), lilac = RGBA("#c8bff0"), gold = RGBA("#f6dc98")
    static let blush = RGBA("#ff8d9c"), glow = RGBA("#fff1c9"), ground = RGBA("#b9a3c9")
    static let mouth = RGBA("#7a2f34"), jMouth = RGBA("#7a2f4a")
}

enum Figures {
    static func giraffe(_ mood: Sketch.GiraffeMood) -> Figure {
        typealias S = Shape
        let tilt: Double = mood == .listening ? -10 : mood == .together ? 6 : 0
        let H: ([Pt]) -> [Pt] = { S.rotate($0, tilt, around: Pt(100, 150)) }
        func fur(gap: Double = 2.4) -> [Hatch] {
            [Hatch(color: Palette.gGold, gap: gap), Hatch(color: Palette.gApricot, angle: 32, gap: 4.8, alpha: 0.45, width: 1.2)]
        }
        let head = H(S.path("M100 40 C134 40 146 62 146 84 C146 105 132 120 100 120 C68 120 54 105 54 84 C54 62 66 40 100 40 Z"))
        let muzzle = H(S.ellipse(100, 102, 33, 19, 0, 0.03, 6))
        let neck = S.path("M82 112 C80 135 79 150 77 174 L123 174 C121 150 120 135 118 112 Z")
        let torso = S.path("M100 160 C136 160 150 196 150 228 C150 258 130 272 100 272 C70 272 50 258 50 228 C50 196 64 160 100 160 Z")
        let belly = S.ellipse(100, 232, 30, 32, 0, 0.05, 7)
        let legL = S.path("M70 256 L68 288 L89 288 L91 262 Z"), legR = S.path("M109 262 L111 288 L132 288 L130 256 Z")
        let tail = S.tube("M146 232 Q166 236 172 256", 4, 3)
        let armPaths: [String] = switch mood {
        case .calm: ["M64 182 Q48 206 52 232", "M136 182 Q152 206 148 232"]
        case .listening: ["M64 182 Q70 218 94 208", "M136 182 Q152 206 148 232"]
        case .happy: ["M64 184 Q40 162 36 132", "M136 184 Q160 162 164 132"]
        case .together: ["M64 182 Q48 206 52 232", "M136 182 Q176 166 204 194"]
        }
        let arms = armPaths.map { S.tube($0, 15, 13) }
        let spotSpecs: [(Double, Double, Double, Double)] = [(90, 140, 5, 4), (110, 156, 4, 3.5), (74, 200, 9, 7), (126, 214, 8, 7), (86, 250, 7, 6), (132, 244, 6, 5), (116, 186, 6, 5)]
        let spots = spotSpecs.enumerated().map { i, s in S.ellipse(s.0, s.1, s.2, s.3, Double(i) * 23, 0.22, 20 + i) }

        var parts: [Piece] = [
            Piece(shape: tail.shape, fills: [Hatch(color: Palette.gGold, gap: 2)], open: tail.shape),
            Piece(shape: S.ellipse(tail.end.x, tail.end.y + 3, 5, 7, -15, 0.2, 8), fills: [Hatch(color: Palette.gTip, gap: 1.4)]),
            Piece(shape: H(S.ellipse(50, 68, 21, 10, -24, 0.04, 2)), fills: [Hatch(color: Palette.gGold, gap: 2.2)]),
            Piece(shape: H(S.ellipse(150, 68, 21, 10, 24, 0.04, 3)), fills: [Hatch(color: Palette.gGold, gap: 2.2)]),
            Piece(shape: H(S.ellipse(53, 68, 12, 5, -24, 0.08, 70)), fills: [Hatch(color: Palette.gEar, gap: 1.8)], line: false),
            Piece(shape: H(S.ellipse(147, 68, 12, 5, 24, 0.08, 71)), fills: [Hatch(color: Palette.gEar, gap: 1.8)], line: false),
            Piece(shape: H(S.path("M82 52 L76 24 L82 24 L88 50 Z")), fills: [Hatch(color: Palette.gApricot, gap: 2)], width: 1),
            Piece(shape: H(S.path("M118 52 L124 24 L118 24 L112 50 Z")), fills: [Hatch(color: Palette.gApricot, gap: 2)], width: 1),
            Piece(shape: H(S.ellipse(78.5, 20, 8, 7.5, 0, 0.06, 4)), fills: [Hatch(color: Palette.gTip, gap: 1.4)]),
            Piece(shape: H(S.ellipse(121.5, 20, 8, 7.5, 0, 0.06, 5)), fills: [Hatch(color: Palette.gTip, gap: 1.4)]),
            Piece(shape: legL, fills: fur(), shade: (9, 0, 0.5)), Piece(shape: legR, fills: fur(), shade: (9, 0, 0.5)),
            Piece(shape: S.ellipse(79, 289, 13, 6, 0, 0.08, 9), fills: [Hatch(color: Palette.gTip, gap: 1.6)]),
            Piece(shape: S.ellipse(121, 289, 13, 6, 0, 0.08, 10), fills: [Hatch(color: Palette.gTip, gap: 1.6)]),
            Piece(shape: torso, fills: fur(), shade: (8, 8, 0.5)),
            Piece(shape: belly, fills: [Hatch(color: Palette.gCream, gap: 2.4)], width: 0.9, lineAlpha: 0.6),
            // Le cou n'a que ses deux côtés : il sort du corps sans couture.
            Piece(shape: neck, fills: fur(), shade: (9, 0, 0.5), line: false),
        ]
        parts += spots.map { Piece(shape: $0, fills: [Hatch(color: Palette.gSpot, angle: -50, gap: 1.6)], overlay: true, line: false) }
        parts += [
            Piece(shape: head, fills: fur(gap: 2.3), shade: (7, 8, 0.5), width: 1.5),
            Piece(shape: H(S.ellipse(74, 56, 7, 5.5, -10, 0.25, 30)), fills: [Hatch(color: Palette.gSpot, gap: 1.6)], overlay: true, line: false),
            Piece(shape: H(S.ellipse(126, 52, 5.5, 4.5, 15, 0.25, 31)), fills: [Hatch(color: Palette.gSpot, gap: 1.6)], overlay: true, line: false),
            Piece(shape: muzzle, fills: [Hatch(color: Palette.gCream, gap: 2.4)], shade: (4, 6, 0.3), width: 1.1, lineAlpha: 0.7),
        ]
        for arm in arms {
            parts.append(Piece(shape: arm.shape, fills: fur(), open: arm.shape, shade: (5, 5, 0.5)))
            parts.append(Piece(shape: S.ellipse(arm.end.x, arm.end.y, 8, 7, 0, 0.08, 11), fills: [Hatch(color: Palette.gTip, gap: 1.5)]))
        }

        let closed = mood == .happy || mood == .together
        let eyes = closed ? [] : [H(S.ellipse(80, 73, 5, 6.5, 0, 0.05, 40)), H(S.ellipse(120, 73, 5, 6.5, 0, 0.05, 41))]
        var lines = [Stroke(points: S.path("M81.6 118 C80 135 79 150 77 170"), width: 1.3), Stroke(points: S.path("M118.4 118 C120 135 121 150 123 170"), width: 1.3)]
        if closed { lines += [Stroke(points: H(S.path("M73 77 Q80 67 87 77")), width: 2.4), Stroke(points: H(S.path("M113 77 Q120 67 127 77")), width: 2.4)] }
        if mood == .listening { lines += [Stroke(points: H(S.path("M71 60 Q80 54 89 59")), width: 1.6), Stroke(points: H(S.path("M111 59 Q120 54 129 60")), width: 1.6)] }
        let mouth = mood == .happy ? H(S.path("M88 106 Q100 122 112 106 Z")) : nil
        if mouth == nil { lines.append(Stroke(points: H(S.path(mood == .together ? "M89 106 Q100 116 111 106" : "M91 107 Q100 114 109 107")), width: 1.8)) }
        let mane = (0..<6).map { k in S.ellipse(119 + Double(k) * 0.3, 114 + Double(k) * 10, 2.2, 4, 10, 0.2, 100 + k) }

        var darks: [([Pt], RGBA)] = eyes.map { ($0, Palette.sepia) }
        darks += [(H(S.ellipse(90, 97, 3, 2.2, 0, 0.1, 90)), Palette.sepia), (H(S.ellipse(110, 97, 3, 2.2, 0, 0.1, 91)), Palette.sepia)]
        if let mouth { darks.append((mouth, Palette.mouth)) }
        darks += mane.map { ($0, Palette.gTip) }

        var pastels = [
            Dab(shape: H(S.ellipse(66, 90, 10, 7, 0, 0.1, 80)), color: Palette.blush, alpha: 0.7, density: 1.6),
            Dab(shape: H(S.ellipse(134, 90, 10, 7, 0, 0.1, 81)), color: Palette.blush, alpha: 0.7, density: 1.6),
        ]
        if mood == .listening { pastels.append(Dab(shape: S.ellipse(94, 206, 14, 10, 0, 0.2, 84), color: Palette.blush, alpha: 0.35, density: 0.8)) }

        return Figure(
            ink: Palette.sepia, shadeTone: Palette.gShade, parts: parts, lines: lines,
            darks: darks.map { (shape: $0.0, color: $0.1) }, pastels: pastels,
            glints: eyes.isEmpty ? [] : [H([Pt(82, 70.5)])[0], H([Pt(122, 70.5)])[0]],
            sparkles: mood == .happy ? [(Pt(30, 100), 8), (Pt(172, 96), 7), (Pt(160, 150), 5)] : [],
            feet: (Pt(100, 290), 62), back: Palette.peach,
            box: (Pt(-6, 6), Pt(206, 298)), head: (Pt(34, 6), Pt(166, 126))
        )
    }

    static func jackal(_ mood: Sketch.JackalMood) -> Figure {
        typealias S = Shape
        let tilt: Double = switch mood { case .sulky: 7; case .together: -8; case .soft: -4; case .cross: 0 }
        let H: ([Pt]) -> [Pt] = { S.rotate($0, tilt, around: Pt(100, 150)) }
        func fur(gap: Double = 2.3) -> [Hatch] {
            [Hatch(color: Palette.jFur, gap: gap), Hatch(color: Palette.jFur2, angle: 32, gap: 4.8, alpha: 0.45, width: 1.2)]
        }
        let droop: Double = mood == .sulky ? 22 : mood == .cross ? -4 : 0
        let earL = H(S.rotate(S.path("M62 98 C52 72 50 48 56 26 C70 38 86 56 96 74 Z"), -droop, around: Pt(76, 86)))
        let earR = H(S.rotate(S.path("M138 98 C148 72 150 48 144 26 C130 38 114 56 104 74 Z"), droop, around: Pt(124, 86)))
        let earLi = H(S.rotate(S.path("M66 86 C60 68 60 52 62 40 C72 50 80 60 86 72 Z"), -droop, around: Pt(76, 86)))
        let earRi = H(S.rotate(S.path("M134 86 C140 68 140 52 138 40 C128 50 120 60 114 72 Z"), droop, around: Pt(124, 86)))
        let head = H(S.path("M100 62 C134 62 152 84 152 108 C152 120 148 128 142 134 L151 140 L139 143 L141 151 C129 158 114 162 100 162 C86 162 71 158 59 151 L61 143 L49 140 L58 134 C52 128 48 120 48 108 C48 84 66 62 100 62 Z"))
        let snout = H(S.path("M100 112 C116 112 124 124 124 134 C124 146 112 152 100 152 C88 152 76 146 76 134 C76 124 84 112 100 112 Z"))
        let torso = S.path("M100 150 C128 150 142 180 142 214 C142 248 126 266 100 266 C74 266 58 248 58 214 C58 180 72 150 100 150 Z")
        let chest = S.path("M84 158 L92 170 L100 160 L108 170 L116 158 C124 184 124 220 116 246 C106 254 94 254 84 246 C76 220 76 184 84 158 Z")
        let legL = S.path("M72 252 L70 288 L91 288 L92 258 Z"), legR = S.path("M108 258 L109 288 L130 288 L128 252 Z")
        let wag: Double = mood == .together ? -18 : mood == .sulky ? 30 : 0
        let tail = S.rotate(S.path("M136 236 C170 238 188 214 184 184 C176 204 160 214 140 218 Z"), wag, around: Pt(138, 228))
        let tailTip = S.rotate(S.path("M184 184 C189 194 187 206 180 212 C178 202 178 194 184 184 Z"), wag, around: Pt(138, 228))
        let armPaths: [String] = switch mood {
        case .cross: ["M70 182 Q94 216 126 200", "M130 182 Q108 222 76 206"]
        case .sulky: ["M70 182 Q62 206 68 230", "M130 182 Q138 206 132 230"]
        case .soft: ["M70 182 Q62 206 68 230", "M130 182 Q154 196 172 178"]
        case .together: ["M70 182 Q62 206 68 230", "M130 182 Q140 210 124 226"]
        }
        let arms = armPaths.map { S.tube($0, 14, 12) }

        var parts: [Piece] = [
            Piece(shape: tail, fills: fur(gap: 2.1), shade: (6, 6, 0.5)),
            Piece(shape: tailTip, fills: [Hatch(color: Palette.jTip, gap: 1.6)]),
            Piece(shape: earL, fills: fur()), Piece(shape: earR, fills: fur(), shade: (6, -4, 0.5)),
            Piece(shape: earLi, fills: [Hatch(color: Palette.jEar, gap: 1.8)], line: false),
            Piece(shape: earRi, fills: [Hatch(color: Palette.jEar, gap: 1.8)], line: false),
            Piece(shape: legL, fills: fur(), shade: (8, 0, 0.5)), Piece(shape: legR, fills: fur(), shade: (8, 0, 0.5)),
            Piece(shape: S.ellipse(80, 289, 12, 6, 0, 0.08, 9), fills: [Hatch(color: Palette.jLight, gap: 2)]),
            Piece(shape: S.ellipse(120, 289, 12, 6, 0, 0.08, 10), fills: [Hatch(color: Palette.jLight, gap: 2)]),
            Piece(shape: torso, fills: fur(), shade: (8, 8, 0.5)),
            Piece(shape: chest, fills: [Hatch(color: Palette.jLight, gap: 2.6, alpha: 0.9)], width: 1, lineAlpha: 0.6),
            Piece(shape: head, fills: fur(gap: 2.2), shade: (7, 8, 0.5), width: 1.5),
            Piece(shape: snout, fills: [Hatch(color: Palette.jLight, gap: 2.2)], shade: (4, 6, 0.3), width: 1.1, lineAlpha: 0.7),
        ]
        // Bras croisés : le premier passe derrière le second.
        for arm in arms {
            parts.append(Piece(shape: arm.shape, fills: fur(), open: arm.shape, shade: (5, 5, 0.5)))
            parts.append(Piece(shape: S.ellipse(arm.end.x, arm.end.y, 7.5, 6.5, 0, 0.08, 12), fills: [Hatch(color: Palette.jLight, gap: 2)]))
        }

        var lines = [Stroke(points: H(S.path("M100 130 L100 136")), width: 1.6)]
        var eyes: [[Pt]] = [], lids: [[Pt]] = []
        var mouth: [Pt]? = nil
        switch mood {
        case .cross:
            eyes = [H(S.ellipse(82, 104, 5, 6, 0, 0.05, 40)), H(S.ellipse(118, 104, 5, 6, 0, 0.05, 41))]
            lines += [Stroke(points: H(S.path("M70 89 L92 98")), width: 3), Stroke(points: H(S.path("M130 89 L108 98")), width: 3),
                      Stroke(points: H(S.path("M92 143 Q100 137 108 143")), width: 1.8)]
        case .sulky:
            eyes = [H(S.ellipse(82, 108, 5, 5.5, 0, 0.05, 40)), H(S.ellipse(118, 108, 5, 5.5, 0, 0.05, 41))]
            lids = [H(S.path("M75 107 C75 98 89 98 89 107 Z")), H(S.path("M111 107 C111 98 125 98 125 107 Z"))]
            lines += [Stroke(points: H(S.path("M74 106 L90 106")), width: 1.6), Stroke(points: H(S.path("M110 106 L126 106")), width: 1.6),
                      Stroke(points: H(S.path("M72 94 L92 97")), width: 2.4), Stroke(points: H(S.path("M128 94 L108 97")), width: 2.4),
                      Stroke(points: H(S.path("M93 143 L107 143")), width: 1.8)]
        case .soft:
            eyes = [H(S.ellipse(82, 104, 5.8, 7, 0, 0.05, 40)), H(S.ellipse(118, 104, 5.8, 7, 0, 0.05, 41))]
            lines += [Stroke(points: H(S.path("M72 90 Q81 84 90 88")), width: 2), Stroke(points: H(S.path("M128 90 Q119 84 110 88")), width: 2),
                      Stroke(points: H(S.path("M90 139 Q100 148 110 139")), width: 1.8)]
        case .together:
            lines += [Stroke(points: H(S.path("M75 106 Q82 97 89 106")), width: 2.4), Stroke(points: H(S.path("M111 106 Q118 97 125 106")), width: 2.4)]
            mouth = H(S.path("M90 139 Q100 152 110 139 Z"))
        }
        var darks: [([Pt], RGBA)] = [(H(S.ellipse(100, 124, 8, 6, 0, 0.05, 7)), Palette.jNose)]
        darks += eyes.map { ($0, Palette.plum) }
        darks += lids.map { ($0, Palette.jFur2) }
        if let mouth { darks.append((mouth, Palette.jMouth)) }
        var pastels: [Dab] = []
        if mood == .soft || mood == .together {
            pastels += [Dab(shape: H(S.ellipse(68, 124, 8, 6, 0, 0.1, 84)), color: Palette.blush, alpha: 0.7, density: 1.6),
                        Dab(shape: H(S.ellipse(132, 124, 8, 6, 0, 0.1, 85)), color: Palette.blush, alpha: 0.7, density: 1.6)]
        }
        var glints = [H([Pt(97, 122)])[0]]
        if !eyes.isEmpty && mood != .sulky { glints += [H([Pt(84, 101.5)])[0], H([Pt(120, 101.5)])[0]] }

        return Figure(
            ink: Palette.plum, shadeTone: Palette.jShade, parts: parts, lines: lines,
            darks: darks.map { (shape: $0.0, color: $0.1) }, pastels: pastels, glints: glints,
            sparkles: mood == .soft ? [(Pt(176, 160), 6)] : [],
            feet: (Pt(100, 290), 56), back: Palette.lilac,
            box: (Pt(-6, 10), Pt(206, 298)), head: (Pt(36, 14), Pt(164, 166))
        )
    }
}
