import SwiftUI
import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let hostingController = UIHostingController(rootView: ShareLoadingView())
        addChild(hostingController)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        extractURL { [weak self] url in
            DispatchQueue.main.async {
                guard let self, let url else {
                    self?.switchToResult(error: "未找到有效的音乐链接")
                    return
                }
                self.tryOpenMainApp(url: url)
            }
        }
    }

    private func extractURL(completion: @escaping (URL?) -> Void) {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let providers = extensionItem.attachments else {
            completion(nil)
            return
        }

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                    if let url = item as? URL {
                        completion(url)
                    } else if let str = item as? String, let url = URL(string: str) {
                        completion(url)
                    } else {
                        completion(nil)
                    }
                }
                return
            }
        }

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
                    if let text = item as? String, text.hasPrefix("http"),
                       let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        completion(url)
                    } else {
                        completion(nil)
                    }
                }
                return
            }
        }

        completion(nil)
    }

    private func tryOpenMainApp(url: URL) {
        guard var components = URLComponents(string: "musicshare://convert") else {
            switchToConversion(url: url)
            return
        }
        components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]

        guard let appURL = components.url else {
            switchToConversion(url: url)
            return
        }

        extensionContext?.open(appURL) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.extensionContext?.completeRequest(returningItems: nil)
                } else {
                    self?.switchToConversion(url: url)
                }
            }
        }
    }

    private func switchToConversion(url: URL) {
        let viewModel = ShareViewModel(
            dismiss: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            },
            openURL: { [weak self] targetURL in
                self?.extensionContext?.open(targetURL)
            }
        )

        let shareView = ShareView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: shareView)

        for child in children {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }

        addChild(hostingController)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        viewModel.resolveURL(url)
    }

    private func switchToResult(error: String) {
        let viewModel = ShareViewModel(
            dismiss: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            },
            openURL: { _ in }
        )
        viewModel.errorMessage = error
        viewModel.isLoading = false

        let shareView = ShareView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: shareView)

        for child in children {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }

        addChild(hostingController)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
}

struct ShareLoadingView: View {
    var body: some View {
        ProgressView("正在打开…")
    }
}
