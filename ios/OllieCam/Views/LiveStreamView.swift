import SwiftUI

struct LiveStreamView: View {
    @Environment(ServerStore.self) private var serverStore
    @Environment(OrientationManager.self) private var orientationManager
    @State private var viewModel = LiveStreamViewModel()
    @State private var isFullScreen = false
    @State private var controlsVisible = true
    @State private var hideControlsTask: Task<Void, Never>?

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
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            handleDeviceRotation()
        }
        .onDisappear {
            if isFullScreen {
                exitFullScreen()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isFullScreen)
        .statusBarHidden(isFullScreen)
        .toolbar(isFullScreen ? .hidden : .automatic, for: .tabBar)
        .toolbar(isFullScreen ? .hidden : .automatic, for: .navigationBar)
    }

    // MARK: - Orientation

    private func handleDeviceRotation() {
        let orientation = UIDevice.current.orientation
        guard orientation == .portrait || orientation.isLandscape else { return }

        if orientation.isLandscape && !isFullScreen && viewModel.isStreamActive {
            enterFullScreen(requestLandscape: false)
        } else if orientation == .portrait && isFullScreen {
            exitFullScreen()
        }
    }

    private func enterFullScreen(requestLandscape: Bool) {
        orientationManager.setLandscapeAllowed(true)
        withAnimation(.easeInOut(duration: 0.3)) {
            isFullScreen = true
            controlsVisible = true
        }
        if requestLandscape {
            orientationManager.requestLandscape()
        }
        scheduleHideControls()
    }

    private func exitFullScreen() {
        hideControlsTask?.cancel()
        withAnimation(.easeInOut(duration: 0.3)) {
            isFullScreen = false
        }
        orientationManager.requestPortrait()
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            orientationManager.setLandscapeAllowed(false)
        }
    }

    // MARK: - Controls Visibility

    private func toggleControls() {
        if controlsVisible {
            hideControlsTask?.cancel()
            withAnimation(.easeOut(duration: 0.2)) {
                controlsVisible = false
            }
        } else {
            withAnimation(.easeIn(duration: 0.2)) {
                controlsVisible = true
            }
            scheduleHideControls()
        }
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                controlsVisible = false
            }
        }
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
            }

            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture { toggleControls() }

            if controlsVisible {
                fullScreenControlBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: controlsVisible)
        .persistentSystemOverlays(.hidden)
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
                exitFullScreen()
            } label: {
                Image(systemName: "pause.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            Button {
                viewModel.toggleMute()
                scheduleHideControls()
            } label: {
                Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            Button {
                viewModel.playerService.seekToLive()
                scheduleHideControls()
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
                exitFullScreen()
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Video Area

    private var videoArea: some View {
        ZStack {
            if viewModel.isStreamActive, let player = viewModel.playerService.player {
                VideoPlayerView(player: player)
                    .onTapGesture {
                        enterFullScreen(requestLandscape: false)
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
                    enterFullScreen(requestLandscape: true)
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
