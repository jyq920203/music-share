import Foundation

struct MusicLink: Identifiable {
    let id = UUID()
    let platform: MusicPlatform
    let url: URL
    let originalURL: URL?

    init(platform: MusicPlatform, url: URL, originalURL: URL?) {
        self.platform = platform
        self.url = url
        self.originalURL = originalURL
    }
}

struct SongLinkResponse: Codable {
    let entityUniqueId: String?
    let linksByPlatform: [String: PlatformLink]
    let entitiesByUniqueId: [String: Entity]

    enum CodingKeys: String, CodingKey {
        case entityUniqueId
        case linksByPlatform
        case entitiesByUniqueId
    }
}

struct PlatformLink: Codable {
    let url: String
    let nativeAppUriMobile: String?
    let nativeAppUriDesktop: String?
    let entityUniqueId: String
}

struct Entity: Codable {
    let id: String?
    let type: String?
    let title: String?
    let artistName: String?
    let thumbnailUrl: String?
    let thumbnailWidth: Int?
    let thumbnailHeight: Int?
    let apiProvider: String?
    let platforms: [String]?
}

struct SearchResult {
    let href: String
    let thumbnail: String?
    let title: String?
    let artistName: String?
    let platformName: String?
}
