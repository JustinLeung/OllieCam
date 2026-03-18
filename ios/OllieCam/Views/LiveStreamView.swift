import SwiftUI

struct LiveStreamView: View {
    @Environment(ServerStore.self) private var serverStore
    @State private var viewModel = LiveStreamViewModel()
    @State private var isFullScreen = false

    var body: some View {
        ZStack(alignment: .top) {
            if isFullScreen {
                fullScreenView
            } else {
                normalView
            }

            if let alert = viewModel.currentAlert {
                AlertBannerView(event: alert) {
                    viewModel.dismissAlert()
                }
            }
        }
        .task {
            if let server = serverStore.activeServer {
                await viewModel.configure(with: server)
            }
        }
        .onChange(of: serverStore.activeServer) {
            Task {
                if let server = serverStore.activeServer {
                    await viewModel.stopStream()
                    await viewModel.configure(with: server)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isFullScreen)
        .statusBarHidden(isFullScreen)
    }

    // MARK: - Normal Layout

    private var normalView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    videoArea

                    StatusIndicatorView(
                        isPlaying: viewModel.isStreamActive,
                        isConnectedSSE: viewModel.isConnectedSSE
                    )
                    .padding(12)
                }

                controlBar

                if !viewModel.activityLog.isEmpty {
                    Divider()
                        .padding(.horizontal)
                        .padding(.top, 4)

                    ActivityLogView(events: viewModel.activityLog)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(serverStore.activeServer?.name.isEmpty == false ? serverStore.activeServer!.name : "OllieCam")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Full Screen Layout

    private var fullScreenView: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            if viewModel.isStreamActive, let player = viewModel.playerService.player {
                VideoPlayerView(player: player)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { isFullScreen = false }
                    }
            }

            fullScreenControlBar
        }
    }

    private var fullScreenControlBar: some View {
        HStack(spacing: 24) {
            StatusIndicatorView(
                isPlaying: viewModel.isStreamActive,
                isConnectedSSE: viewModel.isConnectedSSE
            )

            Spacer()

            Button {
                Task { await viewModel.stopStream() }
                withAnimation { isFullScreen = false }
            } label: {
                Image(systemName: "pause.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            Button {
                viewModel.toggleMute()
            } label: {
                Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            Button {
                viewModel.playerService.seekToLive()
            } label: {
                Text("LIVE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.red)
                    .clipShape(Capsule())
            }

            Spacer()

            Button {
                withAnimation { isFullScreen = false }
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Video Area

    private var videoArea: some View {
        ZStack {
            if viewModel.isStreamActive, let player = viewModel.playerService.player {
                VideoPlayerView(player: player)
                    .onTapGesture {
                        withAnimation { isFullScreen = true }
                    }
            } else if let snapshot = viewModel.snapshotImage {
                Image(uiImage: snapshot)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .overlay {
                        playOverlay
                    }
            } else {
                Rectangle()
                    .fill(Color(.tertiarySystemFill))
                    .overlay {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            playOverlay
                        }
                    }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var playOverlay: some View {
        Button {
            Task { await viewModel.startStream() }
        } label: {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 64))
                .symbolRenderingMode(.hierarchical)
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 20) {
            Button {
                if viewModel.isStreamActive {
                    Task { await viewModel.stopStream() }
                } else {
                    Task { await viewModel.startStream() }
                }
            } label: {
                Image(systemName: viewModel.isStreamActive ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }

            Button {
                viewModel.toggleMute()
            } label: {
                Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }

            Spacer()

            if viewModel.isStreamActive {
                Button {
                    viewModel.playerService.seekToLive()
                } label: {
                    Text("LIVE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.red)
                        .clipShape(Capsule())
                }

                Button {
                    withAnimation { isFullScreen = true }
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}
