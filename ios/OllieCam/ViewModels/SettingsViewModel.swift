import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var serverURL: String = ""
    var password: String = ""
    var connectionStatus: ConnectionStatus = .idle
    var errorMessage: String?

    // Notification settings
    var ntfyTopic: String = ""
    var ntfyServer: String = Constants.Notifications.defaultNtfyServer
    var notificationsEnabled: Bool = false
    var notificationTestStatus: NotificationTestStatus = .idle

    private(set) var savedConfiguration: ServerConfiguration = .empty
    private let apiClient = APIClient()

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

    init() {
        loadSavedConfiguration()
    }

    var currentConfiguration: ServerConfiguration {
        ServerConfiguration(serverURL: serverURL, password: password)
    }

    var isConfigured: Bool {
        savedConfiguration.baseURL != nil
    }

    func loadSavedConfiguration() {
        let url = KeychainHelper.load(forKey: Constants.Keychain.urlKey) ?? ""
        let pass = KeychainHelper.load(forKey: Constants.Keychain.passwordKey) ?? ""
        serverURL = url
        password = pass
        savedConfiguration = ServerConfiguration(serverURL: url, password: pass)

        ntfyTopic = KeychainHelper.load(forKey: Constants.Keychain.ntfyTopicKey) ?? ""
        ntfyServer = KeychainHelper.load(forKey: Constants.Keychain.ntfyServerKey)
            ?? Constants.Notifications.defaultNtfyServer
    }

    func saveConfiguration() {
        KeychainHelper.save(serverURL, forKey: Constants.Keychain.urlKey)
        KeychainHelper.save(password, forKey: Constants.Keychain.passwordKey)
        savedConfiguration = currentConfiguration
    }

    func testConnection() async {
        connectionStatus = .testing
        errorMessage = nil

        await apiClient.updateConfiguration(currentConfiguration)

        do {
            _ = try await apiClient.testConnection()
            connectionStatus = .connected
            saveConfiguration()
        } catch {
            connectionStatus = .failed
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Notifications

    func fetchNotificationConfig() async {
        await apiClient.updateConfiguration(currentConfiguration)
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
            // Server may not support notifications yet — not an error
        }
    }

    func sendTestNotification() async {
        notificationTestStatus = .sending
        await apiClient.updateConfiguration(currentConfiguration)
        do {
            try await apiClient.sendTestNotification()
            notificationTestStatus = .sent
        } catch {
            notificationTestStatus = .failed(error.localizedDescription)
        }
    }
}
