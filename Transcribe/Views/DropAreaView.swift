import SwiftUI

/// "ここに動画をドロップ" area with a file picker button.
struct DropAreaView: View {
    let onAdd: ([URL]) -> Void

    @State private var isTargeted = false
    @State private var isImporterPresented = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "film.stack")
                .font(.system(size: 32))
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
            Text("ここに動画をドロップ")
                .font(.headline)
            Text("mp4 / mov / m4v / m4a / mp3 / wav")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("ファイルを選択…") { isImporterPresented = true }
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                )
        )
        .dropDestination(for: URL.self) { urls, _ in
            let files = urls.filter(\.isFileURL)
            guard !files.isEmpty else { return false }
            onAdd(files)
            return true
        } isTargeted: { isTargeted = $0 }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: AudioExtractor.supportedTypes,
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result { onAdd(urls) }
        }
    }
}
