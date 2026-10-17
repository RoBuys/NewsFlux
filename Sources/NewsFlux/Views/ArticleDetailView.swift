import SwiftUI
import WebKit

struct ArticleDetailView: View {
    @Environment(FeedStore.self) private var store
    @Environment(\.openURL) private var openURL
    let article: Article

    private enum Mode: String, CaseIterable { case summary = "Résumé", web = "Page web" }
    @ViewState private var mode: Mode = .summary

    var body: some View {
        Group {
            switch mode {
            case .summary: summary
            case .web:
                if let link = article.link { WebView(url: link) } else { summary }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Picker("Affichage", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .disabled(article.link == nil)

                if let link = article.link {
                    Button { openURL(link) } label: {
                        Label("Ouvrir dans le navigateur", systemImage: "safari")
                    }
                    .help("Ouvrir dans le navigateur")
                    ShareLink(item: link)
                }
            }
        }
    }

    private var summary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let imageURL = article.imageURL {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(.quaternary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(store.feed(for: article.feedID)?.title.uppercased() ?? "")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    Text(article.title)
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .textSelection(.enabled)
                    if let date = article.published {
                        Text(date, format: .dateTime.weekday(.wide).day().month(.wide).year().hour().minute())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if !article.summary.isEmpty {
                    Text(article.summary)
                        .font(.system(.title3, design: .serif))
                        .lineSpacing(5)
                        .textSelection(.enabled)
                }

                if article.link != nil {
                    Button {
                        mode = .web
                    } label: {
                        Label("Lire l'article complet", systemImage: "doc.richtext")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(32)
            .frame(maxWidth: .infinity)
        }
    }
}

/// Affiche une page web dans l'application.
struct WebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.load(URLRequest(url: url))
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        if view.url != url { view.load(URLRequest(url: url)) }
    }
}
