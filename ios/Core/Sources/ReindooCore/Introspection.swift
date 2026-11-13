import Foundation

public enum IntrospectionError: Error, Equatable, CustomStringConvertible {
    case unknownAction(String, available: [String])
    case badInput(action: String, expected: String)

    public var description: String {
        switch self {
        case .unknownAction(let name, let available):
            "action inconnue « \(name) ». Disponibles : \(available.joined(separator: ", "))"
        case .badInput(let action, let expected):
            "entrée invalide pour « \(action) ». Attendu : \(expected)"
        }
    }
}

/// Ce qu'un écran dit de lui-même au CLI et aux tests.
///
/// Trois règles, reprises de Reflex :
///   1. ce que l'utilisateur voit est dans l'état ; ce qu'il peut faire est une action ;
///   2. le nœud ne répète aucune règle — il liste toutes les actions, et c'est
///      `send` qui refuse ;
///   3. `perform` ne fait que décoder puis appeler `send`. Le CLI ne peut rien
///      qu'une vue ne puisse.
@MainActor
public protocol Introspectable: AnyObject {
    /// Identifiant stable de l'écran.
    var nodeName: String { get }
    /// L'état, encodé en JSON.
    func nodeState() throws -> Data
    /// Chaque action, avec la forme de son entrée : `["setQuery": "{text}"]`.
    var nodeActions: [(name: String, input: String)] { get }
    /// Rend `false` si ce nœud ne connaît pas l'action.
    func perform(_ action: String, input: Data?) throws -> Bool
    /// Le nœud suivant vers l'écran au premier plan.
    var childNode: (any Introspectable)? { get }
}

enum Input {
    struct Text: Decodable { var text: String }
    struct Word: Decodable { var word: String }
    struct Name: Decodable { var name: String }
    struct Target: Decodable {
        var word: String
        var language: Language
    }

    static func decode<T: Decodable>(_ type: T.Type, _ data: Data?, action: String, expected: String) throws -> T {
        guard let data, let value = try? JSONDecoder().decode(type, from: data) else {
            throw IntrospectionError.badInput(action: action, expected: expected)
        }
        return value
    }

    static func encode<T: Encodable>(_ state: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(state)
    }
}

/// Le protocole du CLI : `ls` et `do`. Les tests parlent le même.
@MainActor
public final class Session {
    public let app: AppModel

    public init(app: AppModel) {
        self.app = app
    }

    private var path: [any Introspectable] {
        var nodes: [any Introspectable] = [app]
        while let next = nodes[nodes.count - 1].childNode { nodes.append(next) }
        return nodes
    }

    /// L'écran au premier plan : son nom, son état, et tout ce qu'on peut y
    /// faire — ses actions, plus celles que ses conteneurs lui prêtent.
    public func ls() throws -> [String: Any] {
        let path = self.path
        let focused = path[path.count - 1]
        let actions = path.reversed().flatMap(\.nodeActions)
        return [
            "screen": focused.nodeName,
            "path": path.map(\.nodeName),
            "state": try JSONSerialization.jsonObject(with: focused.nodeState()),
            "app": try JSONSerialization.jsonObject(with: app.nodeState()),
            "actions": actions.map { $0.input.isEmpty ? $0.name : "\($0.name) \($0.input)" },
        ]
    }

    public func lsJSON() throws -> String {
        let data = try JSONSerialization.data(withJSONObject: ls(), options: [.sortedKeys, .withoutEscapingSlashes])
        return String(decoding: data, as: UTF8.self)
    }

    /// L'écran au premier plan d'abord, puis ses conteneurs.
    public func perform(_ action: String, input: String? = nil) throws {
        let path = self.path
        let data = input.map { Data($0.utf8) }
        for node in path.reversed() where try node.perform(action, input: data) { return }
        throw IntrospectionError.unknownAction(action, available: path.reversed().flatMap(\.nodeActions).map(\.name))
    }
}
