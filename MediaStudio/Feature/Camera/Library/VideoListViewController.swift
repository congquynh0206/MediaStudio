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
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth * 1.3)
        layout.sectionInset = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing)
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        
        collectionView.register(VideoCell.self, forCellWithReuseIdentifier: "VideoCell")
        
        view.addSubview(collectionView)
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
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("Đã chọn video: \(viewModel.videos[indexPath.row].name)")
    }
}

// MARK: - Cell
class VideoCell: UICollectionViewCell {
    
    private let thumbnailImageView = UIImageView()
    private let durationLabel = UILabel()
    
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
        
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            durationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            durationLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            durationLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),
            durationLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func configure(with item: VideoItem) {
        thumbnailImageView.image = item.thumbnail
        
        // Format giây thành 00:00
        let min = Int(item.duration) / 60
        let sec = Int(item.duration) % 60
        durationLabel.text = String(format: " %02d:%02d ", min, sec)
    }
}
