import Foundation

enum Text {
    /// La clé de recherche : sans casse ni accents. « Élève » et « eleve » se
    /// rejoignent, ce qui compte sur un clavier de téléphone.
    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    /// Un modèle du wiki que l'extraction n'a pas déplié, comme `{{rfdef}}`.
    /// Ce n'est pas un sens : c'est la page qui en réclame un.
    static func isWikiResidue(_ text: String) -> Bool {
        text.contains("{{") || text.contains("}}")
    }

    /// Le résumé d'une entrée joint ses sens par « / ». On garde les lisibles.
    static func cleanGloss(_ gloss: String) -> String {
        gloss.components(separatedBy: " / ")
            .filter { !isWikiResidue($0) && !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: " / ")
    }

    /// Le mot vers lequel un résumé renvoie, s'il ne fait que ça :
    /// « Số nhiều của that » rend « that ». Un vrai sens peut aussi finir
    /// par « của » (« Vợ của vua ») : c'est le lexique qui tranche, en
    /// vérifiant que le mot visé est une de ses vedettes.
    static func pointer(in gloss: String) -> String? {
        guard let range = gloss.range(of: " của ", options: .backwards) else { return nil }
        let head = gloss[..<range.lowerBound]
        var tail = gloss[range.upperBound...].trimmingCharacters(in: .whitespaces)
        if tail.hasSuffix(".") { tail.removeLast() }
        guard !tail.isEmpty, !tail.contains(" "), head.count <= 60, !head.contains(" / ") else { return nil }
        return tail
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
