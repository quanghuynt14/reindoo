import ReindooCore
import SwiftUI

struct SearchView: View {
    let model: SearchViewModel
    let title: String

    var body: some View {
        let state = model.state

        List {
            if !state.query.isEmpty {
                ForEach(state.completions, id: \.self) { word in
                    WordRow(word: word) { model.send(.open(word)) }
                }
            } else if !state.recents.isEmpty {
                Section(state.recentsTitle) {
                    ForEach(state.recents, id: \.self) { word in
                        WordRow(word: word) { model.send(.open(word)) }
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if let message = state.emptyMessage {
                ContentUnavailableView {
                    Label(state.prompt, systemImage: "text.magnifyingglass")
                } description: {
                    Text(message)
                }
            }
        }
        .navigationTitle(title)
        .searchable(
            text: Binding(get: { state.query }, set: { model.send(.setQuery($0)) }),
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: state.prompt
        )
        .toolbar {
            HerdToolbarItem()
            // Toujours visible : la langue change le sens de tout l'écran.
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker(title, selection: Binding(get: { state.language }, set: { model.send(.setLanguage($0)) })) {
                        ForEach(state.languages, id: \.language) { option in
                            Text(option.label).tag(option.language)
                        }
                    }
                } label: {
                    Text(state.languages.first(where: \.isSelected)?.label ?? "")
                        .fixedSize()
                }
            }
        }
        .onSubmit(of: .search) { model.send(.submit) }
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .sensoryFeedback(.selection, trigger: state.language)
        .onAppear { model.send(.appear) }
    }
}

/// Un mot qu'on peut ouvrir. Toute la ligne se touche.
struct WordRow: View {
    let word: String
    var detail: String?
    var badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.gap) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(word)
                        .font(Theme.headword(.title3))
                        .foregroundStyle(.primary)
                    if let detail {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                if let badge {
                    Text(badge)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                // Le signe du système pour « ceci s'ouvre ».
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Dans une liste : des lignes moins hautes, alignées sur le grand titre
        // (16 pt), et pas de trait au-dessus
        // de la première.
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listSectionSeparator(.hidden, edges: .top)
    }
}
