import SwiftUI

struct ClipsGridView: View {
    @Environment(SettingsViewModel.self) private var settingsVM
    @State private var viewModel = ClipsViewModel()
    @State private var selectedClip: ClipMetadata?
    @State private var filterType: DetectionType?

    private var filteredClips: [ClipMetadata] {
        if let filterType {
            viewModel.clips.filter { $0.type == filterType }
        } else {
            viewModel.clips
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        Group {
            if viewModel.clips.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No Clips Yet",
                    systemImage: "film.stack",
                    description: Text("Event clips will appear here when barks or whines are detected.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        filterBar

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filteredClips) { clip in
                                Button {
                                    selectedClip = clip
                                } label: {
                                    ClipCardView(clip: clip, viewModel: viewModel)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle("Clips")
        .overlay {
            if viewModel.isLoading && viewModel.clips.isEmpty {
                ProgressView()
            }
        }
        .refreshable {
            await viewModel.loadClips()
        }
        .task {
            viewModel.configure(with: settingsVM.savedConfiguration)
            await viewModel.loadClips()
        }
        .onChange(of: settingsVM.savedConfiguration) {
            viewModel.configure(with: settingsVM.savedConfiguration)
            Task { await viewModel.loadClips() }
        }
        .sheet(item: $selectedClip) { clip in
            ClipPlayerView(clip: clip, clipsViewModel: viewModel)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: filterType == nil) {
                    withAnimation { filterType = nil }
                }
                FilterChip(title: "Barks", isSelected: filterType == .bark, color: .red) {
                    withAnimation { filterType = .bark }
                }
                FilterChip(title: "Whines", isSelected: filterType == .whine, color: .yellow) {
                    withAnimation { filterType = .whine }
                }
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? color : Color(.tertiarySystemFill))
                .clipShape(Capsule())
        }
    }
}
