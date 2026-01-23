//
//  RecorderViewController.swift
//  MediaStudio
//
//  Created by Trangptt on 23/1/26.
//

import UIKit
import AVFoundation

class RecorderViewController: UIViewController {

    // MARK: - Outlets
    // Nhớ kéo thả từ Storyboard vào đây nhé!
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var visualizerView: VisualizerView! // Placeholder
    
    // MARK: - Properties
    private let viewModel = RecorderViewModel()
    
    // MARK: - Lifecycle
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
                self?.recordButton.backgroundColor = .systemRed
                self?.recordButton.setTitle("REC", for: .normal)
            case .recording:
                self?.recordButton.backgroundColor = .gray
                self?.recordButton.setTitle("STOP", for: .normal)
            case .error(let msg):
                self?.showAlert(message: msg)
            }
        }
    }
    
    // MARK: - Actions
    @IBAction func didTapRecordButton(_ sender: UIButton) {
        viewModel.toggleRecording()
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Lỗi", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @IBAction func didTapListButton(_ sender: Any) {
        // Code chuyển màn hình thủ công (vì khác Storyboard)
        let storyboard = UIStoryboard(name: "Library", bundle: nil)
        // Lưu ý: Library.storyboard phải tick "Is Initial View Controller" vào cái VC của nó
        // HOẶC dùng ID để instantiate
        if let libraryVC = storyboard.instantiateInitialViewController() {
            // Nếu có NavigationController thì push, không thì present
            present(libraryVC, animated: true)
        }
    }
}
