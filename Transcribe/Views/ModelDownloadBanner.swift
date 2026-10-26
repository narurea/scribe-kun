import SwiftUI

/// Shown at the top of the main window while the selected model is not on disk.
struct ModelDownloadBanner: View {
    let model: WhisperModel
    @Environment(ModelManager.self) private var modelManager

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 6) {
                Text("文字起こしモデル（\(model.rawValue)）のダウンロードが必要です")
                    .font(.headline)
                Text("初回のみ約\(model.sizeLabel)をHugging Faceから取得します。動画や音声が外部に送信されることはありません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                switch modelManager.state(for: model) {
                case .downloading(let progress):
                    ProgressView(value: progress) {
                        EmptyView()
                    } currentValueLabel: {
                        Text("\(Int(progress * 100))%")
                    }
                case .failed(let message):
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                default:
                    EmptyView()
                }
            }

            Spacer(minLength: 8)

            if case .downloading = modelManager.state(for: model) {
                Button("中止") { modelManager.cancelDownload(model) }
            } else {
                Button("ダウンロード") { modelManager.download(model) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.08))
    }
}
