import ReindooCore
import SwiftUI

struct HistoryView: View {
    let model: HistoryViewModel

    var body: some View {
        let state = model.state

        List {
            ForEach(state.items) { item in
                WordRow(word: item.word, detail: item.gloss, badge: item.languageLabel) {
                    model.send(.open(item.word, item.language))
                }
                .swipeActions {
                    Button(role: .destructive) {
                        model.send(.remove(item.word, item.language))
                    } label: {
                        Label(state.removeLabel, systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .animation(.snappy, value: state.items)
        .overlay {
            if let message = state.emptyMessage {
                ContentUnavailableView {
                    Label(state.title, systemImage: "clock")
                } description: {
                    Text(message)
                }
            }
        }
        .navigationTitle(state.title)
        .onAppear { model.send(.appear) }
    }
}
