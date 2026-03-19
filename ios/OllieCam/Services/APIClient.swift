import Foundation
import UIKit

actor APIClient {
    private let session: URLSession
    private var configuration: ServerConfiguration

    init(configuration: ServerConfiguration = .empty) {
        self.configuration = configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }

    func updateConfiguration(_ configuration: ServerConfiguration) {
        self.configuration = configuration
    }

    // MARK: - URL Building

    func url(for path: String) -> URL? {
        configuration.baseURL?.appendingPathComponent(path)
    }

    private func authorizedRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if let auth = configuration.authHeader {
            request.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // MARK: - Connection Test

    func testConnection() async throws -> Bool {
        guard let url = url(for: "snapshot") else {
            throw APIError.invalidURL
        }
        let request = authorizedRequest(for: url)
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.serverError(httpResponse.statusCode)
        }
        return true
    }

    // MARK: - Snapshot

    func fetchSnapshot() async throws -> UIImage {
        guard let url = url(for: "snapshot") else {
            throw APIError.invalidURL
        }
        let request = authorizedRequest(for: url)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        guard let image = UIImage(data: data) else {
            throw APIError.invalidImageData
        }
        return image
    }

    // MARK: - Bark Reporting

    func reportBark(type: DetectionType, confidence: Double) async throws {
        guard let url = url(for: "bark") else {
            throw APIError.invalidURL
        }
        var request = authorizedRequest(for: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "type": type.rawValue,
            "confidence": confidence
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
    }

    // MARK: - Clips

    func fetchClips() async throws -> [ClipMetadata] {
        guard let url = url(for: "api/clips") else {
            throw APIError.invalidURL
        }
        let request = authorizedRequest(for: url)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ClipMetadata].self, from: data)
    }

    func deleteClip(id: String) async throws {
        guard let url = url(for: "api/clips/\(id)") else {
            throw APIError.invalidURL
        }
        var request = authorizedRequest(for: url)
        request.httpMethod = "DELETE"
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
    }

    func clipURL(for filename: String) -> URL? {
        url(for: "clips/\(filename)")
    }

    func thumbnailURL(for filename: String) -> URL? {
        url(for: "clips/\(filename)")
    }

    // MARK: - Notifications

    func fetchNotificationConfig() async throws -> NotificationConfig {
        guard let url = url(for: "api/notifications/config") else {
            throw APIError.invalidURL
        }
        let request = authorizedRequest(for: url)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        return try JSONDecoder().decode(NotificationConfig.self, from: data)
    }

    func sendTestNotification() async throws {
        guard let url = url(for: "api/notifications/test") else {
            throw APIError.invalidURL
        }
        var request = authorizedRequest(for: url)
        request.httpMethod = "POST"
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        if httpResponse.statusCode == 400 {
            throw APIError.serverError(400)
        }
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - HLS

    func streamURL() -> URL? {
        url(for: "stream/master.m3u8")
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidImageData
    case unauthorized
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid server URL"
        case .invalidResponse:
            "Invalid server response"
        case .invalidImageData:
            "Could not decode image"
        case .unauthorized:
            "Authentication failed. Check your password."
        case .serverError(let code):
            "Server error (\(code))"
        }
    }
}
