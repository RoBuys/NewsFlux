import Foundation
import Observation

/// État central de l'application : flux suivis, articles, lus/non lus.
@MainActor
@Observable
final class FeedStore {
    private(set) var feeds: [Feed] = []
    private(set) var articles: [Article] = []
    private(set) var readIDs: Set<String> = []
    private(set) var errors: [Feed.ID: String] = [:]
    private(set) var isRefreshing = false
    private(set) var lastRefresh: Date?

    private let storageURL: URL

    static let defaultFeeds = [
        Feed(title: "Le Monde – À la une", url: URL(string: "https://www.lemonde.fr/rss/une.xml")!),
        Feed(title: "Hacker News", url: URL(string: "https://hnrss.org/frontpage")!),
        Feed(title: "The Verge", url: URL(string: "https://www.theverge.com/rss/index.xml")!),
        Feed(title: "Apple Newsroom", url: URL(string: "https://www.apple.com/newsroom/rss-feed.rss")!),
    ]

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NewsFlux", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("state.json")
        load()
    }

    // MARK: Requêtes

    func feed(for id: Feed.ID) -> Feed? { feeds.first { $0.id == id } }

    func isRead(_ article: Article) -> Bool { readIDs.contains(article.id) }

    func unreadCount(for item: SidebarItem) -> Int {
        articles(for: item).filter { !isRead($0) }.count
    }

    func articles(for item: SidebarItem, matching query: String = "") -> [Article] {
        let base: [Article] = switch item {
        case .all: articles
        case .unread: articles.filter { !isRead($0) }
        case .feed(let id): articles.filter { $0.feedID == id }
        }
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.summary.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: Actions

    func addFeed(url: URL) async throws {
        let (title, _) = try await Self.fetch(url: url, feedID: UUID())
        let feed = Feed(title: title ?? url.host() ?? url.absoluteString, url: url)
        feeds.append(feed)
        save()
        await refresh()
    }

    func removeFeed(_ id: Feed.ID) {
        feeds.removeAll { $0.id == id }
        articles.removeAll { $0.feedID == id }
        errors[id] = nil
        save()
    }

    func markRead(_ article: Article, _ read: Bool = true) {
        if read { readIDs.insert(article.id) } else { readIDs.remove(article.id) }
        save()
    }

    func markAllRead(in item: SidebarItem) {
        readIDs.formUnion(articles(for: item).map(\.id))
        save()
    }

    /// Recharge tous les flux en parallèle.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let results = await withTaskGroup(of: (Feed.ID, Result<[Article], Error>).self) { group in
            for feed in feeds {
                group.addTask {
                    do { return (feed.id, .success(try await Self.fetch(url: feed.url, feedID: feed.id).1)) }
                    catch { return (feed.id, .failure(error)) }
                }
            }
            var all: [(Feed.ID, Result<[Article], Error>)] = []
            for await result in group { all.append(result) }
            return all
        }

        var merged: [Article] = []
        for (feedID, result) in results {
            switch result {
            case .success(let items):
                merged += items
                errors[feedID] = nil
            case .failure(let error):
                // On garde les articles déjà chargés pour ce flux.
                merged += articles.filter { $0.feedID == feedID }
                errors[feedID] = error.localizedDescription
            }
        }
        articles = merged.sorted { ($0.published ?? .distantPast) > ($1.published ?? .distantPast) }
        lastRefresh = .now
    }

    // MARK: Réseau

    nonisolated private static func fetch(url: URL, feedID: Feed.ID) async throws -> (String?, [Article]) {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("NewsFlux/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        let parsed = try FeedParser.parse(data)
        let articles = parsed.items.map { item in
            Article(
                id: "\(feedID.uuidString)|\(item.guid ?? item.link?.absoluteString ?? item.title)",
                feedID: feedID,
                title: item.title.isEmpty ? "(Sans titre)" : item.title,
                link: item.link,
                summary: item.summary,
                imageURL: item.imageURL,
                published: item.published
            )
        }
        return (parsed.title, articles)
    }

    // MARK: Persistance

    private struct State: Codable {
        var feeds: [Feed]
        var readIDs: Set<String>
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let state = try? JSONDecoder().decode(State.self, from: data) else {
            feeds = Self.defaultFeeds
            return
        }
        feeds = state.feeds
        readIDs = state.readIDs
    }

    private func save() {
        // Ne conserve que les « lus » encore présents pour éviter une croissance infinie.
        let known = Set(articles.map(\.id))
        let pruned = articles.isEmpty ? readIDs : readIDs.intersection(known)
        let state = State(feeds: feeds, readIDs: pruned)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }
}
