import Foundation

/// Les langues que le dictionnaire sert : celle du mot cherché.
/// Le français et l'anglais sont expliqués en vietnamien ; le vietnamien,
/// en français — et en anglais, marqué [EN], là où le Wiktionnaire français
/// n'a rien. Mêmes valeurs que `DICTIONARY_SOURCE_LANGUAGES` côté serveur.
public enum Language: String, Codable, Sendable, CaseIterable {
    case french
    case english
    case vietnamese

    /// Le code de la langue dans le fichier du lexique : un octet par ligne
    /// au lieu d'un mot.
    var code: Int64 {
        switch self {
        case .french: 0
        case .english: 1
        case .vietnamese: 2
        }
    }

    /// Le vietnamien se tape souvent sans accents, faute de clavier : « an »
    /// veut dire « ăn » plus souvent que « an ». La recherche le sait.
    var isOftenTypedBare: Bool { self == .vietnamese }
}

public struct Example: Codable, Equatable, Sendable {
    public var sourceSentence: String
    public var targetTranslation: String

    public init(sourceSentence: String, targetTranslation: String) {
        self.sourceSentence = sourceSentence
        self.targetTranslation = targetTranslation
    }
}

public struct Sense: Codable, Equatable, Sendable {
    public var explain: String
    public var synonyms: [String]
    public var antonyms: [String]
    public var exampleSentences: [Example]
    /// Ce qu'un francophone se trompe à faire avec ce sens. Seules les
    /// entrées reindoo en ont.
    public var note: String?
    /// « reindoo » pour les entrées écrites pour l'app ; rien pour un sens
    /// du Wiktionnaire.
    public var source: String?
    /// Le même sens en anglais, à côté du français. Seules les entrées
    /// reindoo Việt–Pháp en ont : qui apprend les trois langues lit les deux.
    public var en: String?

    public var isOwn: Bool { source == Self.own }
    public static let own = "reindoo"

    public init(
        explain: String, synonyms: [String] = [], antonyms: [String] = [], exampleSentences: [Example] = [],
        note: String? = nil, source: String? = nil, en: String? = nil
    ) {
        self.explain = explain
        self.synonyms = synonyms
        self.antonyms = antonyms
        self.exampleSentences = exampleSentences
        self.note = note
        self.source = source
        self.en = en
    }

    // Le lexique compilé omet les listes vides.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        explain = try container.decode(String.self, forKey: .explain)
        synonyms = try container.decodeIfPresent([String].self, forKey: .synonyms) ?? []
        antonyms = try container.decodeIfPresent([String].self, forKey: .antonyms) ?? []
        exampleSentences = try container.decodeIfPresent([Example].self, forKey: .exampleSentences) ?? []
        note = try container.decodeIfPresent(String.self, forKey: .note)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        en = try container.decodeIfPresent(String.self, forKey: .en)
    }
}

/// Une entrée du lexique. Même forme que `Word` dans `@practice/shared`,
/// moins l'identifiant Mongo : ici la clé est (langue, mot).
/// Ce qui aide à retenir un mot : d'où il vient, ses voisins, un mémo. Écrit
/// à la main dans `dictionnaire` (`data/memo-<langue>.jsonl`), en vietnamien,
/// pour les mots qui ont une histoire. Les trois parties sont facultatives ;
/// `**gras**` et `*italique*` y sont permis.
public struct Memo: Codable, Equatable, Sendable {
    public var origin: String?
    public var related: String?
    public var tip: String?

    public init(origin: String? = nil, related: String? = nil, tip: String? = nil) {
        self.origin = origin
        self.related = related
        self.tip = tip
    }

    /// Une note sans aucun texte ne compte pas : pas de bouton pour rien.
    public var isEmpty: Bool {
        [origin, related, tip].allSatisfy { $0?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true }
    }
}

/// La note telle que l'écran la montre : ses parties dans l'ordre, chacune
/// avec son titre. Le mot et l'entrée la partagent, avec le reel.
public struct MemoState: Codable, Equatable, Sendable {
    public struct Part: Codable, Equatable, Sendable {
        /// `origin`, `related` ou `tip` : la vue en tire son icône.
        public var name: String
        public var title: String
        public var text: String
    }

    public var title: String
    public var parts: [Part]

    init?(_ memo: Memo?, word: String, copy: Copy) {
        guard let memo, !memo.isEmpty else { return nil }
        title = word
        parts = [("origin", copy.memoOrigin, memo.origin), ("related", copy.memoRelated, memo.related), ("tip", copy.memoTip, memo.tip)]
            .compactMap { name, title, text in
                guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
                return Part(name: name, title: title, text: text)
            }
    }
}

public struct Entry: Codable, Equatable, Sendable {
    public var word: String
    public var language: Language
    public var translated: String
    public var explains: [Sense]
    public var ipa: [String]
    public var audio: String?
    public var wiki: String?
    public var derived: [String]
    public var memo: Memo?

    public init(
        word: String, language: Language, translated: String, explains: [Sense] = [],
        ipa: [String] = [], audio: String? = nil, wiki: String? = nil, derived: [String] = [],
        memo: Memo? = nil
    ) {
        self.word = word
        self.language = language
        self.translated = translated
        self.explains = explains
        self.ipa = ipa
        self.audio = audio
        self.wiki = wiki
        self.derived = derived
        self.memo = memo?.isEmpty == false ? memo : nil
    }
}

/// Ce que rend une recherche. Un mot absent est dit absent, avec de quoi
/// rebondir : le lexique est fini, et rien ne l'invente.
public enum Lookup: Equatable, Sendable {
    case found(Entry, matchedForm: String?, alsoFrom: [String])
    case notFound(query: String, suggestions: [String])
}

public struct WordKey: Codable, Hashable, Sendable {
    public var language: Language
    public var word: String

    public init(_ language: Language, _ word: String) {
        self.language = language
        self.word = word
    }
}
