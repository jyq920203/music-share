import Foundation

// MARK: - Strategy Protocol

protocol ConversionStrategy {
    func convert(_ url: URL, service: MusicLinkService) async throws -> [MusicLink]
}

// MARK: - Service

final class MusicLinkService {
    static let shared = MusicLinkService()

    let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private let songLinkBaseURL = "https://api.song.link/v1-alpha.1/links"

    private let strategies: [String: ConversionStrategy] = [
        "qqMusic": QQMusicStrategy(),
        "netease": NetEaseStrategy(),
    ]

    private let defaultStrategy = SongLinkStrategy()

    private init() {}

    func convertLink(_ url: URL) async throws -> [MusicLink] {
        let trimmed = trimURL(url)
        let sourcePlatform = MusicPlatform.detectPlatform(from: trimmed)

        guard isValidMusicURL(trimmed) else {
            throw ServiceError.notAMusicLink
        }

        let strategy = sourcePlatform.flatMap { strategies[$0.id] } ?? defaultStrategy
        let links = try await strategy.convert(trimmed, service: self)

        var result = links
        result.removeAll { $0.platform.id == sourcePlatform?.id }
        result.sort { a, b in
            (MusicPlatform.allPlatforms.firstIndex(where: { $0.id == a.platform.id }) ?? 99)
                < (MusicPlatform.allPlatforms.firstIndex(where: { $0.id == b.platform.id }) ?? 99)
        }

        if result.isEmpty { throw ServiceError.cannotResolve }
        return result
    }

    // MARK: - Strategy Delegates

    func songLinkResolve(_ url: URL) async throws -> SongLinkPayload {
        let apiURL = buildSongLinkURL(for: url)
        var request = URLRequest(url: apiURL)
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
        guard http.statusCode == 200 else { throw ServiceError.cannotResolve }

        let decoded = try JSONDecoder().decode(SongLinkResponse.self, from: data)
        let links = extractInternationalLinks(from: decoded)

        var title: String?
        var artist: String?
        if let eid = decoded.entityUniqueId,
           let entity = decoded.entitiesByUniqueId[eid] {
            title = entity.title
            artist = entity.artistName
        }

        let searchQuery: String?
        if let t = title, let a = artist { searchQuery = "\(t) \(a)" }
        else { searchQuery = nil }

        return SongLinkPayload(links: links, searchQuery: searchQuery)
    }

    func searchChineseDirectLinks(_ query: String, skip: String?) async -> [MusicLink] {
        var results: [MusicLink] = []
        if skip != "qqMusic", let link = try? await searchQQMusic(query) {
            results.append(link)
        }
        if skip != "netease", let link = try? await searchNetEaseMusic(query) {
            results.append(link)
        }
        return results
    }

    func buildSearchLinks(for platforms: [MusicPlatform], query: String) -> [MusicLink] {
        platforms.map { platform in
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let url = Self.searchURLMap[platform.id, default: "https://\(platform.domain)"]
            let expanded = url.replacingOccurrences(of: "{q}", with: encoded)
            return MusicLink(platform: platform, url: URL(string: expanded) ?? URL(string: "https://\(platform.domain)")!, originalURL: nil)
        }
    }

    // MARK: - Internal Helpers

    private func extractInternationalLinks(from response: SongLinkResponse) -> [MusicLink] {
        let map: [String: MusicPlatform] = [
            "spotify": .spotify, "appleMusic": .appleMusic, "youtube": .youtube,
            "youtubeMusic": .youtubeMusic, "deezer": .deezer, "tidal": .tidal,
            "amazonMusic": .amazonMusic
        ]
        return response.linksByPlatform.compactMap { key, link in
            guard let platform = map[key],
                  let url = URL(string: link.url) else { return nil }
            return MusicLink(platform: platform, url: url, originalURL: nil)
        }
    }

    private func buildSongLinkURL(for url: URL) -> URL {
        let encoded = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "\(songLinkBaseURL)?url=\(encoded)")!
    }

    // MARK: - QQ Music

    func getQQMusicSongInfo(songId: String) async throws -> SongInfo {
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
        let artist = (trackInfo["singer"] as? [[String: Any]])?.first?["name"] as? String ?? ""
        return SongInfo(title: title, artist: artist)
    }

    func extractQQSongID(from url: URL) -> String? {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let id = components.queryItems?.first(where: { $0.name == "songid" })?.value,
           !id.isEmpty { return id }
        let parts = url.pathComponents
        if let last = parts.last, last.allSatisfy(\.isNumber), !last.isEmpty { return last }
        if let idx = parts.lastIndex(of: "songDetail"), idx + 1 < parts.count { return parts[idx + 1] }
        return nil
    }

    private func searchQQMusic(_ query: String) async throws -> MusicLink? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://c.y.qq.com/soso/fcgi-bin/client_search_cp?format=json&w=\(encoded)&n=1") else { return nil }
        let (data, _) = try await session.data(from: url)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataDict = json["data"] as? [String: Any],
              let song = dataDict["song"] as? [String: Any],
              let list = song["list"] as? [[String: Any]],
              let first = list.first else { return nil }
        let songId: String
        if let v = first["songid"] as? Int { songId = String(v) }
        else if let v = first["songid"] as? String { songId = v }
        else { return nil }
        guard let detailURL = URL(string: "https://y.qq.com/n/ryqq/songDetail/\(songId)") else { return nil }
        return MusicLink(platform: .qqMusic, url: detailURL, originalURL: nil)
    }

    // MARK: - NetEase

    func getNetEaseSongInfo(songId: String) async throws -> SongInfo {
        guard let url = URL(string: "https://music.163.com/api/song/detail?ids=%5B\(songId)%5D") else {
            throw ServiceError.invalidURL
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        req.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let songs = json["songs"] as? [[String: Any]],
              let first = songs.first,
              let title = first["name"] as? String else { throw ServiceError.cannotResolve }
        let artist = (first["artists"] as? [[String: Any]])?.first?["name"] as? String ?? ""
        return SongInfo(title: title, artist: artist)
    }

    func extractNetEaseSongID(from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "id" })?.value
    }

    private func searchNetEaseMusic(_ query: String) async throws -> MusicLink? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://music.163.com/api/search/get?s=\(encoded)&type=1&limit=1") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        req.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let songs = result["songs"] as? [[String: Any]],
              let first = songs.first else { return nil }
        let id: String
        if let v = first["id"] as? Int { id = String(v) }
        else if let v = first["id"] as? String { id = v }
        else { return nil }
        guard let detailURL = URL(string: "https://music.163.com/song?id=\(id)") else { return nil }
        return MusicLink(platform: .netease, url: detailURL, originalURL: nil)
    }

    // MARK: - URL Utils

    static let searchURLMap: [String: String] = [
        "spotify": "https://open.spotify.com/search/{q}",
        "appleMusic": "https://music.apple.com/search?term={q}",
        "youtube": "https://www.youtube.com/results?search_query={q}",
        "youtubeMusic": "https://music.youtube.com/search?q={q}",
        "deezer": "https://www.deezer.com/search/{q}",
        "tidal": "https://tidal.com/search?q={q}",
        "amazonMusic": "https://music.amazon.com/search/{q}",
    ]

    func isValidMusicURL(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        let idPlatforms = ["music.163.com", "y.qq.com"]
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let qi = components.queryItems {
            if qi.contains(where: { $0.name == "id" }), idPlatforms.contains(where: host.contains) { return true }
            if qi.contains(where: { $0.name == "i" }) { return true }
        }
        let hasTrack = path.contains("/track/") || path.contains("songdetail")
        let hasWatch = path.contains("/watch")
        if host.contains("open.spotify.com") || host.contains("y.qq.com") { return hasTrack }
        if host.contains("youtube.com") { return hasWatch }
        if host.contains("deezer.com") || host.contains("tidal.com") { return hasTrack }
        return ["music.apple.com", "music.amazon.com", "music.youtube.com", "music.163.com"].contains(where: host.contains)
    }

    func trimURL(_ url: URL) -> URL {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        let strip = ["si","utm_source","utm_medium","utm_campaign","feature","ref","referrer","source","at","ct","itscg","itsct","ls","mt","app"]
        comps.queryItems = comps.queryItems?.filter { !strip.contains($0.name) }
        return comps.url ?? url
    }
}

// MARK: - SongLink Strategy

private struct SongLinkStrategy: ConversionStrategy {
    func convert(_ url: URL, service: MusicLinkService) async throws -> [MusicLink] {
        let payload = try await service.songLinkResolve(url)
        let internationalLinks = payload.links
        var covered = Set(internationalLinks.map(\.platform.id))

        let query = payload.searchQuery ?? MusicLinkService.extractSearchQueryStatic(from: url)

        // Fill QQ/NetEase
        let chinese = await service.searchChineseDirectLinks(query, skip: nil)
        covered.formUnion(chinese.map(\.platform.id))
        var all = internationalLinks + chinese

        // Fill missing international with search
        let uncovered = MusicPlatform.allPlatforms.filter {
            $0.id != "qqMusic" && $0.id != "netease" && !covered.contains($0.id)
        }
        all += service.buildSearchLinks(for: uncovered, query: query)

        return all
    }
}

// MARK: - QQ Music Strategy

private struct QQMusicStrategy: ConversionStrategy {
    func convert(_ url: URL, service: MusicLinkService) async throws -> [MusicLink] {
        guard let songId = service.extractQQSongID(from: url) else {
            throw ServiceError.invalidURL
        }

        // Try Song.Link first with normalized URL (it rarely works but worth a shot)
        let normalized = URL(string: "https://y.qq.com/n/ryqq/songDetail/\(songId)") ?? url
        if let payload = try? await service.songLinkResolve(normalized), !payload.links.isEmpty {
            return await fillMissing(international: payload.links, query: payload.searchQuery, skip: "qqMusic", service: service)
        }

        // Fallback: get song info from QQ API
        let info = try await service.getQQMusicSongInfo(songId: songId)
        let query = "\(info.title) \(info.artist)"
        return await fillMissing(international: [], query: query, skip: "qqMusic", service: service)
    }
}

// MARK: - NetEase Strategy

private struct NetEaseStrategy: ConversionStrategy {
    func convert(_ url: URL, service: MusicLinkService) async throws -> [MusicLink] {
        guard let songId = service.extractNetEaseSongID(from: url) else {
            throw ServiceError.invalidURL
        }

        if let payload = try? await service.songLinkResolve(url), !payload.links.isEmpty {
            return await fillMissing(international: payload.links, query: payload.searchQuery, skip: "netease", service: service)
        }

        let info = try await service.getNetEaseSongInfo(songId: songId)
        let query = "\(info.title) \(info.artist)"
        return await fillMissing(international: [], query: query, skip: "netease", service: service)
    }
}

// MARK: - Shared Strategy Helpers

private func fillMissing(international: [MusicLink], query: String?, skip: String, service: MusicLinkService) async -> [MusicLink] {
    let q = query ?? ""
    var covered = Set(international.map(\.platform.id))

    let chinese = await service.searchChineseDirectLinks(q, skip: skip)
    covered.formUnion(chinese.map(\.platform.id))

    var all = international + chinese
    let uncovered = MusicPlatform.allPlatforms.filter {
        $0.id != "qqMusic" && $0.id != "netease" && !covered.contains($0.id)
    }
    all += service.buildSearchLinks(for: uncovered, query: q)
    return all
}

// MARK: - Payload Types

struct SongLinkPayload {
    let links: [MusicLink]
    let searchQuery: String?

    static var empty: SongLinkPayload { SongLinkPayload(links: [], searchQuery: nil) }
}

extension MusicLinkService {
    static func extractSearchQueryStatic(from url: URL) -> String {
        let parts = url.pathComponents.filter { $0 != "/" }
        let known = Set(["track","album","song","playlist","artist","n","ryqq","detail","songDetail","search","results","watch","m","s","cn"])
        let candidates = parts.filter {
            let d = $0.removingPercentEncoding ?? $0
            return !d.isEmpty && !d.allSatisfy(\.isNumber) && !known.contains(d.lowercased()) && d.count > 1
        }
        let query = candidates
            .map { ($0.removingPercentEncoding ?? $0).replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ") }
            .joined(separator: " ").trimmingCharacters(in: .whitespaces)
        if !query.isEmpty { return query }
        let fb = (url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent).replacingOccurrences(of: "-", with: " ")
        return fb.components(separatedBy: CharacterSet.decimalDigits).joined().trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Supporting Types

struct SongInfo: Codable {
    let title: String
    let artist: String
    var searchQuery: String { "\(title) \(artist)".trimmingCharacters(in: .whitespaces) }
}

enum ServiceError: LocalizedError {
    case invalidURL, invalidResponse, serverError(Int), cannotResolve, notAMusicLink
    var errorDescription: String? {
        switch self {
        case .invalidURL: "无效的链接"
        case .invalidResponse: "服务器响应异常"
        case .serverError(let c): "服务器错误 (\(c))"
        case .cannotResolve: "无法解析该音乐链接"
        case .notAMusicLink: "请分享具体的歌曲链接，不支持搜索/主页/艺人页面"
        }
    }
}
