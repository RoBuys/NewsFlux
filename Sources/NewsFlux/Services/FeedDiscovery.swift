import AppKit
import Foundation

/// Téléchargement des flux et recherche d'un flux à partir de l'adresse d'un site.
enum FeedDiscovery {
    enum Failure: LocalizedError {
        case noFeedFound
        case alreadySubscribed

        var errorDescription: String? {
            switch self {
            case .noFeedFound: "Aucun flux RSS ou Atom trouvé à cette adresse."
            case .alreadySubscribed: "Vous suivez déjà ce flux."
            }
        }
    }

    /// Chemins courants essayés quand la page n'annonce aucun flux.
    private static let commonPaths = ["/feed", "/rss", "/feed.xml", "/rss.xml", "/atom.xml", "/index.xml"]

    /// Télécharge et analyse un flux connu.
    static func parse(_ url: URL) async throws -> ParsedFeed {
        let parsed = try FeedParser.parse(try await download(url))
        guard parsed.isFeed else { throw Failure.noFeedFound }
        return parsed
    }

    /// Renvoie l'adresse du flux et son contenu, que `url` soit un flux ou une page web.
    static func discover(from url: URL) async throws -> (URL, ParsedFeed) {
        let data = try await download(url)
        if let parsed = try? FeedParser.parse(data), parsed.isFeed { return (url, parsed) }

        let html = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        var candidates = HTML.feedLinks(in: html, base: url)
        candidates += commonPaths.compactMap { URL(string: $0, relativeTo: url)?.absoluteURL }

        var seen = Set<URL>()
        for candidate in candidates where seen.insert(candidate).inserted {
            if let parsed = try? await parse(candidate) { return (candidate, parsed) }
        }
        throw Failure.noFeedFound
    }

    static func download(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("NewsFlux/1.1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

/// Récupère l'icône d'un site : celle annoncée dans sa page d'accueil, sinon /favicon.ico.
enum IconLoader {
    static func fetchIcon(for site: URL) async -> Data? {
        guard let scheme = site.scheme, let host = site.host(),
              let home = URL(string: "\(scheme)://\(host)/") else { return nil }

        var candidates: [URL] = []
        if let data = try? await FeedDiscovery.download(home) {
            let html = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            if let icon = HTML.iconLink(in: html, base: home) { candidates.append(icon) }
        }
        candidates.append(home.appendingPathComponent("favicon.ico"))

        for url in candidates {
            if let data = try? await FeedDiscovery.download(url), NSImage(data: data) != nil {
                return data
            }
        }
        return nil
    }
}
