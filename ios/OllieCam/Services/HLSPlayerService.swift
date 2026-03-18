import AVFoundation
import Observation

@MainActor
@Observable
final class HLSPlayerService {
    private(set) var player: AVPlayer?
    private(set) var isPlaying = false
    private(set) var isMuted = true

    private var playerItem: AVPlayerItem?
    private var rateObservation: NSKeyValueObservation?

    func configure(streamURL: URL, authHeader: String?) {
        stop()

        var options: [String: Any] = [:]
        if let authHeader {
            options["AVURLAssetHTTPHeaderFieldsKey"] = ["Authorization": authHeader]
        }

        let asset = AVURLAsset(url: streamURL, options: options)
        let item = AVPlayerItem(asset: asset)
        playerItem = item

        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.allowsExternalPlayback = false
        avPlayer.isMuted = true
        player = avPlayer

        rateObservation = avPlayer.observe(\.rate) { [weak self] player, _ in
            Task { @MainActor in
                guard let self else { return }
                self.isPlaying = player.rate > 0
            }
        }
    }

    func play() {
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func stop() {
        rateObservation?.invalidate()
        rateObservation = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerItem = nil
        isPlaying = false
    }

    func seekToLive() {
        guard let item = playerItem else { return }
        let seekableRanges = item.seekableTimeRanges
        guard let lastRange = seekableRanges.last?.timeRangeValue else { return }
        let livePosition = CMTimeAdd(lastRange.start, lastRange.duration)
        player?.seek(to: livePosition)
    }

    func toggleMute() {
        isMuted.toggle()
        player?.isMuted = isMuted
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        player?.isMuted = muted
    }
}
