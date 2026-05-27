import SwiftUI

struct ShareView: View {
    @ObservedObject var viewModel: ShareViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("音乐分享")
                    .font(.headline)
                Spacer()
                Button("关闭") { viewModel.dismiss() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            if viewModel.isLoading {
                Spacer()
                ProgressView("正在查找其他平台的链接...")
                Spacer()
            } else if let error = viewModel.errorMessage {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if !viewModel.links.isEmpty {
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
                                        Text(link.url.absoluteString)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.forward.app")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        if let source = viewModel.sourceURL,
                           let platform = MusicPlatform.detectPlatform(from: source) {
                            Label("从 \(platform.name) 转换", systemImage: "arrow.triangle.swap")
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                Spacer()
                Text("未找到链接")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}
