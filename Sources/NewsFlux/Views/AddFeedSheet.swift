import SwiftUI

struct AddFeedSheet: View {
    @Environment(FeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @ViewState private var urlString = ""
    @ViewState private var error: String?
    @ViewState private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ajouter un flux").font(.title2.bold())
            Text("Collez l'adresse d'un flux RSS ou Atom.")
                .foregroundStyle(.secondary)

            TextField("https://exemple.com/feed.xml", text: $urlString)
                .textFieldStyle(.roundedBorder)
                .onSubmit(add)

            if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            HStack {
                Spacer()
                Button("Annuler", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(action: add) {
                    if isLoading { ProgressView().controlSize(.small) } else { Text("Ajouter") }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(urlString.isEmpty || isLoading)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func add() {
        var text = urlString.trimmingCharacters(in: .whitespaces)
        if !text.contains("://") { text = "https://" + text }
        guard let url = URL(string: text), url.host() != nil else {
            error = "Adresse invalide."
            return
        }
        isLoading = true
        error = nil
        Task {
            do {
                try await store.addFeed(url: url)
                dismiss()
            } catch {
                self.error = "Impossible de lire ce flux : \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
