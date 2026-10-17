import SwiftUI

struct ArticleListView: View {
    @Environment(FeedStore.self) private var store
    let articles: [Article]
    @Binding var selection: Article.ID?

    var body: some View {
        Group {
            if articles.isEmpty {
                if store.isRefreshing {
                    ProgressView("Chargement des flux…")
                } else {
                    ContentUnavailableView("Rien à lire", systemImage: "checkmark.seal",
                                           description: Text("Aucun article à afficher ici."))
                }
            } else {
                List(articles, selection: $selection) { article in
                    ArticleRow(article: article, isRead: store.isRead(article),
                               feedTitle: store.feed(for: article.feedID)?.title ?? "")
                        .contextMenu {
                            let read = store.isRead(article)
                            Button(read ? "Marquer comme non lu" : "Marquer comme lu") {
                                store.markRead(article, !read)
                            }
                            if let link = article.link {
                                Link("Ouvrir dans le navigateur", destination: link)
                            }
                        }
                }
                .listStyle(.inset)
            }
        }
    }
}

struct ArticleRow: View {
    let article: Article
    let isRead: Bool
    let feedTitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(isRead ? Color.clear : Color.accentColor)
                .frame(width: 7, height: 7)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.headline)
                    .foregroundStyle(isRead ? .secondary : .primary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Text(feedTitle).lineLimit(1)
                    if let date = article.published {
                        Text("·")
                        Text(date, format: .relative(presentation: .named))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !article.summary.isEmpty {
                    Text(article.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            if let imageURL = article.imageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.secondary.opacity(0.1)
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.vertical, 6)
    }
}
