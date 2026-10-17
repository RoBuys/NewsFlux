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
    }
}
