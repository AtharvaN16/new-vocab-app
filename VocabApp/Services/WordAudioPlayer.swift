import AVFoundation
import Observation

@Observable
final class WordAudioPlayer {
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    var isPlaying: Bool = false

    init() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    func toggle(url urlString: String?) {
        guard let urlString, let url = URL(string: urlString) else { return }
        if isPlaying {
            stop()
        } else {
            let item = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: item)
            player?.play()
            isPlaying = true
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                self?.stop()
            }
        }
    }

    func stop() {
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
    }

    deinit { stop() }
}
