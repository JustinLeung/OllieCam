import SwiftUI

struct ServerListView: View {
    @Environment(ServerStore.self) private var serverStore
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(\.openURL) private var openURL
    @State private var showingAddServer = false
    @State private var editingServer: ServerConfiguration?
    @State private var copiedTopic = false

    var body: some View {
        List {
            Section("Servers") {
                ForEach(serverStore.servers) { server in
                    Button {
                        serverStore.setActiveServer(id: server.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(server.name.isEmpty ? server.serverURL : server.name)
                                    .foregroundStyle(.primary)
                                    .fontWeight(server.id == serverStore.activeServerID ? .semibold : .regular)
                                Text(server.serverURL)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if server.id == serverStore.activeServerID {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            serverStore.deleteServer(id: server.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            editingServer = server
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                }
            }

            Section {
                Button {
                    showingAddServer = true
                } label: {
                    Label("Add Server", systemImage: "plus")
                }
            }

            if let server = serverStore.activeServer {
                notificationsSection(for: server)
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingAddServer) {
            NavigationStack {
                ServerFormView(mode: .add)
            }
        }
        .sheet(item: $editingServer) { server in
            NavigationStack {
                ServerFormView(mode: .edit(server))
            }
        }
        .task {
            if let server = serverStore.activeServer {
                await settingsVM.fetchNotificationConfig(for: server, store: serverStore)
            }
        }
        .onChange(of: serverStore.activeServerID) {
            copiedTopic = false
            settingsVM.notificationTestStatus = .idle
            Task {
                if let server = serverStore.activeServer {
                    await settingsVM.fetchNotificationConfig(for: server, store: serverStore)
                }
            }
        }
    }

    // MARK: - Notifications

    @ViewBuilder
    private func notificationsSection(for server: ServerConfiguration) -> some View {
        Section {
            HStack {
                Text("Push Notifications")
                Spacer()
                if server.hasNotifications {
                    Text("Enabled")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Text("Not detected")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            if server.hasNotifications {
                Button {
                    UIPasteboard.general.string = server.ntfyTopic
                    copiedTopic = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        copiedTopic = false
                    }
                } label: {
                    HStack {
                        Text("Topic")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(copiedTopic ? "Copied!" : server.ntfyTopic)
                            .foregroundStyle(copiedTopic ? .green : .secondary)
                    }
                    .font(.caption)
                }

                if let subscribeURL = server.ntfySubscribeURL {
                    Button {
                        openURL(subscribeURL)
                    } label: {
                        HStack {
                            Text("Subscribe in ntfy App")
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button {
                    Task { await settingsVM.sendTestNotification(for: server) }
                } label: {
                    HStack {
                        Text("Send Test Notification")
                        Spacer()
                        notificationTestStatusView
                    }
                }
                .disabled(settingsVM.notificationTestStatus == .sending)
            } else {
                Button("Refresh from Server") {
                    Task {
                        await settingsVM.fetchNotificationConfig(for: server, store: serverStore)
                    }
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            if server.hasNotifications {
                Text("Install the [ntfy app](https://apps.apple.com/app/ntfy/id1625396347) and tap Subscribe to receive push notifications.")
            } else {
                Text("Notifications are auto-configured on the server. Tap Refresh to detect.")
            }
        }
    }

    @ViewBuilder
    private var notificationTestStatusView: some View {
        switch settingsVM.notificationTestStatus {
        case .idle:
            EmptyView()
        case .sending:
            ProgressView()
        case .sent:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
