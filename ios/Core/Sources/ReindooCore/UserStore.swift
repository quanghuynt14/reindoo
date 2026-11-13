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
