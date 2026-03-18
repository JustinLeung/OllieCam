import SwiftUI

struct SettingsView: View {
    @Environment(SettingsViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let isInitialSetup: Bool

    var body: some View {
        @Bindable var viewModel = viewModel

        Form {
            Section("Server") {
                TextField("Server URL", text: $viewModel.serverURL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                SecureField("Password (optional)", text: $viewModel.password)
                    .textContentType(.password)
            }

            Section {
                Button {
                    Task { await viewModel.testConnection() }
                } label: {
                    HStack {
                        Text("Test Connection")

                        Spacer()

                        connectionStatusView
                    }
                }
                .disabled(viewModel.serverURL.isEmpty || viewModel.connectionStatus == .testing)
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Section {
                HStack {
                    Text("Push Notifications")
                    Spacer()
                    if viewModel.notificationsEnabled {
                        Text("Enabled")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else {
                        Text("Not configured")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }

                if viewModel.notificationsEnabled {
                    LabeledContent("Topic", value: viewModel.ntfyTopic)
                        .font(.caption)

                    Button {
                        Task { await viewModel.sendTestNotification() }
                    } label: {
                        HStack {
                            Text("Send Test Notification")
                            Spacer()
                            notificationTestStatusView
                        }
                    }
                    .disabled(viewModel.notificationTestStatus == .sending)
                }

                Button("Detect from Server") {
                    Task { await viewModel.fetchNotificationConfig() }
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text("Set NTFY_TOPIC on the server to enable. Install the ntfy app to receive push notifications when barking or whining is detected.")
            }

            if viewModel.connectionStatus == .connected && isInitialSetup {
                Section {
                    Button("Continue") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .navigationTitle(isInitialSetup ? "Setup" : "Settings")
        .task {
            if viewModel.isConfigured {
                await viewModel.fetchNotificationConfig()
            }
        }
    }

    @ViewBuilder
    private var notificationTestStatusView: some View {
        switch viewModel.notificationTestStatus {
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

    @ViewBuilder
    private var connectionStatusView: some View {
        switch viewModel.connectionStatus {
        case .idle:
            EmptyView()
        case .testing:
            ProgressView()
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
