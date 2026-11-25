#if canImport(CoreGraphics)
import CoreGraphics

/// Peint un dessin : les couches de traits, mangées par le grain du papier,
/// posées l'une sur l'autre. Le plan a décidé de chaque trait ; ici, on ne
/// fait que les poser. Seulement là où Core Graphics existe : l'outil qui
/// peint les dessins à la construction, et l'app.
public enum SketchPainter {
    private static var space: CGColorSpace { CGColorSpace(name: CGColorSpace.sRGB)! }
    private static let info = CGImageAlphaInfo.premultipliedLast.rawValue

    private static func context(_ width: Int, _ height: Int) -> CGContext? {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space, bitmapInfo: info)
    }

    private static func pixels(_ context: CGContext) -> UnsafeMutableBufferPointer<UInt8>? {
        guard let data = context.data else { return nil }
        return UnsafeMutableBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: context.bytesPerRow * context.height)
    }

    private static func polygon(_ points: [Pt]) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: points.map { CGPoint(x: $0.x, y: $0.y) })
        path.closeSubpath()
        return path
    }

    private static func color(_ c: RGBA, _ alpha: Double) -> CGColor {
        CGColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: c.a * alpha)
    }

    /// Le dessin entier, sur sa feuille.
    public static func paint(_ plan: SketchPlan) -> CGImage? {
        let w = plan.width, h = plan.height
        guard let sheet = context(w, h), let paper = pixels(sheet) else { return nil }
        let tooth = Paper.tooth(width: w, height: h)
        Paper.sheet(tooth, width: w, height: h, into: paper)
        // Core compte en pixels depuis le haut ; Core Graphics depuis le bas.
        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(h))
        // Une même liste de formes de devant revient d'une couche à l'autre :
        // son masque se calcule une fois par dessin.
        var masks: [[[Pt]]: CGImage] = [:]
        for layer in plan.layers {
            paint(layer, onto: sheet, tooth: tooth, flip: flip, masks: &masks)
        }
        sheet.setBlendMode(.normal)
        sheet.concatenate(flip)
        sheet.setFillColor(CGColor(srgbRed: 1, green: 0.99, blue: 0.965, alpha: 0.95))
        for glint in plan.glints {
            sheet.fillEllipse(in: CGRect(x: glint.center.x - glint.radius, y: glint.center.y - glint.radius, width: glint.radius * 2, height: glint.radius * 2))
        }
        return sheet.makeImage()
    }

    /// Une couche : peinte à part, mangée par le grain, puis posée sur la feuille.
    private static func paint(_ layer: SketchPlan.Layer, onto base: CGContext, tooth: [Float], flip: CGAffineTransform, masks: inout [[[Pt]]: CGImage]) {
        let w = base.width, h = base.height
        let full = CGRect(x: 0, y: 0, width: w, height: h)
        guard let ink = context(w, h) else { return }
        ink.setLineCap(.round)
        ink.setLineJoin(.round)
        for batch in layer.batches {
            ink.saveGState()
            if let clip = batch.clip, !clip.cuts.isEmpty {
                let mask = masks[clip.cuts] ?? cutout(clip.cuts, width: w, height: h, flip: flip)
                masks[clip.cuts] = mask
                if let mask { ink.clip(to: full, mask: mask) }
            }
            ink.concatenate(flip)
            if let clip = batch.clip, !clip.shape.isEmpty {
                ink.addPath(polygon(clip.shape))
                ink.clip()
            }
            if let wash = batch.wash {
                let rect = CGRect(x: wash.rect.0.x, y: wash.rect.0.y, width: wash.rect.1.x - wash.rect.0.x, height: wash.rect.1.y - wash.rect.0.y)
                if wash.radial, let gradient = CGGradient(colorsSpace: space, colors: [color(batch.color, wash.alpha), color(batch.color, 0)] as CFArray, locations: [0, 1]) {
                    let center = CGPoint(x: rect.midX, y: rect.midY)
                    ink.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: max(rect.width, rect.height) / 2, options: [])
                } else {
                    ink.setFillColor(color(batch.color, wash.alpha))
                    ink.fill(rect)
                }
            }
            stroke(batch.lines, color: batch.color, in: ink)
            if !batch.erase.isEmpty {
                ink.setBlendMode(.clear)
                for shape in batch.erase { ink.addPath(polygon(shape)); ink.fillPath() }
                ink.setBlendMode(.normal)
            }
            ink.restoreGState()
        }
        if let layerPixels = pixels(ink) {
            Paper.bite(layerPixels, tooth: tooth, threshold: layer.threshold, softness: layer.softness)
        }
        guard let painted = ink.makeImage() else { return }
        base.setBlendMode(layer.blend == .multiply ? .multiply : .normal)
        base.draw(painted, in: full)
    }

    /// Les traits d'un lot, rangés par force et par épaisseur : un seul geste
    /// de Core Graphics par rangée au lieu d'un par trait.
    private static func stroke(_ lines: [SketchPlan.Line], color c: RGBA, in ink: CGContext) {
        var rows: [Int: CGMutablePath] = [:]
        for line in lines where line.points.count > 1 {
            let a = min(23, max(0, Int(line.alpha * 24))), wide = min(399, max(0, Int(line.width * 4)))
            let path = rows[a * 400 + wide] ?? CGMutablePath()
            path.addLines(between: line.points.map { CGPoint(x: $0.x, y: $0.y) })
            rows[a * 400 + wide] = path
        }
        for (key, path) in rows {
            ink.setStrokeColor(color(c, (Double(key / 400) + 0.5) / 24))
            ink.setLineWidth((CGFloat(key % 400) + 0.5) / 4)
            ink.addPath(path)
            ink.strokePath()
        }
    }

    /// Le masque d'une zone : blanc partout, sauf sous les formes de devant.
    private static func cutout(_ cuts: [[Pt]], width: Int, height: Int, flip: CGAffineTransform) -> CGImage? {
        guard let mask = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        mask.setFillColor(gray: 1, alpha: 1)
        mask.fill(CGRect(x: 0, y: 0, width: width, height: height))
        mask.concatenate(flip)
        mask.setFillColor(gray: 0, alpha: 1)
        for cut in cuts { mask.addPath(polygon(cut)); mask.fillPath() }
        return mask.makeImage()
    }

    /// Rien que le crayon, sans papier : pour un signe que le texte teinte.
    public static func pencil(_ plan: SketchPlan) -> CGImage? {
        guard let layer = plan.layers.last, let ink = context(plan.width, plan.height) else { return nil }
        ink.translateBy(x: 0, y: CGFloat(plan.height))
        ink.scaleBy(x: 1, y: -1)
        ink.setLineCap(.round)
        ink.setLineJoin(.round)
        for batch in layer.batches { stroke(batch.lines, color: batch.color, in: ink) }
        return ink.makeImage()
    }
}
#endif
