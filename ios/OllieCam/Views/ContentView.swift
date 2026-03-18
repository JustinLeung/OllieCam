import SwiftUI

struct ContentView: View {
    @Environment(ServerStore.self) private var serverStore

    var body: some View {
        if serverStore.isConfigured {
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
                        ServerListView()
                    }
                }
            }
        } else {
            NavigationStack {
                ServerFormView(mode: .initialSetup)
            }
        }
    }
}
