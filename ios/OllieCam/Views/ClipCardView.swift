import SwiftUI

struct ClipCardView: View {
    let clip: ClipMetadata
    let viewModel: ClipsViewModel

    @State private var thumbnailURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topLeading) {
                if let thumbnailURL {
                    AsyncImage(url: thumbnailURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.6)
                            }
                    }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }

                Text(clip.type.rawValue.uppercased())
                    .font(.system(size: 9))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(clip.type.color)
                    .clipShape(.rect(cornerRadius: 3))
                    .padding(4)
            }
            .frame(width: 120, height: 68)
            .clipShape(.rect(cornerRadius: 8))

            Text(clip.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .task {
            thumbnailURL = await viewModel.thumbnailURL(for: clip)
        }
    }
}
