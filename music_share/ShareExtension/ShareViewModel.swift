import SwiftUI

@MainActor
final class ShareViewModel: ObservableObject {
    @Published var links: [MusicLink] = []
    @Published var sourceURL: URL?
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let dismissAction: () -> Void
    private let openURLAction: (URL) -> Void

    init(dismiss: @escaping () -> Void, openURL: @escaping (URL) -> Void) {
        self.dismissAction = dismiss
        self.openURLAction = openURL
    }

    func resolveURL(_ url: URL) {
        sourceURL = url
        Task {
            do {
                links = try await MusicLinkService.shared.convertLink(url)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func dismiss() { dismissAction() }

    func openURL(_ url: URL, platformId: String) {
        let schemeURL = buildSchemeURL(webURL: url, platformId: platformId)
        openURLAction(schemeURL ?? url)
    }

    func openInMainApp() {
        guard let sourceURL else { return }
        let encoded = sourceURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let mainAppURL = URL(string: "musicshare://share?url=\(encoded)") else { return }
        openURLAction(mainAppURL)
    }

    private func buildSchemeURL(webURL: URL, platformId: String) -> URL? {
        let schemeMap: [String: String] = [
            "spotify": "spotify://",
            "appleMusic": "music://",
            "youtube": "youtube://",
            "youtubeMusic": "youtubemusic://",
            "deezer": "deezer://",
            "tidal": "tidal://",
            "amazonMusic": "amazonmusic://",
            "qqMusic": "qqmusic://",
            "netease": "orpheus://"
        ]
        guard let scheme = schemeMap[platformId],
              let host = webURL.host else { return nil }
        let schemeString = webURL.absoluteString.replacingOccurrences(of: "https://\(host)", with: scheme)
        return URL(string: schemeString)
    }
}
