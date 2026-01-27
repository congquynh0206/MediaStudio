//
//  PlayerViewController.swift
//  MediaStudio
//
//  Created by Trangptt on 26/1/26.
//

import UIKit

class PlayerViewController: UIViewController {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    
    @IBOutlet weak var artworkImageView: UIImageView!
    
    var itemToPlay: MediaItem?
    private var viewModel: PlayerViewModel!
    
    // Biến để kiểm tra user có đang kéo slider không
    private var isDraggingSlider = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupViewModel()
    }
    
    private func setupUI() {
        // Nút Play
        playButton.layer.cornerRadius = 30
        playButton.tintColor = .label
        
        // Slider
        timeSlider.minimumValue = 0
        // Kéo thả
        timeSlider.addTarget(self, action: #selector(sliderDidDrag), for: .valueChanged)
        timeSlider.addTarget(self, action: #selector(sliderDidEndDrag), for: [.touchUpInside, .touchUpOutside])
        
        // Image
        artworkImageView.tintColor = .systemGray
        artworkImageView.contentMode = .scaleAspectFit
        
        artworkImageView.layer.cornerRadius = artworkImageView.frame.height / 2
        artworkImageView.clipsToBounds = true
        
        artworkImageView.layer.borderWidth = 2
        artworkImageView.layer.borderColor = UIColor.systemGray.cgColor
    }
    
    private func setupViewModel() {
        guard let item = itemToPlay else { return }
        
        viewModel = PlayerViewModel(item: item)
        
        // Hiển thị thông tin ban đầu
        nameLabel.text = item.name
        durationLabel.text = viewModel.durationString
        timeSlider.maximumValue = Float(viewModel.duration)
        
        // Lắng nghe cập nhật thời gian (Timer)
        viewModel.onTimeUpdate = { [weak self] currentSeconds, timeString in
            guard let self = self else { return }
            
            if !self.isDraggingSlider {
                self.timeSlider.value = currentSeconds
            }
            self.currentTimeLabel.text = timeString
        }
        
        // Trạng thái Play/Pause
        viewModel.onStatusChanged = { [weak self] isPlaying in
            let iconName = isPlaying ? "pause.fill" : "play.fill"
            self?.playButton.setImage(UIImage(systemName: iconName), for: .normal)
            if isPlaying {
                self?.startRotating()
            } else {
                self?.stopRotating()
            }
        }
    }
    
    // MARK: - Actions
    
    @IBAction func didTapPlayButton(_ sender: Any) {
        viewModel.togglePlayPause()
    }
    
    // Khi user đang kéo thì ngừng Timer
    @objc func sliderDidDrag() {
        isDraggingSlider = true
    }
    
    // Khi user thả tay ra thì tua
    @objc func sliderDidEndDrag() {
        isDraggingSlider = false
        viewModel.seek(to: timeSlider.value)
    }
    
    @IBAction func didTapRewind(_ sender: Any) {
        viewModel.seek(by: -5) // Trừ 5 giây
    }
    
    // Nhớ nối dây từ nút Tiến vào hàm này
    @IBAction func didTapForward(_ sender: Any) {
        viewModel.seek(by: 5) // Cộng 5 giây
    }
    // Hàm bắt đầu xoay
    private func startRotating() {
        let rotation = CABasicAnimation(keyPath: "transform.rotation")
        rotation.fromValue = 0
        rotation.toValue = 2 * Double.pi // Xoay 360 độ (2 pi)
        rotation.duration = 4 // 4s/vong
        rotation.repeatCount = Float.infinity // Quay vô tận
        artworkImageView.layer.add(rotation, forKey: "spinningAnimation")
    }
    
    @IBAction func didTapEditButton(_ sender: Any) {
        // 1. Lấy màn hình Edit từ Storyboard
        let storyboard = UIStoryboard(name: "Library", bundle: nil) // Hoặc tên file storyboard của bạn
        if let editVC = storyboard.instantiateViewController(withIdentifier: "EditViewController") as? EditViewController {
            editVC.itemToEdit = self.itemToPlay
            
            editVC.modalPresentationStyle = .fullScreen
            
            // 3. Mở lên
            present(editVC, animated: true)
        }
    }
    
    // Hàm dừng xoay
    private func stopRotating() {
        artworkImageView.layer.removeAnimation(forKey: "spinningAnimation")
    }
}
