import SwiftUI

struct ContentView: View {
    var body: some View {
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
    }
}
