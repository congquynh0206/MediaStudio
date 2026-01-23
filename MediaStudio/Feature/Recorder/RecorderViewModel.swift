import Foundation
import AVFoundation

// Trạng thái của Recorder
enum RecorderState {
    case idle
    case recording
    case error(String)
}

@MainActor // 1. Đánh dấu toàn bộ class chạy trên Main Thread để an toàn UI
class RecorderViewModel: NSObject {
    
    // MARK: - Properties
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    
    // Closure binding
    var onStateChanged: ((RecorderState) -> Void)?
    var onTimerUpdate: ((String) -> Void)?
    var onPowerUpdate: ((Float) -> Void)? // Thêm cái này để vẽ sóng
    
    private(set) var currentState: RecorderState = .idle {
        didSet { onStateChanged?(currentState) }
    }
    
    private var currentDuration: TimeInterval = 0
    private var currentFilename: String = ""
    
    // MARK: - Permission Check (FIX iOS 17 Warning)
    func toggleRecording() {
        switch currentState {
        case .idle:
            checkPermissionAndStart()
        case .recording:
            stopRecording()
        case .error:
            currentState = .idle
        }
    }
    
    private func checkPermissionAndStart() {
        // Fix warning: Dùng AVAudioApplication thay vì AVAudioSession
        let permission = AVAudioApplication.shared.recordPermission
        
        switch permission {
        case .granted:
            startRecordingInternal()
            
        case .denied:
            currentState = .error("Vui lòng vào Cài đặt cấp quyền Micro.")
            
        case .undetermined:
            print("⚠️ Đang xin quyền...")
            // Fix warning: API mới cho iOS 17+
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.startRecordingInternal()
                    } else {
                        self?.currentState = .error("Bạn cần cấp quyền Micro.")
                    }
                }
            }
            
        @unknown default:
            currentState = .error("Lỗi xác định quyền.")
        }
    }
    
    // MARK: - Recording Logic
    private func startRecordingInternal() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            currentState = .error("Lỗi Audio Session: \(error.localizedDescription)")
            return
        }
        
        let filename = UUID().uuidString + ".m4a"
        self.currentFilename = filename
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = docDir.appendingPathComponent(filename)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true // Bật đo sóng âm
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            currentState = .recording
            startTimer()
        } catch {
            currentState = .error("Lỗi khởi tạo Recorder: \(error.localizedDescription)")
        }
    }
    
    private func stopRecording() {
        audioRecorder?.stop()
        stopTimer()
    }
    
    // MARK: - Timer Logic (FIX Concurrency Warning)
    private func startTimer() {
        stopTimer() // Reset cũ trước
        currentDuration = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // --- SỬA LẠI ĐOẠN NÀY: Dùng dữ liệu thật 100% ---
                self.audioRecorder?.updateMeters()
                // Kênh 0 là Mono/Left. Giá trị từ -160 (im lặng) đến 0 (to nhất)
                let power = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
                self.onPowerUpdate?(power)
                // ------------------------------------------------
                
                // Update thời gian
                self.currentDuration += 0.05
                if Int(self.currentDuration * 20) % 20 == 0 {
                    self.formatTime(self.currentDuration)
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatTime(_ seconds: TimeInterval) {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        let timeString = formatter.string(from: seconds) ?? "00:00"
        onTimerUpdate?(timeString)
    }
    
    private func saveRecordingToDatabase() {
        // Logic lưu DB (đã có ở bước trước)
        let newItem = MediaItem(
            id: UUID().uuidString,
            name: "Audio \(Date().formatted(date: .numeric, time: .shortened))",
            type: .audio,
            relativePath: currentFilename,
            duration: currentDuration,
            createdAt: Date(),
            isFavorite: false
        )
        
        Task {
            do {
                try await MediaRepository.shared.save(item: newItem)
                print("💾 Saved recording to Realm!")
            } catch {
                print("❌ Save failed: \(error)")
            }
        }
    }
}

// MARK: - Delegate (FIX Concurrency Warning)
// AVAudioRecorderDelegate gọi callback từ background thread
// Chúng ta cần đánh dấu nonisolated và nhảy về MainActor thủ công
extension RecorderViewModel: AVAudioRecorderDelegate {
    
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            self.currentState = .idle
            if flag {
                self.saveRecordingToDatabase()
            } else {
                self.currentState = .error("Ghi âm bị lỗi")
            }
        }
    }
}
