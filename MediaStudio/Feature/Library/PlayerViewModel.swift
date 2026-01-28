//
//  PlayerViewModel.swift
//  MediaStudio
//
//  Created by Trangptt on 26/1/26.
//


import Foundation
import AVFoundation
import MediaPlayer

@MainActor
class PlayerViewModel: NSObject {
    
    // File cần phát
    let item: MediaItem
    
    var onTimeUpdate: ((Float, String) -> Void)? // Trả về giá trị Slider, chuỗi 00:00
    var onStatusChanged: ((Bool) -> Void)?       // True = Đang chạy, False = Dừng
    
    var onDurationChanged: ((Float, String) -> Void)?
    
    // Biến để theo dõi sự thay đổi
    private var durationObservation: NSKeyValueObservation?
    
    var player: AVPlayer?
    private var timer: Timer?
    
    init(item: MediaItem) {
        self.item = item
        super.init()
        setupPlayer()
        setupRemoteCommandCenter()
        updateNowPlayingInfo()
    }
    
    private func setupPlayer() {
        guard let url = item.fullFileURL else { return }
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Vì tải lâu hơn nên đợi tải xong mới hiển thị
        durationObservation = playerItem.observe(\.duration, options: [.new, .initial]) { [weak self] item, _ in
            Task { @MainActor in
                let duration = item.duration.seconds
                if !duration.isNaN && duration > 0 {
                    let durationString = self?.formatTime(duration) ?? "00:00"
                    // Bắn tín hiệu ra ngoài View
                    self?.onDurationChanged?(Float(duration), durationString)
                }
            }
        }
        
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }
    
    @objc private func playerDidFinishPlaying() {
        Task { @MainActor in
            stopTimer()
            onStatusChanged?(false)
            onTimeUpdate?(0, "00:00")
            seek(to: 0) // Tua về đầu
            updateNowPlayingInfo()
        }
    }
    // MARK: Setup lockscreen
    
    func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Nút Play
        commandCenter.playCommand.addTarget { [weak self] event in
            self?.togglePlayPause()
            return .success
        }
        
        // Nút Pause
        commandCenter.pauseCommand.addTarget { [weak self] event in
            self?.togglePlayPause()
            return .success
        }
        
        // Nút Tua
        commandCenter.skipForwardCommand.preferredIntervals = [5] // 5 giây
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            self?.seek(by: 5)
            return .success
        }
        commandCenter.skipBackwardCommand.preferredIntervals = [5]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            self?.seek(by: -5)
            return .success
        }
        
        // Thanh trượt
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: Float(event.positionTime))
            return .success
        }
    }
    
    func updateNowPlayingInfo() {
        guard let player = player else { return }
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = item.name
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
        info[MPNowPlayingInfoPropertyPlaybackRate] = (player.timeControlStatus == .playing) ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    // MARK: - Điều khiển
    
    func togglePlayPause() {
        guard let player = player else { return }
        
        // Check rate để biết đang play hay pause
        if player.timeControlStatus == .playing {
            player.pause()
            stopTimer()
            onStatusChanged?(false)
        } else {
            player.play()
            startTimer()
            onStatusChanged?(true)
        }
        updateNowPlayingInfo()
    }
    
    func seek(to value: Float) {
        let time = CMTime(seconds: Double(value), preferredTimescale: 600)
        player?.seek(to: time)
        updateMetrics()
    }
    
    func seek(by seconds: TimeInterval) {
        guard let player = player else { return }
        let currentTime = player.currentTime().seconds
        let newTime = currentTime + seconds
        let duration = self.duration
        
        // Kẹp trong khoảng 0 -> duration
        let clampedTime = max(0, min(newTime, duration))
        
        seek(to: Float(clampedTime))
    }
    
    var duration: TimeInterval {
        let seconds = player?.currentItem?.duration.seconds ?? 0
        return seconds.isNaN ? 0 : seconds
    }
    
    var durationString: String {
        return formatTime(duration)
    }
    
    // MARK: - Timer , Info
    
    private func startTimer() {
        stopTimer()
        // Cập nhật mỗi 0.1s
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetrics()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateMetrics() {
        guard let player = player else { return }
        let current = player.currentTime().seconds
        
        // Xử lý trường hợp NaN (Lỗi chia cho 0)
        let safeCurrent = current.isNaN ? 0 : current
        let timeString = formatTime(safeCurrent)
        
        onTimeUpdate?(Float(safeCurrent), timeString)
        
        // Update lockscreen thỉnh thoảng
        if Int(safeCurrent * 10) % 10 == 0 {
            updateNowPlayingInfo()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        if time.isNaN || time.isInfinite { return "00:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension PlayerViewModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stopTimer()
            self.onStatusChanged?(false)
            // Reset về 0
            self.onTimeUpdate?(0, "00:00")
            self.updateNowPlayingInfo()
        }
    }
}
