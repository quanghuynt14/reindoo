import Foundation

/// Un changement que le serveur ne connaît pas encore.
public struct Change: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case historyAdd = "history.add"
        case historyDelete = "history.delete"
        case likeAdd = "like.add"
        case likeDelete = "like.delete"

        /// Deux changements de la même famille sur le même mot : le dernier
        /// écrit gagne, et le précédent n'a plus à partir.
        var family: String { String(rawValue.prefix { $0 != "." }) }
    }

    /// Généré sur l'appareil. C'est la clé d'idempotence : le serveur traite
    /// un identifiant déjà vu comme déjà fait.
    public var id: String
    public var kind: Kind
    public var key: WordKey
    public var at: Date
}

public struct SavedWord: Equatable, Sendable {
    public var key: WordKey
    public var at: Date
}

/// Ce qui appartient à l'utilisateur : l'historique, les cœurs, et la file des
/// changements à envoyer. Chaque écriture est locale d'abord, et pose son
/// changement dans la même transaction.
@MainActor
public final class UserStore {
    private let database: Database
    private let now: () -> Date
    private let makeID: () -> String

    private static let migrations: [String] = [
        """
        CREATE TABLE history (
          language   TEXT NOT NULL,
          word       TEXT NOT NULL,
          searchedAt REAL NOT NULL,
          PRIMARY KEY (language, word)
        ) WITHOUT ROWID;
        CREATE INDEX history_recent ON history (searchedAt DESC);
        CREATE TABLE outbox (
          seq      INTEGER PRIMARY KEY AUTOINCREMENT,
          id       TEXT NOT NULL UNIQUE,
          kind     TEXT NOT NULL,
          family   TEXT NOT NULL,
          language TEXT NOT NULL,
          word     TEXT NOT NULL,
          at       REAL NOT NULL,
          parked   TEXT
        );
        """,
        """
        CREATE TABLE liked (
          language TEXT NOT NULL,
          word     TEXT NOT NULL,
          likedAt  REAL NOT NULL,
          PRIMARY KEY (language, word)
        ) WITHOUT ROWID;
        """,
        """
        CREATE TABLE setting (
          key   TEXT PRIMARY KEY,
          value TEXT NOT NULL
        ) WITHOUT ROWID;
        """,
        """
        CREATE TABLE memory (
          language   TEXT NOT NULL,
          word       TEXT NOT NULL,
          stability  REAL NOT NULL,
          difficulty REAL NOT NULL,
          reviewedAt REAL NOT NULL,
          due        REAL NOT NULL,
          reviews    INTEGER NOT NULL,
          lapses     INTEGER NOT NULL,
          PRIMARY KEY (language, word)
        ) WITHOUT ROWID;
        CREATE TABLE recall (
          seq      INTEGER PRIMARY KEY AUTOINCREMENT,
          language TEXT NOT NULL,
          word     TEXT NOT NULL,
          at       REAL NOT NULL,
          answer   TEXT NOT NULL
        );
        """,
        """
        CREATE TABLE mark (
          language  TEXT NOT NULL,
          word      TEXT NOT NULL,
          hard      INTEGER NOT NULL,
          returnLap INTEGER NOT NULL,
          PRIMARY KEY (language, word)
        ) WITHOUT ROWID;
        """,
    ]

    /// `path` vaut `":memory:"` pour une base jetable.
    public init(
        path: String,
        now: @escaping () -> Date = Date.init,
        makeID: @escaping () -> String = { UUID().uuidString }
    ) throws {
        database = try Database(path: path)
        self.now = now
        self.makeID = makeID
        try migrate()
    }

    /// Migrations numérotées, vers l'avant seulement.
    private func migrate() throws {
        let current = try database.query("PRAGMA user_version") { Int($0.int(0)) }.first ?? 0
        guard current <= Self.migrations.count else {
            throw DatabaseError(code: 0, message: "base utilisateur plus récente que l'app (\(current))")
        }
        for (index, migration) in Self.migrations.enumerated() where index >= current {
            try database.transaction {
                try database.execute(migration)
                try database.execute("PRAGMA user_version = \(index + 1)")
            }
        }
    }

    // MARK: Historique

    /// Un mot n'apparaît qu'une fois : le revoir le remonte en tête.
    public func remember(_ key: WordKey) throws {
        let at = now()
        try database.transaction {
            try database.run(
                "INSERT OR REPLACE INTO history (language, word, searchedAt) VALUES (?, ?, ?)",
                arguments(key) + [.real(at.timeIntervalSince1970)]
            )
            try enqueue(.historyAdd, key, at)
        }
    }

    public func forget(_ key: WordKey) throws {
        let at = now()
        try database.transaction {
            try database.run("DELETE FROM history WHERE language = ? AND word = ?", arguments(key))
            try enqueue(.historyDelete, key, at)
        }
    }

    public func history(limit: Int = 200) throws -> [SavedWord] {
        try saved("SELECT language, word, searchedAt FROM history ORDER BY searchedAt DESC, word LIMIT \(limit)")
    }

    // MARK: Cœurs

    /// Un mot aimé revient plus souvent dans le reel.
    public func setLiked(_ key: WordKey, _ liked: Bool) throws {
        let at = now()
        try database.transaction {
            if liked {
                try database.run(
                    "INSERT OR REPLACE INTO liked (language, word, likedAt) VALUES (?, ?, ?)",
                    arguments(key) + [.real(at.timeIntervalSince1970)]
                )
            } else {
                try database.run("DELETE FROM liked WHERE language = ? AND word = ?", arguments(key))
            }
            try enqueue(liked ? .likeAdd : .likeDelete, key, at)
        }
    }

    public func liked() throws -> Set<WordKey> {
        Set(try saved("SELECT language, word, likedAt FROM liked").map(\.key))
    }

    // MARK: Réglages

    /// Un choix de l'utilisateur pour cet appareil, comme le décor du reel. Il
    /// ne part pas au serveur : il n'a pas d'équivalent sur le site.
    public func setting(_ key: String) throws -> String? {
        try database.query("SELECT value FROM setting WHERE key = ?", [.text(key)]) { $0.text(0) }.first
    }

    public func setSetting(_ key: String, _ value: String) throws {
        try database.run("INSERT OR REPLACE INTO setting (key, value) VALUES (?, ?)", [.text(key), .text(value)])
    }

    // MARK: Mémoire

    /// L'heure de l'appareil, celle que les fixtures remplacent.
    public func currentTime() -> Date { now() }

    /// Retient la réponse et calcule quand le mot reviendra. Chaque réponse
    /// reste aussi dans `recall` : c'est ce qui permettra un jour de mesurer
    /// ce qui aide vraiment à retenir.
    ///
    /// Rien ne part au serveur : il ne connaît pas encore la mémoire d'un mot,
    /// et une `Change` ne porte pas de réponse. Comme les réglages, cela reste
    /// sur l'appareil pour l'instant.
    @discardableResult
    public func recall(_ key: WordKey, _ answer: Recall) throws -> Memory {
        var result: Memory!
        try database.transaction { result = try writeRecall(key, answer) }
        return result
    }

    /// Le geste du reel : « à revoir » rend le mot difficile, « je sais » le
    /// met de côté jusqu'au tour `returnLap`. La réponse compte aussi pour
    /// la mémoire, dans la même transaction.
    public func mark(_ key: WordKey, _ answer: Recall, returnLap: Int) throws {
        try database.transaction {
            try writeRecall(key, answer)
            try database.run(
                "INSERT OR REPLACE INTO mark (language, word, hard, returnLap) VALUES (?, ?, ?, ?)",
                arguments(key) + [.int(answer == .forgot ? 1 : 0), .int(Int64(answer == .knew ? returnLap : 0))]
            )
        }
    }

    public func marks() throws -> [WordKey: Mark] {
        let rows = try database.query("SELECT language, word, hard, returnLap FROM mark") { row -> (WordKey, Mark)? in
            guard let language = Language(rawValue: row.text(0)) else { return nil }
            return (WordKey(language, row.text(1)), Mark(isHard: row.int(2) != 0, returnLap: Int(row.int(3))))
        }
        return Dictionary(rows.compactMap { $0 }, uniquingKeysWith: { first, _ in first })
    }

    @discardableResult
    private func writeRecall(_ key: WordKey, _ answer: Recall) throws -> Memory {
        let at = now()
        var result: Memory!
        do {
            let next = try memory(key).map { FSRS.next($0, answer, at: at) } ?? FSRS.first(answer, at: at)
            try database.run(
                """
                INSERT OR REPLACE INTO memory (language, word, stability, difficulty, reviewedAt, due, reviews, lapses)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments(key) + [
                    .real(next.stability), .real(next.difficulty),
                    .real(next.reviewedAt.timeIntervalSince1970), .real(next.due.timeIntervalSince1970),
                    .int(Int64(next.reviews)), .int(Int64(next.lapses)),
                ]
            )
            try database.run(
                "INSERT INTO recall (language, word, at, answer) VALUES (?, ?, ?, ?)",
                arguments(key) + [.real(at.timeIntervalSince1970), .text(answer.rawValue)]
            )
            result = next
        }
        return result
    }

    public func memory(_ key: WordKey) throws -> Memory? {
        try memories("WHERE language = ? AND word = ?", arguments(key))[key]
    }

    public func memories() throws -> [WordKey: Memory] {
        try memories("", [])
    }

    /// Les réponses données, la plus ancienne d'abord.
    public func recalls() throws -> [(key: WordKey, at: Date, answer: Recall)] {
        try database.query("SELECT language, word, at, answer FROM recall ORDER BY seq") { row -> (key: WordKey, at: Date, answer: Recall)? in
            guard let language = Language(rawValue: row.text(0)), let answer = Recall(rawValue: row.text(3)) else { return nil }
            return (WordKey(language, row.text(1)), Date(timeIntervalSince1970: row.real(2)), answer)
        }.compactMap { $0 }
    }

    private func memories(_ filter: String, _ values: [Value]) throws -> [WordKey: Memory] {
        let rows = try database.query(
            "SELECT language, word, stability, difficulty, reviewedAt, due, reviews, lapses FROM memory \(filter)", values
        ) { row -> (WordKey, Memory)? in
            guard let language = Language(rawValue: row.text(0)) else { return nil }
            return (WordKey(language, row.text(1)), Memory(
                stability: row.real(2), difficulty: row.real(3),
                reviewedAt: Date(timeIntervalSince1970: row.real(4)), due: Date(timeIntervalSince1970: row.real(5)),
                reviews: Int(row.int(6)), lapses: Int(row.int(7))
            ))
        }
        return Dictionary(rows.compactMap { $0 }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: File d'envoi

    public func pendingChanges() throws -> [Change] {
        try database.query(
            "SELECT id, kind, language, word, at FROM outbox WHERE parked IS NULL ORDER BY seq"
        ) { row -> Change? in
            guard let kind = Change.Kind(rawValue: row.text(1)), let language = Language(rawValue: row.text(2)) else { return nil }
            return Change(id: row.text(0), kind: kind, key: WordKey(language, row.text(3)), at: Date(timeIntervalSince1970: row.real(4)))
        }.compactMap { $0 }
    }

    public func pendingCount() throws -> Int {
        try database.query("SELECT count(*) FROM outbox WHERE parked IS NULL") { Int($0.int(0)) }.first ?? 0
    }

    public func parkedCount() throws -> Int {
        try database.query("SELECT count(*) FROM outbox WHERE parked IS NOT NULL") { Int($0.int(0)) }.first ?? 0
    }

    func acknowledge(_ id: String) throws {
        try database.run("DELETE FROM outbox WHERE id = ?", [.text(id)])
    }

    /// Le serveur a refusé ce changement. On le met de côté plutôt que de
    /// bloquer la file ou de le perdre en silence.
    func park(_ id: String, reason: String) throws {
        try database.run("UPDATE outbox SET parked = ? WHERE id = ?", [.text(reason), .text(id)])
    }

    private func enqueue(_ kind: Change.Kind, _ key: WordKey, _ at: Date) throws {
        try database.run(
            "DELETE FROM outbox WHERE family = ? AND language = ? AND word = ? AND parked IS NULL",
            [.text(kind.family)] + arguments(key)
        )
        try database.run(
            "INSERT INTO outbox (id, kind, family, language, word, at) VALUES (?, ?, ?, ?, ?, ?)",
            [.text(makeID()), .text(kind.rawValue), .text(kind.family)] + arguments(key) + [.real(at.timeIntervalSince1970)]
        )
    }

    private func saved(_ sql: String) throws -> [SavedWord] {
        try database.query(sql) { row -> SavedWord? in
            guard let language = Language(rawValue: row.text(0)) else { return nil }
            return SavedWord(key: WordKey(language, row.text(1)), at: Date(timeIntervalSince1970: row.real(2)))
        }.compactMap { $0 }
    }

    private func arguments(_ key: WordKey) -> [Value] {
        [.text(key.language.rawValue), .text(key.word)]
    }
}
