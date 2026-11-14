import Foundation

/// Les entiers de JavaScript, à l'identique. Les décors tirent leurs formes de
/// petits hachages écrits en JS, où une multiplication se fait en flottant et
/// `| 0` replie sur 32 bits : pour retrouver les mêmes arbres et les mêmes
/// flocons, il faut les mêmes arrondis.
enum JS {
    /// `ToInt32`.
    static func int32(_ value: Double) -> Int32 {
        Int32(bitPattern: uint32(value))
    }

    /// `ToUint32`, ce que fait `x >>> 0`.
    static func uint32(_ value: Double) -> UInt32 {
        guard value.isFinite else { return 0 }
        let whole = value.rounded(.towardZero)
        var folded = whole.truncatingRemainder(dividingBy: 4_294_967_296)
        if folded < 0 { folded += 4_294_967_296 }
        return UInt32(folded)
    }

    /// `a ^ b` sur deux nombres.
    static func xor(_ a: Double, _ b: Double) -> Double {
        Double(int32(a) ^ int32(b))
    }

    /// `a >>> n`.
    static func ushr(_ a: Double, _ n: UInt32) -> Double {
        Double(uint32(a) >> n)
    }

    /// `Math.imul(a, b)`.
    static func imul(_ a: Double, _ b: Double) -> Double {
        Double(int32(a) &* int32(b))
    }

    /// `Math.round` : la moitié monte, même sous zéro.
    static func round(_ value: Double) -> Double {
        (value + 0.5).rounded(.down)
    }
}
