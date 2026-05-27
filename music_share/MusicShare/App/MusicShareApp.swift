import SwiftUI
import UIKit

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
    @Published var pendingClipboardURL: URL?

    private var hasCheckedClipboard = false

    func checkClipboard() {
        guard !hasCheckedClipboard else { return }
        hasCheckedClipboard = true
        guard let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              text.hasPrefix("http"),
              let url = URL(string: text) else { return }
        pendingClipboardURL = url
    }

    func confirmClipboard() {
        guard let url = pendingClipboardURL else { return }
        pendingClipboardURL = nil
        handleIncomingURL(url)
    }

    func dismissClipboard() {
        pendingClipboardURL = nil
    }

    func handleIncomingURL(_ url: URL) {
        let musicURL: URL
        if url.scheme == "musicshare",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryURL = components.queryItems?.first(where: { $0.name == "url" })?.value?.removingPercentEncoding,
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
