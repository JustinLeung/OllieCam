import SwiftUI

struct ClipCardView: View {
    let clip: ClipMetadata
    let viewModel: ClipsViewModel

    @State private var thumbnailURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                if let thumbnailURL {
                    AsyncImage(url: thumbnailURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.tertiarySystemFill))
                            .overlay {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                    }
                } else {
                    Rectangle()
                        .fill(Color(.tertiarySystemFill))
                        .overlay {
                            Image(systemName: "film")
                                .foregroundStyle(.secondary)
                        }
                }

                HStack(spacing: 4) {
                    Image(systemName: clip.type.icon)
                        .font(.system(size: 9))
                    Text(clip.type.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(clip.type.color.opacity(0.9))
                .clipShape(Capsule())
                .padding(6)
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(clip.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(Int(clip.confidence * 100))% confidence")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .task {
            thumbnailURL = await viewModel.thumbnailURL(for: clip)
        }
    }
}
