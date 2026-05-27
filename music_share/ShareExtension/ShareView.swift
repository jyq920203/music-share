import SwiftUI

struct ShareView: View {
    @ObservedObject var viewModel: ShareViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.errorMessage, viewModel.links.isEmpty {
                    errorView(error)
                } else {
                    linksListView
                }
            }
            .navigationTitle("音乐分享")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { viewModel.dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    if let source = viewModel.sourceURL,
                       let platform = MusicPlatform.detectPlatform(from: source) {
                        Label(platform.name, systemImage: "arrow.triangle.swap")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
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

    private var linksListView: some View {
        List {
            Section {
                ForEach(viewModel.links) { link in
                    Button {
                        viewModel.openURL(link.url)
                    } label: {
                        HStack(spacing: 12) {
                            Image(link.platform.id)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(link.platform.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text(link.url.absoluteString)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.forward.app.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                if let source = viewModel.sourceURL,
                   let platform = MusicPlatform.detectPlatform(from: source) {
                    HStack {
                        Image(systemName: "link")
                        Text("从 \(platform.name) 转换")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
