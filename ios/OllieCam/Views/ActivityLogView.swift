import SwiftUI

struct ActivityLogView: View {
    let events: [BarkEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activity")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal)

            if events.isEmpty {
                Text("No activity yet")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal)
                    .padding(.vertical, 12)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(events) { event in
                            ActivityLogRow(event: event)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 150)
                .scrollIndicators(.hidden)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct ActivityLogRow: View {
    let event: BarkEvent

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(event.type.color)
                .frame(width: 8, height: 8)

            Text(event.type.rawValue.capitalized)
                .font(.subheadline)
                .foregroundStyle(.white)

            Text("\(Int(event.confidence * 100))%")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))

            Spacer()

            Text(event.timestamp, style: .time)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.vertical, 4)
    }
}
