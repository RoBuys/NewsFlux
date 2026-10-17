import Foundation

/// Un flux RSS ou Atom suivi par l'utilisateur.
struct Feed: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var title: String
    var url: URL
}

/// Un article issu d'un flux.
struct Article: Identifiable, Hashable, Sendable {
    /// Identifiant stable : identifiant du flux + guid (ou lien) de l'article.
    let id: String
    let feedID: Feed.ID
    let title: String
    let link: URL?
    let summary: String
    let imageURL: URL?
    let published: Date?
}

/// Élément sélectionné dans la barre latérale.
enum SidebarItem: Hashable {
    case all
    case unread
    case feed(Feed.ID)
}
