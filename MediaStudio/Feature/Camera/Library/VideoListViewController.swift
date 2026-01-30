//
//  VideoListViewController.swift
//  MediaStudio
//
//  Created by Trangptt on 29/1/26.
//


import UIKit
import AVKit

class VideoListViewController: UIViewController, UISearchResultsUpdating {
    
    private var collectionView: UICollectionView!
    private let viewModel = VideoListViewModel()
    private let searchController  = UISearchController(searchResultsController: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "My Videos"
        view.backgroundColor = .systemBackground
        
        setupCollectionView()
        bindViewModel()
        setupNavigationBar()
        setupSearchController()
    }
    
    private func setupNavigationBar() {
        // Nút Close bên trái
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Close", style: .done, target: self, action: #selector(didTapClose))
        
        // Nút Thùng rác bên phải
        let trashBtn = UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(didTapTrashButton))
        navigationItem.rightBarButtonItem = trashBtn
        
        updateTitle()
    }
    // Search
    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false   // ko làm tối màn khi search
        searchController.searchBar.placeholder = "Search videos"
        
        // Gắn vào Navigation Bar
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        
        definesPresentationContext = true
    }
    
    // Chạy mỗi khi user gõ
    func updateSearchResults(for searchController: UISearchController) {
        // Lấy text user gõ
        guard let text = searchController.searchBar.text else { return }
        
        // Gọi ViewModel lọc
        viewModel.search(query: text)
    }
    
    private func updateTitle() {
        navigationItem.prompt = nil
        if viewModel.currentMode == .normal {
            title = "My Videos"
            navigationItem.rightBarButtonItem?.image = UIImage(systemName: "trash")
            navigationItem.rightBarButtonItem?.tintColor = .systemBlue
        } else {
            let titleLabel = UILabel()
            titleLabel.text = "Trash Bin"
            titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
            titleLabel.textColor = .label
            titleLabel.textAlignment = .center
            
            // Label Phụ
            let subtitleLabel = UILabel()
            subtitleLabel.text = "Files auto-deleted after 30 days"
            subtitleLabel.font = .systemFont(ofSize: 11, weight: .regular)
            subtitleLabel.textColor = .systemGray
            subtitleLabel.textAlignment = .center
            
            // Gom vào 1 cái StackView dọc
            let stackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
            stackView.axis = .vertical
            stackView.alignment = .center
            stackView.distribution = .fillProportionally
            
            navigationItem.rightBarButtonItem?.image = UIImage(systemName: "list.bullet")
            navigationItem.rightBarButtonItem?.tintColor = .systemBlue
            
            // Gán StackView vào Title
            navigationItem.titleView = stackView
        }
        navigationController?.view.setNeedsLayout()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.loadVideos()
    }
    
    private func bindViewModel() {
        viewModel.onDataLoaded = { [weak self] in
            // Dùng performWithoutAnimation để tắt hiệu ứng nháy
            UIView.performWithoutAnimation {
                self?.collectionView.reloadData()
            }
        }
    }
    
    @objc private func didTapClose() {
        dismiss(animated: true)
    }
    
    @objc private func didTapTrashButton() {
        // Đổi chế độ trong ViewModel
        viewModel.toggleMode()
        updateTitle()
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
        
        guard let url = video.fullFileURL else {
            print("Lỗi: Không tìm thấy đường dẫn file video")
            return
        }
        
        // Tạo Player
        let player = AVPlayer(url: url)
        
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.entersFullScreenWhenPlaybackBegins = true
        
        present(playerVC, animated: true) {
            player.play()
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
            if self.viewModel.currentMode == .normal {
                
                // List
                let rename = UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { _ in
                    self.showRenameAlert(at: indexPath)
                }
                
                let extract = UIAction(title: "Extract Audio", image: UIImage(systemName: "waveform")) { _ in
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
                
                let shareAction = UIAction(title: "Share Video", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                    let video = self.viewModel.videos[indexPath.row]
                    guard let url = video.fullFileURL else {return}
                    let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    self.present(activityVC, animated: true)
                }
                
                let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                    self.viewModel.moveToTrash(at: indexPath.row)
                }
                
                return UIMenu(title: "Options", children: [rename, extract, shareAction, delete])
                
            } else {
                
                // Thùng rác
                
                // Restore
                let restore = UIAction(title: "Restore", image: UIImage(systemName: "arrow.uturn.backward")) { _ in
                    self.viewModel.restoreVideo(at: indexPath.row)
                }
                
                // Xóa vĩnh viễn
                let deleteForever = UIAction(title: "Delete Forever", image: UIImage(systemName: "xmark.bin.fill"), attributes: .destructive) { _ in
                    
                    let alert = UIAlertController(title: "Delete Permanently?", message: "This video will be lost forever.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                    alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
                        self.viewModel.deletePermanently(at: indexPath.row)
                    }))
                    self.present(alert, animated: true)
                }
                
                return UIMenu(title: "Trash Options", children: [restore, deleteForever])
            }
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
    
    func configure(with item: MediaItem) {
        
        if let url = item.fullFileURL {
            generateThumbnail(url: url) { image in
                // UI bắt buộc phải update trên Main Thread
                DispatchQueue.main.async {
                    self.thumbnailImageView.image = image
                }
            }
        }
        
        // Format giây thành 00:00
        let min = Int(item.duration) / 60
        let sec = Int(item.duration) % 60
        durationLabel.text = String(format: " %02d:%02d ", min, sec)
        nameLabel.text = item.name
    }
    
    // Hàm tạo thumbnail từ Video URL
    private func generateThumbnail(url: URL, completion: @escaping (UIImage?) -> Void) {
        Task {
            
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            
            // Giúp ảnh không bị xoay ngang/ngược
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 300, height: 300)
            
            do {
                // Lấy frame ở giây thứ 0
                let time = CMTime(seconds: 0.0, preferredTimescale: 600)
                let (cgImage, _) = try await generator.image(at: time)
                let image = UIImage(cgImage: cgImage)
                
                // Update UI
                await MainActor.run {
                    completion(image)
                }
            } catch {
                print("Lỗi tạo thumbnail: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}
