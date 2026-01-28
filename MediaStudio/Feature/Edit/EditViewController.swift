//
//  EditViewController.swift
//  MediaStudio
//
//  Created by Trangptt on 27/1/26.
//

import UIKit
import AVFoundation
import WARangeSlider
import DSWaveformImage
import DSWaveformImageViews

class EditViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var waveformImageView: WaveformImageView!
    @IBOutlet weak var rangeSlider: RangeSlider!
    @IBOutlet weak var startLabel: UILabel!
    @IBOutlet weak var endLabel: UILabel!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var previewButton: UIButton!
    
    @IBOutlet weak var volumeLabel: UILabel!
    @IBOutlet weak var volumeSlider: UISlider!
    
    // MARK: - Components
    private let selectionBox = UIView()
    
    private let playbackIndicator = UIView()
    
    // MARK: - Data & Player
    var itemToEdit: MediaItem?
    
    var onDidSave: (() -> Void)?
    
    var currentVolume: Float = 1.0
    
    // Trình phát nhạc
    var player: AVPlayer?
    var timeObserver: Any?
    var isPreviewing = false // Trạng thái đang nghe thử hay không
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupSelectionBox()
        setupVolumeControl()
        setupPlaybackIndicator()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateSelectionBoxFrame()
    }
    
    // Khi thoát màn hình thì tắt nhạc
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPreview()
    }
    
    // Thanh chỉ
    private func setupPlaybackIndicator() {
        playbackIndicator.backgroundColor = .white
        playbackIndicator.frame = CGRect(x: 0, y: 0, width: 2, height: 0)
        playbackIndicator.isHidden = true
        
        waveformImageView.addSubview(playbackIndicator)
    }
    
    private func setupUI() {
        guard let item = itemToEdit, let fileURL = item.fullFileURL else { return }
        
        // Tên
        titleLabel.text = item.name
        
        // Sóng âm
        waveformImageView.backgroundColor = .clear
        let waveConfig = Waveform.Configuration(
            style: .striped(.init(color: .systemBlue, width: 3, spacing: 2)),
            verticalScalingFactor: 0.8
        )
        waveformImageView.configuration = waveConfig
        waveformImageView.waveformAudioURL = fileURL
        
        // Slider
        rangeSlider.backgroundColor = .clear
        rangeSlider.minimumValue = 0.0
        rangeSlider.maximumValue = item.duration
        rangeSlider.lowerValue = 0.0
        rangeSlider.upperValue = item.duration
        
        rangeSlider.trackHighlightTintColor = .systemBlue
        rangeSlider.trackTintColor = .darkGray
        rangeSlider.thumbTintColor = .white
        
        rangeSlider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        
        // Player
        let asset = AVURLAsset(url: fileURL)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        
        updateLabels(start: 0, end: item.duration)
    }
    
    // Volume
    private func setupVolumeControl() {
        // Min 0% - Max 200% (2.0)
        volumeSlider.minimumValue = 0.0
        volumeSlider.maximumValue = 2.0
        volumeSlider.value = 1.0 // Mặc định 100%
        
        volumeSlider.thumbTintColor = .white
        
        volumeLabel.text = "Volume: 100%"
        
        // Lắng nghe sự kiện kéo
        volumeSlider.addTarget(self, action: #selector(volumeChanged(_:)), for: .valueChanged)
    }
    
    // Xử lý khi kéo volume
    @objc func volumeChanged(_ slider: UISlider) {
        currentVolume = slider.value
        let percentage = Int(currentVolume * 100)
        volumeLabel.text = "Volume: \(percentage)%"
        
        applyVolumeToPlayer()
    }
    
    // Hàm để kích âm lượng
    private func applyVolumeToPlayer() {
        guard let playerItem = player?.currentItem else { return }
        Task {
            do {
                if let audioMix = try await AudioHelper.createAudioMix(for: playerItem.asset, volume: currentVolume) {
                    playerItem.audioMix = audioMix
                }
            } catch {
                print("Lỗi chỉnh volume: \(error)")
            }
        }
    }
    
    private func setupSelectionBox() {
        selectionBox.layer.borderColor = UIColor.systemYellow.cgColor
        selectionBox.layer.borderWidth = 2
        selectionBox.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.2)
        selectionBox.isUserInteractionEnabled = false
        waveformImageView.addSubview(selectionBox)
    }
    
    // MARK: - Logic Slider
    @objc func sliderValueChanged(_ slider: RangeSlider) {
        // Nếu đang nghe thử mà kéo slider thì dừng lại ngay
        if isPreviewing {
            stopPreview()
        }
        
        updateLabels(start: slider.lowerValue, end: slider.upperValue)
        updateSelectionBoxFrame()
    }
    
    private func updateSelectionBoxFrame() {
        let duration = rangeSlider.maximumValue
        if duration == 0 { return }
        
        let waveWidth = waveformImageView.bounds.width
        let waveHeight = waveformImageView.bounds.height
        
        let startRatio = CGFloat(rangeSlider.lowerValue / duration)
        let endRatio = CGFloat(rangeSlider.upperValue / duration)
        
        let startX = startRatio * waveWidth
        let endX = endRatio * waveWidth
        
        selectionBox.frame = CGRect(x: startX, y: 0, width: endX - startX, height: waveHeight)
    }
    
    // MARK: - Nghe Thử
    
    @IBAction func didTapPreviewButton(_ sender: Any) {
        if isPreviewing {
            stopPreview()
        } else {
            startPreview()
        }
    }
    
    private func startPreview() {
        guard let player = player else { return }
        
        let startTime = rangeSlider.lowerValue
        let endTime = rangeSlider.upperValue
        let totalDuration = rangeSlider.maximumValue
        
        // Tua đến điểm bắt đầu (startTime)
        let targetTime = CMTime(seconds: startTime, preferredTimescale: 600)
        player.seek(to: targetTime)
        
        // Bắt đầu phát
        player.play()
        isPreviewing = true
        previewButton.setImage(UIImage(systemName: "stop.fill"), for: .normal)
        
        // Bật thanh chỉ
        playbackIndicator.isHidden = false
        playbackIndicator.frame.size.height = waveformImageView.bounds.height
        
        // Nếu chạy qua điểm End thì dừng lại
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            let currentSeconds = time.seconds
            
            // Tính vị trí X trên màn hình
            if totalDuration > 0 {
                let ratio = CGFloat(currentSeconds / totalDuration)
                let waveWidth = self.waveformImageView.bounds.width
                let currentX = ratio * waveWidth
                
                // Di chuyển thanh kim chỉ
                self.playbackIndicator.frame.origin.x = currentX
            }
            
            if time.seconds >= endTime {
                self.stopPreview()
            }
        }
    }
    
    private func stopPreview() {
        player?.pause()
        isPreviewing = false
        
        // Hủy theo dõi thời gian
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        previewButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playbackIndicator.isHidden = true
    }
    
    // MARK: - Helper
    private func updateLabels(start: Double, end: Double) {
        startLabel.text = formatTime(start)
        endLabel.text = formatTime(end)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Cancel , Save
    @IBAction func didTapCancel(_ sender: Any) {
        dismiss(animated: true)
    }
    
    @IBAction func didTapSave(_ sender: Any) {
        let alert = UIAlertController(title: "Save Changes", message: "How would you like to save this trimmed file?", preferredStyle: .actionSheet)
        
        //  Lưu thành file mới
        let newFileAction = UIAlertAction(title: "Save as a new file", style: .default) { [weak self] _ in
            self?.processSave(isOverwrite: false)
        }
        
        // Ghi đè file gốc
        let overwriteAction = UIAlertAction(title: "Replace the original file.", style: .destructive) { [weak self] _ in
            self?.processSave(isOverwrite: true)
        }
        
        // Hủy
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alert.addAction(newFileAction)
        alert.addAction(overwriteAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    // Hàm xử lý cắt và lưu vào DB
    private func processSave(isOverwrite: Bool) {
        guard let item = itemToEdit, let sourceURL = item.fullFileURL else { return }
        
        let startTime = rangeSlider.lowerValue
        let endTime = rangeSlider.upperValue
        let newDuration = endTime - startTime
        
        // Hiện loading
        let loadingAlert = UIAlertController(title: "Processing...", message: nil, preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        // Gọi hàm cắt file
        exportAudio(sourceURL: sourceURL, startTime: startTime, endTime: endTime, volume: currentVolume) { [weak self] newURL in
            guard let self = self else { return }
            
            // Xử lý Database trong luồng chính
            DispatchQueue.main.async {
                if let newURL = newURL {
                    Task {
                        do {
                            let newFileName = newURL.lastPathComponent
                            
                            if isOverwrite {
                                // Ghi đè
                                try await MediaRepository.shared.updateAfterTrim(
                                    itemID: item.id,
                                    newRelativePath: newFileName,
                                    newDuration: newDuration
                                )
                            } else {
                                // Tạo file mới
                                try await MediaRepository.shared.saveAsNewItem(
                                    originalName: item.name,
                                    relativePath: newFileName,
                                    duration: newDuration
                                )
                            }
                            
                            // Xong thi đóng loading và đóng màn hình edit
                            loadingAlert.dismiss(animated: true) {
                                self.onDidSave?() // Báo reload
                                self.dismiss(animated: true)
                            }
                            
                        } catch {
                            print("Lỗi DB: \(error)")
                            loadingAlert.message = "Lỗi lưu dữ liệu"
                        }
                    }
                } else {
                    loadingAlert.dismiss(animated: true)
                }
            }
        }
    }
    
    private func exportAudio(sourceURL: URL, startTime: Double, endTime: Double, volume: Float, completion: @escaping (URL?) -> Void) {
        let asset = AVURLAsset(url: sourceURL)
        
        Task {
            // Kiểm tra tính tương thích
            guard await AVAssetExportSession.compatibility(ofExportPreset: AVAssetExportPresetAppleM4A, with: asset, outputFileType: .m4a) else {
                print("Lỗi: M4A không tương thích với asset này")
                completion(nil)
                return
            }
            
            // Tạo Session
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                completion(nil); return
            }
            
            let fileName = "Edit_\(Date().timeIntervalSince1970).m4a"
            let outputURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
            
            // Cấu hình thời gian
            let start = CMTime(seconds: startTime, preferredTimescale: 1000)
            let end = CMTime(seconds: endTime, preferredTimescale: 1000)
            exportSession.timeRange = CMTimeRange(start: start, end: end)
            
            // Cấu hình Volume (Async)
            if let audioMix = try? await AudioHelper.createAudioMix(for: asset, volume: volume) {
                exportSession.audioMix = audioMix
            }
            
            // Xuất file
            do {
                try await exportSession.export(to: outputURL, as: .m4a)
                print("Xuất file thành công: \(outputURL)")
                completion(outputURL)
            } catch {
                print("Lỗi Export: \(error)")
                completion(nil)
            }
        }
    }
}
