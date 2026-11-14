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

// Un décor du reel, figé à un instant, en SVG : de quoi le regarder dans un
// navigateur sans Mac.
if arguments.first == "scene" {
    guard arguments.count >= 2, let theme = SceneTheme.named(arguments[1]) else {
        fail("usage : reindoo-cli scene <thème> [largeur hauteur [secondes]]. Thèmes : \(SceneTheme.all.map(\.id).joined(separator: ", "))")
    }
    // `original` : le décor d'origine, 1600 sur 1000, pour le comparer à theme-examples.
    if arguments.count >= 3, arguments[2] == "original" {
        guard let scene = theme.original() else { fail("\(theme.id) n'a plus de version d'origine") }
        print(FrozenSVG.render(scene, at: arguments.count >= 4 ? Double(arguments[3]) ?? 0 : 0))
        exit(0)
    }
    let numbers = arguments.dropFirst(2).compactMap(Double.init)
    let width = numbers.count >= 2 ? numbers[0] : 390, height = numbers.count >= 2 ? numbers[1] : 844
    let time = numbers.count >= 3 ? numbers[2] : 0
    print(FrozenSVG.render(theme.scene(width: width, height: height), at: time))
    exit(0)
}

// Comment chaque décor se découpe : ce que l'app résout une fois, ce qu'elle
// rejoue à chaque image.
if arguments.first == "plan" {
    for theme in SceneTheme.all where arguments.count < 2 || arguments[1] == theme.id {
        let scene = theme.scene(width: 390, height: 844)
        let plan = scene.plan(motion: true)
        let live = plan.parts.reduce(0) { total, part in
            if case .live(let nodes, let style) = part { return total + scene.record(nodes, style, at: 7).reduce(0) { $0 + $1.count } }
            return total
        }
        let summary = plan.summary
        print("\(theme.id): \(summary.stillParts) parties fixes, \(summary.stillOps) gestes fixes, \(summary.liveNodes) nœuds vivants, \(live) gestes par image")
    }
    exit(0)
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
