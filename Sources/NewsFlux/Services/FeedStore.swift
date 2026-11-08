import AppKit
import Foundation
import Observation

/// État central de l'application : flux, dossiers, articles, lus/non lus, favoris, icônes.
@MainActor
@Observable
final class FeedStore {
    private(set) var feeds: [Feed] = []
    private(set) var articles: [Article] = []
    private(set) var readIDs: Set<String> = []
    private(set) var starredIDs: Set<String> = []
    private(set) var icons: [Feed.ID: NSImage] = [:]
    private(set) var errors: [Feed.ID: String] = [:]
    private(set) var isRefreshing = false
    private(set) var lastRefresh: Date?

    /// Les articles plus anciens que cette durée sont oubliés (sauf favoris).
    private static let retention: TimeInterval = 30 * 24 * 3600
    private static let maxArticlesPerFeed = 300
    private static let refreshInterval: Duration = .seconds(15 * 60)

    private let directory: URL
    private var stateURL: URL { directory.appendingPathComponent("state.json") }
    private var articlesURL: URL { directory.appendingPathComponent("articles.json") }
    private var iconsDirectory: URL { directory.appendingPathComponent("icons", isDirectory: true) }
    private var iconAttempts: Set<Feed.ID> = []

    static let defaultFeeds = [
        Feed(title: "Le Monde – À la une", url: URL(string: "https://www.lemonde.fr/rss/une.xml")!,
             siteURL: URL(string: "https://www.lemonde.fr")),
        Feed(title: "Hacker News", url: URL(string: "https://hnrss.org/frontpage")!,
             siteURL: URL(string: "https://news.ycombinator.com")),
        Feed(title: "The Verge", url: URL(string: "https://www.theverge.com/rss/index.xml")!,
             siteURL: URL(string: "https://www.theverge.com")),
        Feed(title: "Apple Newsroom", url: URL(string: "https://www.apple.com/newsroom/rss-feed.rss")!,
             siteURL: URL(string: "https://www.apple.com/newsroom/")),
    ]

    init() {
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NewsFlux", isDirectory: true)
        try? FileManager.default.createDirectory(at: iconsDirectory, withIntermediateDirectories: true)
        load()

        // Actualisation au lancement puis à intervalle régulier, même fenêtre fermée.
        Task { [weak self] in
            while let self {
                await self.refresh()
                try? await Task.sleep(for: Self.refreshInterval)
            }
        }
    }

    // MARK: Requêtes

    func feed(for id: Feed.ID) -> Feed? { feeds.first { $0.id == id } }

    func isRead(_ article: Article) -> Bool { readIDs.contains(article.id) }

    func isStarred(_ article: Article) -> Bool { starredIDs.contains(article.id) }

    /// Noms des dossiers, triés.
    var folders: [String] {
        Set(feeds.compactMap(\.folder)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func feeds(in folder: String?) -> [Feed] { feeds.filter { $0.folder == folder } }

    func unreadCount(for item: SidebarItem) -> Int {
        articles(for: item).filter { !isRead($0) }.count
    }

    var totalUnread: Int { articles.filter { !isRead($0) }.count }

    func articles(for item: SidebarItem, matching query: String = "") -> [Article] {
        let base: [Article] = switch item {
        case .all: articles
        case .unread: articles.filter { !isRead($0) }
        case .starred: articles.filter { isStarred($0) }
        case .folder(let name):
            articles.filter { feed(for: $0.feedID)?.folder == name }
        case .feed(let id): articles.filter { $0.feedID == id }
        }
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.summary.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: Flux et dossiers

    /// Ajoute un flux à partir de son adresse ou de celle du site (le flux est alors recherché dans la page).
    func addFeed(from url: URL, folder: String? = nil) async throws {
        let (feedURL, parsed) = try await FeedDiscovery.discover(from: url)
        if feeds.contains(where: { $0.url == feedURL }) { throw FeedDiscovery.Failure.alreadySubscribed }
        let feed = Feed(title: parsed.title ?? feedURL.host() ?? feedURL.absoluteString, url: feedURL,
                        siteURL: parsed.siteURL ?? url, folder: folder)
        feeds.append(feed)
        merge(Self.articles(from: parsed, feedID: feed.id), into: feed.id)
        saveState()
        saveArticles()
        await loadMissingIcons()
    }

    func removeFeed(_ id: Feed.ID) {
        feeds.removeAll { $0.id == id }
        articles.removeAll { $0.feedID == id }
        errors[id] = nil
        icons[id] = nil
        try? FileManager.default.removeItem(at: iconFile(for: id))
        saveState()
        saveArticles()
    }

    func move(_ feedID: Feed.ID, to folder: String?) {
        updateFeed(feedID) { $0.folder = folder?.trimmingCharacters(in: .whitespaces).nilIfEmpty }
    }

    func renameFolder(_ name: String, to newName: String) {
        let newName = newName.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty else { return }
        for index in feeds.indices where feeds[index].folder == name { feeds[index].folder = newName }
        saveState()
    }

    /// Supprime le dossier ; ses flux sont conservés, hors dossier.
    func deleteFolder(_ name: String) {
        for index in feeds.indices where feeds[index].folder == name { feeds[index].folder = nil }
        saveState()
    }

    func setNotifications(_ enabled: Bool, for feedID: Feed.ID) async {
        if enabled { _ = await Notifier.requestAuthorization() }
        updateFeed(feedID) { $0.notify = enabled }
    }

    private func updateFeed(_ id: Feed.ID, _ change: (inout Feed) -> Void) {
        guard let index = feeds.firstIndex(where: { $0.id == id }) else { return }
        change(&feeds[index])
        saveState()
    }

    // MARK: Lu / favoris

    func markRead(_ article: Article, _ read: Bool = true) {
        if read { readIDs.insert(article.id) } else { readIDs.remove(article.id) }
        saveState()
    }

    func markAllRead(in item: SidebarItem) {
        readIDs.formUnion(articles(for: item).map(\.id))
        saveState()
    }

    func toggleStar(_ article: Article) {
        if starredIDs.contains(article.id) { starredIDs.remove(article.id) } else { starredIDs.insert(article.id) }
        saveState()
    }

    // MARK: Actualisation

    /// Recharge tous les flux en parallèle.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let results = await withTaskGroup(of: (Feed.ID, Result<ParsedFeed, Error>).self) { group in
            for feed in feeds {
                group.addTask {
                    do { return (feed.id, .success(try await FeedDiscovery.parse(feed.url))) }
                    catch { return (feed.id, .failure(error)) }
                }
            }
            var all: [(Feed.ID, Result<ParsedFeed, Error>)] = []
            for await result in group { all.append(result) }
            return all
        }

        for (feedID, result) in results {
            guard let feed = feed(for: feedID) else { continue }
            switch result {
            case .success(let parsed):
                errors[feedID] = nil
                if feed.siteURL == nil, let site = parsed.siteURL { updateFeed(feedID) { $0.siteURL = site } }
                let newArticles = merge(Self.articles(from: parsed, feedID: feedID), into: feedID)
                if feed.notify { Notifier.notify(feed: feed, articles: newArticles) }
            case .failure(let error):
                // On garde les articles déjà enregistrés pour ce flux.
                errors[feedID] = error.localizedDescription
            }
        }
        lastRefresh = .now
        saveArticles()
        saveState()
        await loadMissingIcons()
    }

    /// Fusionne les articles reçus avec ceux déjà enregistrés et renvoie les nouveaux non lus.
    @discardableResult
    private func merge(_ fresh: [Article], into feedID: Feed.ID) -> [Article] {
        let previous = articles.filter { $0.feedID == feedID }
        let previousIDs = Set(previous.map(\.id))
        let freshIDs = Set(fresh.map(\.id))
        let cutoff = Date.now.addingTimeInterval(-Self.retention)

        // Articles disparus du flux : conservés s'ils sont en favoris ou encore récents.
        let kept = previous.filter {
            !freshIDs.contains($0.id) && (starredIDs.contains($0.id) || ($0.published ?? .distantPast) > cutoff)
        }
        let combined = (fresh + kept)
            .sorted { ($0.published ?? .distantPast) > ($1.published ?? .distantPast) }
        let limited = combined.enumerated()
            .filter { $0.offset < Self.maxArticlesPerFeed || starredIDs.contains($0.element.id) }
            .map(\.element)

        articles = (articles.filter { $0.feedID != feedID } + limited)
            .sorted { ($0.published ?? .distantPast) > ($1.published ?? .distantPast) }

        // Au tout premier chargement d'un flux, rien n'est « nouveau ».
        guard !previous.isEmpty else { return [] }
        return fresh.filter { !previousIDs.contains($0.id) && !readIDs.contains($0.id) }
    }

    private static func articles(from parsed: ParsedFeed, feedID: Feed.ID) -> [Article] {
        parsed.items.map { item in
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
    }

    // MARK: Icônes des sites

    private func iconFile(for id: Feed.ID) -> URL {
        iconsDirectory.appendingPathComponent("\(id.uuidString).img")
    }

    private func loadMissingIcons() async {
        let missing = feeds.filter { icons[$0.id] == nil && !iconAttempts.contains($0.id) }
        iconAttempts.formUnion(missing.map(\.id))
        await withTaskGroup(of: (Feed.ID, Data?).self) { group in
            for feed in missing {
                let site = feed.siteURL ?? feed.url
                group.addTask { (feed.id, await IconLoader.fetchIcon(for: site)) }
            }
            for await (id, data) in group {
                guard let data, let image = NSImage(data: data) else { continue }
                icons[id] = image
                try? data.write(to: iconFile(for: id), options: .atomic)
            }
        }
    }

    // MARK: Persistance

    private struct State: Codable {
        var feeds: [Feed]
        var readIDs: Set<String>
        var starredIDs: Set<String>?
    }

    private func load() {
        if let data = try? Data(contentsOf: stateURL),
           let state = try? JSONDecoder().decode(State.self, from: data) {
            feeds = state.feeds
            readIDs = state.readIDs
            starredIDs = state.starredIDs ?? []
        } else {
            feeds = Self.defaultFeeds
        }
        if let data = try? Data(contentsOf: articlesURL),
           let saved = try? JSONDecoder().decode([Article].self, from: data) {
            let known = Set(feeds.map(\.id))
            articles = saved.filter { known.contains($0.feedID) }
        }
        for feed in feeds {
            if let data = try? Data(contentsOf: iconFile(for: feed.id)), let image = NSImage(data: data) {
                icons[feed.id] = image
            }
        }
    }

    private func saveState() {
        // Ne conserve que les identifiants d'articles encore connus.
        let known = Set(articles.map(\.id))
        let read = articles.isEmpty ? readIDs : readIDs.intersection(known)
        let starred = articles.isEmpty ? starredIDs : starredIDs.intersection(known)
        let state = State(feeds: feeds, readIDs: read, starredIDs: starred)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: stateURL, options: .atomic)
        }
    }

    private func saveArticles() {
        if let data = try? JSONEncoder().encode(articles) {
            try? data.write(to: articlesURL, options: .atomic)
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
