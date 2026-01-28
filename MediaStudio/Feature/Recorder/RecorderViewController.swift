//
//  RecorderViewController.swift
//  MediaStudio
//
//  Created by Trangptt on 23/1/26.
//

import UIKit
import AVFoundation

class RecorderViewController: UIViewController {
    
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var visualizerView: VisualizerView! // Placeholder
  
    private let viewModel = RecorderViewModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
    }
    
    private func setupUI() {
        // Làm đẹp nút Record
        recordButton.layer.cornerRadius = recordButton.frame.height / 2
        recordButton.backgroundColor = .systemRed
        recordButton.tintColor = .white
        recordButton.setTitle("REC", for: .normal)
    }
    
    private func bindViewModel() {
        // Lắng nghe Timer để update Label
        viewModel.onTimerUpdate = { [weak self] timeString in
            self?.timerLabel.text = timeString
        }
        viewModel.onPowerUpdate = { [weak self] power in
            self?.visualizerView.updateWaveform(value: power)
        }
        
        // Lắng nghe State để đổi màu nút bấm
        viewModel.onStateChanged = { [weak self] state in
            switch state {
            case .idle:
                if self?.recordButton.currentTitle == "STOP" {
                    self?.showSavedAlert()
                }
                
                self?.recordButton.backgroundColor = .systemRed
                self?.recordButton.setTitle("REC", for: .normal)
                self?.timerLabel.text = "00:00"
            case .recording:
                self?.recordButton.backgroundColor = .gray
                self?.recordButton.setTitle("STOP", for: .normal)
            case .error(let msg):
                self?.showAlert(message: msg)
            }
        }
    }
    
    // Alert
    private func showSavedAlert() {
        let alert = UIAlertController(title: "Saved", message: "The recording has been saved successfully!", preferredStyle: .alert)
        present(alert, animated: true)
        
        // Tự tắt sau 1.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
    }
    
    @IBAction func didTapRecordButton(_ sender: UIButton) {
        viewModel.toggleRecording()
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Lỗi", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @IBAction func didTapListButton(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Library", bundle: nil)
        if let libraryVC = storyboard.instantiateInitialViewController() {
            let nav = UINavigationController(rootViewController: libraryVC)
            
            present(nav, animated: true)
        }
    }
}
