import Foundation

struct NotificationConfig: Codable, Sendable {
    let enabled: Bool
    let topic: String?
    let server: String
}
