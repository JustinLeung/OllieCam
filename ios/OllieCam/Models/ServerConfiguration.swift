import Foundation

struct ServerConfiguration: Sendable, Equatable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var serverURL: String
    var password: String
    var ntfyTopic: String
    var ntfyServer: String

    var baseURL: URL? {
        var urlString = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "http://\(urlString)"
        }
        if urlString.hasSuffix("/") {
            urlString = String(urlString.dropLast())
        }
        return URL(string: urlString)
    }

    var hasAuth: Bool {
        !password.isEmpty
    }

    var authHeader: String? {
        guard hasAuth else { return nil }
        let credentials = "admin:\(password)"
        guard let data = credentials.data(using: .utf8) else { return nil }
        return "Basic \(data.base64EncodedString())"
    }

    var hasNotifications: Bool { !ntfyTopic.isEmpty }

    var ntfySubscribeURL: URL? {
        guard hasNotifications else { return nil }
        return URL(string: "\(ntfyServer)/\(ntfyTopic)")
    }

    init(id: UUID = UUID(), name: String = "", serverURL: String = "", password: String = "", ntfyTopic: String = "", ntfyServer: String = Constants.Notifications.defaultNtfyServer) {
        self.id = id
        self.name = name
        self.serverURL = serverURL
        self.password = password
        self.ntfyTopic = ntfyTopic
        self.ntfyServer = ntfyServer
    }

    static let empty = ServerConfiguration()
}
