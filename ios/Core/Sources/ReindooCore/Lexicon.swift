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

        // Tapé sans accents, un mot vietnamien en a souvent plusieurs : « an »
        // est ăn, án, ấn, an… Le plus fréquent d'abord, les autres à côté —
        // même si « an » existe tel quel, il est rarement ce qu'on cherchait.
        if language.isOftenTypedBare, Text.isBare(typed) {
            let candidates = try entries(folded: Text.fold(typed), in: language)
            if let best = candidates.first {
                let others = candidates.dropFirst().map(\.word) + lemmas
                return .found(best, matchedForm: nil, alsoFrom: Array(unique(others, except: best.word).prefix(Self.alsoFromLimit)))
            }
        }

        if let direct = try entry(matching: typed, in: language) {
            return .found(direct, matchedForm: nil, alsoFrom: lemmas.filter { $0 != direct.word })
        }

        if !lemmas.isEmpty {
            let entries = try self.entries(lemmas, in: language)
            if let best = entries.first {
                if language.isTypedByReading {
                    // « shi » a des dizaines de caractères : le plus courant,
                    // quelques autres. Une lecture n'est pas « une forme de »
                    // ; un caractère traditionnel, si.
                    let note = Text.hasHanzi(typed) ? typed : nil
                    return .found(best, matchedForm: note, alsoFrom: Array(entries.dropFirst().map(\.word).prefix(Self.alsoFromLimit)))
                }
                // « hoà » mène à « hòa » : le même mot, le ton posé ailleurs.
                // Ce n'est pas « une forme de », il n'y a rien à en dire.
                let note = Text.fold(typed) == Text.fold(best.word) ? nil : typed
                return .found(best, matchedForm: note, alsoFrom: entries.dropFirst().map(\.word))
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

    /// Vrai quand le sens de l'entrée n'est qu'un renvoi vers une autre
    /// vedette : un pluriel, un temps, une abréviation. Un dixième du
    /// lexique. Bon pour la recherche, pas pour un quiz ni une découverte.
    public func pointsElsewhere(_ entry: Entry) -> Bool {
        guard let target = Text.pointer(in: entry.translated), target != entry.word else { return false }
        return ((try? self.entry(target, in: entry.language)) ?? nil) != nil
            || ((try? self.entry(target.lowercased(), in: entry.language)) ?? nil) != nil
    }

    /// Ce que l'utilisateur complète pendant qu'il tape. Les plus fréquents d'abord.
    public func completions(for prefix: String, in language: Language, limit: Int = 20) throws -> [String] {
        let folded = Text.fold(prefix.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !folded.isEmpty else { return [] }
        if language.isTypedByReading, let key = Text.pinyinKey(folded) {
            return try completions(reading: key, in: language, limit: limit)
        }
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

    /// Les mots chinois dont la lecture commence par ce qui est tapé : « nih »
    /// propose 你好. Les clés de lecture sont dans la table des formes.
    private func completions(reading key: String, in language: Language, limit: Int) throws -> [String] {
        let rows = try database.query(
            "SELECT form, lemmas FROM form WHERE language = ? AND form >= ? AND form < ? ORDER BY length(form), form LIMIT 200",
            [.int(language.code), .text(key), .text(key + "\u{10FFFF}")]
        ) { ($0.text(0), $0.text(1)) }
        // Seules les clés comptent : une forme en caractères ne commence pas
        // par une lettre latine, mais une forme pinyin à accents, si.
        let exact = Set(rows.filter { $0.0 == key }.flatMap { $0.1.split(separator: "\t").map(String.init) })
        var words: [String] = []
        var seen = Set<String>()
        for (form, lemmas) in rows where Text.pinyinKey(form) == form {
            for lemma in lemmas.split(separator: "\t").map(String.init) where seen.insert(lemma).inserted { words.append(lemma) }
        }
        guard !words.isEmpty else { return [] }
        let ranks = try words.reduce(into: [String: Double]()) { ranks, word in
            if let rank = try database.query(
                "SELECT rank FROM entry WHERE language = ? AND word = ?", [.int(language.code), .text(word)]
            ) { $0.real(0) }.first { ranks[word] = rank }
        }
        return words.filter { ranks[$0] != nil }
            .sorted { (exact.contains($0) ? 1 : 0, ranks[$0]!, $1) > (exact.contains($1) ? 1 : 0, ranks[$1]!, $0) }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: Les trois temps

    /// Assez pour choisir, pas assez pour noyer : « no » a quatorze lectures.
    static let alsoFromLimit = 8

    private func unique(_ words: [String], except first: String) -> [String] {
        var seen: Set<String> = [first]
        return words.filter { seen.insert($0).inserted }
    }

    /// Toutes les vedettes qu'une clé repliée peut vouloir dire, la plus
    /// fréquente d'abord.
    private func entries(folded: String, in language: Language) throws -> [Entry] {
        try database.query(
            "SELECT word, body FROM entry WHERE language = ? AND folded = ? ORDER BY rank DESC, word LIMIT 20",
            [.int(language.code), .text(folded)]
        ) { ($0.text(0), $0.text(1)) }.map { try decode($0.1, word: $0.0, language: language) }
    }

    /// La vedette telle que tapée ; sinon sans majuscules ; sinon sans accents.
    /// Le site ne fait que le premier. Un téléphone met une majuscule en début
    /// de saisie et rend les accents pénibles : on pardonne les deux.
    private func entry(matching typed: String, in language: Language) throws -> Entry? {
        if let exact = try entry(typed, in: language) { return exact }
        let lowered = typed.lowercased()
        if lowered != typed, let entry = try entry(lowered, in: language) { return entry }
        // En vietnamien, l'accent tapé est un choix : « hoà » ne veut pas dire
        // « hoa », la fleur. Il passe par l'index des formes, qui connaît
        // l'autre place du ton.
        if language.isOftenTypedBare { return nil }
        return try database.query(
            "SELECT word, body FROM entry WHERE language = ? AND folded = ? ORDER BY rank DESC LIMIT 1",
            [.int(language.code), .text(Text.fold(typed))]
        ) { ($0.text(0), $0.text(1)) }.first.map { try decode($0.1, word: $0.0, language: language) }
    }

    private func lemmas(forForm form: String, in language: Language) throws -> [String] {
        var candidates = [form, form.lowercased()]
        if language.isTypedByReading {
            candidates += [Text.toneKey(form), Text.pinyinKey(form)].compactMap { $0 }
        }
        for candidate in candidates {
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

    /// Une ligne du NDJSON. Tout ce qui relie ses noms de champs à ceux de
    /// l'app est ici, et nulle part ailleurs.
    ///
    /// Le chinois (`make mongo LANG=zh`) suit le même schéma, à deux
    /// différences près : sa prononciation est du pinyin, et un mot peut
    /// porter sa lecture Hán Việt. Tant que le dépôt `dictionnaire` n'a pas
    /// fixé leurs noms, on accepte les plus probables, en texte ou en liste.
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
        var memo: Memo?
        var rank: Double?
        var form: String?
        var lemmas: [String]?
        var pinyin: [String]?
        var hanViet: [String]?

        private enum Keys: String, CodingKey {
            case _collection, sourceLanguage, word, translated, explains, ipa, audio, wiki, derived, memo, rank, form, lemmas
            case pinyin, hanViet, hanviet, han_viet, sinoVietnamese
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            _collection = try c.decode(String.self, forKey: ._collection)
            sourceLanguage = try c.decode(String.self, forKey: .sourceLanguage)
            word = try c.decodeIfPresent(String.self, forKey: .word)
            translated = try c.decodeIfPresent(String.self, forKey: .translated)
            explains = try c.decodeIfPresent([Sense].self, forKey: .explains)
            ipa = try c.decodeIfPresent([String].self, forKey: .ipa)
            audio = try c.decodeIfPresent(String.self, forKey: .audio)
            wiki = try c.decodeIfPresent(String.self, forKey: .wiki)
            derived = try c.decodeIfPresent([String].self, forKey: .derived)
            memo = try c.decodeIfPresent(Memo.self, forKey: .memo)
            rank = try c.decodeIfPresent(Double.self, forKey: .rank)
            form = try c.decodeIfPresent(String.self, forKey: .form)
            lemmas = try c.decodeIfPresent([String].self, forKey: .lemmas)
            pinyin = Self.texts(c, .pinyin)
            hanViet = [Keys.hanViet, .hanviet, .han_viet, .sinoVietnamese].lazy.compactMap { Self.texts(c, $0) }.first
        }

        /// Un texte ou une liste de textes ; rien de vide.
        private static func texts(_ c: KeyedDecodingContainer<Keys>, _ key: Keys) -> [String]? {
            let list = (try? c.decodeIfPresent([String].self, forKey: key)) ?? (try? c.decodeIfPresent(String.self, forKey: key)).flatMap { $0.map { [$0] } }
            let kept = (list ?? []).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            return kept.isEmpty ? nil : kept
        }

        /// Ce que l'app montre comme prononciation : le pinyin s'il est à
        /// part, sinon le champ `ipa`, qui le porte pour le chinois.
        var pronunciation: [String] { pinyin ?? ipa ?? [] }
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
        var readings = Readings()
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
                        // Un sens vide (« (Danh từ) . ») part, sauf s'il porte des exemples.
                        let senses = (line.explains ?? []).filter {
                            !Text.isWikiResidue($0.explain)
                                && (!Text.bareSense($0.explain).isEmpty || !$0.exampleSentences.isEmpty)
                        }
                        var translated = Text.cleanGloss(line.translated ?? "")
                        if translated.isEmpty { translated = Text.summary(from: senses) }
                        let entry = Entry(
                            word: word, language: language, translated: translated,
                            explains: senses,
                            ipa: line.pronunciation, audio: line.audio,
                            wiki: line.wiki, derived: line.derived ?? [], memo: line.memo,
                            hanViet: line.hanViet ?? []
                        )
                        if language.isTypedByReading {
                            for reading in line.pronunciation { readings.add(reading, for: word) }
                        }
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
                        if language.isTypedByReading {
                            for lemma in lemmas { readings.add(form, for: lemma) }
                        }
                    } else {
                        report.skipped += 1
                    }
                }
            }
            try readings.write(into: database)
        }

        try database.execute("CREATE INDEX entry_folded ON entry (language, folded, rank DESC);")
        try database.run("INSERT INTO meta (key, value) VALUES ('schema', ?)", [.text(String(Lexicon.schemaVersion))])
        try database.execute("VACUUM;")
        return report
    }
}

/// Les clés de lecture du chinois : chaque pinyin, ramené à `Text.pinyinKey`,
/// mène à ses caractères. Rangées dans la table des formes, à côté des formes
/// que le NDJSON donne, et fusionnées avec elles : « shi » en a des dizaines.
private struct Readings {
    private var lemmas: [String: [String]] = [:]

    mutating func add(_ reading: String, for word: String) {
        for key in [Text.toneKey(reading), Text.pinyinKey(reading)].compactMap({ $0 })
        where !(lemmas[key]?.contains(word) ?? false) {
            lemmas[key, default: []].append(word)
        }
    }

    @MainActor
    func write(into database: Database) throws {
        let code = Language.chinese.code
        for key in lemmas.keys.sorted() {
            let existing = try database.query(
                "SELECT lemmas FROM form WHERE language = ? AND form = ?", [.int(code), .text(key)]
            ) { $0.text(0) }.first.map { $0.split(separator: "\t").map(String.init) } ?? []
            var merged = existing
            for word in lemmas[key] ?? [] where !merged.contains(word) { merged.append(word) }
            try database.run(
                "INSERT OR REPLACE INTO form (language, form, lemmas) VALUES (?, ?, ?)",
                [.int(code), .text(key), .text(merged.joined(separator: "\t"))]
            )
        }
    }
}
