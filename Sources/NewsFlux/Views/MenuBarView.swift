import AppKit
import SwiftUI

/// Panneau affiché depuis l'icône de la barre des menus : derniers articles non lus.
struct MenuBarView: View {
    @Environment(FeedStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openURL) private var openURL

    private var unread: [Article] {
        Array(store.articles(for: .unread).prefix(15))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("NewsFlux").font(.headline)
                Spacer()
                Text(store.totalUnread == 0 ? "Tout est lu" : "\(store.totalUnread) non lus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await store.refresh() }
                } label: {
                    if store.isRefreshing {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(store.isRefreshing)
                .help("Actualiser")
            }
            .padding(12)

            Divider()

            if unread.isEmpty {
                ContentUnavailableView("Rien de nouveau", systemImage: "checkmark.seal")
                    .frame(height: 140)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(unread) { article in
                            MenuBarArticleRow(article: article,
                                              feedTitle: store.feed(for: article.feedID)?.title ?? "") {
                                store.markRead(article)
                                if let link = article.link { openURL(link) }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 420)
            }

            Divider()

            HStack {
                Button("Ouvrir NewsFlux") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("Tout marquer comme lu") { store.markAllRead(in: .unread) }
                    .disabled(unread.isEmpty)
                Button("Quitter") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
            .font(.callout)
            .padding(10)
        }
        .frame(width: 360)
    }
}

private struct MenuBarArticleRow: View {
    let article: Article
    let feedTitle: String
    let action: () -> Void
    @ViewState private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                FeedIcon(feedID: article.feedID, size: 16)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(article.title)
                        .font(.callout.weight(.medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 4) {
                        Text(feedTitle).lineLimit(1)
                        if let date = article.published {
                            Text("·")
                            Text(date, format: .relative(presentation: .named))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(hovering ? Color.accentColor.opacity(0.15) : .clear,
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(article.link?.absoluteString ?? "")
    }
}
