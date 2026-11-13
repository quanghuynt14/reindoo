import ReindooCore
import SwiftUI

/// Le reel : une carte par écran, on fait défiler vers le haut, sans fin.
/// Chaque mot a sa couleur. La carte dit le mot, attend, puis montre le sens.
struct ReviewView: View {
    let model: ReviewViewModel

    @AppStorage("reel.readAloud") private var readAloud = true

    /// Le temps laissé pour deviner avant que le sens se montre seul.
    private static let revealAfter = 2.2

    var body: some View {
        let state = model.state
        let current = state.cards.indices.contains(state.position) ? state.cards[state.position] : nil
        let aloud = readAloud

        // La page est mesurée une fois, ici, et chaque carte reçoit cette
        // taille : des cartes de hauteurs différentes ne se caleraient plus.
        GeometryReader { page in
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(state.cards) { card in
                    ReelCard(
                        card: card, isCurrent: card.id == current?.id,
                        hint: state.revealHint, openLabel: state.openLabel,
                        likeLabel: state.likeLabel, listenLabel: state.listenLabel,
                        revealAfter: Self.revealAfter,
                        reveal: { model.send(.reveal(card.id)) },
                        like: { model.send(.like(card.id)) },
                        open: { model.send(.open(card.id)) },
                        choose: { model.send(.choose(card.id, $0)) }
                    )
                    .frame(width: page.size.width, height: page.size.height)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: Binding(
            get: { current?.id },
            set: { id in
                if let index = state.cards.firstIndex(where: { $0.id == id }) { model.send(.setPosition(index)) }
            }
        ), anchor: .top)
        }
        .background {
            if let current {
                ReelBackdrop(hue: current.hue).ignoresSafeArea()
            }
        }
        .overlay {
            if let message = state.emptyMessage {
                ContentUnavailableView {
                    Label(state.title, systemImage: "rectangle.stack")
                } description: {
                    Text(message)
                }
            }
        }
        .navigationTitle(current == nil ? state.title : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(current == nil ? nil : .dark, for: .navigationBar)
        .toolbar {
            // Les rennes suivent : un saut par carte, une pirouette toutes les dix.
            HerdToolbarItem(hops: state.position, tricks: state.position / 10)
            // Le même rond que les boutons des cartes : il se lit sur toutes les
            // couleurs, en clair comme en sombre.
            BareToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker(state.filterTitle, selection: Binding(
                        get: { state.filter },
                        set: { model.send(.setFilter(Language(rawValue: $0))) }
                    )) {
                        ForEach(state.filters, id: \.name) { option in
                            Text(option.label).tag(option.name)
                        }
                    }
                    Picker(state.sortTitle, selection: Binding(
                        get: { state.sort.rawValue },
                        set: { name in
                            if let sort = ReviewViewModel.Sort(rawValue: name) { model.send(.setSort(sort)) }
                        }
                    )) {
                        ForEach(state.sorts, id: \.name) { option in
                            Text(option.label).tag(option.name)
                        }
                    }
                    Toggle(state.readAloudLabel, systemImage: "speaker.wave.2", isOn: $readAloud)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(current == nil ? Color.primary : .white)
                        .frame(width: 40, height: 40)
                        .background((current == nil ? Color.primary : .white).opacity(0.16), in: .circle)
                }
                .accessibilityLabel(state.optionsLabel)
            }
        }
        .sensoryFeedback(.selection, trigger: state.sort)
        .sensoryFeedback(.selection, trigger: state.filter)
        .onAppear { model.send(.appear) }
        .onDisappear { Speaker.shared.stop() }
        // Une carte arrive : on dit le mot, on laisse deviner, puis le sens
        // vient seul. Changer de carte annule l'attente.
        .task(id: current?.id) { @MainActor in
            guard let current, current.kind == .word || current.kind == .discovery else { return }
            if aloud { Speaker.shared.say(current.word, in: current.language) }
            guard !current.isRevealed else { return }
            try? await Task.sleep(for: .seconds(Self.revealAfter))
            if !Task.isCancelled { model.send(.unveil(current.id)) }
        }
    }
}

/// Le fond : un dégradé à la teinte du mot, et une lueur qui dérive. D'une
/// carte à l'autre, les couleurs se fondent.
private struct ReelBackdrop: View {
    let hue: Double

    @State private var drifting = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hue: hue, saturation: 0.62, brightness: 0.56),
                    Color(hue: (hue + 0.09).truncatingRemainder(dividingBy: 1), saturation: 0.78, brightness: 0.24),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .id(hue)
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.45), value: hue)
        .overlay {
            Circle()
                .fill(.white.opacity(0.14))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: drifting ? 110 : -110, y: drifting ? -220 : 160)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 7).repeatForever(autoreverses: true),
                    value: drifting
                )
        }
        .clipped()
        .onAppear { drifting = true }
        .accessibilityHidden(true)
    }
}

/// Une carte du reel. Toucher montre ou cache le sens ; toucher deux fois pose
/// un cœur.
private struct ReelCard: View {
    let card: ReviewViewModel.Card
    let isCurrent: Bool
    let hint: String
    let openLabel: String
    let likeLabel: String
    let listenLabel: String
    let revealAfter: Double
    let reveal: () -> Void
    let like: () -> Void
    let open: () -> Void
    let choose: (Int) -> Void

    @State private var heart = false
    @State private var floating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var wordSize: CGFloat = 52

    private var hasMeaning: Bool { card.kind == .word || card.kind == .discovery }

    var body: some View {
        ZStack {
            switch card.kind {
            case .word, .discovery: word
            case .quiz: quiz
            case .streak: streak
            }
            if heart {
                Image(systemName: "heart.fill")
                    .font(.system(size: 110))
                    .shadow(color: .black.opacity(0.25), radius: 12)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            // Comme une story : le trait se remplit, puis le sens vient.
            // Seule la carte à l'écran le porte : celui de la suivante se
            // verrait sous la barre d'onglets.
            if hasMeaning, isCurrent, !card.isRevealed {
                ProgressLine(running: isCurrent, duration: revealAfter)
                    .padding(.horizontal, Theme.margin)
                    .padding(.top, 6)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            // Ceux de la carte qui part s'effacent : ils se verraient sous
            // l'heure, en haut de la suivante.
            if hasMeaning {
                actions
                    .opacity(isCurrent ? 1 : 0)
                    .animation(.easeOut(duration: 0.2), value: isCurrent)
            }
        }
        .foregroundStyle(.white)
        .contentShape(.rect)
        .onTapGesture(count: 2) { doubleTap() }
        .onTapGesture { if hasMeaning { reveal() } }
        .animation(.smooth(duration: 0.5), value: card.isRevealed)
        .sensoryFeedback(.impact(weight: .medium), trigger: card.isLiked)
        .onAppear { floating = true }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: hint) { if hasMeaning { reveal() } }
    }

    private func doubleTap() {
        guard card.kind != .streak else { return }
        if !card.isLiked { like() }
        withAnimation(.spring(duration: 0.35, bounce: 0.5)) { heart = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.7))
            withAnimation(.easeOut(duration: 0.25)) { heart = false }
        }
    }

    // MARK: Un mot

    private var word: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 12) {
                tag(card.badge ?? card.languageLabel)
                headword
                if !card.ipa.isEmpty {
                    Text(card.ipa)
                        .font(.title3)
                        .opacity(isCurrent ? 0.85 : 0)
                        // La prononciation suit le mot d'un temps.
                        .animation(.easeOut(duration: 0.4).delay(isCurrent ? 0.35 : 0), value: isCurrent)
                }
            }
            ZStack(alignment: .top) {
                if card.isRevealed {
                    VStack(spacing: Theme.gap) {
                        Text(card.gloss)
                            .font(.title.weight(.semibold))
                        if let example = card.example {
                            VStack(spacing: 4) {
                                Text(example.sourceSentence)
                                    .font(Theme.entryBody.italic())
                                Text(example.targetTranslation)
                                    .font(.subheadline)
                                    .opacity(0.8)
                            }
                        }
                    }
                    .multilineTextAlignment(.center)
                    .transition(.blurReplace)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .top)
            .padding(.top, Theme.section)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.section)
        .animation(.spring(duration: 0.5, bounce: 0.3), value: isCurrent)
    }

    /// Le mot arrive en grandissant, puis flotte doucement.
    private var headword: some View {
        Text(card.word)
            .font(.system(size: wordSize, weight: .semibold, design: .serif))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.4)
            .offset(y: reduceMotion ? 0 : (floating ? -5 : 5))
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                value: floating
            )
            .scaleEffect(isCurrent ? 1 : 0.8)
            .opacity(isCurrent ? 1 : 0.4)
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.white.opacity(0.18), in: .capsule)
    }

    private var actions: some View {
        HStack(spacing: 34) {
            ReelButton(
                image: card.isLiked ? "heart.fill" : "heart", label: likeLabel,
                tint: card.isLiked ? Color(red: 1, green: 0.36, blue: 0.42) : .white,
                bounce: card.isLiked, action: like
            )
            ReelButton(image: "speaker.wave.2.fill", label: listenLabel) {
                Speaker.shared.say(card.word, in: card.language)
            }
            ReelButton(image: "book", label: openLabel, action: open)
        }
        .padding(.bottom, Theme.section)
    }

    // MARK: Une question

    private var quiz: some View {
        VStack(spacing: Theme.section) {
            VStack(spacing: 12) {
                tag(card.badge ?? "")
                headword
            }
            VStack(spacing: 10) {
                ForEach(Array(card.choices.enumerated()), id: \.offset) { index, choice in
                    Button {
                        choose(index)
                    } label: {
                        Text(choice.label)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .background(colour(of: choice, at: index), in: .rect(cornerRadius: 16))
                            .contentShape(.rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(card.picked == nil)
                }
            }
        }
        .padding(.horizontal, Theme.section)
        .animation(.spring(duration: 0.5, bounce: 0.3), value: isCurrent)
        .animation(.snappy, value: card.picked)
        .sensoryFeedback(trigger: card.picked) { _, picked in
            guard let picked, card.choices.indices.contains(picked) else { return nil }
            return card.choices[picked].isCorrect ? .success : .error
        }
    }

    /// Avant la réponse, tous les choix se valent. Après : le bon en vert, et
    /// celui qu'on a pris à tort en rouge.
    private func colour(of choice: ReviewViewModel.Choice, at index: Int) -> Color {
        guard let picked = card.picked else { return .white.opacity(0.18) }
        if choice.isCorrect { return Color(red: 0.16, green: 0.62, blue: 0.36) }
        if index == picked { return Color(red: 0.80, green: 0.22, blue: 0.22) }
        return .white.opacity(0.08)
    }

    // MARK: La série

    private var streak: some View {
        VStack(spacing: Theme.gap) {
            Text("🔥")
                .font(.system(size: 72))
                .scaleEffect(isCurrent ? 1 : 0.3)
                .rotationEffect(.degrees(isCurrent || reduceMotion ? 0 : -30))
            Text(card.word)
                .font(.system(size: 88, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(card.badge ?? "")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Theme.section)
        .animation(.spring(duration: 0.6, bounce: 0.55), value: isCurrent)
        .sensoryFeedback(.success, trigger: isCurrent) { _, now in now }
    }
}

/// Un bouton rond, sous le mot.
private struct ReelButton: View {
    let image: String
    let label: String
    var tint: Color = .white
    var bounce = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: image)
                .font(.title2)
                .foregroundStyle(tint)
                .symbolEffect(.bounce, value: bounce)
                .frame(width: 54, height: 54)
                .background(.white.opacity(0.16), in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Le trait qui se remplit pendant qu'on devine.
private struct ProgressLine: View {
    let running: Bool
    let duration: Double

    @State private var fill: CGFloat = 0

    var body: some View {
        Capsule()
            .fill(.white.opacity(0.25))
            .frame(height: 3)
            .overlay {
                Capsule()
                    .fill(.white)
                    .scaleEffect(x: fill, y: 1, anchor: .leading)
            }
            .onChange(of: running, initial: true) { _, now in
                if now {
                    withAnimation(.linear(duration: duration)) { fill = 1 }
                } else {
                    fill = 0
                }
            }
            .accessibilityHidden(true)
    }
}
