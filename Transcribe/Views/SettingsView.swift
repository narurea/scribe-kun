import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(ModelManager.self) private var modelManager

    @AppStorage(SettingsKey.outputPlain) private var outputPlain = true
    @AppStorage(SettingsKey.outputTimestamps) private var outputTimestamps = false
    @AppStorage(SettingsKey.outputSRT) private var outputSRT = false
    @AppStorage(SettingsKey.outputFolderBookmark) private var outputFolderBookmark: Data?
    @AppStorage(SettingsKey.model) private var modelRawValue = WhisperModel.default.rawValue
    @AppStorage(SettingsKey.language) private var language = TranscriptionLanguage.auto
    @AppStorage(SettingsKey.notifyOnCompletion) private var notifyOnCompletion = true

    @State private var folderError: String?

    private var model: WhisperModel { WhisperModel(rawValue: modelRawValue) ?? .default }

    var body: some View {
        Form {
            Section("出力形式") {
                Toggle(OutputFormat.plain.label, isOn: $outputPlain)
                Toggle(OutputFormat.timestamps.label, isOn: $outputTimestamps)
                Toggle(OutputFormat.srt.label, isOn: $outputSRT)
                if !outputPlain && !outputTimestamps && !outputSRT {
                    Text("何も選ばれていない場合は「本文のみ」で保存します")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.checkbox)

            Section("保存先フォルダ") {
                HStack {
                    Text(OutputFolder.displayPath(bookmark: outputFolderBookmark))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Spacer()
                    Button("変更…", action: chooseFolder)
                }
                if outputFolderBookmark != nil {
                    Button("初期値（書類/Transcripts）に戻す") { outputFolderBookmark = nil }
                }
                if let folderError {
                    Text(folderError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("文字起こし") {
                Picker("モデル", selection: $modelRawValue) {
                    ForEach(WhisperModel.allCases) { model in
                        Text(model.menuLabel).tag(model.rawValue)
                    }
                }
                modelStatus

                Picker("言語", selection: $language) {
                    ForEach(TranscriptionLanguage.choices, id: \.code) { choice in
                        Text(choice.name).tag(choice.code)
                    }
                }
            }

            Section("通知") {
                Toggle("完了時に通知する", isOn: $notifyOnCompletion)
                    .toggleStyle(.switch)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: modelRawValue) {
            // Fetch a newly selected model right away if it is not on disk yet.
            modelManager.download(model)
        }
        .onChange(of: notifyOnCompletion) {
            if notifyOnCompletion { Notifier.shared.requestAuthorization() }
        }
    }

    @ViewBuilder
    private var modelStatus: some View {
        switch modelManager.state(for: model) {
        case .downloaded:
            Label("ダウンロード済み", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        case .downloading(let progress):
            HStack {
                ProgressView(value: progress)
                Text("\(Int(progress * 100))%")
                    .monospacedDigit()
                Button("中止") { modelManager.cancelDownload(model) }
            }
        case .notDownloaded:
            HStack {
                Text("未ダウンロード")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("ダウンロード") { modelManager.download(model) }
            }
        case .failed(let message):
            HStack {
                Text(message)
                    .foregroundStyle(.red)
                Spacer()
                Button("再試行") { modelManager.download(model) }
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "選択"
        panel.message = "文字起こしの保存先フォルダを選んでください"
        panel.directoryURL = OutputFolder.resolve(bookmark: outputFolderBookmark)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            outputFolderBookmark = try OutputFolder.makeBookmark(for: url)
            folderError = nil
        } catch {
            folderError = "フォルダを保存できませんでした：\(error.localizedDescription)"
        }
    }
}
