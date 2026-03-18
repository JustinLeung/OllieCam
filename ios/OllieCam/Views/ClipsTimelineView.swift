import SwiftUI

struct ClipsTimelineView: View {
    let viewModel: ClipsViewModel
    let onClipTap: (ClipMetadata) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Event Clips")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                }

                Button {
                    Task { await viewModel.loadClips() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal)

            if viewModel.clips.isEmpty {
                Text("No clips yet")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal)
                    .padding(.vertical, 12)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(viewModel.clips) { clip in
                            Button {
                                onClipTap(clip)
                            } label: {
                                ClipCardView(clip: clip, viewModel: viewModel)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .scrollIndicators(.hidden)
                .frame(height: 100)
            }
        }
        .padding(.vertical, 8)
    }
}
