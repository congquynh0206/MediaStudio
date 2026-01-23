//
//  MediaCell.swift
//  MediaStudio
//
//  Created by Trangptt on 23/1/26.
//


import UIKit

class MediaCell: UITableViewCell {
    
    // Nhớ kéo IBOutlet từ Storyboard vào đây
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Làm đẹp icon
        iconImageView.layer.cornerRadius = 8
        iconImageView.backgroundColor = .systemGray6
        iconImageView.tintColor = .systemBlue
    }

    func configure(with item: MediaItem) {
        nameLabel.text = item.name
        
        // Format giây thành 00:00
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        let timeStr = formatter.string(from: item.duration) ?? "00:00"
        
        let dateStr = item.createdAt.formatted(date: .numeric, time: .shortened)
        durationLabel.text = "\(timeStr) • \(dateStr)"
        
        let iconName = item.type == .audio ? "mic.fill" : "video.fill"
        iconImageView.image = UIImage(systemName: iconName)
    }
}