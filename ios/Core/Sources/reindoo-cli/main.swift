import Foundation
import ReindooCore

// Le CLI de Reflex, en petit. Pas de couleurs, pas d'animation : il est fait
// pour un agent.
//
//   reindoo-cli [--fixture sample|returning] [--ui en|fr|vi]   lit des commandes sur stdin
//   reindoo-cli [--fixture …] <commande> [; <commande>] les exécute puis sort
//   reindoo-cli build-lexicon <sortie.sqlite> <entrée.ndjson>…
//
// Commandes :  ls   |   do <action> [json]

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func jsonLine(_ object: [String: Any]) -> String {
    let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data("{}".utf8)
    return String(decoding: data, as: UTF8.self)
}

@MainActor
func run(_ command: String, in session: Session) -> Bool {
    let parts = command.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 2).map(String.init)
    guard let verb = parts.first else { return true }
    do {
        switch verb {
        case "ls":
            print(try session.lsJSON())
        case "do":
            guard parts.count >= 2 else {
                print(jsonLine(["error": "usage : do <action> [json]"]))
                return false
            }
            try session.perform(parts[1], input: parts.count > 2 ? parts[2] : nil)
            print(try session.lsJSON())
        default:
            print(jsonLine(["error": "commande inconnue « \(verb) ». Disponibles : ls, do"]))
            return false
        }
        return true
    } catch {
        print(jsonLine(["error": "\(error)"]))
        return false
    }
}

var arguments = Array(CommandLine.arguments.dropFirst())

if arguments.first == "build-lexicon" {
    guard arguments.count >= 3 else { fail("usage : reindoo-cli build-lexicon <sortie.sqlite> <entrée.ndjson>…") }
    let sources = arguments.dropFirst(2).map { path -> String in
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { fail("illisible : \(path)") }
        return text
    }
    do {
        let report = try LexiconBuilder.build(ndjson: sources, to: arguments[1])
        print(jsonLine(["entries": report.entries, "forms": report.forms, "skipped": report.skipped, "path": arguments[1]]))
        exit(0)
    } catch {
        fail("\(error)")
    }
}

var fixture = Fixture.sample
if arguments.first == "--fixture" {
    guard arguments.count >= 2, let chosen = Fixture(rawValue: arguments[1]) else {
        fail("fixture inconnue. Disponibles : \(Fixture.allCases.map(\.rawValue).joined(separator: ", "))")
    }
    fixture = chosen
    arguments.removeFirst(2)
}

var ui = UILanguage.vietnamese
if arguments.first == "--ui" {
    guard arguments.count >= 2, let chosen = UILanguage(rawValue: arguments[1]) else {
        fail("langue d'interface inconnue. Disponibles : \(UILanguage.allCases.map(\.rawValue).joined(separator: ", "))")
    }
    ui = chosen
    arguments.removeFirst(2)
}

let session: Session
do {
    session = Session(app: try fixture.makeApp(ui: ui))
} catch {
    fail("\(error)")
}

if arguments.isEmpty {
    while let line = readLine() {
        _ = run(line, in: session)
    }
} else {
    // Une invocation, plusieurs commandes séparées par « ; » : l'état vit le
    // temps du processus.
    var succeeded = true
    for command in arguments.joined(separator: " ").split(separator: ";") {
        succeeded = run(String(command), in: session) && succeeded
    }
    exit(succeeded ? 0 : 1)
}
