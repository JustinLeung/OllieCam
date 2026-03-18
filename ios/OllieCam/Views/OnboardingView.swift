import SwiftUI

struct OnboardingView: View {
    @Environment(ServerStore.self) private var serverStore
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(\.openURL) private var openURL

    @State private var currentPage = 0
    @State private var connectedServer: ServerConfiguration?
    @State private var snapshotImage: UIImage?
    @State private var isConnecting = false
    @State private var ntfyInstallTapped = false
    @State private var ntfySubscribeTapped = false
    @State private var testNotificationSent = false

    let onComplete: () -> Void

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)
            connectPage.tag(1)
            if showNotificationsPage {
                notificationsPage.tag(2)
                completionPage.tag(3)
            } else {
                completionPage.tag(2)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .animation(.easeInOut(duration: 0.3), value: currentPage)
    }

    private var showNotificationsPage: Bool {
        connectedServer?.hasNotifications == true
    }

    private var lastPage: Int {
        showNotificationsPage ? 3 : 2
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "pawprint.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("Welcome to OllieCam")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Keep an eye on your pup from anywhere")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                featureRow(icon: "video.fill", color: .blue, text: "Watch your dog live")
                featureRow(icon: "waveform.badge.magnifyingglass", color: .orange, text: "Bark & whine detection")
                featureRow(icon: "bell.badge", color: .red, text: "Push notifications to your phone")
            }
            .padding(.horizontal, 40)

            Spacer()

            Button {
                withAnimation { currentPage = 1 }
            } label: {
                Text("Get Started")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 32)
            Text(text)
                .font(.body)
        }
    }

    // MARK: - Page 2: Connect

    private var connectPage: some View {
        @Bindable var settingsVM = settingsVM

        return VStack(spacing: 24) {
            Spacer()

            if let snapshot = snapshotImage {
                Image(uiImage: snapshot)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 16))
                    .overlay(
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                            .shadow(radius: 4)
                    )
                    .padding(.horizontal, 32)
                    .transition(.scale.combined(with: .opacity))

                Text("Connected!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)

                Text("Connect to Your Server")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Enter the URL shown in your OllieCam terminal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    TextField("Server URL", text: $settingsVM.serverURL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(.rect(cornerRadius: 12))

                    SecureField("Password (optional)", text: $settingsVM.password)
                        .textContentType(.password)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(.rect(cornerRadius: 12))
                }
                .padding(.horizontal, 32)

                if let error = settingsVM.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            if connectedServer != nil {
                Button {
                    withAnimation { currentPage = showNotificationsPage ? 2 : lastPage }
                } label: {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 32)
            } else {
                Button {
                    Task { await connectServer() }
                } label: {
                    if isConnecting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Connect")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(settingsVM.serverURL.isEmpty || isConnecting)
                .padding(.horizontal, 32)
            }

            Spacer().frame(height: 48)
        }
    }

    private func connectServer() async {
        isConnecting = true
        // prepareForAdd sets a stable UUID; preserve the user's typed URL/password
        let url = settingsVM.serverURL
        let password = settingsVM.password
        settingsVM.prepareForAdd()
        settingsVM.serverURL = url
        settingsVM.password = password
        guard let config = await settingsVM.testConnection() else {
            isConnecting = false
            return
        }

        serverStore.addServer(config)
        connectedServer = config

        // Fetch notification config
        await settingsVM.fetchNotificationConfig(for: config, store: serverStore)
        // Re-read from store since ntfy config was saved there
        if let updated = serverStore.activeServer {
            connectedServer = updated
        }

        // Try to load a snapshot for the delight moment
        let client = APIClient(configuration: config)
        snapshotImage = try? await client.fetchSnapshot()

        isConnecting = false
    }

    // MARK: - Page 3: Notifications

    private var notificationsPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("Never Miss a Bark")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Get push notifications when your dog barks or whines")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(alignment: .leading, spacing: 16) {
                ntfyStep(
                    number: 1,
                    title: "Install the ntfy app",
                    subtitle: "Free push notification app",
                    icon: "arrow.down.app",
                    isDone: ntfyInstallTapped
                ) {
                    if let url = URL(string: "https://apps.apple.com/app/ntfy/id1625396347") {
                        openURL(url)
                        ntfyInstallTapped = true
                    }
                }

                ntfyStep(
                    number: 2,
                    title: "Subscribe to your topic",
                    subtitle: connectedServer?.ntfyTopic ?? "",
                    icon: "app.badge",
                    isDone: ntfySubscribeTapped
                ) {
                    if let url = connectedServer?.ntfySubscribeURL {
                        openURL(url)
                        ntfySubscribeTapped = true
                    }
                }

                ntfyStep(
                    number: 3,
                    title: "Send a test notification",
                    subtitle: testNotificationSent ? "Sent!" : "Verify it works",
                    icon: "paperplane.fill",
                    isDone: testNotificationSent
                ) {
                    if let server = connectedServer {
                        Task {
                            await settingsVM.sendTestNotification(for: server)
                            testNotificationSent = settingsVM.notificationTestStatus == .sent
                        }
                    }
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    withAnimation { currentPage = lastPage }
                } label: {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Skip for now") {
                    withAnimation { currentPage = lastPage }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private func ntfyStep(number: Int, title: String, subtitle: String, icon: String, isDone: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isDone ? Color.green : Color(.tertiarySystemFill))
                        .frame(width: 36, height: 36)
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    } else {
                        Text("\(number)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: icon)
                    .foregroundStyle(.tint)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    // MARK: - Page 4: Completion

    private var completionPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "pawprint.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
                .symbolEffect(.bounce, value: currentPage == lastPage)

            VStack(spacing: 8) {
                Text("You're All Set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                if let name = connectedServer?.name, !name.isEmpty {
                    Text("Connected to \(name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                onComplete()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Watching")
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}
