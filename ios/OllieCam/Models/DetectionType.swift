import SwiftUI

enum DetectionType: String, Codable, Sendable {
    case bark
    case whine

    var color: Color {
        switch self {
        case .bark: .red
        case .whine: .yellow
        }
    }

    var icon: String {
        switch self {
        case .bark: "speaker.wave.3.fill"
        case .whine: "waveform"
        }
    }

    var label: String {
        switch self {
        case .bark: "Bark Detected"
        case .whine: "Whine Detected"
        }
    }
}
