import Foundation

enum Text {
    /// La clé de recherche : sans casse ni accents. « Élève » et « eleve » se
    /// rejoignent, ce qui compte sur un clavier de téléphone.
    ///
    /// « đ » n'est pas un d accentué pour Unicode, mais une lettre à part :
    /// le repli de Foundation le laisse. Un Vietnamien sans clavier tape
    /// pourtant « dep » pour « đẹp ».
    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .replacingOccurrences(of: "đ", with: "d")
    }

    /// Vrai quand le texte n'a ni accent ni « đ » : tapé sans clavier.
    static func isBare(_ text: String) -> Bool {
        fold(text) == text.lowercased()
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

    /// Ce qu'un sens dit une fois ôtées ses étiquettes : « (Danh từ) Sao
    /// chổi. » rend « Sao chổi ». « (Danh từ) . » ne dit rien.
    static func bareSense(_ explain: String) -> String {
        var text = Substring(explain).drop { $0 == " " }
        while text.first == "(", let close = text.firstIndex(of: ")") {
            text = text[text.index(after: close)...].drop { $0 == " " }
        }
        return text.trimmingCharacters(in: CharacterSet(charactersIn: " .;:,"))
    }

    /// Un résumé tiré du premier sens lisible, quand la source n'en donne pas.
    static func summary(from senses: [Sense]) -> String {
        guard let bare = senses.lazy.map({ bareSense($0.explain) }).first(where: { !$0.isEmpty }) else { return "" }
        return bare.prefix(1).uppercased() + bare.dropFirst()
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
