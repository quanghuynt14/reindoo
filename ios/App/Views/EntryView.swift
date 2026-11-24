import ReindooCore
import SwiftUI

struct EntryView: View {
    let model: EntryViewModel

    var body: some View {
        let state = model.state

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.section) {
                switch state.status {
                case .found: found(state)
                case .notFound: notFound(state)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.margin)
            .padding(.vertical, Theme.gap)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Le cerveau, à côté du cœur : seulement pour un mot qui a une histoire.
            if state.status == .found, state.memo != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.send(.showMemo) } label: {
                        Image(systemName: "brain")
                    }
                    .accessibilityLabel(state.memoLabel)
                    .accessibilityIdentifier("entry.memo")
                }
            }
            if state.status == .found {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.send(.like) } label: {
                        Image(systemName: state.isLiked ? "heart.fill" : "heart")
                            .foregroundStyle(state.isLiked ? Color(red: 1, green: 0.36, blue: 0.42) : Color.primary)
                            .symbolEffect(.bounce, value: state.isLiked)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .accessibilityLabel(state.likeLabel)
                    .accessibilityAddTraits(state.isLiked ? .isSelected : [])
                    .accessibilityIdentifier("entry.like")
                    .sensoryFeedback(.impact(weight: .medium), trigger: state.isLiked)
                }
            }
        }
        .onDisappear { Speaker.shared.stop() }
        .sheet(isPresented: Binding(
            get: { model.state.isMemoShown },
            set: { if !$0 { model.send(.hideMemo) } }
        )) {
            if let memo = model.state.memo {
                MemoView(memo: memo, closeLabel: model.state.closeLabel) { model.send(.hideMemo) }
            }
        }
    }

    // MARK: Trouvé

    @ViewBuilder
    private func found(_ state: EntryViewModel.State) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: Theme.gap) {
                Text(state.word)
                    .font(Theme.headword())
                    .textSelection(.enabled)
                Spacer(minLength: 0)
                // Toucher le haut-parleur, c'est demander : la voix passe outre
                // le bouton silencieux, comme dans le reel.
                Button {
                    Speaker.shared.say(state.word, in: state.language, asked: true)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(.tint.opacity(0.12), in: .circle)
                }
                .accessibilityLabel(state.listenLabel)
                .accessibilityIdentifier("entry.listen")
            }
            if !state.ipa.isEmpty {
                Text(state.ipa)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let hanViet = state.hanViet {
                Text(hanViet)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let traditional = state.traditional {
                Text(traditional)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Text(state.translated)
                .font(.title2.weight(.medium))
                .foregroundStyle(.tint)
                .padding(.top, 6)
        }

        if state.matchedNote != nil || !state.alsoFrom.isEmpty {
            VStack(alignment: .leading, spacing: Theme.gap) {
                if let note = state.matchedNote {
                    Label(note, systemImage: "arrow.turn.down.right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !state.alsoFrom.isEmpty {
                    WordChips(title: state.alsoFromTitle, words: state.alsoFrom) { model.send(.open($0)) }
                }
            }
        }

        ForEach(state.senses, id: \.index) { sense in
            VStack(alignment: .leading, spacing: Theme.gap) {
                if let heading = sense.heading {
                    Text(heading)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.top, sense.index == 0 ? 0 : Theme.gap)
                        .accessibilityAddTraits(.isHeader)
                }
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    if state.senses.count > 1 {
                        Text("\(sense.number)")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text(sense.explain)
                        .font(Theme.entryBody)
                        .textSelection(.enabled)
                }
                ForEach(sense.examples, id: \.sourceSentence) { example in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(example.sourceSentence)
                            .font(Theme.entryBody.italic())
                        if let pinyin = example.pinyin {
                            Text(pinyin)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(example.targetTranslation)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, Theme.gap)
                    .overlay(alignment: .leading) {
                        Capsule().fill(.quaternary).frame(width: 3)
                    }
                    .textSelection(.enabled)
                }
                if let note = sense.note {
                    Label(note, systemImage: "lightbulb")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                if !sense.synonyms.isEmpty {
                    WordChips(title: sense.synonymsTitle, words: sense.synonyms) { model.send(.open($0)) }
                }
                if !sense.antonyms.isEmpty {
                    WordChips(title: sense.antonymsTitle, words: sense.antonyms) { model.send(.open($0)) }
                }
            }
        }

        if !state.derived.isEmpty {
            WordChips(title: state.derivedTitle, words: state.derived) { model.send(.open($0)) }
        }

        if let wiki = state.wiki, let url = URL(string: wiki) {
            Link(destination: url) {
                Label("Wiktionary", systemImage: "arrow.up.right")
                    .font(.footnote)
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: Introuvable

    @ViewBuilder
    private func notFound(_ state: EntryViewModel.State) -> some View {
        VStack(alignment: .leading, spacing: Theme.gap) {
            Text(state.title)
                .font(.title2.weight(.semibold))
            if let hint = state.hint {
                Text(hint)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, Theme.section)

        ForEach(state.elsewhere, id: \.language) { other in
            VStack(alignment: .leading, spacing: 0) {
                Text(other.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                WordRow(word: other.word, detail: other.translated) { model.send(.openElsewhere(other.language)) }
            }
        }

        VStack(spacing: 0) {
            ForEach(state.suggestions, id: \.self) { word in
                WordRow(word: word) { model.send(.open(word)) }
                Divider()
            }
        }
    }
}

/// Des renvois vers d'autres mots, qui passent à la ligne quand il le faut.
struct WordChips: View {
    let title: String
    let words: [String]
    let open: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            FlowLayout(spacing: 8) {
                ForEach(words, id: \.self) { word in
                    Button(word) { open(word) }
                        .font(.system(.subheadline, design: .serif))
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(.primary)
                        .frame(minHeight: 44)
                }
            }
        }
    }
}

/// Aligne ses enfants de gauche à droite et passe à la ligne.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrange(subviews, width: bounds.width)
        for (subview, origin) in zip(subviews, arrangement.origins) {
            subview.place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: ProposedViewSize(width: bounds.width, height: nil)
            )
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (CGSize(width: widest, height: y + rowHeight), origins)
    }
}
