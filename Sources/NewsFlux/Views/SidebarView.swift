import SwiftUI

struct SidebarView: View {
    @Environment(FeedStore.self) private var store
    @Binding var selection: SidebarItem?
    @Binding var showingAddFeed: Bool

    @ViewState private var collapsedFolders: Set<String> = []
    @ViewState private var folderPrompt: FolderPrompt?
    @ViewState private var folderName = ""

    /// Saisie d'un nom de dossier : création (pour y ranger un flux) ou renommage.
    private enum FolderPrompt: Identifiable {
        case create(Feed.ID)
        case rename(String)

        var id: String {
            switch self {
            case .create(let id): "create-\(id)"
            case .rename(let name): "rename-\(name)"
            }
        }
    }

    var body: some View {
        List(selection: $selection) {
            Section("Bibliothèque") {
                Label("Tous les articles", systemImage: "tray.full")
                    .badge(store.unreadCount(for: .all))
                    .tag(SidebarItem.all)
                Label("Non lus", systemImage: "circle.inset.filled")
                    .badge(store.unreadCount(for: .unread))
                    .tag(SidebarItem.unread)
                Label("Favoris", systemImage: "star")
                    .badge(store.articles(for: .starred).count)
                    .tag(SidebarItem.starred)
            }

            Section("Flux") {
                ForEach(store.folders, id: \.self) { folder in
                    DisclosureGroup(isExpanded: expansion(for: folder)) {
                        ForEach(store.feeds(in: folder)) { feedRow($0) }
                    } label: {
                        Label(folder, systemImage: "folder")
                            .badge(store.unreadCount(for: .folder(folder)))
                            .tag(SidebarItem.folder(folder))
                            .contextMenu { folderMenu(folder) }
                    }
                }
                ForEach(store.feeds(in: nil)) { feedRow($0) }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .alert(promptTitle, isPresented: isPromptPresented) {
            TextField("Nom du dossier", text: $folderName)
            Button("Annuler", role: .cancel) {}
            Button("OK") { applyPrompt() }
        }
    }

    // MARK: Lignes

    private func feedRow(_ feed: Feed) -> some View {
        HStack {
            Label {
                Text(feed.title).lineLimit(1)
            } icon: {
                FeedIcon(feedID: feed.id)
            }
            Spacer()
            if feed.notify {
                Image(systemName: "bell.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .help("Notifications activées")
            }
            if let error = store.errors[feed.id] {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(error)
            }
        }
        .badge(store.unreadCount(for: .feed(feed.id)))
        .tag(SidebarItem.feed(feed.id))
        .contextMenu { feedMenu(feed) }
    }

    @ViewBuilder
    private func feedMenu(_ feed: Feed) -> some View {
        Button("Tout marquer comme lu") { store.markAllRead(in: .feed(feed.id)) }
        Button(feed.notify ? "Désactiver les notifications" : "Activer les notifications") {
            Task { await store.setNotifications(!feed.notify, for: feed.id) }
        }
        Menu("Déplacer vers") {
            ForEach(store.folders, id: \.self) { folder in
                Button(folder) { store.move(feed.id, to: folder) }
                    .disabled(feed.folder == folder)
            }
            if !store.folders.isEmpty { Divider() }
            Button("Nouveau dossier…") { prompt(.create(feed.id), name: "") }
            if feed.folder != nil {
                Button("Hors dossier") { store.move(feed.id, to: nil) }
            }
        }
        Divider()
        Button("Supprimer le flux", role: .destructive) {
            if selection == .feed(feed.id) { selection = .all }
            store.removeFeed(feed.id)
        }
    }

    @ViewBuilder
    private func folderMenu(_ folder: String) -> some View {
        Button("Tout marquer comme lu") { store.markAllRead(in: .folder(folder)) }
        Button("Renommer…") { prompt(.rename(folder), name: folder) }
        Divider()
        Button("Supprimer le dossier (garder les flux)", role: .destructive) {
            if selection == .folder(folder) { selection = .all }
            store.deleteFolder(folder)
        }
    }

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack {
                Button {
                    showingAddFeed = true
                } label: {
                    Label("Ajouter un flux", systemImage: "plus")
                }
                .keyboardShortcut("n")

                Spacer()

                Button {
                    Task { await store.refresh() }
                } label: {
                    if store.isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(store.isRefreshing)
                .help("Actualiser les flux (⌘R)")
            }
            .buttonStyle(.borderless)

            Group {
                if store.isRefreshing {
                    Text("Actualisation…")
                } else if let last = store.lastRefresh {
                    Text("Actualisé à \(last, format: .dateTime.hour().minute())")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    // MARK: Dossiers

    private func expansion(for folder: String) -> Binding<Bool> {
        Binding {
            !collapsedFolders.contains(folder)
        } set: { expanded in
            if expanded { collapsedFolders.remove(folder) } else { collapsedFolders.insert(folder) }
        }
    }

    private var isPromptPresented: Binding<Bool> {
        Binding { folderPrompt != nil } set: { if !$0 { folderPrompt = nil } }
    }

    private var promptTitle: String {
        if case .rename = folderPrompt { return "Renommer le dossier" }
        return "Nouveau dossier"
    }

    private func prompt(_ kind: FolderPrompt, name: String) {
        folderName = name
        folderPrompt = kind
    }

    private func applyPrompt() {
        let name = folderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let kind = folderPrompt else { return }
        switch kind {
        case .create(let feedID):
            store.move(feedID, to: name)
        case .rename(let old):
            store.renameFolder(old, to: name)
            if selection == .folder(old) { selection = .folder(name) }
        }
        folderPrompt = nil
    }
}

/// Icône du site d'un flux, ou pictogramme générique en attendant.
struct FeedIcon: View {
    @Environment(FeedStore.self) private var store
    let feedID: Feed.ID
    var size: CGFloat = 16

    var body: some View {
        if let image = store.icons[feedID] {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        } else {
            Image(systemName: "dot.radiowaves.up.forward")
                .frame(width: size, height: size)
        }
    }
}
