import SwiftUI

struct LiveStreamView: View {
    @Environment(SettingsViewModel.self) private var settingsVM
    @State private var viewModel = LiveStreamViewModel()
    @State private var clipsVM = ClipsViewModel()
    @State private var showSettings = false
    @State private var showClipPlayer: ClipMetadata?
    @State private var isFullScreen = false

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: Constants.UserInterface.backgroundColor)
                .ignoresSafeArea()

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
            await viewModel.configure(with: settingsVM.savedConfiguration)
            clipsVM.configure(with: settingsVM.savedConfiguration)
            await clipsVM.loadClips()
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(isInitialSetup: false)
            }
        }
        .sheet(item: $showClipPlayer) { clip in
            ClipPlayerView(clip: clip, clipsViewModel: clipsVM)
        }
        .onChange(of: settingsVM.savedConfiguration) {
            Task {
                await viewModel.configure(with: settingsVM.savedConfiguration)
                clipsVM.configure(with: settingsVM.savedConfiguration)
                await clipsVM.loadClips()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isFullScreen)
        .statusBarHidden(isFullScreen)
    }

    // MARK: - Normal Layout

    private var normalView: some View {
        VStack(spacing: 0) {
            headerBar
            videoArea
            controlBar
            ActivityLogView(events: viewModel.activityLog)
            ClipsTimelineView(viewModel: clipsVM) { clip in
                showClipPlayer = clip
            }
        }
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
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.red)
                    .clipShape(.rect(cornerRadius: 4))
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
        .background(.black.opacity(0.5))
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            StatusIndicatorView(
                isPlaying: viewModel.isStreamActive,
                isConnectedSSE: viewModel.isConnectedSSE
            )

            Spacer()

            Text("OllieCam")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gear")
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
                    .fill(Color.black)
                    .overlay {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            playOverlay
                        }
                    }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var playOverlay: some View {
        Button {
            Task { await viewModel.startStream() }
        } label: {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 24) {
            Button {
                if viewModel.isStreamActive {
                    Task { await viewModel.stopStream() }
                } else {
                    Task { await viewModel.startStream() }
                }
            } label: {
                Image(systemName: viewModel.isStreamActive ? "pause.fill" : "play.fill")
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

            if viewModel.isStreamActive {
                Button {
                    viewModel.playerService.seekToLive()
                } label: {
                    Text("LIVE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.red)
                        .clipShape(.rect(cornerRadius: 4))
                }

                Spacer()

                Button {
                    withAnimation { isFullScreen = true }
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
