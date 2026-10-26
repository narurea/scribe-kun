import SwiftUI

struct MainView: View {
    @Environment(QueueController.self) private var queue
    @Environment(ModelManager.self) private var modelManager
    @AppStorage(SettingsKey.model) private var modelRawValue = WhisperModel.default.rawValue
    @AppStorage(SettingsKey.outputFolderBookmark) private var outputFolderBookmark: Data?
    @AppStorage(SettingsKey.notifyOnCompletion) private var notifyOnCompletion = true

    private var model: WhisperModel { WhisperModel(rawValue: modelRawValue) ?? .default }

    var body: some View {
        VStack(spacing: 0) {
            if !modelManager.isDownloaded(model) {
                ModelDownloadBanner(model: model)
                Divider()
            }

            DropAreaView { urls in queue.add(urls) }
                .padding(16)

            Divider()

            queueList
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            bottomBar
        }
        .frame(minWidth: 520, minHeight: 420)
        .alert(
            "追加できないファイルがあります",
            isPresented: Binding(
                get: { !queue.rejectedFiles.isEmpty },
                set: { if !$0 { queue.rejectedFiles = [] } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(queue.rejectedFiles.joined(separator: "\n"))
        }
        .task {
            if notifyOnCompletion { Notifier.shared.requestAuthorization() }
        }
        .onChange(of: modelManager.isDownloaded(model)) {
            queue.processNextIfNeeded()
        }
    }

    @ViewBuilder
    private var queueList: some View {
        if queue.items.isEmpty {
            ContentUnavailableView(
                "キューは空です",
                systemImage: "text.badge.plus",
                description: Text("動画や音声ファイルを追加すると、上から順に文字起こしします")
            )
        } else {
            List(queue.items) { item in
                QueueRowView(
                    item: item,
                    onCancel: { queue.cancel(item) },
                    onShowInFinder: { queue.showInFinder(item) }
                )
            }
            .listStyle(.inset)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
            Text(OutputFolder.displayPath(bookmark: outputFolderBookmark))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
                .help("保存先フォルダ")
            Spacer()
            if queue.hasFinishedItems {
                Button("完了した項目を消去") { queue.removeFinished() }
            }
            SettingsLink {
                Label("設定", systemImage: "gearshape")
            }
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
