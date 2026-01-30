//
//  CameraViewModel.swift
//  MediaStudio
//
//  Created by Trangptt on 29/1/26.
//


import Foundation
import AVFoundation
import Photos
import UIKit

class CameraViewModel: NSObject {
    
    var onShowAlert: ((String, String) -> Void)?
    var onRecordingStateChanged: ((Bool) -> Void)? // true = đang quay, false = dừng
    var onTimerUpdate: ((String) -> Void)?
    var onSessionReady: ((AVCaptureSession) -> Void)? // Báo cho View biết Session đã sẵn sàng để hiện Preview
    var onFlashModeChanged: ((Bool) -> Void)? // true = Đèn đang sáng
    
    private var captureSession: AVCaptureSession?
    private var videoOutput = AVCaptureMovieFileOutput()
    private var currentPosition: AVCaptureDevice.Position = .back
    
    // Timer
    private var recordingTimer: Timer?
    private var recordingCounter: Int = 0
    
    
    
    // Kiểm tra xem Camera hiện tại có đèn không
    var hasTorch: Bool {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition) else {
            return false
        }
        return device.hasTorch
    }
    
    // Hàm bật/tăst đèn
    func toggleTorch() {
        // Tìm đúng thiết bị đang dùng
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition),
              device.hasTorch else { return }
        
        do {
            // Lock trước khi chỉnh
            try device.lockForConfiguration()
            
            if device.torchMode == .on {
                device.torchMode = .off
                onFlashModeChanged?(false)
            } else {
                // bật mức sáng nhất
                try device.setTorchModeOn(level: 1.0)
                onFlashModeChanged?(true) // Báo UI
            }
            
            // Unlock
            device.unlockForConfiguration()
            
        } catch {
            print("Lỗi bật đèn: \(error)")
        }
    }
    
    // Kiểm tra và Setup
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.setupCameraSession()
                }
            }
        case .authorized:
            setupCameraSession()
        default:
            onShowAlert?("Error", "Please grant Camera permissions in Settings")
        }
    }
    
    private func setupCameraSession() {
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        if session.canSetSessionPreset(.high) { session.sessionPreset = .high }
        
        // Setup Input, Output
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition),
              let audioDevice = AVCaptureDevice.default(for: .audio) else { return }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
            
            if session.canAddInput(videoInput) { session.addInput(videoInput) }
            if session.canAddInput(audioInput) { session.addInput(audioInput) }
            if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
            
            session.commitConfiguration()
            self.captureSession = session
            
            // Báo cho View
            DispatchQueue.main.async {
                self.onSessionReady?(session)
            }
            
            // Chạy
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
            
        } catch {
            print("Setup error: \(error)")
        }
    }
    
    // Quay
    func toggleRecord() {
        if videoOutput.isRecording {
            // Stop
            videoOutput.stopRecording()
            stopTimer()
            onRecordingStateChanged?(false)
        } else {
            // Start
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("tempVideo.mov")
            try? FileManager.default.removeItem(at: tempURL)
            
            videoOutput.startRecording(to: tempURL, recordingDelegate: self)
            startTimer()
            onRecordingStateChanged?(true)
        }
    }
    
    // Đổi cam
    func switchCamera() {
        guard let session = captureSession else { return }
        session.beginConfiguration()
        
        // Gỡ input cũ
        guard let currentInput = session.inputs.first(where: { ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.video) ?? false }) as? AVCaptureDeviceInput else {
            session.commitConfiguration()
            return
        }
        session.removeInput(currentInput)
        
        // Tìm input mới
        currentPosition = (currentPosition == .back) ? .front : .back
        
        do {
            if let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition) {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                if session.canAddInput(newInput) {
                    session.addInput(newInput)
                } else {
                    session.addInput(currentInput) // Fail thì rollback
                }
            }
        } catch {
            session.addInput(currentInput)
        }
        
        session.commitConfiguration()
        onFlashModeChanged?(false)
    }
    
    
    func startSession() {
        if let session = captureSession, !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        }
    }
    
    func stopSession() {
        captureSession?.stopRunning()
    }
    
    // Timer
    private func startTimer() {
        recordingCounter = 0
        onTimerUpdate?("00:00")
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordingCounter += 1
            let min = self.recordingCounter / 60
            let sec = self.recordingCounter % 60
            self.onTimerUpdate?(String(format: "%02d:%02d", min, sec))
        }
    }
    
    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        onTimerUpdate?("00:00")
    }
}

extension CameraViewModel: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        stopTimer()
        
        if let error = error {
            DispatchQueue.main.async { self.onShowAlert?("Lỗi", error.localizedDescription) }
            return
        }
        
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let savedURL = try VideoRepository.shared.saveVideo(from: outputFileURL)
                
                // Tính toán đường dẫn tương đối
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let relativePath = savedURL.path.replacingOccurrences(of: documentsURL.path + "/", with: "")
                
                // Lấy duration
                let asset = AVURLAsset(url: savedURL)
                let duration = try await asset.load(.duration).seconds
                
                // Tạo Item
                let newItem = MediaItem(
                    id: UUID().uuidString,
                    name: savedURL.lastPathComponent,
                    type: .video, 
                    relativePath: relativePath,
                    duration: duration,
                    createdAt: Date(),
                    isFavorite: false,
                    isDeleted: false,
                    deletedDate: nil
                )
                
                // 5. Lưu Realm
                try await MediaRepository.shared.save(item: newItem)
                
                await MainActor.run {
                    self.onShowAlert?("Saved", "The video has been saved to the Library")
                }
            } catch {
                await MainActor.run {
                    self.onShowAlert?("Lỗi lưu file", error.localizedDescription)
                }
            }
        }
    }
}
