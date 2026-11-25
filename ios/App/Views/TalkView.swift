import ReindooCore
import SwiftUI

/// « Giao tiếp » : les histoires, chacune sur son décor. En toucher une
/// l'ouvre en plein écran, une carte à la fois, comme le reel.
struct TalkView: View {
    let model: TalkViewModel

    var body: some View {
        let state = model.state
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gap) {
                Text(state.intro)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                ForEach(state.stories) { row in
                    Button { model.send(.open(row.id)) } label: { StoryRow(row: row) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, Theme.section)
        }
        .navigationTitle(state.title)
        .onAppear { model.send(.appear) }
        .fullScreenCover(isPresented: Binding(
            get: { model.state.player != nil },
            set: { if !$0 { model.send(.close) } }
        )) {
            if model.state.player != nil { StoryPlayer(model: model) }
        }
    }
}

/// Une histoire dans la liste : ses personnages sur la couleur de son décor.
private struct StoryRow: View {
    let row: TalkViewModel.Row

    var body: some View {
        let theme = row.scene.flatMap(SceneTheme.named)
        let light = theme?.window == .light
        HStack(spacing: 14) {
            HStack(spacing: -10) {
                ForEach(Array(row.cast.enumerated()), id: \.offset) { _, emoji in
                    Text(emoji).font(.system(size: 40))
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title).font(.headline)
                if !row.gloss.isEmpty {
                    Text(row.gloss).font(.subheadline).opacity(0.8)
                }
                Text(row.score).font(.caption.weight(.semibold)).opacity(0.75)
            }
            Spacer(minLength: 0)
            if row.isDone {
                Image(systemName: "checkmark.circle.fill").font(.title3)
            }
        }
        .foregroundStyle(light ? Color(white: 0.11) : .white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                (theme?.glass.tint.color ?? Theme.accent)
                LinearGradient(colors: [.white.opacity(light ? 0.35 : 0.12), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .clipShape(.rect(cornerRadius: 20))
        .contentShape(.rect(cornerRadius: 20))
    }
}

/// L'histoire ouverte : on fait monter les cartes, le décor reste.
private struct StoryPlayer: View {
    let model: TalkViewModel

    @State private var drag: CGFloat = 0
    @State private var visible = false
    private static let pace = Animation.smooth(duration: 0.38)

    var body: some View {
        if let player = model.state.player {
            let theme = player.scene.flatMap(SceneTheme.named)
            let ink: Color = theme?.window == .light ? Color(white: 0.11) : .white
            GeometryReader { page in
                let height = page.size.height
                ZStack {
                    ForEach(Array(player.cards.enumerated()), id: \.element.id) { index, card in
                        // Seules la carte à l'écran et ses voisines existent.
                        if abs(index - player.position) <= 1 {
                            TalkCard(card: card, player: player, isCurrent: index == player.position, ink: ink, model: model)
                                .frame(width: page.size.width, height: height)
                                .offset(y: CGFloat(index - player.position) * height + drag)
                                .accessibilityHidden(index != player.position)
                        }
                    }
                }
                .frame(width: page.size.width, height: height, alignment: .top)
                .contentShape(.rect)
                .simultaneousGesture(turnGesture(player, height: height))
                .accessibilityScrollAction { edge in
                    switch edge {
                    case .bottom: turn(player, by: 1)
                    case .top: turn(player, by: -1)
                    default: break
                    }
                }
            }
            .foregroundStyle(ink)
            .background {
                if let theme {
                    ZStack {
                        SceneBackdrop(theme: theme, paused: !visible || drag != 0)
                        SceneVeil(glass: theme.glass)
                    }
                    .ignoresSafeArea()
                } else {
                    Theme.accent.ignoresSafeArea()
                }
            }
            .overlay(alignment: .top) {
                HStack {
                    Text(player.title).font(.headline)
                    Spacer()
                    Text("\(player.position + 1)/\(player.cards.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .opacity(0.7)
                    Button { model.send(.close) } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .frame(width: 40, height: 40)
                            .background(ink.opacity(0.16), in: .circle)
                    }
                    .accessibilityLabel(player.closeLabel)
                }
                .padding(.horizontal, Theme.margin)
                .padding(.top, 4)
            }
            .onAppear { visible = true }
            .onDisappear {
                visible = false
                Speaker.shared.stop()
            }
        }
    }

    private func turnGesture(_ player: TalkViewModel.Player, height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                // Un geste de côté trie la réplique : il n'est pas pour la page.
                guard abs(value.translation.height) > abs(value.translation.width) || drag != 0 else { return }
                var pulled = value.translation.height
                let atStart = player.position == 0 && pulled > 0
                let atEnd = player.position >= player.cards.count - 1 && pulled < 0
                if atStart || atEnd { pulled *= 0.3 }
                drag = pulled
            }
            .onEnded { value in
                guard drag != 0 else { return }
                let speed = value.velocity.height
                let step = abs(speed) > 300 ? (speed < 0 ? 1 : -1)
                    : drag < -height / 10 ? 1 : drag > height / 10 ? -1 : 0
                turn(player, by: step)
            }
    }

    private func turn(_ player: TalkViewModel.Player, by step: Int) {
        let target = player.position + step
        withAnimation(Self.pace) {
            drag = 0
            if step != 0, player.cards.indices.contains(target) { model.send(.setPosition(target)) }
        }
    }
}

/// Une carte de l'histoire.
private struct TalkCard: View {
    let card: TalkViewModel.Card
    let player: TalkViewModel.Player
    let isCurrent: Bool
    let ink: Color
    let model: TalkViewModel

    @State private var swipe: CGFloat = 0
    @State private var bobbing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let threshold: CGFloat = 90

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 60)
            switch card.kind {
            case .narration: narration
            case .sort: sort
            case .rewrite: rewrite
            case .report: report
            }
            Spacer(minLength: 40)
            if card.kind == .narration || card.isAnswered {
                Label(player.continueHint, systemImage: "chevron.up")
                    .font(.caption.weight(.semibold))
                    .opacity(0.65)
            }
        }
        .padding(.horizontal, Theme.margin)
        .padding(.bottom, 24)
        .onAppear { bobbing = true }
        .sensoryFeedback(trigger: card.verdict) { _, verdict in
            switch verdict {
            case .right: .success
            case .wrong: .error
            case nil: nil
            }
        }
    }

    // MARK: Les personnages

    /// Un animal qui respire. Il saute quand on lui donne raison.
    private func animal(_ emoji: String, size: CGFloat, delay: Double = 0) -> some View {
        Text(emoji)
            .font(.system(size: size))
            .offset(y: bobbing && !reduceMotion ? -6 : 0)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(delay),
                value: bobbing
            )
            .scaleEffect(card.verdict == .right ? 1.12 : 1)
            .animation(.spring(duration: 0.4, bounce: 0.6), value: card.verdict)
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            .accessibilityHidden(true)
    }

    private var speaker: some View {
        HStack(spacing: 10) {
            if let who = card.cast.first {
                animal(who.emoji, size: 64)
                VStack(alignment: .leading, spacing: 0) {
                    Text(who.name).font(.headline)
                    Text(who.gloss).font(.caption).opacity(0.75)
                }
            }
            Spacer()
            listen
        }
    }

    private var listen: some View {
        Button { Speaker.shared.say(card.text, in: .french, asked: true) } label: {
            Image(systemName: "speaker.wave.2.fill")
                .frame(width: 40, height: 40)
                .background(ink.opacity(0.16), in: .circle)
        }
        .accessibilityLabel(player.listenLabel)
    }

    /// La réplique, dans une bulle.
    private func bubble(_ text: String, gloss: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.system(.title2, design: .serif).weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let gloss {
                Text(gloss).font(.callout).opacity(0.8)
                    .transition(.opacity)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ink.opacity(0.12), in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(ink.opacity(0.18)))
    }

    // MARK: Les cartes

    private var narration: some View {
        VStack(spacing: 26) {
            HStack(spacing: 28) {
                ForEach(Array(card.cast.enumerated()), id: \.offset) { index, who in
                    VStack(spacing: 4) {
                        animal(who.emoji, size: 78, delay: Double(index) * 0.4)
                        Text(who.name).font(.caption.weight(.semibold))
                    }
                }
            }
            Text(card.text)
                .font(.system(.title3, design: .serif))
                .multilineTextAlignment(.center)
            Text(card.gloss)
                .font(.callout)
                .multilineTextAlignment(.center)
                .opacity(0.75)
        }
    }

    private var sort: some View {
        VStack(alignment: .leading, spacing: 18) {
            speaker
            ZStack(alignment: .top) {
                // Le français d'abord : la traduction vient avec la réponse.
                bubble(card.text, gloss: card.isAnswered ? card.gloss : nil)
                stamp
            }
            .offset(x: swipe)
            .rotationEffect(.degrees(Double(swipe / 24)), anchor: .bottom)
            .simultaneousGesture(sortGesture)
            if card.isAnswered { verdict } else { sortButtons }
        }
        .animation(.smooth(duration: 0.35), value: card.verdict)
    }

    /// Le tampon que la carte prend pendant qu'on la pousse : loup à gauche,
    /// girafe à droite.
    @ViewBuilder
    private var stamp: some View {
        let progress = min(1, abs(swipe) / Self.threshold)
        if swipe != 0 {
            Text(swipe < 0 ? "🐺 \(player.wolfLabel)" : "🦒 \(player.giraffeLabel)")
                .font(.title3.weight(.heavy))
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(.thinMaterial, in: .capsule)
                .rotationEffect(.degrees(swipe < 0 ? 8 : -8))
                .opacity(progress)
                .offset(y: -22)
                .accessibilityHidden(true)
        }
    }

    private var sortGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard card.asksAnswer, abs(value.translation.width) > abs(value.translation.height) else { return }
                swipe = value.translation.width
            }
            .onEnded { _ in
                guard swipe != 0 else { return }
                let voice: Voice? = swipe <= -Self.threshold ? .wolf : swipe >= Self.threshold ? .giraffe : nil
                withAnimation(.spring(duration: 0.35)) { swipe = 0 }
                if let voice {
                    withAnimation(.smooth(duration: 0.35)) { model.send(.sort(card.id, voice)) }
                }
            }
    }

    private var sortButtons: some View {
        VStack(spacing: 10) {
            if let question = card.question { Text(question).font(.headline) }
            HStack(spacing: 12) {
                voiceButton(.wolf, "🐺", player.wolfLabel)
                voiceButton(.giraffe, "🦒", player.giraffeLabel)
            }
            Text(player.sortHint).font(.caption).opacity(0.65)
        }
        .frame(maxWidth: .infinity)
    }

    private func voiceButton(_ voice: Voice, _ emoji: String, _ label: String) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.35)) { model.send(.sort(card.id, voice)) }
        } label: {
            HStack(spacing: 6) {
                Text(emoji).font(.title2)
                Text(label).font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(ink.opacity(0.16), in: .capsule)
        }
        .buttonStyle(.plain)
    }

    /// Le verdict, le temps de la phrase, et pourquoi.
    private var verdict: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: card.verdict == .right ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(card.verdict == .right ? Color.green : Color.orange)
                Text(card.verdictLabel ?? "").font(.headline)
                Spacer()
                if let part = card.part {
                    Text(part)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(ink.opacity(0.16), in: .capsule)
                }
            }
            Text(card.why).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 18))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var rewrite: some View {
        VStack(alignment: .leading, spacing: 16) {
            speaker
            HStack(alignment: .top, spacing: 8) {
                Text("🐺").font(.title)
                bubble(card.text, gloss: card.isAnswered ? card.gloss : nil)
            }
            if let question = card.question {
                Text("🦒 \(question)").font(.headline)
            }
            ForEach(Array(card.choices.enumerated()), id: \.offset) { index, choice in
                Button {
                    withAnimation(.smooth(duration: 0.35)) { model.send(.choose(card.id, index)) }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(choice.text).font(.body.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                        if card.isAnswered {
                            Text(choice.gloss).font(.caption).opacity(0.8)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(fill(choice, at: index), in: .rect(cornerRadius: 16))
                    .overlay(alignment: .topTrailing) {
                        if card.isAnswered, choice.isGiraffe {
                            Text("🦒").padding(6)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(card.isAnswered)
            }
            if card.isAnswered { verdict }
        }
    }

    private func fill(_ choice: TalkViewModel.Choice, at index: Int) -> Color {
        guard card.isAnswered else { return ink.opacity(0.14) }
        if choice.isGiraffe { return Color.green.opacity(0.35) }
        if card.picked == index { return Color.orange.opacity(0.35) }
        return ink.opacity(0.06)
    }

    @ViewBuilder
    private var report: some View {
        if let report = card.report {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(report.title).font(.title.weight(.bold))
                    Spacer()
                    Text("🦒").font(.system(size: 44))
                        .rotationEffect(.degrees(bobbing && !reduceMotion ? -6 : 6))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: bobbing)
                }
                pile(report.right, symbol: "checkmark.circle.fill", tint: .green)
                pile(report.wrong, symbol: "xmark.circle.fill", tint: .orange)
                // Ni rouge ni barré : passer n'est pas une faute.
                pile(report.skipped, symbol: "arrow.down.circle", tint: ink.opacity(0.7))
                Text(report.note).font(.footnote).opacity(0.8)
                Button { withAnimation { model.send(.replay) } } label: {
                    Label(report.playAgain, systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(ink.opacity(0.18), in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pile(_ pile: TalkViewModel.Report.Pile, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: symbol).foregroundStyle(tint)
                Text(pile.label).font(.headline)
                Spacer()
                Text("\(pile.lines.count)").font(.headline.monospacedDigit())
            }
            ForEach(Array(pile.lines.prefix(3).enumerated()), id: \.offset) { _, line in
                Text(line).font(.caption).lineLimit(1).opacity(0.75)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
    }
}
