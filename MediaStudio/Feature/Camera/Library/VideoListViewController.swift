//
//  VideoListViewController.swift
//  MediaStudio
//
//  Created by Trangptt on 29/1/26.
//


import UIKit
import AVKit

class VideoListViewController: UIViewController {
    
    private var collectionView: UICollectionView!
    private let viewModel = VideoListViewModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "My Videos"
        view.backgroundColor = .systemBackground
        
        setupCollectionView()
        bindViewModel()
        
        // Nút đóng
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Close", style: .done, target: self, action: #selector(didTapClose))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.loadVideos()
    }
    
    private func bindViewModel() {
        viewModel.onDataLoaded = { [weak self] in
            self?.collectionView.reloadData()
        }
    }
    
    @objc private func didTapClose() {
        dismiss(animated: true)
    }
    
    // MARK: - Setup CollectionView
    private func setupCollectionView() {
        // Layout: 2 cột, khoảng cách 10pt
        let layout = UICollectionViewFlowLayout()
        let spacing: CGFloat = 10
        let itemWidth = (view.frame.width - spacing * 3) / 2
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth * 1.5)
        layout.sectionInset = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing)
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        
        collectionView.register(VideoCell.self, forCellWithReuseIdentifier: "VideoCell")
        
        view.addSubview(collectionView)
    }
    
    private func playVideo(at index: Int) {
        let video = viewModel.videos[index]
        
        // Tạo Player
        let player = AVPlayer(url: video.fileURL)
        
        // Tạo màn hình chứa Player
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        
        // Cho phép phát tràn màn hình
        playerVC.entersFullScreenWhenPlaybackBegins = true
        
        // Mở lên
        present(playerVC, animated: true) {
            player.play() // Tự động chạy
        }
    }
}

extension VideoListViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.videos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VideoCell", for: indexPath) as! VideoCell
        let video = viewModel.videos[indexPath.row]
        cell.configure(with: video)
        return cell
    }
    
    // Chọn video
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Gọi hàm phát video
        playVideo(at: indexPath.row)
    }
    
    // Nhấn giữ hiện menu
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            
            let renameAction = UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { _ in
                self.showRenameAlert(at: indexPath)
            }
            
            // 2. Action: Extract Audio 🎵
            let extractAction = UIAction(title: "Extract Audio", image: UIImage(systemName: "waveform")) { _ in
                // Hiện loading hoặc thông báo
                let alert = UIAlertController(title: "Extracting...", message: "Please wait", preferredStyle: .alert)
                self.present(alert, animated: true)
                
                self.viewModel.extractAudio(at: indexPath.row) { message in
                    alert.dismiss(animated: true) {
                        // Hiện thông báo kết quả
                        let resultAlert = UIAlertController(title: "Result", message: message, preferredStyle: .alert)
                        resultAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(resultAlert, animated: true)
                    }
                }
            }
            
            // Chia sẻ
            let shareAction = UIAction(title: "Share Video", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                let video = self.viewModel.videos[indexPath.row]
                let activityVC = UIActivityViewController(activityItems: [video.fileURL], applicationActivities: nil)
                self.present(activityVC, animated: true)
            }
            
            // Xoá
            let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                // Hiện popup xác nhận cho chắc ăn
                let alert = UIAlertController(title: "Delete Video?", message: "This action cannot be undone.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
                    // Xoá
                    self.viewModel.deleteVideo(at: indexPath.row)
                    collectionView.deleteItems(at: [indexPath])
                }))
                self.present(alert, animated: true)
            }
            
            return UIMenu(title: "Options", children: [renameAction, extractAction, shareAction, deleteAction])
        }
    }
    
    
    // Pop up đổi tên
    private func showRenameAlert(at indexPath: IndexPath) {
        let video = viewModel.videos[indexPath.row]
        let alert = UIAlertController(title: "Rename Video", message: nil, preferredStyle: .alert)
        
        alert.addTextField { tf in
            tf.text = video.name
            tf.placeholder = "Enter new name"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let newName = alert.textFields?.first?.text, !newName.isEmpty {
                self.viewModel.renameVideo(at: indexPath.row, newName: newName)
            }
        })
        
        present(alert, animated: true)
    }
}

// MARK: - Cell
class VideoCell: UICollectionViewCell {
    
    private let thumbnailImageView = UIImageView()
    private let durationLabel = UILabel()
    private let nameLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupUI() {
        // Ảnh bìa
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = 8
        contentView.addSubview(thumbnailImageView)
        
        // Thời lượng
        durationLabel.font = .systemFont(ofSize: 12, weight: .bold)
        durationLabel.textColor = .white
        durationLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        durationLabel.layer.cornerRadius = 4
        durationLabel.clipsToBounds = true
        durationLabel.textAlignment = .center
        contentView.addSubview(durationLabel)
        
        nameLabel.font = .systemFont(ofSize: 14, weight: .bold)
        nameLabel.textColor = .label
        nameLabel.textAlignment = .center
        contentView.addSubview(nameLabel)
        
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: nameLabel.topAnchor, constant: -5),
            
            durationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            durationLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -35),
            durationLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),
            durationLabel.heightAnchor.constraint(equalToConstant: 20),
            
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            nameLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            nameLabel.heightAnchor.constraint(equalToConstant: 20)
            
        ])
    }
    
    func configure(with item: VideoItem) {
        thumbnailImageView.image = item.thumbnail
        
        // Format giây thành 00:00
        let min = Int(item.duration) / 60
        let sec = Int(item.duration) % 60
        durationLabel.text = String(format: " %02d:%02d ", min, sec)
        nameLabel.text = item.name
    }
}
