import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var serverURL: String = ""
    var password: String = ""
    var connectionStatus: ConnectionStatus = .idle
    var errorMessage: String?

    private(set) var savedConfiguration: ServerConfiguration = .empty
    private let apiClient = APIClient()

    enum ConnectionStatus: Equatable {
        case idle
        case testing
        case connected
        case failed
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
}
