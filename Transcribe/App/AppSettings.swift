import Foundation

/// UserDefaults keys shared by `@AppStorage` in the views and by the queue.
enum SettingsKey {
    static let outputPlain = "outputPlain"
    static let outputTimestamps = "outputTimestamps"
    static let outputSRT = "outputSRT"
    static let outputFolderBookmark = "outputFolderBookmark"
    static let model = "model"
    static let language = "language"
    static let notifyOnCompletion = "notifyOnCompletion"

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            outputPlain: true,
            outputTimestamps: false,
            outputSRT: false,
            model: WhisperModel.default.rawValue,
            language: TranscriptionLanguage.auto,
            notifyOnCompletion: true,
        ])
    }
}

enum OutputFormat: String, CaseIterable, Identifiable {
    case plain
    case timestamps
    case srt

    var id: String { rawValue }

    var label: String {
        switch self {
        case .plain: "本文のみ（.txt）"
        case .timestamps: "タイムスタンプ付き（_timestamps.txt）"
        case .srt: "字幕（.srt）"
        }
    }
}

enum WhisperModel: String, CaseIterable, Identifiable {
    case largeV3Turbo = "large-v3-turbo"
    case largeV3 = "large-v3"
    case small = "small"

    static let `default` = WhisperModel.largeV3Turbo

    var id: String { rawValue }

    var fileName: String { "ggml-\(rawValue).bin" }

    var downloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(fileName)")!
    }

    var sizeLabel: String {
        switch self {
        case .largeV3Turbo: "1.6GB"
        case .largeV3: "3.1GB"
        case .small: "490MB"
        }
    }

    var menuLabel: String { "\(rawValue)（約\(sizeLabel)）" }
}

enum TranscriptionLanguage {
    static let auto = "auto"

    /// Choices for the language popup. `auto` lets whisper detect the language.
    static let choices: [(code: String, name: String)] = [
        (auto, "自動"),
        ("ja", "日本語"),
        ("en", "英語"),
        ("zh", "中国語"),
        ("ko", "韓国語"),
        ("es", "スペイン語"),
        ("fr", "フランス語"),
        ("de", "ドイツ語"),
        ("it", "イタリア語"),
        ("pt", "ポルトガル語"),
        ("ru", "ロシア語"),
    ]

    /// Human-readable name for a whisper language code such as "ja".
    static func displayName(for code: String) -> String {
        Locale(identifier: "ja").localizedString(forLanguageCode: code) ?? code
    }
}

/// Snapshot of the settings taken when a file starts processing.
struct TranscriptionSettings {
    var formats: [OutputFormat]
    var model: WhisperModel
    var language: String
    var notifyOnCompletion: Bool
    var outputFolderBookmark: Data?

    static func current(_ defaults: UserDefaults = .standard) -> TranscriptionSettings {
        var formats: [OutputFormat] = []
        if defaults.bool(forKey: SettingsKey.outputPlain) { formats.append(.plain) }
        if defaults.bool(forKey: SettingsKey.outputTimestamps) { formats.append(.timestamps) }
        if defaults.bool(forKey: SettingsKey.outputSRT) { formats.append(.srt) }
        if formats.isEmpty { formats = [.plain] }

        return TranscriptionSettings(
            formats: formats,
            model: WhisperModel(rawValue: defaults.string(forKey: SettingsKey.model) ?? "") ?? .default,
            language: defaults.string(forKey: SettingsKey.language) ?? TranscriptionLanguage.auto,
            notifyOnCompletion: defaults.bool(forKey: SettingsKey.notifyOnCompletion),
            outputFolderBookmark: defaults.data(forKey: SettingsKey.outputFolderBookmark)
        )
    }
}
