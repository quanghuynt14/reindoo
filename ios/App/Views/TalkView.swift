import ReindooCore
import SwiftUI

/// Le papier des cartes et des bulles : tout l'onglet est dessiné à la main.
private let paper = Color(red: 0.99, green: 0.97, blue: 0.93)
private let pencil = Color(red: 0.2, green: 0.13, blue: 0.11)
private let rightTint = Color(red: 0.22, green: 0.55, blue: 0.3)

/// « Giao tiếp » : les histoires rangées par intention, chacune sur son décor.
/// En toucher une l'ouvre en plein écran, une carte à la fois, comme le reel.
struct TalkView: View {
    let model: TalkViewModel

    var body: some View {
        let state = model.state
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gap) {
                Text(state.intro)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                ForEach(state.sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        if let title = section.title {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title).font(.title3.weight(.bold))
                                if let when = section.when {
                                    Text(when).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.top, 10)
                        }
                        ForEach(section.rows) { row in
                            Button { model.send(.open(row.id)) } label: { StoryRow(row: row) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, Theme.section)
        }
        .navigationTitle(state.title)
        // Tous les dessins de l'onglet se lisent d'avance, pendant qu'on
        // regarde la liste : ouvrir une histoire ne décode plus rien.
        .task { await SketchCache.shared.warm(Still.all) }
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
        HStack(spacing: 14) {
            HStack(spacing: -12) {
                ForEach(Array(row.cast.prefix(4).enumerated()), id: \.offset) { _, who in
                    if let sketch = who.sketch {
                        SketchView(.head(sketch))
                            .frame(width: 54, height: 54)
                            .clipShape(.circle)
                            .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1.5))
                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    } else {
                        Text(who.emoji).font(.system(size: 40))
                    }
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title).font(.headline)
                if !row.gloss.isEmpty {
                    Text(row.gloss).font(.subheadline).opacity(0.8)
                }
                Text(row.detail).font(.caption.weight(.semibold)).opacity(0.75)
            }
            Spacer(minLength: 0)
            if row.isDone {
                Hand.glyph(.right, size: 26).foregroundStyle(rightTint)
            }
        }
        .foregroundStyle(pencil)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                paper
                SketchView(.band(row.motif))
                // Un voile de papier : le titre se lit par-dessus le décor.
                LinearGradient(colors: [paper.opacity(0.1), paper.opacity(0.55)], startPoint: .leading, endPoint: .trailing)
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
    private static let pace = Animation.smooth(duration: 0.38)

    var body: some View {
        if let player = model.state.player {
            let ink = pencil
            GeometryReader { page in
                let height = page.size.height
                ZStack {
                    ForEach(Array(player.cards.enumerated()), id: \.element.id) { index, card in
                        // Seules la carte à l'écran et ses voisines existent.
                        if abs(index - player.position) <= 1 {
                            TalkCard(card: card, player: player, ink: ink, model: model)
                                .frame(width: page.size.width, height: height)
                                .offset(y: CGFloat(index - player.position) * height + drag)
                                .accessibilityHidden(index != player.position)
                        }
                    }
                }
                .frame(width: page.size.width, height: height, alignment: .top)
                // Les cartes voisines s'arrêtent au bord : leur bas ne vient
                // plus se glisser sous le titre.
                .clipped()
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
                ZStack {
                    paper
                    SketchView(.backdrop(player.motif))
                }
                .ignoresSafeArea()
            }
            .overlay(alignment: .top) {
                HStack(spacing: 10) {
                    Text(player.title)
                        .font(.headline)
                        .lineLimit(1)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(paper.opacity(0.85), in: .capsule)
                    Spacer(minLength: 0)
                    Text("\(player.position + 1)/\(player.cards.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(paper.opacity(0.85), in: .capsule)
                    Button { model.send(.close) } label: {
                        Hand.glyph(.cross, size: 18)
                            .frame(width: 40, height: 40)
                            .background(paper.opacity(0.85), in: .circle)
                    }
                    .accessibilityLabel(player.closeLabel)
                }
                .padding(.horizontal, Theme.margin)
                .padding(.top, 4)
            }
            // Un mot du français de la girafe, ouvert sans quitter l'histoire.
            .sheet(isPresented: Binding(
                get: { model.state.lookingUp != nil },
                set: { if !$0 { model.send(.closeLookUp) } }
            )) {
                if let entry = model.entry {
                    NavigationStack { EntryView(model: entry) }
                }
            }
            .onDisappear { Speaker.shared.stop() }
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
    let ink: Color
    let model: TalkViewModel

    @State private var swipe: CGFloat = 0
    @State private var bobbing = false
    /// La forme girafe dont on lit l'explication.
    @State private var form: GiraffeForm?
    /// Le mot à ouvrir une fois l'explication refermée : deux feuilles ne
    /// montent pas en même temps.
    @State private var pendingWord: String?
    @State private var writing = false
    @State private var draft = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let threshold: CGFloat = 90

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 56)
            switch card.kind {
            case .narration: narration
            case .sort: sort
            case .rewrite, .body, .need, .hint: choosing
            case .report: report
            }
            Spacer(minLength: 32)
            if card.done == nil, card.kind == .narration || card.isAnswered {
                Label { Text(player.continueHint) } icon: { Hand.glyph(.up, size: 14) }
                    .font(.caption.weight(.semibold))
                    .opacity(0.65)
            }
        }
        .padding(.horizontal, Theme.margin)
        .padding(.bottom, 24)
        .onAppear { bobbing = true }
        // Une réponse à côté ne vibre pas comme une erreur : un simple toucher.
        .sensoryFeedback(trigger: card.verdict) { _, verdict in
            switch verdict {
            case .right: .success
            case .wrong: .impact(weight: .light)
            case nil: nil
            }
        }
        .sheet(item: $form, onDismiss: {
            if let word = pendingWord {
                pendingWord = nil
                model.send(.lookUp(word))
            }
        }) { form in
            formSheet(form)
        }
        .sheet(isPresented: $writing) { writeSheet }
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

    /// Chaque animal a son dessin ; l'emoji ne sert que si le dessin manque.
    @ViewBuilder
    private func portrait(_ who: Animal, size: CGFloat, delay: Double = 0) -> some View {
        if let sketch = sketch(for: who) {
            head(sketch, size: size * 1.2)
                .offset(y: bobbing && !reduceMotion ? -4 : 0)
                .animation(reduceMotion ? nil : .easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(delay), value: bobbing)
        } else {
            animal(who.emoji, size: size, delay: delay)
        }
    }

    /// Une tête dessinée, sur sa pastille de papier.
    private func head(_ sketch: Sketch, size: CGFloat) -> some View {
        SketchView(.head(sketch))
            .frame(width: size, height: size)
            .clipShape(.circle)
            .overlay(Circle().stroke(ink.opacity(0.25)))
            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
    }

    private func sketch(for who: Animal) -> Sketch? {
        switch who.sketch {
        case .giraffe: giraffeMood
        case .jackal: jackalMood
        case .animal(let species, _): .animal(species, card.verdict == .right ? .happy : .calm)
        case let other: other
        }
    }

    /// L'humeur suit la réponse. Le chacal ne boude plus d'une réponse à
    /// côté : quand on l'a entendu, il se radoucit, quelle que soit la réponse.
    private var giraffeMood: Sketch {
        .giraffe(card.verdict == .right ? .happy : card.isAnswered ? .listening : .calm)
    }
    private var jackalMood: Sketch {
        .jackal(card.isAnswered ? .soft : .cross)
    }

    private var speaker: some View {
        HStack(spacing: 10) {
            if let who = card.cast.first {
                portrait(who, size: 60)
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
            Hand.glyph(.speaker, size: 22)
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
        .background(paper.opacity(0.88), in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(ink.opacity(0.22)))
    }

    // MARK: Les cartes

    private var narration: some View {
        VStack(spacing: 24) {
            HStack(spacing: 28) {
                ForEach(Array(card.cast.prefix(4).enumerated()), id: \.offset) { index, who in
                    VStack(spacing: 4) {
                        portrait(who, size: card.cast.count > 2 ? 54 : 78, delay: Double(index) * 0.4)
                        Text(who.name).font(.caption.weight(.semibold))
                    }
                }
            }
            Text(card.text)
                .font(.system(.title3, design: .serif))
                .multilineTextAlignment(.center)
                .padding(16)
                .background(paper.opacity(0.8), in: .rect(cornerRadius: 18))
            if !card.gloss.isEmpty {
                Text(card.gloss)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .opacity(0.75)
            }
            if let done = card.done {
                Button { model.send(.close) } label: {
                    Text(done)
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(paper.opacity(0.9), in: .capsule)
                        .overlay(Capsule().stroke(ink.opacity(0.25)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var sort: some View {
        VStack(alignment: .leading, spacing: 16) {
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

    /// Le tampon que la carte prend pendant qu'on la pousse : chacal à gauche,
    /// girafe à droite.
    @ViewBuilder
    private var stamp: some View {
        let progress = min(1, abs(swipe) / Self.threshold)
        if swipe != 0 {
            HStack(spacing: 6) {
                head(swipe < 0 ? .jackal(.cross) : .giraffe(.calm), size: 30)
                Text(swipe < 0 ? player.jackalLabel : player.giraffeLabel)
            }
                .font(.title3.weight(.heavy))
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(paper, in: .capsule)
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
                let voice: Voice? = swipe <= -Self.threshold ? .jackal : swipe >= Self.threshold ? .giraffe : nil
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
                voiceButton(.jackal, .jackal(.cross), player.jackalLabel)
                voiceButton(.giraffe, .giraffe(.calm), player.giraffeLabel)
            }
            Text(player.sortHint).font(.caption).opacity(0.65)
        }
        .frame(maxWidth: .infinity)
    }

    private func voiceButton(_ voice: Voice, _ sketch: Sketch, _ label: String) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.35)) { model.send(.sort(card.id, voice)) }
        } label: {
            HStack(spacing: 8) {
                head(sketch, size: 40)
                Text(label).font(.headline)
            }
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(paper.opacity(0.8), in: .capsule)
            .overlay(Capsule().stroke(ink.opacity(0.2)))
        }
        .buttonStyle(.plain)
    }

    /// Après la réponse : qui parlait, pourquoi, comment la girafe le dirait,
    /// et le français qui fait parler girafe. Rien de rouge, rien de barré.
    private var verdict: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if card.verdict == .right {
                    Hand.glyph(.right, size: 22).foregroundStyle(rightTint)
                } else {
                    head(card.voice == .jackal ? .jackal(.soft) : .giraffe(.listening), size: 26)
                }
                Text(card.verdictLabel ?? "").font(.headline)
                Spacer()
                if let part = card.part {
                    Text(part)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(ink.opacity(0.12), in: .capsule)
                }
            }
            Text(card.why).font(.callout).fixedSize(horizontal: false, vertical: true)
            if let translation = card.translation {
                HStack(alignment: .top, spacing: 8) {
                    head(.giraffe(.happy), size: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.giraffeWouldSay).font(.caption.weight(.bold)).opacity(0.7)
                        Text(translation)
                            .font(.system(.callout, design: .serif).weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(rightTint.opacity(0.12), in: .rect(cornerRadius: 14))
            }
            if !card.forms.isEmpty { formChips(card.forms) }
            if card.canWrite { ownLine }
        }
        .padding(14)
        .background(paper.opacity(0.92), in: .rect(cornerRadius: 18))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func chip(_ item: GiraffeForm) -> some View {
        Button { form = item } label: {
            Text(item.phrase)
                .font(.system(.footnote, design: .serif).weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(rightTint.opacity(0.14), in: .capsule)
                .overlay(Capsule().stroke(rightTint.opacity(0.35)))
        }
        .buttonStyle(.plain)
    }

    /// Les formes girafe, en pastilles : on touche pour lire pourquoi.
    private func formChips(_ forms: [GiraffeForm]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(player.giraffeFrench).font(.caption.weight(.bold)).opacity(0.7)
            FlowLayout(spacing: 6) {
                ForEach(forms) { chip($0) }
            }
        }
    }

    private func formSheet(_ form: GiraffeForm) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                head(.giraffe(.happy), size: 40)
                Text(player.giraffeFrench).font(.headline)
            }
            Text(form.phrase).font(.system(.title2, design: .serif).weight(.semibold))
            Text(form.note).font(.body).fixedSize(horizontal: false, vertical: true)
            Button {
                pendingWord = form.word
                self.form = nil
            } label: {
                Text("\(player.lookUpLabel) · \(form.word)")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(ink.opacity(0.1), in: .capsule)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .padding(Theme.margin)
        .foregroundStyle(ink)
        .presentationDetents([.medium])
        .presentationBackground(paper)
    }

    /// Sa propre phrase : on l'écrit, puis on la relit soi-même. Personne ne
    /// la corrige ; les quatre questions aident à l'entendre.
    private var ownLine: some View {
        Button {
            draft = card.written ?? ""
            writing = true
        } label: {
            HStack(spacing: 8) {
                Hand.glyph(.talk, size: 18)
                Text(card.written.map { "« \($0) »" } ?? player.writeLabel)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(ink.opacity(0.06), in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ink.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
        .buttonStyle(.plain)
    }

    private var writeSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(player.writeLabel).font(.title3.weight(.bold))
                HStack(alignment: .top, spacing: 8) {
                    head(.jackal(.soft), size: 32)
                    Text(card.text).font(.system(.callout, design: .serif)).opacity(0.8)
                }
                TextField(player.writePlaceholder, text: $draft, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.system(.title3, design: .serif))
                    .padding(12)
                    .background(.white.opacity(0.7), in: .rect(cornerRadius: 14))
                    .textInputAutocapitalization(.sentences)
                Button {
                    model.send(.write(card.id, draft))
                } label: {
                    Text(player.keepLabel)
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(ink.opacity(0.12), in: .capsule)
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if card.written != nil {
                    Text(player.rereadLabel).font(.headline).padding(.top, 6)
                    ForEach(player.checks, id: \.part) { check in
                        Button { model.send(.check(card.id, check.part)) } label: {
                            HStack(spacing: 10) {
                                Group {
                                    if card.checked.contains(check.part) {
                                        Hand.glyph(.check, size: 20).foregroundStyle(rightTint)
                                    } else {
                                        Circle().stroke(ink.opacity(0.4), lineWidth: 1.5).frame(width: 20, height: 20)
                                    }
                                }
                                .frame(width: 24)
                                Text(check.label).font(.callout).multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    if let giraffe = card.choices.first(where: \.isRight) {
                        HStack(alignment: .top, spacing: 8) {
                            head(.giraffe(.happy), size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.giraffeWouldSay).font(.caption.weight(.bold)).opacity(0.7)
                                Text(giraffe.text).font(.system(.callout, design: .serif).weight(.semibold))
                            }
                        }
                        .padding(.top, 6)
                    }
                }
            }
            .padding(Theme.margin)
        }
        .foregroundStyle(ink)
        .presentationDetents([.medium, .large])
        .presentationBackground(paper)
    }

    /// Les cartes où l'on choisit : reformuler, compléter une expression du
    /// corps, trouver le besoin commun, entendre un sous-entendu.
    private var choosing: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch card.kind {
            case .body:
                // Le trou se remplit à la réponse : l'expression entière reste à l'écran.
                bubble(card.isAnswered ? (card.complete ?? card.text) : card.text, gloss: card.isAnswered ? card.gloss : nil)
            case .need:
                ForEach(Array(card.cast.prefix(2).enumerated()), id: \.offset) { index, who in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(spacing: 0) {
                            portrait(who, size: 40, delay: Double(index) * 0.4)
                            Text(who.name).font(.caption2.weight(.semibold))
                        }
                        let line = index == 0 ? card.text : (card.reply ?? "")
                        let gloss = index == 0 ? card.gloss : card.replyGloss
                        bubble(line, gloss: card.isAnswered ? gloss : nil)
                    }
                }
            case .rewrite:
                speaker
                HStack(alignment: .top, spacing: 8) {
                    head(jackalMood, size: 44)
                    bubble(card.text, gloss: card.isAnswered ? card.gloss : nil)
                }
            default:
                speaker
                bubble(card.text, gloss: card.isAnswered ? card.gloss : nil)
            }
            if let question = card.question, !card.isAnswered {
                HStack(spacing: 8) {
                    if card.kind == .rewrite || card.kind == .hint { head(giraffeMood, size: 30) }
                    Text(question).font(.headline)
                }
            }
            // Les choix courts (une partie du corps, un besoin) tiennent sur deux colonnes.
            let wide = card.kind == .rewrite || card.kind == .hint
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: wide ? 1 : 2), spacing: 8) {
                choiceButtons(wide: wide)
            }
            if card.isAnswered { verdict }
        }
        .animation(.smooth(duration: 0.35), value: card.verdict)
    }

    /// Une fois la réponse donnée, seules restent la proposition girafe et
    /// celle qu'on avait choisie : la carte tient dans l'écran.
    private func choiceButtons(wide: Bool) -> some View {
        ForEach(Array(card.choices.enumerated()), id: \.offset) { index, choice in
            if !card.isAnswered || choice.isRight || card.picked == index {
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
                    .padding(wide ? 12 : 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(fill(choice), in: .rect(cornerRadius: 16))
                    .overlay {
                        // Le choix à côté reste lisible, en pointillé : ni rouge ni barré.
                        if card.isAnswered, !choice.isRight {
                            RoundedRectangle(cornerRadius: 16).stroke(ink.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if card.isAnswered, choice.isRight {
                            Group {
                                if wide { head(.giraffe(.happy), size: 24) } else { Hand.glyph(.check, size: 16).foregroundStyle(rightTint) }
                            }
                            .padding(6)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(card.isAnswered)
            }
        }
    }

    private func fill(_ choice: TalkViewModel.Choice) -> Color {
        guard card.isAnswered else { return paper.opacity(0.85) }
        return choice.isRight ? rightTint.opacity(0.22) : paper.opacity(0.6)
    }

    @ViewBuilder
    private var report: some View {
        if let report = card.report {
            VStack(alignment: .leading, spacing: 12) {
                // La fin d'une histoire : la girafe et le chacal, côte à côte.
                SketchView(.scene(.together))
                    .frame(width: 128, height: 110)
                    .clipShape(.rect(cornerRadius: 16))
                    .frame(maxWidth: .infinity)
                Text(report.title).font(.title2.weight(.bold))
                HStack(spacing: 8) {
                    tally(report.right, glyph: .right, tint: rightTint)
                    tally(report.wrong, glyph: .again, tint: ink.opacity(0.7))
                    // Ni rouge ni barré : passer n'est pas une faute.
                    tally(report.skipped, glyph: .skip, tint: ink.opacity(0.5))
                }
                if !report.own.lines.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(report.own.label).font(.headline)
                        ForEach(Array(report.own.lines.prefix(2).enumerated()), id: \.offset) { _, line in
                            Text("« \(line) »").font(.system(.callout, design: .serif)).lineLimit(2)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(paper.opacity(0.88), in: .rect(cornerRadius: 14))
                }
                if !report.forms.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(report.formsTitle).font(.headline)
                        FlowLayout(spacing: 6) {
                            ForEach(report.forms) { chip($0) }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(paper.opacity(0.88), in: .rect(cornerRadius: 14))
                }
                Button { withAnimation { model.send(.replay) } } label: {
                    Label { Text(report.playAgain) } icon: { Hand.glyph(.again, size: 20) }
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(paper.opacity(0.9), in: .capsule)
                        .overlay(Capsule().stroke(ink.opacity(0.25)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Un compte, sans jugement : combien, pas « bien » ou « mal ».
    private func tally(_ pile: TalkViewModel.Report.Pile, glyph: Glyph, tint: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Hand.glyph(glyph, size: 16).foregroundStyle(tint)
                Text("\(pile.lines.count)").font(.title3.monospacedDigit().weight(.bold))
            }
            Text(pile.label).font(.caption2.weight(.semibold)).multilineTextAlignment(.center).lineLimit(2)
        }
        .padding(.vertical, 10).padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background(paper.opacity(0.88), in: .rect(cornerRadius: 14))
    }
}
