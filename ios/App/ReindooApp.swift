import Foundation
import ReindooCore
import SwiftUI

@main
struct ReindooApp: App {
    @State private var launch = Launch()

    var body: some Scene {
        WindowGroup {
            switch launch.result {
            case .success(let app):
                RootView(app: app)
                    .tint(Theme.accent)
            case .failure(let error):
                // Le lexique manque ou ne s'ouvre pas : on le dit, on ne plante pas.
                ContentUnavailableView(
                    Launch.copy.lexiconUnavailable,
                    systemImage: "exclamationmark.triangle",
                    description: Text(String(describing: error))
                )
            }
        }
    }
}

/// Construit Core une fois, au lancement. C'est le seul endroit de l'app qui
/// sait où sont les fichiers.
@MainActor
struct Launch {
    let result: Result<AppModel, Error>

    /// La langue de l'interface suit celle que le système donne à l'app :
    /// Réglages › Reindoo › Langue. Les trois sont déclarées par les dossiers
    /// `.lproj` de Resources.
    static let copy = Copy(UILanguage(code: Bundle.main.preferredLocalizations.first))

    init() {
        result = Result { try Self.makeApp() }
    }

    private static func makeApp() throws -> AppModel {
        let app = try makeModel()
        #if DEBUG
        // `-tab review -query all -open aller -do reveal` : un état reproductible pour les
        // captures d'écran. Compilé hors des versions publiées.
        let session = Session(app: app)
        if let tab = argument("-tab") { try? session.perform("selectTab", input: json(["name": tab])) }
        if let query = argument("-query") { try? session.perform("setQuery", input: json(["text": query])) }
        if let word = argument("-open") { try? session.perform("open", input: json(["word": word])) }
        // `-position 5` : fait défiler le reel carte par carte, comme un doigt.
        if let action = argument("-do") { try? session.perform(action, input: nil) }
        #endif
        return app
    }

    private static func argument(_ name: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    private static func json(_ value: [String: String]) -> String {
        String(decoding: (try? JSONEncoder().encode(value)) ?? Data("{}".utf8), as: UTF8.self)
    }

    private static func makeModel() throws -> AppModel {
        #if DEBUG
        // `-fixture returning` : le petit lexique de Core et un passé inventé.
        if let name = argument("-fixture"), let fixture = Fixture(rawValue: name) {
            return try fixture.makeApp(ui: copy.ui)
        }
        #endif

        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let user = try UserStore(path: support.appendingPathComponent("user.sqlite").path)

        // Le lexique complet est livré dans l'app. Tant qu'il n'y est pas,
        // l'échantillon de Core tient lieu de dictionnaire.
        if let path = Bundle.main.path(forResource: "lexicon", ofType: "sqlite") {
            return AppModel(lexicon: try Lexicon(path: path), user: user, copy: copy)
        }
        let sample = support.appendingPathComponent("sample-lexicon.sqlite").path
        _ = try LexiconBuilder.build(ndjson: [Fixture.sampleNDJSON], to: sample)
        return AppModel(lexicon: try Lexicon(path: sample), user: user, copy: copy)
    }
}
