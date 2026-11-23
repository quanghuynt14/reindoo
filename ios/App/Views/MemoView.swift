import ReindooCore
import SwiftUI

/// La note pour retenir un mot, en feuille : d'où il vient, ses voisins, un
/// mémo. La même pour l'entrée et pour le reel.
struct MemoView: View {
    let memo: MemoState
    let closeLabel: String
    let close: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.section) {
                    ForEach(memo.parts, id: \.name) { part in
                        VStack(alignment: .leading, spacing: 8) {
                            Label(part.title, systemImage: Self.icon(part.name))
                                .font(.headline)
                                .foregroundStyle(.tint)
                            Text(Self.styled(part.text))
                                .font(Theme.entryBody)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.margin)
                .padding(.vertical, Theme.gap)
            }
            .navigationTitle(memo.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(closeLabel, action: close)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private static func icon(_ part: String) -> String {
        switch part {
        case "origin": "clock.arrow.circlepath"
        case "related": "point.3.connected.trianglepath.dotted"
        default: "lightbulb"
        }
    }

    /// `**gras**` et `*italique*` ; un retour à la ligne reste un retour à la
    /// ligne. Un texte que Markdown ne lit pas s'affiche tel quel.
    static func styled(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}
