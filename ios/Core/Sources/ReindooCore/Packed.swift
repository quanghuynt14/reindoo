import Foundation

/// La forme d'une entrée dans le fichier du lexique.
///
/// Une entrée médiane pesait 344 octets, dont une bonne moitié de redite :
/// le mot et la langue, déjà en colonnes ; l'adresse du Wiktionnaire, qui se
/// déduit du mot ; des listes vides ; des noms de clés longs. On ne garde que
/// ce qui ne se retrouve pas ailleurs.
struct Packed: Codable {
    var t: String          // translated
    var s: [PackedSense]?  // explains
    var i: [String]?       // ipa
    var a: String?         // audio
    var w: String?         // wiki, seulement quand il ne se déduit pas
    var n: Bool?           // vrai : pas de page Wiktionnaire
    var d: [String]?       // derived

    init(_ entry: Entry) {
        t = entry.translated
        s = entry.explains.isEmpty ? nil : entry.explains.map(PackedSense.init)
        i = entry.ipa.isEmpty ? nil : entry.ipa
        a = entry.audio
        d = entry.derived.isEmpty ? nil : entry.derived
        if let wiki = entry.wiki {
            w = wiki == Self.wiki(for: entry.word, in: entry.language) ? nil : wiki
        } else {
            n = true
        }
    }

    func entry(word: String, language: Language) -> Entry {
        Entry(
            word: word, language: language, translated: t,
            explains: (s ?? []).map(\.sense), ipa: i ?? [], audio: a,
            wiki: n == true ? nil : (w ?? Self.wiki(for: word, in: language)),
            derived: d ?? []
        )
    }

    /// L'adresse de la page, telle que `dictionnaire` l'écrit.
    static func wiki(for word: String, in language: Language) -> String {
        let title = word.replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: unreserved) ?? word
        let section = switch language {
        case .french: "Ti%E1%BA%BFng_Ph%C3%A1p"
        case .english: "Ti%E1%BA%BFng_Anh"
        }
        return "https://vi.wiktionary.org/wiki/\(title)#\(section)"
    }

    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )
}

struct PackedSense: Codable {
    var e: String        // explain
    var y: [String]?     // synonyms
    var n: [String]?     // antonyms
    var x: [[String]]?   // exemples : [phrase, traduction]

    init(_ sense: Sense) {
        e = sense.explain
        y = sense.synonyms.isEmpty ? nil : sense.synonyms
        n = sense.antonyms.isEmpty ? nil : sense.antonyms
        x = sense.exampleSentences.isEmpty ? nil : sense.exampleSentences.map { [$0.sourceSentence, $0.targetTranslation] }
    }

    var sense: Sense {
        Sense(
            explain: e, synonyms: y ?? [], antonyms: n ?? [],
            exampleSentences: (x ?? []).compactMap { pair in
                pair.count == 2 ? Example(sourceSentence: pair[0], targetTranslation: pair[1]) : nil
            }
        )
    }
}
