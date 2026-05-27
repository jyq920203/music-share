import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let label = UILabel()
        label.text = "正在打开…"
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        extractURL { [weak self] url in
            DispatchQueue.main.async {
                guard let self, let url else {
                    self?.showError("未找到链接")
                    return
                }
                self.openMainApp(with: url)
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

    private func openMainApp(with url: URL) {
        guard var components = URLComponents(string: "musicshare://convert") else {
            complete()
            return
        }
        components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]

        guard let appURL = components.url else {
            complete()
            return
        }

        extensionContext?.open(appURL) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.complete()
                } else {
                    self?.fallbackToClipboard(url)
                }
            }
        }
    }

    private func fallbackToClipboard(_ url: URL) {
        UIPasteboard.general.url = url

        let alert = UIAlertController(
            title: "链接已复制",
            message: "跳转失败，链接已复制到剪切板。请手动打开「音乐分享」App 粘贴转换。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "好的", style: .default) { [weak self] _ in
            self?.complete()
        })
        present(alert, animated: true)
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "关闭", style: .default) { [weak self] _ in
            self?.complete()
        })
        present(alert, animated: true)
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
