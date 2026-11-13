import Foundation

/// Le lexique : un fichier SQLite en lecture seule, livré dans l'app.
///
/// C'est une donnée de référence. On ne la modifie pas, on la remplace en
/// entier. Rien dans les données de l'utilisateur ne pointe vers ses lignes :
/// les favoris et l'historique gardent (langue, mot).
@MainActor
public final class Lexicon {
    private let database: Database

    public static let schemaVersion = 2

    public init(path: String) throws {
        database = try Database(path: path, readOnly: true)
        let found = try database.query("SELECT value FROM meta WHERE key = 'schema'") { $0.text(0) }.first
        guard found == String(Self.schemaVersion) else {
            throw DatabaseError(code: 0, message: "lexique de schéma \(found ?? "inconnu"), attendu \(Self.schemaVersion)")
        }
    }

    public func count(_ language: Language) throws -> Int {
        try database.query("SELECT count(*) FROM entry WHERE language = ?", [.int(language.code)]) { Int($0.int(0)) }.first ?? 0
    }

    // MARK: Chercher

    /// La même recherche que le site, en trois temps : la vedette, puis la
    /// forme fléchie, puis des voisins quand rien ne colle.
    public func lookUp(_ query: String, in language: Language) throws -> Lookup {
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return .notFound(query: typed, suggestions: []) }

        // Consulté dans les deux cas : « went » a sa propre entrée, qui n'est
        // qu'un renvoi vers « go ».
        let lemmas = try self.lemmas(forForm: typed, in: language)

        if let direct = try entry(matching: typed, in: language) {
            return .found(direct, matchedForm: nil, alsoFrom: lemmas.filter { $0 != direct.word })
        }

        if !lemmas.isEmpty {
            let entries = try self.entries(lemmas, in: language)
            if let best = entries.first {
                return .found(best, matchedForm: typed, alsoFrom: entries.dropFirst().map(\.word))
            }
        }

        return .notFound(query: typed, suggestions: try neighbours(of: typed, in: language))
    }

    /// La vedette exacte.
    public func entry(_ word: String, in language: Language) throws -> Entry? {
        try database.query(
            "SELECT word, body FROM entry WHERE language = ? AND word = ?",
            [.int(language.code), .text(word)]
        ) { ($0.text(0), $0.text(1)) }.first.map { try decode($0.1, word: $0.0, language: language) }
    }

    /// Ce que l'utilisateur complète pendant qu'il tape. Les plus fréquents d'abord.
    public func completions(for prefix: String, in language: Language, limit: Int = 20) throws -> [String] {
        let folded = Text.fold(prefix.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !folded.isEmpty else { return [] }
        return try database.query(
            """
            SELECT word FROM entry
            WHERE language = ? AND folded >= ? AND folded < ?
            ORDER BY (folded = ?) DESC, rank DESC, word
            LIMIT ?
            """,
            [.int(language.code), .text(folded), .text(folded + "\u{10FFFF}"), .text(folded), .int(Int64(limit))]
        ) { $0.text(0) }
    }

    // MARK: Les trois temps

    /// La vedette telle que tapée ; sinon sans majuscules ; sinon sans accents.
    /// Le site ne fait que le premier. Un téléphone met une majuscule en début
    /// de saisie et rend les accents pénibles : on pardonne les deux.
    private func entry(matching typed: String, in language: Language) throws -> Entry? {
        if let exact = try entry(typed, in: language) { return exact }
        let lowered = typed.lowercased()
        if lowered != typed, let entry = try entry(lowered, in: language) { return entry }
        return try database.query(
            "SELECT word, body FROM entry WHERE language = ? AND folded = ? ORDER BY rank DESC LIMIT 1",
            [.int(language.code), .text(Text.fold(typed))]
        ) { ($0.text(0), $0.text(1)) }.first.map { try decode($0.1, word: $0.0, language: language) }
    }

    private func lemmas(forForm form: String, in language: Language) throws -> [String] {
        for candidate in [form, form.lowercased()] {
            let found = try database.query(
                "SELECT lemmas FROM form WHERE language = ? AND form = ?",
                [.int(language.code), .text(candidate)]
            ) { $0.text(0) }.first
            if let found { return found.split(separator: "\t").map(String.init) }
        }
        return []
    }

    /// Plusieurs vedettes, la plus fréquente d'abord.
    private func entries(_ words: [String], in language: Language) throws -> [Entry] {
        var ranked: [(Entry, Double)] = []
        for word in words {
            let rows = try database.query(
                "SELECT body, rank FROM entry WHERE language = ? AND word = ?",
                [.int(language.code), .text(word)]
            ) { ($0.text(0), $0.real(1)) }
            if let (body, rank) = rows.first { ranked.append((try decode(body, word: word, language: language), rank)) }
        }
        return ranked.sorted { $0.1 > $1.1 }.map(\.0)
    }

    /// Des vedettes proches. On présélectionne par préfixe, puis on classe en
    /// mémoire par distance d'édition — comme le site.
    private func neighbours(of typed: String, in language: Language) throws -> [String] {
        let folded = Text.fold(typed)
        let prefix = String(folded.prefix(min(3, folded.count)))
        let candidates = try database.query(
            """
            SELECT word FROM entry
            WHERE language = ? AND folded >= ? AND folded < ?
            ORDER BY rank DESC LIMIT 400
            """,
            [.int(language.code), .text(prefix), .text(prefix + "\u{10FFFF}")]
        ) { $0.text(0) }

        return candidates.enumerated()
            .map { (word: $0.element, order: $0.offset, distance: Text.editDistance(folded, Text.fold($0.element), max: 3)) }
            .filter { $0.distance <= 3 }
            .sorted { ($0.distance, $0.order) < ($1.distance, $1.order) }
            .prefix(8)
            .map(\.word)
    }

    // MARK: Piocher

    private var bounds: [Language: (low: Int64, high: Int64)?] = [:]

    private func idBounds(_ language: Language) throws -> (low: Int64, high: Int64)? {
        if let known = bounds[language] { return known }
        let found = try database.query(
            "SELECT count(*), min(id), max(id) FROM entry WHERE language = ?", [.int(language.code)]
        ) { ($0.int(0), $0.int(1), $0.int(2)) }.first
        let range: (low: Int64, high: Int64)? = found.flatMap { $0.0 > 0 ? (low: $0.1, high: $0.2) : nil }
        bounds[language] = .some(range)
        return range
    }

    /// Des vedettes prises à un endroit du lexique que `pick` choisit, les
    /// plus courantes d'abord. `pick(n)` rend un nombre de 0 à n − 1.
    ///
    /// On lit une fenêtre de lignes voisines plutôt que de trier tout le
    /// lexique : c'est l'affaire de quelques pages, pas de 60 Mo.
    public func sample(_ language: Language, limit: Int, pick: (Int) -> Int) throws -> [Entry] {
        guard let range = try idBounds(language) else { return [] }
        let window = 40
        let start = range.low + Int64(pick(Int(range.high - range.low) + 1))
        let read: (Row) -> (word: String, body: String, rank: Double) = { ($0.text(0), $0.text(1), $0.real(2)) }
        var rows = try database.query(
            "SELECT word, body, rank FROM entry WHERE id >= ? AND language = ? LIMIT \(window)",
            [.int(start), .int(language.code)], read
        )
        if rows.count < window {
            // Près de la fin : on complète par le début.
            rows += try database.query(
                "SELECT word, body, rank FROM entry WHERE id < ? AND language = ? LIMIT \(window - rows.count)",
                [.int(start), .int(language.code)], read
            )
        }
        return try rows
            .sorted { $0.rank != $1.rank ? $0.rank > $1.rank : $0.word < $1.word }
            .prefix(limit)
            .map { try decode($0.body, word: $0.word, language: language) }
    }

    private func decode(_ body: String, word: String, language: Language) throws -> Entry {
        try JSONDecoder().decode(Packed.self, from: Data(body.utf8)).entry(word: word, language: language)
    }
}

// MARK: - Construire le fichier

/// Compile le NDJSON du dépôt `dictionnaire` (`make mongo LANG=fr`) en un
/// fichier SQLite. Le site charge ce même NDJSON dans Mongo : les deux
/// dictionnaires ne peuvent pas diverger.
public enum LexiconBuilder {
    public struct Report: Equatable, Sendable {
        public var entries = 0
        public var forms = 0
        public var skipped = 0
    }

    private struct Line: Decodable {
        var _collection: String
        var sourceLanguage: String
        var word: String?
        var translated: String?
        var explains: [Sense]?
        var ipa: [String]?
        var audio: String?
        var wiki: String?
        var derived: [String]?
        var rank: Double?
        var form: String?
        var lemmas: [String]?
    }

    @MainActor
    public static func build(ndjson sources: [String], to path: String) throws -> Report {
        try? FileManager.default.removeItem(atPath: path)
        let database = try Database(path: path)
        try database.execute(
            """
            PRAGMA journal_mode = OFF;
            PRAGMA synchronous = OFF;
            CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL) WITHOUT ROWID;
            -- Une table à rowid : les corps sont longs, et un arbre d'index
            -- (WITHOUT ROWID) les range mal. Mesuré : 33 Mo de perdus sur 105.
            CREATE TABLE entry (
              id       INTEGER PRIMARY KEY,
              language INTEGER NOT NULL,
              word     TEXT NOT NULL,
              folded   TEXT NOT NULL,
              rank     REAL NOT NULL,
              body     TEXT NOT NULL
            );
            CREATE UNIQUE INDEX entry_word ON entry (language, word);
            CREATE TABLE form (
              language INTEGER NOT NULL,
              form     TEXT NOT NULL,
              lemmas   TEXT NOT NULL,
              PRIMARY KEY (language, form)
            ) WITHOUT ROWID;
            """
        )

        var report = Report()
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        try database.transaction {
            for source in sources {
                for raw in source.split(whereSeparator: \.isNewline) {
                    guard let line = try? decoder.decode(Line.self, from: Data(raw.utf8)),
                          let language = Language(rawValue: line.sourceLanguage)
                    else {
                        report.skipped += 1
                        continue
                    }

                    if line._collection == "dictionary", let word = line.word {
                        let entry = Entry(
                            word: word, language: language, translated: line.translated ?? "",
                            explains: line.explains ?? [], ipa: line.ipa ?? [], audio: line.audio,
                            wiki: line.wiki, derived: line.derived ?? []
                        )
                        let body = String(decoding: try encoder.encode(Packed(entry)), as: UTF8.self)
                        // Une vedette en double : la plus fréquente gagne.
                        try database.run(
                            """
                            INSERT INTO entry (language, word, folded, rank, body) VALUES (?, ?, ?, ?, ?)
                            ON CONFLICT (language, word) DO UPDATE SET
                              folded = excluded.folded, rank = excluded.rank, body = excluded.body
                            WHERE excluded.rank > entry.rank
                            """,
                            [.int(language.code), .text(word), .text(Text.fold(word)), .real(line.rank ?? 0), .text(body)]
                        )
                        report.entries += 1
                    } else if line._collection == "dictionary_forms", let form = line.form, let lemmas = line.lemmas {
                        // Séparés par une tabulation : aucun mot n'en contient.
                        let body = lemmas.joined(separator: "\t")
                        try database.run(
                            "INSERT OR REPLACE INTO form (language, form, lemmas) VALUES (?, ?, ?)",
                            [.int(language.code), .text(form), .text(body)]
                        )
                        report.forms += 1
                    } else {
                        report.skipped += 1
                    }
                }
            }
        }

        try database.execute("CREATE INDEX entry_folded ON entry (language, folded, rank DESC);")
        try database.run("INSERT INTO meta (key, value) VALUES ('schema', ?)", [.text(String(Lexicon.schemaVersion))])
        try database.execute("VACUUM;")
        return report
    }
}
