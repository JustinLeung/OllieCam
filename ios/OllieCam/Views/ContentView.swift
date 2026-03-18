import SwiftUI

struct ContentView: View {
    @Environment(SettingsViewModel.self) private var settingsVM

    var body: some View {
        NavigationStack {
            if settingsVM.isConfigured {
                LiveStreamView()
            } else {
                SettingsView(isInitialSetup: true)
            }
        }
    }
}
