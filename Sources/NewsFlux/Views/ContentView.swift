import SwiftUI

struct ContentView: View {
    @Environment(FeedStore.self) private var store
    @ViewState private var sidebarSelection: SidebarItem? = .all
    @ViewState private var articleSelection: Article.ID?
    @ViewState private var search = ""
    @ViewState private var showingAddFeed = false

    private var currentItem: SidebarItem { sidebarSelection ?? .all }

    private var visibleArticles: [Article] {
        store.articles(for: currentItem, matching: search)
    }

    private var selectedArticle: Article? {
        guard let articleSelection else { return nil }
        return store.articles.first { $0.id == articleSelection }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $sidebarSelection, showingAddFeed: $showingAddFeed)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } content: {
            ArticleListView(articles: visibleArticles, selection: $articleSelection)
                .navigationTitle(title(for: currentItem))
                .navigationSubtitle(subtitle)
                .searchable(text: $search, placement: .toolbar, prompt: "Rechercher")
                .navigationSplitViewColumnWidth(min: 300, ideal: 380)
        } detail: {
            if let article = selectedArticle {
                ArticleDetailView(article: article)
                    .id(article.id)
            } else {
                ContentUnavailableView("Aucun article sélectionné", systemImage: "newspaper",
                                       description: Text("Choisissez un article dans la liste."))
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.markAllRead(in: currentItem)
                } label: {
                    Label("Tout marquer comme lu", systemImage: "checkmark.circle")
                }
                .help("Tout marquer comme lu")

                Button {
                    Task { await store.refresh() }
                } label: {
                    if store.isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Actualiser", systemImage: "arrow.clockwise")
                    }
                }
                .help("Actualiser (⌘R)")
                .disabled(store.isRefreshing)
            }
        }
        .sheet(isPresented: $showingAddFeed) { AddFeedSheet() }
        .onChange(of: articleSelection) { _, id in
            if let article = store.articles.first(where: { $0.id == id }) { store.markRead(article) }
        }
        .onChange(of: sidebarSelection) { articleSelection = nil }
        .task {
            // Actualisation au lancement puis toutes les 15 minutes.
            while !Task.isCancelled {
                await store.refresh()
                try? await Task.sleep(for: .seconds(15 * 60))
            }
        }
    }

    private var subtitle: String {
        let unread = store.unreadCount(for: currentItem)
        return unread == 0 ? "Tout est lu" : "\(unread) non lu\(unread > 1 ? "s" : "")"
    }

    private func title(for item: SidebarItem) -> String {
        switch item {
        case .all: "Tous les articles"
        case .unread: "Non lus"
        case .feed(let id): store.feed(for: id)?.title ?? "Flux"
        }
    }
}
