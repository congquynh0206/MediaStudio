//
//  CameraViewController.swift
//  MediaStudio
//
//  Created by Trangptt on 29/1/26.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController {
    
    // UI
    private let previewView = UIView()
    private let recordButton = UIButton()
    private let timerLabel = UILabel()
    private let flipButton = UIButton()
    
    // View Model
    private let viewModel = CameraViewModel()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        viewModel.checkPermissions()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = previewView.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.stopSession()
    }
    
    // Binding
    private func bindViewModel() {
        // Khi Session sẵn sàng thì hiện hình
        viewModel.onSessionReady = { [weak self] session in
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = self?.previewView.bounds ?? .zero
            self?.previewView.layer.addSublayer(layer)
            self?.previewLayer = layer
        }
        
        // Timer
        viewModel.onTimerUpdate = { [weak self] timeString in
            self?.timerLabel.text = timeString
        }
        
        // Update start button
        viewModel.onRecordingStateChanged = { [weak self] isRecording in
            self?.updateRecordButtonUI(isRecording: isRecording)
        }
        
        // Khi cần hiện thông báo
        viewModel.onShowAlert = { [weak self] title, msg in
            let alert = UIAlertController(title: title, message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }
    
    // Action
    @objc private func didTapRecord() {
        viewModel.toggleRecord()
    }
    
    @objc private func didTapFlipCamera() {
        // Animation UI
        UIView.transition(with: flipButton, duration: 0.3, options: .transitionFlipFromLeft, animations: nil)
        viewModel.switchCamera()
    }
    
    // Helper start button
    private func updateRecordButtonUI(isRecording: Bool) {
        timerLabel.isHidden = !isRecording
        
        UIView.animate(withDuration: 0.3) {
            if isRecording {
                self.recordButton.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
                self.recordButton.layer.cornerRadius = 5
                self.recordButton.backgroundColor = .white
                self.flipButton.isEnabled = false
                self.flipButton.alpha = 0.5
            } else {
                self.recordButton.transform = .identity
                self.recordButton.layer.cornerRadius = 35
                self.recordButton.backgroundColor = .red
                self.flipButton.isEnabled = true
                self.flipButton.alpha = 1.0
            }
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        // Preview
        view.addSubview(previewView)
        previewView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.68)
        ])
        
        // Start Button
        view.addSubview(recordButton)
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.layer.cornerRadius = 35
        recordButton.layer.borderWidth = 4
        recordButton.layer.borderColor = UIColor.white.cgColor
        recordButton.backgroundColor = .red
        
        // Setup Timer
        view.addSubview(timerLabel)
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        timerLabel.text = "00:00"
        timerLabel.textColor = .white
        timerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .medium)
        timerLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        timerLabel.layer.cornerRadius = 8
        timerLabel.clipsToBounds = true
        timerLabel.textAlignment = .center
        timerLabel.isHidden = true
        
        // Setup Flip Button
        view.addSubview(flipButton)
        flipButton.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        flipButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath.camera", withConfiguration: config), for: .normal)
        flipButton.tintColor = .white
        
        NSLayoutConstraint.activate([
            recordButton.widthAnchor.constraint(equalToConstant: 70),
            recordButton.heightAnchor.constraint(equalToConstant: 70),
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80),
            
            timerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            timerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            timerLabel.widthAnchor.constraint(equalToConstant: 100),
            timerLabel.heightAnchor.constraint(equalToConstant: 40),
            
            flipButton.leadingAnchor.constraint(equalTo: recordButton.trailingAnchor, constant: 40),
            flipButton.centerYAnchor.constraint(equalTo: recordButton.centerYAnchor),
            flipButton.widthAnchor.constraint(equalToConstant: 50),
            flipButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        recordButton.addTarget(self, action: #selector(didTapRecord), for: .touchUpInside)
        flipButton.addTarget(self, action: #selector(didTapFlipCamera), for: .touchUpInside)
    }
}
