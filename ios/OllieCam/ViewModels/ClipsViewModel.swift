import Foundation
import Observation

@MainActor
@Observable
final class ClipsViewModel {
    private(set) var clips: [ClipMetadata] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private var apiClient: APIClient?
    private var clipNotificationTask: Task<Void, Never>?

    func configure(with configuration: ServerConfiguration) {
        apiClient = APIClient(configuration: configuration)
        observeNewClips()
    }

    func loadClips() async {
        guard let client = apiClient else { return }
        isLoading = true
        errorMessage = nil

        do {
            clips = try await client.fetchClips()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func clipURL(for clip: ClipMetadata) async -> URL? {
        await apiClient?.clipURL(for: clip.clip)
    }

    func thumbnailURL(for clip: ClipMetadata) async -> URL? {
        await apiClient?.thumbnailURL(for: clip.thumbnail)
    }

    func authHeader() async -> String? {
        // Access via the configuration
        nil
    }

    private func observeNewClips() {
        clipNotificationTask?.cancel()
        clipNotificationTask = Task {
            let notifications = NotificationCenter.default.notifications(named: .newClipAvailable)
            for await _ in notifications {
                if Task.isCancelled { break }
                await loadClips()
            }
        }
    }
}
