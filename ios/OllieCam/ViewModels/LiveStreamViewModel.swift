import Observation
import UIKit

@MainActor
@Observable
final class LiveStreamViewModel {
    // Stream state
    private(set) var snapshotImage: UIImage?
    private(set) var isLoading = false
    private(set) var isConnectedSSE = false
    private(set) var errorMessage: String?
    private(set) var isStreamActive = false

    // Detection (received via SSE)
    private(set) var activityLog: [BarkEvent] = []
    private(set) var currentAlert: BarkEvent?

    // Services
    let playerService = HLSPlayerService()
    private var apiClient: APIClient?
    private var sseClient: SSEClient?
    private var currentConfig: ServerConfiguration = .empty

    // Tasks
    private var sseTask: Task<Void, Never>?
    private var alertDismissTask: Task<Void, Never>?

    // Dedup
    private var lastAlertTime: Date = .distantPast

    var isMuted: Bool { playerService.isMuted }

    func configure(with configuration: ServerConfiguration) async {
        currentConfig = configuration

        let client = APIClient(configuration: configuration)
        apiClient = client

        let sse = SSEClient(configuration: configuration)
        sseClient = sse

        await loadSnapshot()
    }

    // MARK: - Snapshot

    func loadSnapshot() async {
        guard let client = apiClient else { return }
        isLoading = true
        do {
            snapshotImage = try await client.fetchSnapshot()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Playback

    func startStream() async {
        guard let client = apiClient,
              let streamURL = await client.streamURL() else { return }

        isStreamActive = true
        playerService.configure(streamURL: streamURL, authHeader: currentConfig.authHeader)
        playerService.play()

        connectSSE()
    }

    func stopStream() async {
        isStreamActive = false
        playerService.stop()
        disconnectSSE()
        await loadSnapshot()
    }

    func toggleMute() {
        playerService.toggleMute()
    }

    // MARK: - SSE

    private func connectSSE() {
        guard let sseClient else { return }

        disconnectSSE()

        sseTask = Task {
            let stream = await sseClient.connect()

            // Monitor connection status
            Task {
                while !Task.isCancelled {
                    isConnectedSSE = await sseClient.isConnected
                    try? await Task.sleep(for: .seconds(1))
                }
            }

            for await event in stream {
                if Task.isCancelled { break }
                handleSSEEvent(event)
            }
            isConnectedSSE = false
        }
    }

    private func disconnectSSE() {
        sseTask?.cancel()
        sseTask = nil
        if let sseClient {
            Task { await sseClient.disconnect() }
        }
        isConnectedSSE = false
    }

    private func handleSSEEvent(_ event: SSEEvent) {
        handleDetection(type: event.type, confidence: event.confidence)

        if let clip = event.clip {
            NotificationCenter.default.post(
                name: .newClipAvailable,
                object: nil,
                userInfo: ["clip": clip]
            )
        }
    }

    // MARK: - Detection Handling

    private func handleDetection(type: DetectionType, confidence: Double) {
        let now = Date.now
        guard now.timeIntervalSince(lastAlertTime) > Constants.SSE.dedupWindow else { return }
        lastAlertTime = now

        let event = BarkEvent(type: type, confidence: confidence)

        activityLog.insert(event, at: 0)
        if activityLog.count > Constants.UserInterface.maxActivityLogEntries {
            activityLog.removeLast()
        }

        showAlert(event)
    }

    private func showAlert(_ event: BarkEvent) {
        alertDismissTask?.cancel()
        currentAlert = event

        alertDismissTask = Task {
            try? await Task.sleep(for: .seconds(Constants.UserInterface.alertDismissDelay))
            if !Task.isCancelled {
                currentAlert = nil
            }
        }
    }

    func dismissAlert() {
        alertDismissTask?.cancel()
        currentAlert = nil
    }

    // MARK: - Lifecycle

    func onDisappear() {
        playerService.stop()
        disconnectSSE()
    }

    func onSceneActive() {
        if isStreamActive {
            connectSSE()
            playerService.seekToLive()
        }
    }

    func onSceneInactive() {
        disconnectSSE()
    }
}

extension Notification.Name {
    static let newClipAvailable = Notification.Name("newClipAvailable")
}
