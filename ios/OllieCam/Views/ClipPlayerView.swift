import AVKit
import SwiftUI

struct ClipPlayerView: View {
    let clip: ClipMetadata
    let clipsViewModel: ClipsViewModel

    @State private var player: AVPlayer?
    @State private var showDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .navigationTitle(clip.type.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Delete this clip?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete Clip", role: .destructive) {
                    Task {
                        await clipsViewModel.deleteClip(clip)
                        dismiss()
                    }
                }
            } message: {
                Text("This clip will be permanently removed from the server.")
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .task {
            guard let url = await clipsViewModel.clipURL(for: clip) else { return }
            let avPlayer = AVPlayer(url: url)
            player = avPlayer
            avPlayer.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
