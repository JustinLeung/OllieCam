import SwiftUI

struct ServerFormView: View {
    @Environment(ServerStore.self) private var serverStore
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(\.dismiss) private var dismiss

    enum Mode: Identifiable {
        case add
        case edit(ServerConfiguration)
        case initialSetup

        var id: String {
            switch self {
            case .add: "add"
            case .edit(let s): "edit-\(s.id)"
            case .initialSetup: "setup"
            }
        }
    }

    let mode: Mode

    var body: some View {
        @Bindable var settingsVM = settingsVM

        Form {
            Section("Server") {
                TextField("Name (optional)", text: $settingsVM.name)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                TextField("Server URL", text: $settingsVM.serverURL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                SecureField("Password (optional)", text: $settingsVM.password)
                    .textContentType(.password)
            }

            Section {
                Button {
                    Task { await saveServer() }
                } label: {
                    HStack {
                        Text("Test & Save")
                        Spacer()
                        connectionStatusView
                    }
                }
                .disabled(settingsVM.serverURL.isEmpty || settingsVM.connectionStatus == .testing)
            }

            if let error = settingsVM.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            if settingsVM.connectionStatus == .connected && isInitialSetup {
                Section {
                    Button("Continue") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            if !isInitialSetup {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            switch mode {
            case .add, .initialSetup:
                settingsVM.prepareForAdd()
            case .edit(let server):
                settingsVM.prepareForEdit(server)
            }
        }
    }

    private var isInitialSetup: Bool {
        if case .initialSetup = mode { return true }
        return false
    }

    private var navigationTitle: String {
        switch mode {
        case .initialSetup: "Setup"
        case .add: "Add Server"
        case .edit: "Edit Server"
        }
    }

    private func saveServer() async {
        guard let config = await settingsVM.testConnection() else { return }

        switch mode {
        case .add, .initialSetup:
            serverStore.addServer(config)
        case .edit:
            serverStore.updateServer(config)
        }

        if !isInitialSetup {
            dismiss()
        }
    }

    @ViewBuilder
    private var connectionStatusView: some View {
        switch settingsVM.connectionStatus {
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
