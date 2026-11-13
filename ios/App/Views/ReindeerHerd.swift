import SwiftUI

/// Les deux rennes du site, à la place d'un logo. On les touche, ils sautent
/// de l'autre côté de leur enclos ; on les touche encore, ils reviennent.
///
/// L'état reste dans la vue : c'est un décor, il ne change rien au dictionnaire.
/// Un écran peut aussi les faire bouger : chaque changement de `hops` les fait
/// sauter, chaque changement de `tricks` leur fait faire un tour sur eux-mêmes.
struct ReindeerHerd: View {
    var hops = 0
    var tricks = 0

    @State private var onRight = false
    @State private var spins = 0
    @State private var bobbing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let width: CGFloat = 116
    static let height: CGFloat = 40
    private static let glyph: CGFloat = 24
    /// Le second renne suit le premier, à une longueur : ils ne se touchent pas.
    private static let stagger: CGFloat = 34
    private static let run = 0.7
    private static let turn = 0.2

    var body: some View {
        Button {
            onRight.toggle()
        } label: {
            ZStack(alignment: .bottomLeading) {
                reindeer(lead: Self.stagger, lift: 0, delay: 0, bobDelay: 0)
                reindeer(lead: 0, lift: 0, delay: 0.12, bobDelay: 0.3)
            }
            .frame(width: Self.width, height: Self.height, alignment: .bottomLeading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: onRight)
        .onAppear { bobbing = true }
        .onChange(of: hops) { onRight.toggle() }
        .onChange(of: tricks) { spins += 1 }
        .accessibilityLabel("Reindoo")
        .accessibilityValue(onRight ? "right" : "left")
        .accessibilityIdentifier("herd")
    }

    private func reindeer(lead: CGFloat, lift: CGFloat, delay: Double, bobDelay: Double) -> some View {
        // Le glyphe est un peu plus large que son corps de police.
        let travel = Self.width - Self.stagger - Self.glyph * 1.3
        return Text("🦌")
            .font(.system(size: Self.glyph))
            // Le glyphe regarde à gauche. Le renne regarde là où il courra :
            // il ne se retourne qu'une fois arrivé.
            .scaleEffect(x: onRight ? 1 : -1, y: 1)
            .animation(.easeOut(duration: Self.turn).delay(reduceMotion ? 0 : Self.run + delay), value: onRight)
            // Le tour : une pirouette, que le saut emporte avec lui.
            .rotationEffect(.degrees(Double(spins) * 360))
            .animation(reduceMotion ? nil : .spring(duration: 0.8, bounce: 0.25).delay(delay), value: spins)
            // Il piétine sur place tant qu'on ne lui demande rien.
            .offset(y: bobbing && !reduceMotion ? -2 : 0)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(bobDelay),
                value: bobbing
            )
            .modifier(Hop(progress: onRight ? 1 : 0, travel: travel, height: reduceMotion ? 0 : 12))
            .animation(reduceMotion ? nil : .easeInOut(duration: Self.run).delay(delay), value: onRight)
            .offset(x: lead, y: -lift)
    }
}

/// Un saut : la course à plat, et un arc dont le sommet tombe à mi-chemin.
private struct Hop: GeometryEffect {
    var progress: CGFloat
    let travel: CGFloat
    let height: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: travel * progress,
            y: -height * sin(.pi * progress)
        ))
    }
}

/// L'enclos dans la barre, en haut à gauche. Depuis iOS 26 la barre pose un
/// fond de verre sous chaque bouton ; les rennes s'en passent.
struct HerdToolbarItem: ToolbarContent {
    var hops = 0
    var tricks = 0

    var body: some ToolbarContent {
        BareToolbarItem(placement: .topBarLeading) { ReindeerHerd(hops: hops, tricks: tricks) }
    }
}

/// Un élément de barre sans le fond de verre du système.
struct BareToolbarItem<Content: View>: ToolbarContent {
    let placement: ToolbarItemPlacement
    @ViewBuilder let content: () -> Content

    var body: some ToolbarContent {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: placement, content: content)
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: placement, content: content)
        }
        #else
        ToolbarItem(placement: placement, content: content)
        #endif
    }
}

#Preview {
    NavigationStack {
        Color.clear.navigationTitle("Từ điển").toolbar { HerdToolbarItem() }
    }
}
