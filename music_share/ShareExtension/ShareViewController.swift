import SwiftUI
import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let viewModel = ShareViewModel(
            dismiss: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            },
            openURL: { [weak self] url in
                self?.extensionContext?.open(url)
            }
        )

        let shareView = ShareView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: shareView)
        addChild(hostingController)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        extractURL { url in
            DispatchQueue.main.async {
                if let url {
                    viewModel.resolveURL(url)
                } else {
                    viewModel.errorMessage = "未找到有效的音乐链接"
                    viewModel.isLoading = false
                }
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
}
