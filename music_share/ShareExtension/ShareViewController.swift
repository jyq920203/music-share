import SwiftUI
import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    private var viewModel: ShareViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel = ShareViewModel(
            dismiss: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            },
            openURL: { [weak self] url in
                self?.extensionContext?.open(url, completionHandler: nil)
            }
        )
        setupUI()
        loadSharedURL()
    }

    private func setupUI() {
        let shareView = ShareView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: shareView)
        addChild(hostingController)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }

    private func loadSharedURL() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let providers = extensionItem.attachments else {
            viewModel.errorMessage = "未能获取分享内容"
            viewModel.isLoading = false
            return
        }

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, error in
                    DispatchQueue.main.async {
                        if let url = item as? URL {
                            self?.viewModel.resolveURL(url)
                        } else if let urlString = item as? String, let url = URL(string: urlString) {
                            self?.viewModel.resolveURL(url)
                        } else {
                            self?.viewModel.errorMessage = "未找到有效的音乐链接"
                            self?.viewModel.isLoading = false
                        }
                    }
                }
                return
            }
        }

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, error in
                    DispatchQueue.main.async {
                        if let text = item as? String,
                           text.hasPrefix("http"),
                           let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            self?.viewModel.resolveURL(url)
                        } else if self?.viewModel.errorMessage == nil && self?.viewModel.links.isEmpty ?? true {
                            self?.viewModel.errorMessage = "未找到有效的音乐链接"
                            self?.viewModel.isLoading = false
                        }
                    }
                }
                return
            }
        }
    }
}

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
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func dismiss() {
        dismissAction()
    }

    func openURL(_ url: URL) {
        openURLAction(url)
    }
}
