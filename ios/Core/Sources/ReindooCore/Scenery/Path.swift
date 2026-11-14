import Foundation

/// Un tracé en commandes absolues, que l'app recopie telles quelles dans un
/// `Path`. Les arcs deviennent des courbes de Bézier dès l'analyse : l'app n'a
/// que quatre gestes à connaître.
public struct PathData: Sendable, Equatable {
    public enum Command: Sendable, Equatable {
        case move(Double, Double)
        case line(Double, Double)
        case quad(Double, Double, Double, Double)
        case cubic(Double, Double, Double, Double, Double, Double)
        case close
    }

    public var commands: [Command] = []
    /// Un numéro stable, donné quand le décor est planifié : l'app garde sous
    /// ce numéro le chemin déjà traduit, au lieu de le refaire à chaque image.
    public var key: Int?
    public init(_ commands: [Command] = []) { self.commands = commands }

    public static func == (left: PathData, right: PathData) -> Bool { left.commands == right.commands }

    public var isEmpty: Bool { commands.isEmpty }

    public static func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double, radius: Double = 0) -> PathData {
        guard radius > 0 else {
            return PathData([.move(x, y), .line(x + width, y), .line(x + width, y + height), .line(x, y + height), .close])
        }
        let r = min(radius, width / 2, height / 2)
        let k = r * 0.5522847498
        return PathData([
            .move(x + r, y), .line(x + width - r, y),
            .cubic(x + width - r + k, y, x + width, y + r - k, x + width, y + r),
            .line(x + width, y + height - r),
            .cubic(x + width, y + height - r + k, x + width - r + k, y + height, x + width - r, y + height),
            .line(x + r, y + height),
            .cubic(x + r - k, y + height, x, y + height - r + k, x, y + height - r),
            .line(x, y + r),
            .cubic(x, y + r - k, x + r - k, y, x + r, y),
            .close,
        ])
    }

    public static func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> PathData {
        let kx = rx * 0.5522847498, ky = ry * 0.5522847498
        return PathData([
            .move(cx + rx, cy),
            .cubic(cx + rx, cy + ky, cx + kx, cy + ry, cx, cy + ry),
            .cubic(cx - kx, cy + ry, cx - rx, cy + ky, cx - rx, cy),
            .cubic(cx - rx, cy - ky, cx - kx, cy - ry, cx, cy - ry),
            .cubic(cx + kx, cy - ry, cx + rx, cy - ky, cx + rx, cy),
            .close,
        ])
    }

    public static func circle(_ cx: Double, _ cy: Double, _ r: Double) -> PathData { ellipse(cx, cy, r, r) }

    public static func line(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> PathData {
        PathData([.move(x1, y1), .line(x2, y2)])
    }

    public static func + (left: PathData, right: PathData) -> PathData {
        PathData(left.commands + right.commands)
    }

    /// La longueur du tracé, courbes comprises, pour les tirets qui le dessinent.
    public var length: Double {
        var total = 0.0
        var current = (0.0, 0.0), start = (0.0, 0.0)
        func distance(_ a: (Double, Double), _ b: (Double, Double)) -> Double { hypot(b.0 - a.0, b.1 - a.1) }
        for command in commands {
            switch command {
            case .move(let x, let y):
                current = (x, y)
                start = current
            case .line(let x, let y):
                total += distance(current, (x, y))
                current = (x, y)
            case .quad(let x1, let y1, let x, let y):
                total += curveLength { t in
                    let u = 1 - t
                    return (u * u * current.0 + 2 * u * t * x1 + t * t * x, u * u * current.1 + 2 * u * t * y1 + t * t * y)
                }
                current = (x, y)
            case .cubic(let x1, let y1, let x2, let y2, let x, let y):
                total += curveLength { t in
                    let u = 1 - t
                    let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
                    return (a * current.0 + b * x1 + c * x2 + d * x, a * current.1 + b * y1 + c * y2 + d * y)
                }
                current = (x, y)
            case .close:
                total += distance(current, start)
                current = start
            }
        }
        return total
    }

    private func curveLength(_ at: (Double) -> (Double, Double)) -> Double {
        var total = 0.0
        var previous = at(0)
        for step in 1...24 {
            let next = at(Double(step) / 24)
            total += hypot(next.0 - previous.0, next.1 - previous.1)
            previous = next
        }
        return total
    }
}

extension PathData: ExpressibleByStringLiteral {
    public init(stringLiteral text: String) { self.init(svg: text) }

    /// Lit l'attribut `d` d'un chemin SVG : toutes les commandes, relatives ou
    /// absolues.
    public init(svg text: String) {
        var reader = PathReader(Array(text.utf8))
        commands = reader.read()
    }
}

/// Lecteur de l'attribut `d`. Les nombres se suivent sans séparateur quand le
/// signe ou le point suffit (`l-30 6`, `.5.5`), comme le permet SVG.
private struct PathReader {
    private let bytes: [UInt8]
    private var index = 0
    private var out: [PathData.Command] = []
    private var x = 0.0, y = 0.0, startX = 0.0, startY = 0.0
    /// Le dernier point de contrôle, pour T et S.
    private var lastQuad: (Double, Double)?
    private var lastCubic: (Double, Double)?

    init(_ bytes: [UInt8]) { self.bytes = bytes }

    mutating func read() -> [PathData.Command] {
        var command: UInt8 = 0
        while true {
            skipSeparators()
            guard index < bytes.count else { break }
            let byte = bytes[index]
            if isLetter(byte) {
                command = byte
                index += 1
                if command == UInt8(ascii: "z") || command == UInt8(ascii: "Z") {
                    close()
                    continue
                }
            } else if command == 0 {
                break
            }
            guard step(command) else { break }
            // Après un M, les paires suivantes sont des L.
            if command == UInt8(ascii: "M") { command = UInt8(ascii: "L") }
            if command == UInt8(ascii: "m") { command = UInt8(ascii: "l") }
        }
        return out
    }

    private mutating func close() {
        out.append(.close)
        x = startX
        y = startY
        lastQuad = nil
        lastCubic = nil
    }

    private mutating func step(_ command: UInt8) -> Bool {
        let relative = command >= UInt8(ascii: "a")
        let dx = relative ? x : 0, dy = relative ? y : 0
        switch command | 0x20 {
        case UInt8(ascii: "m"):
            guard let a = number(), let b = number() else { return false }
            x = a + dx
            y = b + dy
            startX = x
            startY = y
            out.append(.move(x, y))
            lastQuad = nil
            lastCubic = nil
        case UInt8(ascii: "l"):
            guard let a = number(), let b = number() else { return false }
            lineTo(a + dx, b + dy)
        case UInt8(ascii: "h"):
            guard let a = number() else { return false }
            lineTo(a + dx, y)
        case UInt8(ascii: "v"):
            guard let b = number() else { return false }
            lineTo(x, b + dy)
        case UInt8(ascii: "q"):
            guard let x1 = number(), let y1 = number(), let a = number(), let b = number() else { return false }
            quad(x1 + dx, y1 + dy, a + dx, b + dy)
        case UInt8(ascii: "t"):
            guard let a = number(), let b = number() else { return false }
            let control = lastQuad.map { (2 * x - $0.0, 2 * y - $0.1) } ?? (x, y)
            quad(control.0, control.1, a + dx, b + dy)
        case UInt8(ascii: "c"):
            guard let x1 = number(), let y1 = number(), let x2 = number(), let y2 = number(),
                  let a = number(), let b = number() else { return false }
            cubic(x1 + dx, y1 + dy, x2 + dx, y2 + dy, a + dx, b + dy)
        case UInt8(ascii: "s"):
            guard let x2 = number(), let y2 = number(), let a = number(), let b = number() else { return false }
            let control = lastCubic.map { (2 * x - $0.0, 2 * y - $0.1) } ?? (x, y)
            cubic(control.0, control.1, x2 + dx, y2 + dy, a + dx, b + dy)
        case UInt8(ascii: "a"):
            guard let rx = number(), let ry = number(), let rotation = number(),
                  let large = flag(), let sweep = flag(), let a = number(), let b = number() else { return false }
            arc(rx, ry, rotation, large, sweep, a + dx, b + dy)
        default:
            return false
        }
        return true
    }

    private mutating func lineTo(_ a: Double, _ b: Double) {
        x = a
        y = b
        out.append(.line(a, b))
        lastQuad = nil
        lastCubic = nil
    }

    private mutating func quad(_ x1: Double, _ y1: Double, _ a: Double, _ b: Double) {
        out.append(.quad(x1, y1, a, b))
        lastQuad = (x1, y1)
        lastCubic = nil
        x = a
        y = b
    }

    private mutating func cubic(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ a: Double, _ b: Double) {
        out.append(.cubic(x1, y1, x2, y2, a, b))
        lastCubic = (x2, y2)
        lastQuad = nil
        x = a
        y = b
    }

    /// Un arc d'ellipse, en courbes de Bézier d'au plus un quart de tour
    /// (SVG 1.1, annexe F.6).
    private mutating func arc(_ rxIn: Double, _ ryIn: Double, _ degrees: Double, _ large: Bool, _ sweep: Bool, _ x2: Double, _ y2: Double) {
        var rx = abs(rxIn), ry = abs(ryIn)
        let x1 = x, y1 = y
        if rx == 0 || ry == 0 || (x1 == x2 && y1 == y2) {
            lineTo(x2, y2)
            return
        }
        let phi = degrees * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)
        let hx = (x1 - x2) / 2, hy = (y1 - y2) / 2
        let px = cosPhi * hx + sinPhi * hy
        let py = -sinPhi * hx + cosPhi * hy
        let lambda = (px * px) / (rx * rx) + (py * py) / (ry * ry)
        if lambda > 1 {
            rx *= lambda.squareRoot()
            ry *= lambda.squareRoot()
        }
        let numerator = rx * rx * ry * ry - rx * rx * py * py - ry * ry * px * px
        let denominator = rx * rx * py * py + ry * ry * px * px
        var factor = (max(0, numerator) / denominator).squareRoot()
        if large == sweep { factor = -factor }
        let cxp = factor * rx * py / ry
        let cyp = -factor * ry * px / rx
        let cx = cosPhi * cxp - sinPhi * cyp + (x1 + x2) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (y1 + y2) / 2
        func angle(_ ux: Double, _ uy: Double, _ vx: Double, _ vy: Double) -> Double {
            let value = atan2(ux * vy - uy * vx, ux * vx + uy * vy)
            return value
        }
        let theta = angle(1, 0, (px - cxp) / rx, (py - cyp) / ry)
        var delta = angle((px - cxp) / rx, (py - cyp) / ry, (-px - cxp) / rx, (-py - cyp) / ry)
        if !sweep && delta > 0 { delta -= 2 * .pi }
        if sweep && delta < 0 { delta += 2 * .pi }
        let segments = max(1, Int((abs(delta) / (.pi / 2)).rounded(.up)))
        let step = delta / Double(segments)
        let k = 4.0 / 3 * tan(step / 4)
        var start = theta
        func point(_ t: Double) -> (Double, Double) {
            let ex = rx * cos(t), ey = ry * sin(t)
            return (cosPhi * ex - sinPhi * ey + cx, sinPhi * ex + cosPhi * ey + cy)
        }
        func tangent(_ t: Double) -> (Double, Double) {
            let ex = -rx * sin(t), ey = ry * cos(t)
            return (cosPhi * ex - sinPhi * ey, sinPhi * ex + cosPhi * ey)
        }
        for _ in 0..<segments {
            let end = start + step
            let p0 = point(start), p3 = point(end)
            let t0 = tangent(start), t3 = tangent(end)
            cubic(p0.0 + k * t0.0, p0.1 + k * t0.1, p3.0 - k * t3.0, p3.1 - k * t3.1, p3.0, p3.1)
            start = end
        }
        x = x2
        y = y2
    }

    private func isLetter(_ byte: UInt8) -> Bool {
        (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122)
    }

    private mutating func skipSeparators() {
        while index < bytes.count, bytes[index] == 32 || bytes[index] == 44 || bytes[index] == 10 || bytes[index] == 9 || bytes[index] == 13 {
            index += 1
        }
    }

    private mutating func flag() -> Bool? {
        skipSeparators()
        guard index < bytes.count else { return nil }
        let byte = bytes[index]
        guard byte == 48 || byte == 49 else { return nil }
        index += 1
        return byte == 49
    }

    private mutating func number() -> Double? {
        skipSeparators()
        let start = index
        if index < bytes.count, bytes[index] == 45 || bytes[index] == 43 { index += 1 }
        var seenDot = false, seenDigit = false
        while index < bytes.count {
            let byte = bytes[index]
            if byte >= 48 && byte <= 57 {
                seenDigit = true
            } else if byte == 46 && !seenDot {
                seenDot = true
            } else if (byte == 101 || byte == 69) && seenDigit {
                index += 1
                if index < bytes.count, bytes[index] == 45 || bytes[index] == 43 { index += 1 }
                continue
            } else {
                break
            }
            index += 1
        }
        guard seenDigit, let text = String(bytes: bytes[start..<index], encoding: .ascii) else {
            index = start
            return nil
        }
        return Double(text)
    }
}
