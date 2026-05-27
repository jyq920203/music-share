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
    func openURL(_ url: URL) { openURLAction(url) }
}
