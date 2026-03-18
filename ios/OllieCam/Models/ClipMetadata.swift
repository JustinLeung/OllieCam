import Foundation

struct ClipMetadata: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let type: DetectionType
    let confidence: Double
    let timestamp: Date
    let clip: String
    let thumbnail: String
    let duration: Double
}
