import Foundation
import Testing
@testable import ReindooCore

/// Les tests parlent le protocole du CLI : `ls` et `do`. Ils ne peuvent rien
/// qu'un utilisateur ne puisse.
@MainActor
struct Harness {
    let session: Session
    let clock: Clock

    final class Clock: @unchecked Sendable {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
    }

    /// Les tests lisent le vietnamien, sauf ceux qui portent sur la langue.
    static let copy = Copy(.vietnamese)

    init(_ fixture: Fixture = .sample, ui: UILanguage = .vietnamese) throws {
        let clock = Clock()
        self.clock = clock
        // Chaque lecture avance d'une seconde : l'ordre des écritures est sûr.
        session = Session(app: try fixture.makeApp(ui: ui, now: {
            clock.now += 1
            return clock.now
        }))
    }

    var app: AppModel { session.app }

    func `do`(_ action: String, _ input: String? = nil) throws {
        try session.perform(action, input: input)
    }

    var screen: String {
        get throws { try session.ls()["screen"] as? String ?? "" }
    }

    /// `state("senses.0.explain")` — un chemin dans l'état de l'écran au premier plan.
    func state<T>(_ path: String, as type: T.Type = T.self) throws -> T? {
        var value: Any? = try session.ls()["state"]
        for part in path.split(separator: ".") {
            if let index = Int(part) {
                let array = value as? [Any]
                value = array.flatMap { index < $0.count ? $0[index] : nil }
            } else {
                value = (value as? [String: Any])?[String(part)]
            }
        }
        return value as? T
    }

    func appState<T>(_ key: String, as type: T.Type = T.self) throws -> T? {
        (try session.ls()["app"] as? [String: Any])?[key] as? T
    }

    func search(_ text: String) throws {
        let input = String(decoding: try JSONEncoder().encode(["text": text]), as: UTF8.self)
        try self.do("setQuery", input)
        try self.do("submit")
    }
}
