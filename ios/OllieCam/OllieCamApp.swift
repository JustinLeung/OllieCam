import SwiftUI

@main
struct OllieCamApp: App {
    @State private var serverStore = ServerStore()
    @State private var settingsViewModel = SettingsViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(serverStore)
                .environment(settingsViewModel)
        }
    }
}
