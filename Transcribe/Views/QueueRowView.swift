import SwiftUI

struct QueueRowView: View {
    let item: QueueItem
    let onCancel: () -> Void
    let onShowInFinder: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isVideo ? "film" : "waveform")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.fileName)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 10) {
                    statusLabel
                    if let code = item.detectedLanguage {
                        Label(TranscriptionLanguage.displayName(for: code), systemImage: "globe")
                    }
                    elapsedLabel
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                progressBar
            }

            Spacer(minLength: 8)

            actionButton
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch item.status {
        case .waiting:
            Text("待機中")
        case .extractingAudio:
            Text("音声を取り出し中")
        case .transcribing(let progress):
            Text("処理中 \(progress)%")
        case .completed:
            Label("完了", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            Label("エラー", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .help(message)
        case .cancelled:
            Text("キャンセル済み")
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        switch item.status {
        case .extractingAudio(let progress):
            ProgressView(value: progress)
        case .transcribing(let progress):
            ProgressView(value: Double(progress), total: 100)
        case .failed(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(2)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var elapsedLabel: some View {
        if let startedAt = item.startedAt {
            if let finishedAt = item.finishedAt {
                Label(Self.formatElapsed(finishedAt.timeIntervalSince(startedAt)), systemImage: "clock")
            } else {
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    Label(Self.formatElapsed(context.date.timeIntervalSince(startedAt)), systemImage: "clock")
                }
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch item.status {
        case .waiting, .extractingAudio, .transcribing:
            Button("キャンセル", action: onCancel)
        case .completed:
            Button("Finderで表示", action: onShowInFinder)
        default:
            EmptyView()
        }
    }

    static func formatElapsed(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        let hours = total / 3600
        let minutes = total / 60 % 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}
