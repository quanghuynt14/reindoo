import CoreGraphics
import CoreText
import ReindooCore
import SwiftUI
import UIKit

// Ce que Core résout, traduit pour Core Graphics : chemins, couleurs,
// dégradés, glyphes. Rien ne se décide ici.

extension PathData {
    var cgPath: CGPath {
        let path = CGMutablePath()
        for command in commands {
            switch command {
            case .move(let x, let y): path.move(to: CGPoint(x: x, y: y))
            case .line(let x, let y): path.addLine(to: CGPoint(x: x, y: y))
            case .quad(let x1, let y1, let x, let y): path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x1, y: y1))
            case .cubic(let x1, let y1, let x2, let y2, let x, let y):
                path.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: x1, y: y1), control2: CGPoint(x: x2, y: y2))
            case .close: path.closeSubpath()
            }
        }
        return path
    }

    /// Les points d'un trait aux bouts ronds : un sous-chemin de longueur nulle
    /// devient un disque, que tout moteur dessine pareil. Le reste reste un trait.
    func splitDots(radius: Double) -> (rest: CGPath, dots: CGPath?) {
        let rest = CGMutablePath(), dots = CGMutablePath()
        var hasDots = false
        var index = 0
        while index < commands.count {
            if case .move(let x, let y) = commands[index], index + 1 < commands.count,
               case .line(let x2, let y2) = commands[index + 1], x == x2, y == y2 {
                let ends = index + 2 >= commands.count || { if case .move = commands[index + 2] { return true } else { return false } }()
                if ends {
                    dots.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                    hasDots = true
                    index += 2
                    continue
                }
            }
            switch commands[index] {
            case .move(let x, let y): rest.move(to: CGPoint(x: x, y: y))
            case .line(let x, let y): rest.addLine(to: CGPoint(x: x, y: y))
            case .quad(let x1, let y1, let x, let y): rest.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x1, y: y1))
            case .cubic(let x1, let y1, let x2, let y2, let x, let y):
                rest.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: x1, y: y1), control2: CGPoint(x: x2, y: y2))
            case .close: rest.closeSubpath()
            }
            index += 1
        }
        return (rest, hasDots ? dots : nil)
    }
}

extension Affine {
    var cg: CGAffineTransform { CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty) }
}

extension RGBA {
    var cg: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
}

extension Array where Element == Stop {
    var gradient: Gradient { Gradient(stops: map { Gradient.Stop(color: $0.color.color, location: $0.offset) }) }

    var cgGradient: CGGradient? {
        CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: map(\.color.cg) as CFArray,
            locations: map { CGFloat($0.offset) }
        )
    }
}

extension LineCap {
    var cg: CGLineCap {
        switch self {
        case .butt: .butt
        case .round: .round
        case .square: .square
        }
    }
}

/// Des glyphes posés un à un, prêts pour un seul appel à Core Text.
struct GlyphRun {
    var font: CTFont
    var glyphs: [CGGlyph]
    var positions: [CGPoint]

    /// La police à chasse fixe du système, celle que demandaient les décors
    /// (`ui-monospace`), à la graisse voulue.
    static func font(size: Double, weight: Int) -> CTFont {
        let w: UIFont.Weight = weight >= 800 ? .heavy : weight >= 600 ? .bold : weight >= 500 ? .medium : .regular
        return UIFont.monospacedSystemFont(ofSize: size, weight: w) as CTFont
    }

    init(_ glyphs: Glyphs, size: Double, weight: Int) {
        font = Self.font(size: size, weight: weight)
        var characters = glyphs.text.map { UniChar(String($0).utf16.first ?? 32) }
        var found = [CGGlyph](repeating: 0, count: characters.count)
        _ = CTFontGetGlyphsForCharacters(font, &characters, &found, characters.count)
        self.glyphs = found
        // La chasse est fixe : une avance vaut pour toutes.
        var sample = found.first ?? 0
        var advance = CGSize.zero
        _ = CTFontGetAdvancesForGlyphs(font, .horizontal, &sample, &advance, 1)
        let shift = glyphs.centered ? advance.width / 2 : 0
        positions = zip(glyphs.xs, glyphs.ys).map { CGPoint(x: $0 - shift, y: $1) }
    }

    /// Dessine dans un contexte dont l'axe y descend, comme celui des décors.
    func draw(in context: CGContext, color: CGColor) {
        guard !glyphs.isEmpty else { return }
        context.saveGState()
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.setFillColor(color)
        CTFontDrawGlyphs(font, glyphs, positions, glyphs.count, context)
        context.restoreGState()
    }
}
