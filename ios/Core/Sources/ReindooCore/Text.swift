import Foundation

enum Text {
    /// La clé de recherche : sans casse ni accents. « Élève » et « eleve » se
    /// rejoignent, ce qui compte sur un clavier de téléphone.
    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    /// Distance de Levenshtein bornée : au-delà de `max`, on rend `max + 1`.
    /// Portée telle quelle de `searchWord.usecase.ts`.
    static func editDistance(_ a: String, _ b: String, max: Int) -> Int {
        let a = Array(a), b = Array(b)
        if abs(a.count - b.count) > max { return max + 1 }
        if a.isEmpty { return b.count }

        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i]
            var best = i
            for j in stride(from: 1, through: b.count, by: 1) {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                let value = min(current[j - 1] + 1, previous[j] + 1, previous[j - 1] + cost)
                current.append(value)
                if value < best { best = value }
            }
            if best > max { return max + 1 }
            previous = current
        }
        return previous[b.count]
    }
}
