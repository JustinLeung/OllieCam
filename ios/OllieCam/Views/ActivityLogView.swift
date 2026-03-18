import SwiftUI

struct ActivityLogView: View {
    let events: [BarkEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .padding(.horizontal)

            if events.isEmpty {
                ContentUnavailableView(
                    "No Activity",
                    systemImage: "waveform",
                    description: Text("Events will appear here when sounds are detected.")
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(events.prefix(10)) { event in
                        ActivityLogRow(event: event)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
    }
}

private struct ActivityLogRow: View {
    let event: BarkEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.type.icon)
                .font(.callout)
                .foregroundStyle(event.type.color)
                .frame(width: 32, height: 32)
                .background(event.type.color.opacity(0.12))
                .clipShape(.circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.type.rawValue.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(event.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(Int(event.confidence * 100))%")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
    }
}
