import Foundation

/// Un flux RSS ou Atom suivi par l'utilisateur.
struct Feed: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var title: String
    var url: URL
    /// Page d'accueil du site (sert à trouver son icône).
    var siteURL: URL?
    /// Nom du dossier contenant le flux, `nil` s'il n'est rangé nulle part.
    var folder: String?
    /// Notifier les nouveaux articles de ce flux.
    var notify = false

    init(title: String, url: URL, siteURL: URL? = nil, folder: String? = nil) {
        self.title = title
        self.url = url
        self.siteURL = siteURL
        self.folder = folder
    }

    // Décodage tolérant : les fichiers des versions précédentes n'ont pas tous les champs.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        url = try c.decode(URL.self, forKey: .url)
        siteURL = try c.decodeIfPresent(URL.self, forKey: .siteURL)
        folder = try c.decodeIfPresent(String.self, forKey: .folder)
        notify = try c.decodeIfPresent(Bool.self, forKey: .notify) ?? false
    }
}

/// Un article issu d'un flux.
struct Article: Identifiable, Hashable, Codable, Sendable {
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
    case starred
    case folder(String)
    case feed(Feed.ID)
}
