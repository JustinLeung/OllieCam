import Foundation
import Observation

@MainActor
@Observable
final class ServerStore {
    private(set) var servers: [ServerConfiguration] = []
    private(set) var activeServerID: UUID?

    var activeServer: ServerConfiguration? {
        servers.first { $0.id == activeServerID }
    }

    var isConfigured: Bool {
        activeServer?.baseURL != nil
    }

    init() {
        loadServers()
        migrateFromLegacyKeychainIfNeeded()
    }

    // MARK: - CRUD

    func addServer(_ config: ServerConfiguration) {
        servers.append(config)
        savePassword(config.password, for: config.id)
        if activeServerID == nil {
            activeServerID = config.id
        }
        persistServers()
    }

    func updateServer(_ config: ServerConfiguration) {
        guard let index = servers.firstIndex(where: { $0.id == config.id }) else { return }
        servers[index] = config
        savePassword(config.password, for: config.id)
        persistServers()
    }

    func deleteServer(id: UUID) {
        servers.removeAll { $0.id == id }
        deletePassword(for: id)
        if activeServerID == id {
            activeServerID = servers.first?.id
        }
        persistServers()
    }

    func setActiveServer(id: UUID) {
        activeServerID = id
        persistServers()
    }

    func updateNotificationConfig(serverID: UUID, topic: String, server: String) {
        guard let index = servers.firstIndex(where: { $0.id == serverID }) else { return }
        servers[index].ntfyTopic = topic
        servers[index].ntfyServer = server
        persistServers()
    }

    // MARK: - Persistence

    private struct SavedServer: Codable {
        let id: UUID
        var name: String
        var serverURL: String
        var ntfyTopic: String?
        var ntfyServer: String?
    }

    private func loadServers() {
        guard let data = UserDefaults.standard.data(forKey: Constants.Storage.savedServersKey),
              let saved = try? JSONDecoder().decode([SavedServer].self, from: data) else {
            return
        }
        servers = saved.map { s in
            ServerConfiguration(
                id: s.id,
                name: s.name,
                serverURL: s.serverURL,
                password: loadPassword(for: s.id),
                ntfyTopic: s.ntfyTopic ?? "",
                ntfyServer: s.ntfyServer ?? Constants.Notifications.defaultNtfyServer
            )
        }
        if let idString = UserDefaults.standard.string(forKey: Constants.Storage.activeServerIDKey),
           let id = UUID(uuidString: idString) {
            activeServerID = id
        } else {
            activeServerID = servers.first?.id
        }
    }

    private func persistServers() {
        let saved = servers.map { SavedServer(id: $0.id, name: $0.name, serverURL: $0.serverURL, ntfyTopic: $0.ntfyTopic, ntfyServer: $0.ntfyServer) }
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: Constants.Storage.savedServersKey)
        }
        if let id = activeServerID {
            UserDefaults.standard.set(id.uuidString, forKey: Constants.Storage.activeServerIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Constants.Storage.activeServerIDKey)
        }
    }

    private func savePassword(_ password: String, for id: UUID) {
        let key = Constants.Keychain.serverPasswordPrefix + id.uuidString
        if password.isEmpty {
            KeychainHelper.delete(forKey: key)
        } else {
            KeychainHelper.save(password, forKey: key)
        }
    }

    private func loadPassword(for id: UUID) -> String {
        KeychainHelper.load(forKey: Constants.Keychain.serverPasswordPrefix + id.uuidString) ?? ""
    }

    private func deletePassword(for id: UUID) {
        KeychainHelper.delete(forKey: Constants.Keychain.serverPasswordPrefix + id.uuidString)
    }

    // MARK: - Migration from legacy single-server Keychain storage

    private func migrateFromLegacyKeychainIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Constants.Storage.didMigrateLegacyServerKey) else { return }
        UserDefaults.standard.set(true, forKey: Constants.Storage.didMigrateLegacyServerKey)

        guard let url = KeychainHelper.load(forKey: Constants.Keychain.urlKey), !url.isEmpty else { return }
        let password = KeychainHelper.load(forKey: Constants.Keychain.passwordKey) ?? ""

        let name = URL(string: url)?.host ?? url
        let config = ServerConfiguration(name: name, serverURL: url, password: password)
        addServer(config)

        KeychainHelper.delete(forKey: Constants.Keychain.urlKey)
        KeychainHelper.delete(forKey: Constants.Keychain.passwordKey)
    }
}
