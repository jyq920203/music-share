import Foundation

final class MusicLinkService {
    static let shared = MusicLinkService()

    private let songLinkBaseURL = "https://api.song.link/v1-alpha.1/links"
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private init() {}

    func convertLink(_ url: URL) async throws -> [MusicLink] {
        let trimmed = trimURL(url)
        let sourcePlatform = MusicPlatform.detectPlatform(from: trimmed)

        if sourcePlatform?.id == "qqMusic" {
            return try await convertFromQQMusic(trimmed)
        }
        if sourcePlatform?.id == "netease" {
            return try await convertFromNetEase(trimmed)
        }

        return try await convertViaSongLink(trimmed, sourcePlatform: sourcePlatform)
    }

    private func convertViaSongLink(_ url: URL, sourcePlatform: MusicPlatform?) async throws -> [MusicLink] {
        let apiURL = buildSongLinkURL(for: url)

        var request = URLRequest(url: apiURL)
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }

        if httpResponse.statusCode == 404 || httpResponse.statusCode == 400 {
            let query = extractSearchQuery(from: url)
            guard !query.isEmpty else { throw ServiceError.cannotResolve }
            return try await searchAllPlatforms(query: query, originalURL: url, sourcePlatform: sourcePlatform)
        }

        guard httpResponse.statusCode == 200 else {
            throw ServiceError.serverError(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(SongLinkResponse.self, from: data)
        let internationalLinks = extractInternationalLinks(from: decoded, originalURL: url, sourcePlatform: sourcePlatform)

        var songTitle: String?
        var artistName: String?
        if let entityId = decoded.entityUniqueId,
           let entity = decoded.entitiesByUniqueId[entityId] {
            songTitle = entity.title
            artistName = entity.artistName
        }

        let searchQuery: String
        if let t = songTitle, let a = artistName, !t.isEmpty {
            searchQuery = "\(t) \(a)"
        } else {
            searchQuery = extractSearchQuery(from: url)
        }

        async let chineseLinks = searchChineseMusic(searchQuery, originalURL: url)
        let chinese = (try? await chineseLinks) ?? []

        var allLinks = internationalLinks + chinese

        allLinks.removeAll { link in
            sourcePlatform != nil && link.platform.id == sourcePlatform!.id
        }

        let remainingPlatforms = Set(allLinks.map(\.platform.id))
        let missing = MusicPlatform.allPlatforms.filter {
            $0.id != sourcePlatform?.id
            && $0.id != "qqMusic"
            && $0.id != "netease"
            && !remainingPlatforms.contains($0.id)
        }

        let fallbackLinks = missing.map { platform in
            MusicLink(platform: platform, url: buildPlatformSearchURL(platform: platform, query: searchQuery), originalURL: url)
        }

        allLinks.append(contentsOf: fallbackLinks)

        allLinks.sort { a, b in
            let orderA = MusicPlatform.allPlatforms.firstIndex(where: { $0.id == a.platform.id }) ?? 99
            let orderB = MusicPlatform.allPlatforms.firstIndex(where: { $0.id == b.platform.id }) ?? 99
            return orderA < orderB
        }

        if allLinks.isEmpty { throw ServiceError.cannotResolve }

        return allLinks
    }

    private func convertFromQQMusic(_ url: URL) async throws -> [MusicLink] {
        guard let songId = extractQQSongID(from: url) else {
            throw ServiceError.invalidURL
        }

        let songInfo = try await getQQMusicSongInfo(songId: songId)
        let query = "\(songInfo.title) \(songInfo.artist)"
        return try await searchAllPlatforms(query: query, originalURL: url, sourcePlatform: .qqMusic)
    }

    private func convertFromNetEase(_ url: URL) async throws -> [MusicLink] {
        guard let songId = extractNetEaseSongID(from: url) else {
            throw ServiceError.invalidURL
        }

        let songInfo = try await getNetEaseSongInfo(songId: songId)
        let query = "\(songInfo.title) \(songInfo.artist)"
        return try await searchAllPlatforms(query: query, originalURL: url, sourcePlatform: .netease)
    }

    private func searchAllPlatforms(query: String, originalURL: URL, sourcePlatform: MusicPlatform?) async throws -> [MusicLink] {
        async let songLinkResult = trySearchViaSongLink(query, originalURL: originalURL, sourcePlatform: sourcePlatform)
        async let chineseResult = searchChineseMusic(query, originalURL: originalURL)

        let international = (try? await songLinkResult) ?? []
        let chinese = (try? await chineseResult) ?? []

        let coveredPlatforms = Set(international.map(\.platform.id))
        let uncovered = MusicPlatform.allPlatforms.filter {
            $0.id != sourcePlatform?.id
            && $0.id != "qqMusic"
            && $0.id != "netease"
            && !coveredPlatforms.contains($0.id)
        }

        let fallbackLinks = uncovered.map { platform in
            MusicLink(platform: platform, url: buildPlatformSearchURL(platform: platform, query: query), originalURL: originalURL)
        }

        var allLinks = international + chinese + fallbackLinks

        allLinks.sort { a, b in
            let orderA = MusicPlatform.allPlatforms.firstIndex(where: { $0.id == a.platform.id }) ?? 99
            let orderB = MusicPlatform.allPlatforms.firstIndex(where: { $0.id == b.platform.id }) ?? 99
            return orderA < orderB
        }

        if allLinks.isEmpty { throw ServiceError.cannotResolve }
        return allLinks
    }

    private func trySearchViaSongLink(_ query: String, originalURL: URL, sourcePlatform: MusicPlatform?) async throws -> [MusicLink] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let encodedURL = "https://example.com/\(encodedQuery)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        guard let apiURL = URL(string: "\(songLinkBaseURL)?url=\(encodedURL)&songIfSingle=true") else {
            return []
        }

        var request = URLRequest(url: apiURL)
        request.timeoutInterval = 10

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return [] }

            let decoded = try JSONDecoder().decode(SongLinkResponse.self, from: data)
            return extractInternationalLinks(from: decoded, originalURL: originalURL, sourcePlatform: sourcePlatform)
        } catch {
            return []
        }
    }

    private func extractInternationalLinks(from response: SongLinkResponse, originalURL: URL, sourcePlatform: MusicPlatform?) -> [MusicLink] {
        let platformMap: [String: MusicPlatform] = [
            "spotify": .spotify,
            "appleMusic": .appleMusic,
            "youtube": .youtube,
            "youtubeMusic": .youtubeMusic,
            "deezer": .deezer,
            "tidal": .tidal,
            "amazonMusic": .amazonMusic
        ]

        var links: [MusicLink] = []
        for (key, platformLink) in response.linksByPlatform {
            guard let platform = platformMap[key],
                  let linkURL = URL(string: platformLink.url) else { continue }
            if sourcePlatform != nil && platform.id == sourcePlatform!.id { continue }
            links.append(MusicLink(platform: platform, url: linkURL, originalURL: originalURL))
        }
        return links
    }

    private func getQQMusicSongInfo(songId: String) async throws -> SongInfo {
        let body: [String: Any] = [
            "songinfo": [
                "module": "music.pf_song_detail_svr",
                "method": "get_song_detail",
                "param": ["song_id": Int(songId) ?? 0]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body),
              let jsonParam = String(data: jsonData, encoding: .utf8)?
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://u.y.qq.com/cgi-bin/musicu.fcg?format=json&data=\(jsonParam)") else {
            throw ServiceError.invalidResponse
        }

        let (data, _) = try await session.data(from: url)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let songInfo = json["songinfo"] as? [String: Any],
              let infoData = songInfo["data"] as? [String: Any],
              let trackInfo = infoData["track_info"] as? [String: Any],
              let title = trackInfo["name"] as? String else {
            throw ServiceError.cannotResolve
        }

        let artist: String
        if let singers = trackInfo["singer"] as? [[String: Any]],
           let firstName = singers.first?["name"] as? String {
            artist = firstName
        } else {
            artist = ""
        }

        return SongInfo(title: title, artist: artist)
    }

    private func getNetEaseSongInfo(songId: String) async throws -> SongInfo {
        guard let url = URL(string: "https://music.163.com/api/song/detail?ids=%5B\(songId)%5D") else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let songs = json["songs"] as? [[String: Any]],
              let first = songs.first,
              let title = first["name"] as? String else {
            throw ServiceError.cannotResolve
        }

        let artist: String
        if let artists = first["artists"] as? [[String: Any]],
           let firstName = artists.first?["name"] as? String {
            artist = firstName
        } else {
            artist = ""
        }

        return SongInfo(title: title, artist: artist)
    }

    private func searchChineseMusic(_ query: String, originalURL: URL) async throws -> [MusicLink] {
        guard !query.isEmpty else { return [] }

        async let qqResult = searchQQMusic(query, originalURL: originalURL)
        async let neteaseResult = searchNetEaseMusic(query, originalURL: originalURL)

        return [try? await qqResult, try? await neteaseResult].compactMap { $0 }
    }

    private func searchQQMusic(_ query: String, originalURL: URL) async throws -> MusicLink? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let searchURL = URL(string: "https://c.y.qq.com/soso/fcgi-bin/client_search_cp?format=json&w=\(encoded)&n=1") else {
            return nil
        }

        let (data, _) = try await session.data(from: searchURL)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataDict = json["data"] as? [String: Any],
              let song = dataDict["song"] as? [String: Any],
              let list = song["list"] as? [[String: Any]],
              let first = list.first else {
            return nil
        }

        let songId: String
        if let idInt = first["songid"] as? Int {
            songId = String(idInt)
        } else if let idStr = first["songid"] as? String {
            songId = idStr
        } else {
            return nil
        }

        guard let url = URL(string: "https://y.qq.com/n/ryqq/songDetail/\(songId)") else {
            return nil
        }

        return MusicLink(platform: .qqMusic, url: url, originalURL: originalURL)
    }

    private func searchNetEaseMusic(_ query: String, originalURL: URL) async throws -> MusicLink? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let searchURL = URL(string: "https://music.163.com/api/search/get?s=\(encoded)&type=1&limit=1") else {
            return nil
        }

        var request = URLRequest(url: searchURL)
        request.timeoutInterval = 10
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let songs = result["songs"] as? [[String: Any]],
              let first = songs.first else {
            return nil
        }

        let songId: String
        if let idInt = first["id"] as? Int {
            songId = String(idInt)
        } else if let idStr = first["id"] as? String {
            songId = idStr
        } else {
            return nil
        }

        guard let url = URL(string: "https://music.163.com/song?id=\(songId)") else {
            return nil
        }

        return MusicLink(platform: .netease, url: url, originalURL: originalURL)
    }

    private func buildPlatformSearchURL(platform: MusicPlatform, query: String) -> URL {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        let searchPaths: [String: String] = [
            "spotify": "https://open.spotify.com/search/\(encoded)",
            "appleMusic": "https://music.apple.com/search?term=\(encoded)",
            "youtube": "https://www.youtube.com/results?search_query=\(encoded)",
            "youtubeMusic": "https://music.youtube.com/search?q=\(encoded)",
            "deezer": "https://www.deezer.com/search/\(encoded)",
            "tidal": "https://tidal.com/search?q=\(encoded)",
            "amazonMusic": "https://music.amazon.com/search/\(encoded)"
        ]

        if let path = searchPaths[platform.id] {
            return URL(string: path) ?? URL(string: "https://\(platform.domain)")!
        }
        return URL(string: "https://\(platform.domain)")!
    }

    private func buildSongLinkURL(for url: URL) -> URL {
        let encoded = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "\(songLinkBaseURL)?url=\(encoded)")!
    }

    private func extractQQSongID(from url: URL) -> String? {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let songId = queryItems.first(where: { $0.name == "songid" })?.value,
           !songId.isEmpty {
            return songId
        }

        let pathComponents = url.pathComponents
        if let last = pathComponents.last, last.allSatisfy({ $0.isNumber }), !last.isEmpty {
            return last
        }
        if let idx = pathComponents.lastIndex(where: { $0 == "songDetail" }),
           idx + 1 < pathComponents.count {
            return pathComponents[idx + 1]
        }
        return nil
    }

    private func extractNetEaseSongID(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        return queryItems.first(where: { $0.name == "id" })?.value
    }

    private func trimURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        let removeParams = ["si", "utm_source", "utm_medium", "utm_campaign", "feature", "ref", "referrer", "source", "at", "ct", "itscg", "itsct", "ls", "mt", "app"]
        components.queryItems = components.queryItems?.filter { item in
            !removeParams.contains(item.name)
        }
        return components.url ?? url
    }

    private func extractSearchQuery(from url: URL) -> String {
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        let knownWords = ["track", "album", "song", "playlist", "artist", "n", "ryqq", "detail", "songDetail", "search", "results", "watch", "m", "s", "cn"]

        let candidates = pathComponents.filter { component in
            let decoded = component.removingPercentEncoding ?? component
            guard !decoded.isEmpty,
                  !decoded.allSatisfy({ $0.isNumber }),
                  !knownWords.contains(decoded.lowercased()),
                  decoded.count > 1 else { return false }
            return true
        }

        let query = candidates
            .map { ($0.removingPercentEncoding ?? $0).replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ") }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        if !query.isEmpty { return query }

        let fallback = (url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent)
            .replacingOccurrences(of: "-", with: " ")
        let numbersStripped = fallback.components(separatedBy: CharacterSet.decimalDigits).joined()
        return numbersStripped.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Supporting Types

struct SongInfo {
    let title: String
    let artist: String
}

enum ServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case cannotResolve

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的链接"
        case .invalidResponse: return "服务器响应异常"
        case .serverError(let code): return "服务器错误 (\(code))"
        case .cannotResolve: return "无法解析该音乐链接"
        }
    }
}
