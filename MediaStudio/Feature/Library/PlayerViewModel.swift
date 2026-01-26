//
//  PlayerViewModel.swift
//  MediaStudio
//
//  Created by Trangptt on 26/1/26.
//


import Foundation
import AVFoundation

@MainActor
class PlayerViewModel: NSObject {
    
    // File cần phát
    let item: MediaItem
    
    var onTimeUpdate: ((Float, String) -> Void)? // Trả về giá trị Slider, chuỗi 00:00
    var onStatusChanged: ((Bool) -> Void)?       // True = Đang chạy, False = Dừng
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    init(item: MediaItem) {
        self.item = item
        super.init()
        setupPlayer()
    }
    
    private func setupPlayer() {
        guard let url = item.fullFileURL else { return }
        do {
            // Cấu hình Session
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Init Player
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
        } catch {
            print("Lỗi Player: \(error)")
        }
    }
    
    // MARK: Điều khiển
    
    func togglePlayPause() {
        guard let player = audioPlayer else { return }
        
        if player.isPlaying {
            player.pause()
            stopTimer()
            onStatusChanged?(false)
        } else {
            player.play()
            startTimer()
            onStatusChanged?(true)
        }
    }
    
    // Tua
    func seek(to value: Float) {
        // 0.0 đến 1.0
        audioPlayer?.currentTime = TimeInterval(value)
    }
    
    func seek(by seconds: TimeInterval) {
        guard let player = audioPlayer else { return }
        
        // Tính thời gian mới
        let newTime = player.currentTime + seconds
        
        // Check min max
        let clampedTime = max(0, min(newTime, player.duration))
        
        // Tua
        player.currentTime = clampedTime
        
        // Update UI
        updateMetrics()
    }
    
    var duration: TimeInterval {
        return audioPlayer?.duration ?? 0
    }
    
    var durationString: String {
        return formatTime(duration)
    }
    
    // MARK: - Timer & Helper
    
    private func startTimer() {
        stopTimer()
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
        guard let player = audioPlayer else { return }
        let current = player.currentTime
        let timeString = formatTime(current)
        
        onTimeUpdate?(Float(current), timeString)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
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
        }
    }
}
