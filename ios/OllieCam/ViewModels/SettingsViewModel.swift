import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    // Form fields
    var name: String = ""
    var serverURL: String = ""
    var password: String = ""
    var connectionStatus: ConnectionStatus = .idle
    var errorMessage: String?

    // Notification settings
    var ntfyTopic: String = ""
    var ntfyServer: String = Constants.Notifications.defaultNtfyServer
    var notificationsEnabled: Bool = false
    var notificationTestStatus: NotificationTestStatus = .idle

    private let apiClient = APIClient()
    private var pendingID = UUID()
    private var editingServerID: UUID?

    enum ConnectionStatus: Equatable {
        case idle
        case testing
        case connected
        case failed
    }

    enum NotificationTestStatus: Equatable {
        case idle
        case sending
        case sent
        case failed(String)
    }

    // MARK: - Form Setup

    func prepareForAdd() {
        pendingID = UUID()
        editingServerID = nil
        name = ""
        serverURL = ""
        password = ""
        connectionStatus = .idle
        errorMessage = nil
    }

    func prepareForEdit(_ server: ServerConfiguration) {
        editingServerID = server.id
        name = server.name
        serverURL = server.serverURL
        password = server.password
        connectionStatus = .idle
        errorMessage = nil
    }

    var isEditing: Bool { editingServerID != nil }

    var currentConfiguration: ServerConfiguration {
        ServerConfiguration(
            id: editingServerID ?? pendingID,
            name: name.isEmpty ? (URL(string: serverURL)?.host ?? serverURL) : name,
            serverURL: serverURL,
            password: password
        )
    }

    // MARK: - Connection Test

    func testConnection() async -> ServerConfiguration? {
        let config = currentConfiguration
        connectionStatus = .testing
        errorMessage = nil

        await apiClient.updateConfiguration(config)

        do {
            _ = try await apiClient.testConnection()
            connectionStatus = .connected
            return config
        } catch {
            connectionStatus = .failed
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Notifications

    func fetchNotificationConfig(for server: ServerConfiguration) async {
        await apiClient.updateConfiguration(server)
        do {
            let config = try await apiClient.fetchNotificationConfig()
            notificationsEnabled = config.enabled
            if let topic = config.topic, !topic.isEmpty {
                ntfyTopic = topic
            }
            ntfyServer = config.server
            KeychainHelper.save(ntfyTopic, forKey: Constants.Keychain.ntfyTopicKey)
            KeychainHelper.save(ntfyServer, forKey: Constants.Keychain.ntfyServerKey)
        } catch {
            // Server may not support notifications yet
        }
    }

    func sendTestNotification(for server: ServerConfiguration) async {
        notificationTestStatus = .sending
        await apiClient.updateConfiguration(server)
        do {
            try await apiClient.sendTestNotification()
            notificationTestStatus = .sent
        } catch {
            notificationTestStatus = .failed(error.localizedDescription)
        }
    }

    var ntfySubscribeURL: URL? {
        guard !ntfyTopic.isEmpty else { return nil }
        return URL(string: "\(ntfyServer)/\(ntfyTopic)")
    }

    func loadNotificationSettings() {
        ntfyTopic = KeychainHelper.load(forKey: Constants.Keychain.ntfyTopicKey) ?? ""
        ntfyServer = KeychainHelper.load(forKey: Constants.Keychain.ntfyServerKey)
            ?? Constants.Notifications.defaultNtfyServer
    }
}
