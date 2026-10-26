import SwiftUI
import UserNotifications

@main
struct TranscribeApp: App {
    @State private var modelManager: ModelManager
    @State private var queue: QueueController

    init() {
        SettingsKey.registerDefaults()
        UNUserNotificationCenter.current().delegate = Notifier.shared

        let modelManager = ModelManager()
        _modelManager = State(initialValue: modelManager)
        _queue = State(initialValue: QueueController(modelManager: modelManager))
    }

    var body: some Scene {
        Window("scribe-kun", id: "main") {
            MainView()
                .environment(queue)
                .environment(modelManager)
        }
        .defaultSize(width: 640, height: 520)

        Settings {
            SettingsView()
                .environment(queue)
                .environment(modelManager)
        }
    }
}
