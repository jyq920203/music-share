import Foundation

struct MusicPlatform: Identifiable, Hashable {
    let id: String
    let name: String
    let iconName: String
    let colorHex: String
    let urlScheme: String
    let universalLinkHost: String?
    let domain: String

    var color: String { colorHex }

    static let spotify = MusicPlatform(
        id: "spotify",
        name: "Spotify",
        iconName: "music.note",
        colorHex: "#1DB954",
        urlScheme: "spotify://",
        universalLinkHost: "open.spotify.com",
        domain: "open.spotify.com"
    )

    static let appleMusic = MusicPlatform(
        id: "appleMusic",
        name: "Apple Music",
        iconName: "apple.logo",
        colorHex: "#FA586A",
        urlScheme: "music://",
        universalLinkHost: nil,
        domain: "music.apple.com"
    )

    static let youtube = MusicPlatform(
        id: "youtube",
        name: "YouTube",
        iconName: "play.rectangle.fill",
        colorHex: "#FF0000",
        urlScheme: "youtube://",
        universalLinkHost: "www.youtube.com",
        domain: "www.youtube.com"
    )

    static let youtubeMusic = MusicPlatform(
        id: "youtubeMusic",
        name: "YouTube Music",
        iconName: "play.circle.fill",
        colorHex: "#FF0000",
        urlScheme: "youtubemusic://",
        universalLinkHost: "music.youtube.com",
        domain: "music.youtube.com"
    )

    static let deezer = MusicPlatform(
        id: "deezer",
        name: "Deezer",
        iconName: "waveform.circle.fill",
        colorHex: "#A238FF",
        urlScheme: "deezer://",
        universalLinkHost: "www.deezer.com",
        domain: "www.deezer.com"
    )

    static let tidal = MusicPlatform(
        id: "tidal",
        name: "Tidal",
        iconName: "waveform",
        colorHex: "#00FFFF",
        urlScheme: "tidal://",
        universalLinkHost: nil,
        domain: "tidal.com"
    )

    static let amazonMusic = MusicPlatform(
        id: "amazonMusic",
        name: "Amazon Music",
        iconName: "a.circle.fill",
        colorHex: "#00A8E1",
        urlScheme: "amazonmusic://",
        universalLinkHost: nil,
        domain: "music.amazon.com"
    )

    static let qqMusic = MusicPlatform(
        id: "qqMusic",
        name: "QQ音乐",
        iconName: "music.quarternote.3",
        colorHex: "#31C27C",
        urlScheme: "qqmusic://",
        universalLinkHost: nil,
        domain: "y.qq.com"
    )

    static let netease = MusicPlatform(
        id: "netease",
        name: "网易云音乐",
        iconName: "music.note.list",
        colorHex: "#C62F2F",
        urlScheme: "orpheus://",
        universalLinkHost: nil,
        domain: "music.163.com"
    )

    static let allPlatforms: [MusicPlatform] = [
        .spotify, .appleMusic, .youtube, .youtubeMusic,
        .deezer, .tidal, .amazonMusic, .qqMusic, .netease
    ]

    static func detectPlatform(from url: URL) -> MusicPlatform? {
        let host = url.host?.lowercased() ?? ""
        for platform in allPlatforms {
            if host.contains(platform.domain) {
                return platform
            }
        }
        return nil
    }
}
