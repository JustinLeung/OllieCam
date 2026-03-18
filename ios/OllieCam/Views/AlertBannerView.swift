import SwiftUI

struct AlertBannerView: View {
    let event: BarkEvent
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: event.type.icon)
                    .font(.title2)
                    .foregroundStyle(event.type.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.type.label)
                        .font(.subheadline)
                        .fontWeight(.bold)

                    Text("Confidence: \(Int(event.confidence * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isVisible = false
                    }
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(.rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .padding(.horizontal)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    init(event: BarkEvent, onDismiss: @escaping () -> Void) {
        self.event = event
        self.onDismiss = onDismiss
        self._isVisible = State(initialValue: true)
    }
}
