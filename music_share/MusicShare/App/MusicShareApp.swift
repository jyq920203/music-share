import SwiftUI

@main
struct MusicShareApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onOpenURL { url in
                    appState.handleIncomingURL(url)
                }
        }
    }
}

final class AppState: ObservableObject {
    @Published var links: [MusicLink] = []
    @Published var sourceURL: URL?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var songTitle: String?

    func handleIncomingURL(_ url: URL) {
        let musicURL: URL
        if url.scheme == "musicshare",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryURL = components.queryItems?.first(where: { $0.name == "url" })?.value,
           let decoded = URL(string: queryURL) {
            musicURL = decoded
        } else {
            musicURL = url
        }
        sourceURL = musicURL
        Task { await resolveLinks(for: musicURL) }
    }

    @MainActor
    func resolveLinks(for url: URL) async {
        isLoading = true
        errorMessage = nil
        links = []

        do {
            links = try await MusicLinkService.shared.convertLink(url)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
