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
    
    // MARK: - Components
    private let selectionBox = UIView()
    
    // MARK: - Data & Player
    var itemToEdit: MediaItem?
    
    var onDidSave: (() -> Void)?
    
    // Trình phát nhạc
    var player: AVPlayer?
    var timeObserver: Any?
    var isPreviewing = false // Trạng thái đang nghe thử hay không
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupSelectionBox()
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
        let playerItem = AVPlayerItem(url: fileURL)
        player = AVPlayer(playerItem: playerItem)
        
        updateLabels(start: 0, end: item.duration)
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
        
        // Tua đến điểm bắt đầu (startTime)
        let targetTime = CMTime(seconds: startTime, preferredTimescale: 600)
        player.seek(to: targetTime)
        
        // Bắt đầu phát
        player.play()
        isPreviewing = true
        previewButton.setImage(UIImage(systemName: "stop.fill"), for: .normal)
        
        // Nếu chạy qua điểm End thì dừng lại
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 10), queue: .main) { [weak self] time in
            guard let self = self else { return }
            
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
    
    // MARK: - Cancel & Save
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
        
        // Option C: Hủy
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alert.addAction(newFileAction)
        alert.addAction(overwriteAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    // Hàm xử lý logic cắt và lưu vào DB (Được tách riêng để tái sử dụng)
    private func processSave(isOverwrite: Bool) {
        guard let item = itemToEdit, let sourceURL = item.fullFileURL else { return }
        
        let startTime = rangeSlider.lowerValue
        let endTime = rangeSlider.upperValue
        let newDuration = endTime - startTime
        
        // Hiện loading
        let loadingAlert = UIAlertController(title: "Processing...", message: nil, preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        // Gọi hàm cắt file (Trim)
        trimAudio(sourceURL: sourceURL, startTime: startTime, endTime: endTime) { [weak self] newURL in
            guard let self = self else { return }
            
            // Xử lý Database trong luồng chính
            DispatchQueue.main.async {
                if let newURL = newURL {
                    Task {
                        do {
                            let newFileName = newURL.lastPathComponent
                            
                            if isOverwrite {
                                // CASE 1: GHI ĐÈ
                                try await MediaRepository.shared.updateAfterTrim(
                                    itemID: item.id,
                                    newRelativePath: newFileName,
                                    newDuration: newDuration
                                )
                            } else {
                                // CASE 2: TẠO FILE MỚI
                                try await MediaRepository.shared.saveAsNewItem(
                                    originalName: item.name,
                                    relativePath: newFileName,
                                    duration: newDuration
                                )
                            }
                            
                            // Xong xuôi -> Đóng loading -> Đóng màn hình Edit
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
                    // Có thể hiện thêm 1 alert báo lỗi ở đây nếu muốn
                }
            }
        }
    }
    
    private func trimAudio(sourceURL: URL, startTime: Double, endTime: Double, completion: @escaping (URL?) -> Void) {
        let asset = AVAsset(url: sourceURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            completion(nil); return
        }
        let fileName = "Trimmed_\(Date().timeIntervalSince1970).m4a"
        let outputURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
        
        let start = CMTime(seconds: startTime, preferredTimescale: 1000)
        let end = CMTime(seconds: endTime, preferredTimescale: 1000)
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(start: start, end: end)
        
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed: completion(outputURL)
            default: completion(nil)
            }
        }
    }
}
