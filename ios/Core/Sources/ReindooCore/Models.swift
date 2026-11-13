import Foundation

/// Les langues que le dictionnaire sert. Les gloses sont en vietnamien.
/// Mêmes valeurs que `DICTIONARY_SOURCE_LANGUAGES` côté serveur.
public enum Language: String, Codable, Sendable, CaseIterable {
    case french
    case english

    /// Le code de la langue dans le fichier du lexique : un octet par ligne
    /// au lieu d'un mot.
    var code: Int64 {
        switch self {
        case .french: 0
        case .english: 1
        }
    }
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

    public init(explain: String, synonyms: [String] = [], antonyms: [String] = [], exampleSentences: [Example] = []) {
        self.explain = explain
        self.synonyms = synonyms
        self.antonyms = antonyms
        self.exampleSentences = exampleSentences
    }

    // Le lexique compilé omet les listes vides.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        explain = try container.decode(String.self, forKey: .explain)
        synonyms = try container.decodeIfPresent([String].self, forKey: .synonyms) ?? []
        antonyms = try container.decodeIfPresent([String].self, forKey: .antonyms) ?? []
        exampleSentences = try container.decodeIfPresent([Example].self, forKey: .exampleSentences) ?? []
    }
}

/// Une entrée du lexique. Même forme que `Word` dans `@practice/shared`,
/// moins l'identifiant Mongo : ici la clé est (langue, mot).
public struct Entry: Codable, Equatable, Sendable {
    public var word: String
    public var language: Language
    public var translated: String
    public var explains: [Sense]
    public var ipa: [String]
    public var audio: String?
    public var wiki: String?
    public var derived: [String]

    public init(
        word: String, language: Language, translated: String, explains: [Sense] = [],
        ipa: [String] = [], audio: String? = nil, wiki: String? = nil, derived: [String] = []
    ) {
        self.word = word
        self.language = language
        self.translated = translated
        self.explains = explains
        self.ipa = ipa
        self.audio = audio
        self.wiki = wiki
        self.derived = derived
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
