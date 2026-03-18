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
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.type.label)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("Confidence: \(Int(event.confidence * 100))%")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isVisible = false
                    }
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding()
            .background(event.type.color.opacity(0.9))
            .clipShape(.rect(cornerRadius: 12))
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
