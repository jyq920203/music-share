import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var inputURL = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                inputSection

                if appState.isLoading {
                    loadingView
                } else if let error = appState.errorMessage, appState.links.isEmpty {
                    errorView(error)
                } else if !appState.links.isEmpty {
                    linksListView
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("音乐分享")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var inputSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)

                TextField("粘贴音乐链接...", text: $inputURL)
                    .textFieldStyle(.plain)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused($isFocused)
                    .submitLabel(.go)
                    .onSubmit { resolveInput() }

                if !inputURL.isEmpty {
                    Button { inputURL = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(action: resolveInput) {
                HStack {
                    Image(systemName: "arrow.triangle.swap")
                    Text("转换")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在查找其他平台的链接...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("转换失败", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("粘贴音乐链接", systemImage: "music.note.list")
        } description: {
            Text("支持 Spotify、Apple Music、QQ音乐、网易云音乐等多个平台的链接互转")
        }
        .frame(maxHeight: .infinity)
    }

    private var linksListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(appState.links) { link in
                    LinkRow(link: link)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }

    private func sourcePlatformCard(_ url: URL) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("原始链接")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.blue)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func resolveInput() {
        let trimmed = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return }
        isFocused = false
        appState.handleIncomingURL(url)
    }
}

struct LinkRow: View {
    let link: MusicLink

    var body: some View {
        Button {
            openLink(link.url)
        } label: {
            HStack(spacing: 12) {
                Image(link.platform.id)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(link.platform.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(link.url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Image(systemName: "arrow.up.forward.app.fill")
                    .foregroundStyle(.blue)
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func openLink(_ url: URL) {
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

        if let scheme = schemeMap[link.platform.id],
           let host = url.host,
           let path = URL(string: url.absoluteString.replacingOccurrences(of: "https://\(host)", with: scheme)) {

            UIApplication.shared.open(path) { success in
                if !success {
                    UIApplication.shared.open(url)
                }
            }
        } else {
            UIApplication.shared.open(url)
        }
    }
}


