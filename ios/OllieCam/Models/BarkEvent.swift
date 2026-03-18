import Foundation

struct BarkEvent: Identifiable, Codable, Sendable {
    let id: UUID
    let type: DetectionType
    let confidence: Double
    let timestamp: Date

    init(type: DetectionType, confidence: Double, timestamp: Date = .now) {
        self.id = UUID()
        self.type = type
        self.confidence = confidence
        self.timestamp = timestamp
    }
}
