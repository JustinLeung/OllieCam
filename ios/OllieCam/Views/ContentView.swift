import SwiftUI

struct ContentView: View {
    @Environment(SettingsViewModel.self) private var settingsVM

    var body: some View {
        if settingsVM.isConfigured {
            TabView {
                Tab("Live", systemImage: "video.fill") {
                    NavigationStack {
                        LiveStreamView()
                    }
                }
                Tab("Clips", systemImage: "film.stack") {
                    NavigationStack {
                        ClipsGridView()
                    }
                }
                Tab("Settings", systemImage: "gearshape") {
                    NavigationStack {
                        SettingsView(isInitialSetup: false)
                    }
                }
            }
        } else {
            NavigationStack {
                SettingsView(isInitialSetup: true)
            }
        }
    }
}
