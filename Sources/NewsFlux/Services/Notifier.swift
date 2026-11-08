import Foundation
import UserNotifications

/// Notifications des nouveaux articles.
enum Notifier {
    /// Les notifications exigent une vraie .app (indisponibles avec `swift run`).
    static var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    static func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        let options: UNAuthorizationOptions = [.alert, .sound]
        return (try? await UNUserNotificationCenter.current().requestAuthorization(options: options)) ?? false
    }

    /// Une notification par article, ou une seule notification groupée au-delà de trois.
    static func notify(feed: Feed, articles: [Article]) {
        guard isAvailable, !articles.isEmpty else { return }
        if articles.count <= 3 {
            for article in articles {
                post(title: feed.title, body: article.title, feed: feed, link: article.link)
            }
        } else {
            let titles = articles.prefix(3).map { "• \($0.title)" }.joined(separator: "\n")
            post(title: feed.title, body: "\(articles.count) nouveaux articles\n\(titles)", feed: feed, link: nil)
        }
    }

    private static func post(title: String, body: String, feed: Feed, link: URL?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = feed.id.uuidString
        if let link { content.userInfo = ["link": link.absoluteString] }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
