import Foundation

#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif

public struct DatabaseError: Error, CustomStringConvertible, Equatable {
    public let code: Int32
    public let message: String
    public var description: String { "SQLite \(code): \(message)" }
}

enum Value {
    case text(String)
    case real(Double)
    case int(Int64)
    case null
}

/// Une ligne de résultat. Ne vit que le temps de la fermeture qui la reçoit.
struct Row {
    fileprivate let statement: OpaquePointer

    func text(_ index: Int32) -> String {
        guard let pointer = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: pointer)
    }

    func real(_ index: Int32) -> Double { sqlite3_column_double(statement, index) }
    func int(_ index: Int32) -> Int64 { sqlite3_column_int64(statement, index) }
}

/// Une connexion SQLite, sans plus. Elle n'est pas `Sendable` : chaque magasin
/// possède la sienne et ne la sort pas de l'acteur principal.
final class Database {
    private var handle: OpaquePointer?
    private var statements: [String: OpaquePointer] = [:]

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(path: String, readOnly: Bool = false) throws {
        let flags = readOnly
            ? SQLITE_OPEN_READONLY
            : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        let status = sqlite3_open_v2(path, &handle, flags, nil)
        guard status == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "ouverture impossible"
            sqlite3_close_v2(handle)
            handle = nil
            throw DatabaseError(code: status, message: message)
        }
    }

    deinit {
        for statement in statements.values { sqlite3_finalize(statement) }
        sqlite3_close_v2(handle)
    }

    /// Plusieurs instructions d'un coup, sans paramètres : schéma, PRAGMA.
    func execute(_ sql: String) throws {
        try check(sqlite3_exec(handle, sql, nil, nil, nil))
    }

    func run(_ sql: String, _ arguments: [Value] = []) throws {
        _ = try query(sql, arguments) { _ in () }
    }

    func query<T>(_ sql: String, _ arguments: [Value] = [], _ read: (Row) -> T) throws -> [T] {
        let statement = try prepared(sql)
        defer {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
        }
        for (offset, argument) in arguments.enumerated() {
            let index = Int32(offset + 1)
            let status: Int32
            switch argument {
            case .text(let value): status = sqlite3_bind_text(statement, index, value, -1, Self.transient)
            case .real(let value): status = sqlite3_bind_double(statement, index, value)
            case .int(let value): status = sqlite3_bind_int64(statement, index, value)
            case .null: status = sqlite3_bind_null(statement, index)
            }
            try check(status)
        }
        var rows: [T] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_ROW {
                rows.append(read(Row(statement: statement)))
            } else if status == SQLITE_DONE {
                return rows
            } else {
                try check(status)
            }
        }
    }

    func transaction(_ body: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            try body()
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func prepared(_ sql: String) throws -> OpaquePointer {
        if let statement = statements[sql] { return statement }
        var statement: OpaquePointer?
        try check(sqlite3_prepare_v2(handle, sql, -1, &statement, nil))
        guard let statement else {
            throw DatabaseError(code: SQLITE_MISUSE, message: "instruction vide")
        }
        statements[sql] = statement
        return statement
    }

    private func check(_ status: Int32) throws {
        guard status == SQLITE_OK || status == SQLITE_DONE || status == SQLITE_ROW else {
            throw DatabaseError(code: status, message: String(cString: sqlite3_errmsg(handle)))
        }
    }
}
