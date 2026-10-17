import SwiftUI

struct SidebarView: View {
    @Environment(FeedStore.self) private var store
    @Binding var selection: SidebarItem?
    @Binding var showingAddFeed: Bool

    var body: some View {
        List(selection: $selection) {
            Section {
                Label("Tous les articles", systemImage: "tray.full")
                    .badge(store.unreadCount(for: .all))
                    .tag(SidebarItem.all)
                Label("Non lus", systemImage: "circle.inset.filled")
                    .badge(store.unreadCount(for: .unread))
                    .tag(SidebarItem.unread)
            }

            Section("Flux") {
                ForEach(store.feeds) { feed in
                    HStack {
                        Label(feed.title, systemImage: "dot.radiowaves.up.forward")
                            .lineLimit(1)
                        if let error = store.errors[feed.id] {
                            Spacer()
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .help(error)
                        }
                    }
                    .badge(store.unreadCount(for: .feed(feed.id)))
                    .tag(SidebarItem.feed(feed.id))
                    .contextMenu {
                        Button("Tout marquer comme lu") { store.markAllRead(in: .feed(feed.id)) }
                        Divider()
                        Button("Supprimer le flux", role: .destructive) {
                            if selection == .feed(feed.id) { selection = .all }
                            store.removeFeed(feed.id)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button {
                showingAddFeed = true
            } label: {
                Label("Ajouter un flux", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("n")
            .padding(10)
        }
    }
}
