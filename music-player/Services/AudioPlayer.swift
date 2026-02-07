//
//  AudioPlayer.swift
//  music-player
//
//  AVPlayer wrapper for audio playback
//

import Foundation
import AVFoundation
import Combine

@MainActor
class AudioPlayer: ObservableObject {
    static let shared = AudioPlayer()

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    @Published var currentSong: Song?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isBuffering = false
    @Published var queue: [Song] = []
    @Published var currentIndex: Int = 0

    private init() {
        setupAudioSession()
    }

    deinit {
        // Clean up time observer - need to capture player reference
        // since we can't call MainActor methods from deinit
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
        }
    }

    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        // macOS doesn't require audio session configuration like iOS
        // AVPlayer works directly
    }

    // MARK: - Play Song
    func play(song: Song) {
        guard let streamURL = song.streamURL else {
            print("No stream URL available for song: \(song.name)")
            return
        }

        // Stop current playback
        stop()

        currentSong = song
        duration = song.durationSeconds

        // Create player item and player
        playerItem = AVPlayerItem(url: streamURL)
        player = AVPlayer(playerItem: playerItem)

        // Observe player status
        observePlayerStatus()

        // Add time observer
        addTimeObserver()

        // Start playback
        player?.play()
        isPlaying = true
    }

    // MARK: - Play from Queue
    func play(song: Song, queue: [Song]) {
        self.queue = queue
        if let index = queue.firstIndex(where: { $0.id == song.id }) {
            currentIndex = index
        }
        play(song: song)
    }

    // MARK: - Toggle Play/Pause
    func togglePlayPause() {
        guard player != nil else { return }

        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }

    // MARK: - Pause
    func pause() {
        player?.pause()
        isPlaying = false
    }

    // MARK: - Resume
    func resume() {
        player?.play()
        isPlaying = true
    }

    // MARK: - Stop
    func stop() {
        removeTimeObserver()
        player?.pause()
        player = nil
        playerItem = nil
        isPlaying = false
        currentTime = 0
    }

    // MARK: - Seek
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }

    // MARK: - Seek by Percentage
    func seek(toPercentage percentage: Double) {
        let time = duration * percentage
        seek(to: time)
    }

    // MARK: - Next
    func next() {
        guard !queue.isEmpty else { return }

        let nextIndex = currentIndex + 1
        if nextIndex < queue.count {
            currentIndex = nextIndex
            play(song: queue[nextIndex])
        } else {
            // Loop back to first song
            currentIndex = 0
            play(song: queue[0])
        }
    }

    // MARK: - Previous
    func previous() {
        guard !queue.isEmpty else { return }

        // If more than 3 seconds into song, restart current song
        if currentTime > 3 {
            seek(to: 0)
            return
        }

        let prevIndex = currentIndex - 1
        if prevIndex >= 0 {
            currentIndex = prevIndex
            play(song: queue[prevIndex])
        } else {
            // Loop to last song
            currentIndex = queue.count - 1
            play(song: queue[currentIndex])
        }
    }

    // MARK: - Add to Queue
    func addToQueue(song: Song) {
        queue.append(song)
    }

    // MARK: - Clear Queue
    func clearQueue() {
        queue = []
        currentIndex = 0
    }

    // MARK: - Time Observer
    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds

                // Update duration from player item if available
                if let duration = self?.playerItem?.duration.seconds,
                   duration.isFinite && duration > 0 {
                    self?.duration = duration
                }
            }
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    // MARK: - Player Status Observer
    private func observePlayerStatus() {
        playerItem?.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .readyToPlay:
                    self?.isBuffering = false
                    if let duration = self?.playerItem?.duration.seconds,
                       duration.isFinite && duration > 0 {
                        self?.duration = duration
                    }
                case .failed:
                    print("Player failed: \(self?.playerItem?.error?.localizedDescription ?? "Unknown error")")
                    self?.isBuffering = false
                case .unknown:
                    self?.isBuffering = true
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)

        // Observe when playback ends
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.next()
            }
            .store(in: &cancellables)
    }

    // MARK: - Formatted Time Strings
    var currentTimeFormatted: String {
        formatTime(currentTime)
    }

    var durationFormatted: String {
        formatTime(duration)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
