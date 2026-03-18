import SwiftUI

struct StatusIndicatorView: View {
    let isPlaying: Bool
    let isConnectedSSE: Bool

    @State private var isPulsing = false

    private var status: StreamStatus {
        if isPlaying && isConnectedSSE {
            return .live
        } else if isPlaying {
            return .streaming
        } else {
            return .paused
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
                .scaleEffect(isPulsing && status == .live ? 1.3 : 1.0)
                .animation(
                    status == .live
                        ? .easeInOut(duration: 1).repeatForever(autoreverses: true)
                        : .default,
                    value: isPulsing
                )

            Text(status.label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(status == .paused ? .secondary : status.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .onAppear { isPulsing = true }
    }
}

private enum StreamStatus {
    case live
    case streaming
    case paused

    var label: String {
        switch self {
        case .live: "LIVE"
        case .streaming: "Streaming"
        case .paused: "Paused"
        }
    }

    var color: Color {
        switch self {
        case .live: .red
        case .streaming: .orange
        case .paused: .gray
        }
    }
}
