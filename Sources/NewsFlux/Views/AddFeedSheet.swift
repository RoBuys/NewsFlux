import SwiftUI

struct AddFeedSheet: View {
    @Environment(FeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @ViewState private var urlString = ""
    @ViewState private var folder = ""
    @ViewState private var error: String?
    @ViewState private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ajouter un flux").font(.title2.bold())
            Text("Collez l'adresse d'un site ou de son flux RSS / Atom : le flux sera trouvé automatiquement.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("lemonde.fr ou https://exemple.com/feed.xml", text: $urlString)
                .textFieldStyle(.roundedBorder)
                .onSubmit(add)

            HStack {
                Text("Dossier")
                TextField("Aucun", text: $folder)
                    .textFieldStyle(.roundedBorder)
                if !store.folders.isEmpty {
                    Menu {
                        ForEach(store.folders, id: \.self) { name in
                            Button(name) { folder = name }
                        }
                    } label: {
                        Image(systemName: "folder")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Choisir un dossier existant")
                }
            }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            HStack {
                if isLoading {
                    ProgressView().controlSize(.small)
                    Text("Recherche du flux…").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Annuler", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Ajouter", action: add)
                    .keyboardShortcut(.defaultAction)
                    .disabled(urlString.isEmpty || isLoading)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private func add() {
        var text = urlString.trimmingCharacters(in: .whitespaces)
        if !text.contains("://") { text = "https://" + text }
        guard let url = URL(string: text), url.host() != nil else {
            error = "Adresse invalide."
            return
        }
        let folderName = folder.trimmingCharacters(in: .whitespaces)
        isLoading = true
        error = nil
        Task {
            do {
                try await store.addFeed(from: url, folder: folderName.isEmpty ? nil : folderName)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
