import Foundation

struct ServerConfiguration: Codable, Sendable, Equatable {
    var serverURL: String
    var password: String

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

    static let empty = ServerConfiguration(serverURL: "", password: "")
}
