import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.center = view.center
        spinner.startAnimating()
        view.addSubview(spinner)

        let label = UILabel()
        label.text = "正在跳转到音乐分享..."
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.frame = CGRect(x: 0, y: spinner.frame.maxY + 16, width: view.bounds.width, height: 20)
        view.addSubview(label)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.processSharedItems()
        }
    }

    private func processSharedItems() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let providers = extensionItem.attachments else {
            complete()
            return
        }

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] item, _ in
                    DispatchQueue.main.async {
                        let url = item as? URL ?? (item as? String).flatMap(URL.init(string:))
                        if let url { self?.redirectToMainApp(url) }
                        else { self?.complete() }
                    }
                }
                return
            }
        }

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] item, _ in
                    DispatchQueue.main.async {
                        if let text = item as? String,
                           let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
                           text.hasPrefix("http") {
                            self?.redirectToMainApp(url)
                        } else {
                            self?.complete()
                        }
                    }
                }
                return
            }
        }

        complete()
    }

    private func redirectToMainApp(_ url: URL) {
        var components = URLComponents()
        components.scheme = "musicshare"
        components.host = "share"
        components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        guard let mainAppURL = components.url else { return }

        // 1. 尝试通过 extensionContext 打开
        extensionContext?.open(mainAppURL, completionHandler: nil)

        // 2. 同时尝试 responder chain 找到 UIApplication 直接 open
        DispatchQueue.main.async {
            var responder: UIResponder? = self
            while let r = responder {
                if let app = r as? UIApplication {
                    app.open(mainAppURL, options: [:], completionHandler: nil)
                    break
                }
                responder = r.next
            }
        }
    }

    private func complete() {
        self.extensionContext?.completeRequest(returningItems: nil)
    }
}
