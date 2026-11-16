import ReindooCore
import SwiftUI

/// Le reel : une carte par écran, on fait défiler vers le haut, sans fin.
/// Chaque mot a sa couleur. La carte dit le mot, attend, puis montre le sens.
struct ReviewView: View {
    let model: ReviewViewModel

    @AppStorage("reel.readAloud") private var readAloud = true
    /// Le décor se fige pendant qu'on fait défiler, et quand l'onglet n'est
    /// pas à l'écran : le défilement passe avant lui.
    @State private var scrolling = false
    @State private var visible = false
    /// Le doigt tire la page de tant de points ; vers le haut, c'est négatif.
    @State private var drag: CGFloat = 0
    @State private var pageHeight: CGFloat = 0
    /// Un doigt posé et tenu met le trait en pause, comme une story.
    @GestureState private var held = false
    /// Lâcher après avoir tenu n'est pas un toucher : le sens ne vient pas.
    @State private var justHeld = false

    /// Le temps laissé pour deviner avant que le sens se montre seul.
    private static let revealAfter = 2.2
    /// Une page se pose toujours en ce temps, quel que soit l'élan : ni trop
    /// vite après un geste vif, ni trop lentement après un geste mou.
    private static let pace = Animation.smooth(duration: 0.38)

    var body: some View {
        let state = model.state
        let current = state.cards.indices.contains(state.position) ? state.cards[state.position] : nil
        // Passé la moitié de la page, la carte qui vient est déjà celle qu'on
        // montre : le mot grandit, ses boutons viennent, le décor change.
        let shown = shownCard(state)
        let aloud = readAloud

        // Le reel tourne ses pages lui-même. Une ScrollView pose la page à la
        // vitesse de l'élan, et un geste vif en sautait une : ici, le doigt
        // tire la page, puis elle se pose en un temps fixe, une carte à la fois.
        GeometryReader { page in
            let height = page.size.height
            ZStack {
                ForEach(window(state)) { card in
                    let index = state.cards.firstIndex { $0.id == card.id } ?? state.position
                    let offset = CGFloat(index - state.position) * height + drag
                    ReelCard(
                        card: card, isCurrent: card.id == shown?.id,
                        // La carte qui monte s'efface à mesure ; celle qui
                        // arrive d'en bas est là tout entière.
                        presence: height > 0 && offset < 0 ? max(0, 1 + offset / height) : 1,
                        held: held,
                        hint: state.revealHint, openLabel: state.openLabel,
                        likeLabel: state.likeLabel, listenLabel: state.listenLabel,
                        revealAfter: Self.revealAfter,
                        reveal: { if !justHeld { model.send(.reveal(card.id)) } },
                        unveil: { model.send(.unveil(card.id)) },
                        like: { model.send(.like(card.id)) },
                        open: { model.send(.open(card.id)) },
                        choose: { model.send(.choose(card.id, $0)) }
                    )
                    .frame(width: page.size.width, height: height)
                    .offset(y: offset)
                    .transition(.identity)
                    .accessibilityHidden(card.id != current?.id)
                }
            }
            .frame(width: page.size.width, height: height, alignment: .top)
            .contentShape(.rect)
            .gesture(pageTurn(state, height: height))
            .simultaneousGesture(hold)
            .accessibilityScrollAction { edge in
                switch edge {
                case .bottom: turn(state, by: 1)
                case .top: turn(state, by: -1)
                default: break
                }
            }
        }
        .background {
            // Les décors s'empilent dans l'ordre des cartes. Celui d'en haut
            // se montre à mesure que sa carte monte : l'ancien se fond dans
            // le nouveau au rythme du doigt.
            let turned = state.position - (pageHeight > 0 ? drag / pageHeight : 0)
            ZStack {
                ForEach(backdrops(state)) { card in
                    let index = state.cards.firstIndex { $0.id == card.id } ?? state.position
                    backdrop(card, paused: scrolling || !visible || card.id != current?.id)
                        .opacity(min(1, max(0, turned - CGFloat(index) + 1)))
                        .transition(.identity)
                }
            }
        }
        // Les décors des cartes voisines se préparent pendant qu'on lit
        // celle-ci : revenir en arrière est aussi rapide qu'avancer.
        .task(id: neighbours(state).compactMap(\.scene)) {
            for card in neighbours(state) {
                if let name = card.scene, let theme = SceneTheme.named(name) { SceneCache.shared.prepare(theme) }
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
        .toolbarColorScheme(shown == nil ? nil : shown!.isLight ? .light : .dark, for: .navigationBar)
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
                    Picker(state.sceneTitle, selection: Binding(
                        get: { state.scene },
                        set: { model.send(.setScene($0)) }
                    )) {
                        ForEach(state.scenes, id: \.name) { option in
                            Text(option.label).tag(option.name)
                        }
                    }
                    .pickerStyle(.menu)
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
                    let ink = shown.map(Self.ink) ?? Color.primary
                    Image(systemName: "slider.horizontal.3")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(ink)
                        .frame(width: 40, height: 40)
                        .background(ink.opacity(0.16), in: .circle)
                }
                .accessibilityLabel(state.optionsLabel)
            }
        }
        .sensoryFeedback(.selection, trigger: state.sort)
        .sensoryFeedback(.selection, trigger: state.filter)
        .onAppear {
            visible = true
            model.send(.appear)
        }
        .onDisappear {
            visible = false
            Speaker.shared.stop()
        }
        // Une carte arrive : on dit le mot. Le trait de la carte compte le
        // temps laissé pour deviner, puis montre le sens.
        .task(id: shown?.id) { @MainActor in
            guard let shown, shown.kind == .word || shown.kind == .discovery else { return }
            if aloud { Speaker.shared.say(shown.word, in: shown.language) }
        }
        .onChange(of: held) { _, now in
            if now {
                justHeld = true
            } else {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.3))
                    justHeld = false
                }
            }
        }
    }
}

extension ReviewView {
    /// Le mot vers lequel tire le doigt, passé la moitié de la page.
    private func shownCard(_ state: ReviewViewModel.State) -> ReviewViewModel.Card? {
        let step = pageHeight > 0 && abs(drag) > pageHeight / 2 ? (drag < 0 ? 1 : -1) : 0
        let index = state.position + step
        if state.cards.indices.contains(index) { return state.cards[index] }
        return state.cards.indices.contains(state.position) ? state.cards[state.position] : nil
    }

    /// Les cartes posées : celle à l'écran et ses deux voisines. Les autres
    /// sont loin hors de l'écran.
    private func window(_ state: ReviewViewModel.State) -> [ReviewViewModel.Card] {
        (state.position - 1...state.position + 1).compactMap { state.cards.indices.contains($0) ? state.cards[$0] : nil }
    }

    /// Les décors à poser : celui de la carte à l'écran, et ses voisins
    /// pendant qu'une page tourne.
    private func backdrops(_ state: ReviewViewModel.State) -> [ReviewViewModel.Card] {
        guard scrolling else {
            return state.cards.indices.contains(state.position) ? [state.cards[state.position]] : []
        }
        return window(state)
    }

    @ViewBuilder
    private func backdrop(_ card: ReviewViewModel.Card, paused: Bool) -> some View {
        if let name = card.scene, let theme = SceneTheme.named(name) {
            ZStack {
                SceneBackdrop(theme: theme, paused: paused)
                SceneVeil(glass: theme.glass)
            }
            .ignoresSafeArea()
        } else {
            ReelBackdrop(hue: card.hue).ignoresSafeArea()
        }
    }

    /// Tenir le doigt un instant : le trait s'arrête jusqu'à ce qu'on lâche.
    private var hold: some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($held) { value, held, _ in
                if case .second(true, _) = value { held = true }
            }
    }

    /// Le geste : le doigt tire la page ; lâchée, elle avance d'une carte si
    /// le doigt est allé au-delà d'un quart, ou s'il a lancé la page assez fort.
    private func pageTurn(_ state: ReviewViewModel.State, height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                // Un geste de côté n'est pas pour le reel.
                guard abs(value.translation.height) > abs(value.translation.width) || drag != 0 else { return }
                pageHeight = height
                scrolling = true
                var pulled = value.translation.height
                // Au bord du paquet, la page résiste.
                let atStart = state.position == 0 && pulled > 0
                let atEnd = state.position >= state.cards.count - 1 && pulled < 0
                if atStart || atEnd { pulled *= 0.3 }
                drag = pulled
            }
            .onEnded { value in
                guard drag != 0 else { return }
                let pulled = value.translation.height
                let thrown = value.predictedEndTranslation.height
                let step = pulled < -height / 4 || thrown < -height / 2 ? 1
                    : pulled > height / 4 || thrown > height / 2 ? -1 : 0
                turn(state, by: step)
            }
    }

    /// Avance ou recule d'une carte, toujours au même rythme.
    private func turn(_ state: ReviewViewModel.State, by step: Int) {
        let target = state.position + step
        let moves = step != 0 && state.cards.indices.contains(target)
        scrolling = true
        withAnimation(Self.pace) {
            drag = 0
            if moves { model.send(.setPosition(target)) }
        } completion: {
            if drag == 0 { scrolling = false }
        }
    }

    /// La couleur du texte : sombre sur un décor clair, blanche partout ailleurs.
    static func ink(_ card: ReviewViewModel.Card) -> Color {
        card.isLight ? Color(white: 0.11) : .white
    }

    /// Les cartes juste après et juste avant celle à l'écran.
    func neighbours(_ state: ReviewViewModel.State) -> [ReviewViewModel.Card] {
        [state.position + 1, state.position - 1, state.position + 2].compactMap { state.cards.indices.contains($0) ? state.cards[$0] : nil }
    }
}

/// Le voile du décor : sa teinte, posée là où le texte se lit, et rien en haut
/// ni en bas, où le décor vit.
private struct SceneVeil: View {
    let glass: SceneTheme.Glass

    var body: some View {
        let tint = glass.tint.color
        LinearGradient(
            stops: [
                .init(color: tint.opacity(0), location: 0.06),
                .init(color: tint.opacity(glass.opacity), location: 0.24),
                .init(color: tint.opacity(glass.opacity), location: 0.66),
                .init(color: tint.opacity(0), location: 0.84),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .allowsHitTesting(false)
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
    /// 1 quand la carte est en place, 0 quand elle est montée hors de l'écran.
    let presence: Double
    let held: Bool
    let hint: String
    let openLabel: String
    let likeLabel: String
    let listenLabel: String
    let revealAfter: Double
    let reveal: () -> Void
    let unveil: () -> Void
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
        .overlay(alignment: .bottom) {
            // Ceux de la carte qui part s'effacent : ils se verraient sous
            // l'heure, en haut de la suivante.
            if hasMeaning {
                actions
                    .opacity(isCurrent ? 1 : 0)
                    .animation(.easeOut(duration: 0.2), value: isCurrent)
            }
        }
        .opacity(presence)
        .overlay(alignment: .top) {
            // Comme une story : le trait se remplit, puis le sens vient.
            // Seule la carte à l'écran le porte : celui de la suivante se
            // verrait sous la barre d'onglets. Il s'efface trois fois plus
            // vite que la carte.
            if hasMeaning, isCurrent, !card.isRevealed {
                ProgressLine(duration: revealAfter, held: held, ink: ReviewView.ink(card), done: unveil)
                    .padding(.horizontal, Theme.margin)
                    .padding(.top, 6)
                    .opacity(max(0, 1 - 3 * (1 - presence)))
                    .transition(.opacity)
            }
        }
        .foregroundStyle(ReviewView.ink(card))
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
        // Sans rebond : le mot grandit et s'arrête, il ne dépasse pas.
        .animation(.smooth(duration: 0.4), value: isCurrent)
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
            .background(ReviewView.ink(card).opacity(0.18), in: .capsule)
    }

    private var actions: some View {
        HStack(spacing: 34) {
            let ink = ReviewView.ink(card)
            ReelButton(
                image: card.isLiked ? "heart.fill" : "heart", label: likeLabel,
                tint: card.isLiked ? Color(red: 1, green: 0.36, blue: 0.42) : ink, ink: ink,
                bounce: card.isLiked, action: like
            )
            ReelButton(image: "speaker.wave.2.fill", label: listenLabel, tint: ink, ink: ink) {
                Speaker.shared.say(card.word, in: card.language, asked: true)
            }
            ReelButton(image: "book", label: openLabel, tint: ink, ink: ink, action: open)
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
        .animation(.smooth(duration: 0.4), value: isCurrent)
        .animation(.snappy, value: card.picked)
        .sensoryFeedback(trigger: card.picked) { _, picked in
            guard let picked, card.choices.indices.contains(picked) else { return nil }
            return card.choices[picked].isCorrect ? .success : .error
        }
    }

    /// Avant la réponse, tous les choix se valent. Après : le bon en vert, et
    /// celui qu'on a pris à tort en rouge.
    private func colour(of choice: ReviewViewModel.Choice, at index: Int) -> Color {
        guard let picked = card.picked else { return ReviewView.ink(card).opacity(0.18) }
        if choice.isCorrect { return Color(red: 0.16, green: 0.62, blue: 0.36) }
        if index == picked { return Color(red: 0.80, green: 0.22, blue: 0.22) }
        return ReviewView.ink(card).opacity(0.08)
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
        .animation(.smooth(duration: 0.5), value: isCurrent)
        .sensoryFeedback(.success, trigger: isCurrent) { _, now in now }
    }
}

/// Un bouton rond, sous le mot.
private struct ReelButton: View {
    let image: String
    let label: String
    var tint: Color = .white
    /// La couleur du rond : celle du texte de la carte.
    var ink: Color = .white
    var bounce = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: image)
                .font(.title2)
                .foregroundStyle(tint)
                .symbolEffect(.bounce, value: bounce)
                .frame(width: 54, height: 54)
                .background(ink.opacity(0.16), in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Le trait qui se remplit pendant qu'on devine. Un doigt tenu l'arrête ;
/// plein, il montre le sens.
private struct ProgressLine: View {
    let duration: Double
    let held: Bool
    var ink: Color = .white
    let done: () -> Void

    @State private var started = Date.now
    @State private var pausedAt: Date?
    @State private var pausedFor: TimeInterval = 0

    /// Le temps passé à deviner, sans les pauses.
    private func elapsed(at now: Date) -> TimeInterval {
        now.timeIntervalSince(started) - pausedFor - (pausedAt.map { now.timeIntervalSince($0) } ?? 0)
    }

    var body: some View {
        TimelineView(.animation(paused: held)) { context in
            let fill = min(1, max(0, elapsed(at: context.date) / duration))
            Capsule()
                .fill(ink.opacity(0.25))
                .frame(height: 3)
                .overlay {
                    Capsule()
                        .fill(ink)
                        .scaleEffect(x: fill, y: 1, anchor: .leading)
                }
        }
        .onChange(of: held, initial: true) { _, now in
            if now {
                pausedAt = .now
            } else if let at = pausedAt {
                pausedFor += Date.now.timeIntervalSince(at)
                pausedAt = nil
            }
        }
        .task { @MainActor in
            while !Task.isCancelled {
                let left = duration - elapsed(at: .now)
                if left <= 0, pausedAt == nil { done(); return }
                try? await Task.sleep(for: .seconds(min(max(left, 0.05), 0.1)))
            }
        }
        .accessibilityHidden(true)
    }
}
