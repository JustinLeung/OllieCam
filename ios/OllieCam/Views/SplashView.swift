import SwiftUI

struct SplashView: View {
    @State private var pawScale: CGFloat = 0.3
    @State private var pawOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    // Pulse ring
                    Circle()
                        .stroke(lineWidth: 2)
                        .foregroundStyle(.tint.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // Paw icon
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                        .scaleEffect(pawScale)
                        .opacity(pawOpacity)
                }

                VStack(spacing: 6) {
                    Text("OllieCam")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Live Dog Cam")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(titleOpacity)
                .offset(y: titleOffset)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                pawScale = 1.0
                pawOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.15)) {
                ringScale = 1.3
                ringOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                titleOpacity = 1.0
                titleOffset = 0
            }
        }
    }
}
