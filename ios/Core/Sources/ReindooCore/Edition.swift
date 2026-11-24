import Foundation

/// Quelle app tourne. Un même code, deux dictionnaires :
///
/// - `reindoo` : le français et l'anglais expliqués en vietnamien, le
///   vietnamien en français ;
/// - `han` (Reindoo Hán Việt) : le chinois expliqué en vietnamien, le vietnamien
///   en chinois.
///
/// L'app la lit au lancement, dans la clé `ReindooEdition` de son Info.plist.
/// Sans clé, c'est reindoo : l'app d'origine n'a rien à déclarer.
public enum Edition: String, Codable, Sendable, CaseIterable {
    case reindoo
    case han

    public static let infoKey = "ReindooEdition"

    public init(name: String?) {
        self = Edition(rawValue: name ?? "") ?? .reindoo
    }

    /// Les langues que l'app propose, dans l'ordre du sélecteur.
    public var languages: [Language] {
        switch self {
        case .reindoo: [.french, .english, .vietnamese]
        case .han: [.chinese, .vietnamese]
        }
    }

    /// Les langues que ce lexique sert vraiment. Le fichier Việt–Trung peut
    /// manquer encore : on ne propose pas un dictionnaire vide. Un lexique
    /// vide de tout garde la liste entière, plutôt que rien.
    @MainActor
    func languages(in lexicon: Lexicon) -> [Language] {
        let served = languages.filter { ((try? lexicon.count($0)) ?? 0) > 0 }
        return served.isEmpty ? languages : served
    }

    /// Le petit lexique de Core, quand l'app n'a pas le vrai.
    public var sampleNDJSON: String {
        switch self {
        case .reindoo: Fixture.sampleNDJSON
        case .han: Fixture.hanSampleNDJSON
        }
    }
}
