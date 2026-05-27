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
        sourceURL = url
        Task { await resolveLinks(for: url) }
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
