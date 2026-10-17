import Foundation

/// Résultat brut de l'analyse d'un flux.
struct ParsedFeed: Sendable {
    var title: String?
    var items: [ParsedItem]
}

struct ParsedItem: Sendable {
    var guid: String?
    var title = ""
    var link: URL?
    var summary = ""
    var imageURL: URL?
    var published: Date?
}

enum FeedParserError: LocalizedError {
    case invalidXML(String)

    var errorDescription: String? {
        switch self {
        case .invalidXML(let reason): "Flux illisible : \(reason)"
        }
    }
}

/// Analyseur RSS 2.0 / Atom basé sur `XMLParser`.
final class FeedParser: NSObject, XMLParserDelegate {
    private var feed = ParsedFeed(title: nil, items: [])
    private var current: ParsedItem?
    private var text = ""
    private var contentHTML = ""

    static func parse(_ data: Data) throws -> ParsedFeed {
        let delegate = FeedParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        guard parser.parse() else {
            throw FeedParserError.invalidXML(parser.parserError?.localizedDescription ?? "erreur inconnue")
        }
        return delegate.feed
    }

    // MARK: XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        text = ""
        switch name {
        case "item", "entry":
            current = ParsedItem()
            contentHTML = ""
        case "link" where current != nil:
            // Atom : <link rel="alternate" href="…"/>
            if let href = attributes["href"], attributes["rel"] ?? "alternate" == "alternate" {
                current?.link = URL(string: href)
            }
        case "media:content", "media:thumbnail", "enclosure":
            let isImage = attributes["medium"] == "image"
                || attributes["type"]?.hasPrefix("image") == true
                || name == "media:thumbnail"
                || (attributes["type"] == nil && attributes["medium"] == nil)
            if isImage, current?.imageURL == nil, let url = attributes["url"].flatMap(URL.init(string:)) {
                current?.imageURL = url
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(decoding: CDATABlock, as: UTF8.self)
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { text = "" }

        guard current != nil else {
            if name == "title", feed.title == nil { feed.title = value }
            return
        }

        switch name {
        case "title":
            current?.title = HTML.plainText(value)
        case "link":
            if current?.link == nil, !value.isEmpty { current?.link = URL(string: value) }
        case "guid", "id":
            current?.guid = value
        case "description", "summary":
            if current?.summary.isEmpty == true { current?.summary = HTML.plainText(value) }
            if contentHTML.isEmpty { contentHTML = value }
        case "content:encoded", "content":
            contentHTML = value
            if current?.summary.isEmpty == true { current?.summary = HTML.plainText(value) }
        case "pubDate", "published", "dc:date", "updated":
            if current?.published == nil { current?.published = DateParser.parse(value) }
        case "item", "entry":
            if var item = current {
                if item.imageURL == nil { item.imageURL = HTML.firstImage(in: contentHTML) }
                feed.items.append(item)
            }
            current = nil
        default:
            break
        }
    }
}

// MARK: - Utilitaires

enum HTML {
    /// Retire les balises et décode les entités les plus courantes.
    static func plainText(_ html: String) -> String {
        var s = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
                        "&#39;": "'", "&apos;": "'", "&rsquo;": "’", "&lsquo;": "‘", "&hellip;": "…",
                        "&laquo;": "«", "&raquo;": "»", "&eacute;": "é", "&egrave;": "è", "&agrave;": "à"]
        for (entity, char) in entities { s = s.replacingOccurrences(of: entity, with: char) }
        s = s.replacingOccurrences(of: "&#(\\d+);", with: "", options: .regularExpression)
        return s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func firstImage(in html: String) -> URL? {
        guard let range = html.range(of: "<img[^>]+src=[\"']([^\"']+)[\"']", options: .regularExpression)
        else { return nil }
        let tag = String(html[range])
        guard let src = tag.range(of: "src=[\"']([^\"']+)", options: .regularExpression) else { return nil }
        let value = tag[src].dropFirst(5)
        return URL(string: String(value))
    }
}

enum DateParser {
    private static let formats = [
        "EEE, dd MMM yyyy HH:mm:ss Z",
        "EEE, dd MMM yyyy HH:mm:ss zzz",
        "EEE, d MMM yyyy HH:mm:ss Z",
        "dd MMM yyyy HH:mm:ss Z",
        "EEE, dd MMM yyyy HH:mm Z",
    ]

    static func parse(_ string: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: string) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: string) { return date }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}
