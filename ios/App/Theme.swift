import SwiftUI

/// Les décisions de dessin, à un seul endroit. Voir `mobile:native-ios`,
/// references/design.md.
enum Theme {
    /// Un seul accent. Tout le reste vient des couleurs sémantiques du système.
    static let accent = Color(red: 0.76, green: 0.23, blue: 0.19)

    static let margin: CGFloat = 20
    static let gap: CGFloat = 12
    static let section: CGFloat = 28

    /// Les mots du dictionnaire sont en sérif, comme sur le site ; l'interface
    /// reste en police système.
    static func headword(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .serif).weight(.semibold)
    }

    static let entryBody = Font.system(.body, design: .serif)
}
