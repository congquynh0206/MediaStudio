//
//  VideoEditViewController.swift
//  MediaStudio
//
//  Created by Trangptt on 30/1/26.
//


import UIKit
import AVFoundation
import PryntTrimmerView

class VideoEditViewController: UIViewController {
    
    var videoItem: MediaItem?
    
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var playbackTimeChecker: Timer?
    
    private var didLoadAsset = false
    
    // UI Components
    private let playerContainer = UIView()
    private let trimmerView = TrimmerView()
    private let playPauseButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Trim Video"
        
        
        setupUI()
        setupPlayer()
        
        // Nút Cancel
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(didTapCancel))
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = playerContainer.bounds
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Chỉ nạp asset 1 lần duy nhất khi view đã hiện xong
        if !didLoadAsset, let item = videoItem, let url = item.fullFileURL {
            let asset = AVURLAsset(url: url)
            trimmerView.asset = asset
            trimmerView.delegate = self
            didLoadAsset = true
        }
    }
    
    // Setup player
    private func setupPlayer() {
        guard let item = videoItem, let url = item.fullFileURL else { return }
        
        let asset = AVURLAsset(url: url)
        
        // Setup Player
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspect
        playerContainer.layer.addSublayer(playerLayer!)
        
        // Nạp Asset
        trimmerView.asset = asset
        trimmerView.delegate = self // Lắng nghe sự kiện kéo thả
        
        // Theo dõi thời gian chạy để di chuyển thanh kim chỉ
        startPlaybackTimeChecker()
    }
    
    // Timer để cập nhật thanh kim chạy trên timeline
    private func startPlaybackTimeChecker() {
        stopPlaybackTimeChecker()
        playbackTimeChecker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            
            // Nếu video chạy đến điểm cuối của vùng chọn thì dừng lại
            let startTime = trimmerView.startTime ?? .zero
            let endTime = trimmerView.endTime ?? player.currentItem?.duration ?? .zero
            
            if player.currentTime() >= endTime {
                player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
                player.pause()
                self.updatePlayButtonIcon()
            }
            
            // Cập nhật vị trí thanh kim chỉ
            self.trimmerView.seek(to: player.currentTime())
        }
    }
    
    private func stopPlaybackTimeChecker() {
        playbackTimeChecker?.invalidate()
        playbackTimeChecker = nil
    }
    
    // MARK: - Actions
    @objc private func didTapPlayPause() {
        guard let player = player else { return }
        
        if player.timeControlStatus == .playing {
            player.pause()
            setPlayButtonIcon(isPlaying: false)
            
        } else {
            let startTime = trimmerView.startTime ?? .zero
            let endTime = trimmerView.endTime ?? player.currentItem?.duration ?? .zero
            
            if player.currentTime() >= endTime {
                player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
            }
            player.play()
            setPlayButtonIcon(isPlaying: true)
        }
    }
    
    // Hàm đổi icon
    private func setPlayButtonIcon(isPlaying: Bool) {
        let iconName = isPlaying ? "pause.circle.fill" : "play.circle.fill"
        let config = UIImage.SymbolConfiguration(pointSize: 50)
        playPauseButton.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
    }
    
    private func updatePlayButtonIcon() {
        let iconName = (player?.timeControlStatus == .playing) ? "pause.circle.fill" : "play.circle.fill"
        let config = UIImage.SymbolConfiguration(pointSize: 50)
        playPauseButton.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
    }
    
    @objc private func didTapSave() {
        player?.pause()
        updatePlayButtonIcon()
        
        guard let item = videoItem, let sourceURL = item.fullFileURL else { return }
        
        // Lấy thời gian từ Trimmer View convert sang Double
        let startTime = trimmerView.startTime?.seconds ?? 0.0
        let endTime = trimmerView.endTime?.seconds ?? player?.currentItem?.duration.seconds ?? 0.0
        
        let loadingAlert = UIAlertController(title: "Exporting...", message: "Processing video...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        Task {
            do {
                let newURL = try await VideoRepository.shared.trimVideo(sourceURL: sourceURL, startTime: startTime, endTime: endTime)
                
                // Lưu vào db
                let newDuration = endTime - startTime
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let relativePath = newURL.path.replacingOccurrences(of: documentsURL.path + "/", with: "")
                
                let newItem = MediaItem(
                    id: UUID().uuidString,
                    name: "Cut_\(item.name)",
                    type: .video,
                    relativePath: relativePath,
                    duration: newDuration,
                    createdAt: Date(),
                    isDeleted: false,
                    deletedDate: nil
                )
                
                try await MediaRepository.shared.save(item: newItem)
                
                await MainActor.run {
                    loadingAlert.dismiss(animated: true) {
                        self.dismiss(animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    loadingAlert.dismiss(animated: true) {
                        self.showAlert(msg: "Failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    @objc private func didTapCancel() {
        stopPlaybackTimeChecker()
        dismiss(animated: true)
    }
    
    private func showAlert(msg: String) {
        let alert = UIAlertController(title: "Info", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Setup UI
    private func setupUI() {
        view.addSubview(playerContainer)
        view.addSubview(trimmerView)
        view.addSubview(playPauseButton)
        view.addSubview(saveButton)
        
        trimmerView.handleColor = .white
        trimmerView.mainColor = .systemYellow // Màu của khung chọn
        trimmerView.positionBarColor = .white // Màu thanh kim chạy
        trimmerView.maxDuration = 60.0 // Giới hạn cắt tối đa
        trimmerView.minDuration = 3.0  // Giới hạn cắt tối thiểu
        
       
        playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 50)), for: .normal)
        playPauseButton.tintColor = .systemYellow
        playPauseButton.layer.cornerRadius = 6
        playPauseButton.layer.maskedCorners = [
            .layerMinXMinYCorner, // top-left
            .layerMinXMaxYCorner  // bottom-left
        ]
        playPauseButton.addTarget(self, action: #selector(didTapPlayPause), for: .touchUpInside)
        
        saveButton.setTitle("Export Video", for: .normal)
        saveButton.backgroundColor = .systemYellow
        saveButton.setTitleColor(.black, for: .normal)
        saveButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        saveButton.layer.cornerRadius = 25
        saveButton.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)
        
        // Layout
        playerContainer.translatesAutoresizingMaskIntoConstraints = false
        trimmerView.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Video ở trên cùng
            playerContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            playerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerContainer.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.65),
            
            // Trimmer View ở dưới
            trimmerView.topAnchor.constraint(equalTo: playerContainer.bottomAnchor, constant: 20),
            trimmerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 60),
            trimmerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            trimmerView.heightAnchor.constraint(equalToConstant: 50), // Chiều cao thanh timeline
            
            // Nút Play ở giữa timeline và nút Save
            playPauseButton.topAnchor.constraint(equalTo: playerContainer.bottomAnchor, constant: 20),
            playPauseButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            playPauseButton.trailingAnchor.constraint(equalTo: trimmerView.leadingAnchor, constant: 0),
            playPauseButton.heightAnchor.constraint(equalToConstant: 50),
            playPauseButton.widthAnchor.constraint(equalToConstant: 50),
            
            // Nút Save ở dưới cùng
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            saveButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
}

// MARK: - TrimmerViewDelegate
extension VideoEditViewController: TrimmerViewDelegate {
    
    // Khi user kéo thanh timeline -> Cập nhật Player
    func didChangePositionBar(_ playerTime: CMTime) {
        player?.pause()
        player?.seek(to: playerTime, toleranceBefore: .zero, toleranceAfter: .zero)
        updatePlayButtonIcon()
    }
    
    // Khi user kéo đầu mút trái/phải -> Seek player đến vị trí đó để xem thử
    func positionBarStoppedMoving(_ playerTime: CMTime) {
        player?.seek(to: playerTime, toleranceBefore: .zero, toleranceAfter: .zero)
        // updatePlayButtonIcon()
    }
}
