//
//  VideoRepository.swift
//  MediaStudio
//
//  Created by Trangptt on 29/1/26.
//


import Foundation
import UIKit
import AVFoundation

class VideoRepository {
    
    static let shared = VideoRepository()
    
    // Đường dẫn thư mục: Documents/Videos
    private var videoFolderURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("Videos")
    }
    
    private init() {
        createFolderIfNeeded()
    }
    
    // 1. Tạo folder nếu chưa có
    private func createFolderIfNeeded() {
        if !FileManager.default.fileExists(atPath: videoFolderURL.path) {
            try? FileManager.default.createDirectory(at: videoFolderURL, withIntermediateDirectories: true)
        }
    }
    
    // 2. Lưu Video (Chuyển từ thư mục Temp vào Kho)
    func saveVideo(from tempURL: URL) throws {
        // Tạo tên file dựa trên ngày giờ: "VIDEO_20231025_153022.mov"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "VIDEO_\(dateFormatter.string(from: Date())).mov"
        
        let destinationURL = videoFolderURL.appendingPathComponent(fileName)
        
        // Di chuyển file (Move)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
    }
    
    // 3. Lấy toàn bộ danh sách Video
    func fetchAllVideos() async -> [VideoItem] {
        var videos: [VideoItem] = []
        
        do {
            // Lấy danh sách file trong folder
            let fileURLs = try FileManager.default.contentsOfDirectory(at: videoFolderURL, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            
            // Lọc chỉ lấy file .mov hoặc .mp4
            let videoFiles = fileURLs.filter { $0.pathExtension.lowercased() == "mov" || $0.pathExtension.lowercased() == "mp4" }
            
            // Duyệt từng file để lấy thông tin
            for url in videoFiles {
                let asset = AVURLAsset(url: url)
                let duration = try? await asset.load(.duration).seconds
                let resources = try? url.resourceValues(forKeys: [.creationDateKey])
                let date = resources?.creationDate ?? Date()
                
                // Lấy thumbnail (Hàm này viết ở dưới)
                let thumb = await generateThumbnail(for: url)
                
                let video = VideoItem(
                    id: url.lastPathComponent,
                    name: url.lastPathComponent,
                    fileURL: url,
                    createdAt: date,
                    duration: duration ?? 0,
                    thumbnail: thumb
                )
                videos.append(video)
            }
            
            // Sắp xếp: Mới nhất lên đầu
            return videos.sorted(by: { $0.createdAt > $1.createdAt })
            
        } catch {
            print("Lỗi lấy danh sách video: \(error)")
            return []
        }
    }
    
    // 4. Hàm tạo ảnh Thumbnail từ Video (Rất quan trọng) 🖼️
    private func generateThumbnail(for url: URL) async -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true // Để ảnh không bị xoay ngang/dọc sai
        
        // Lấy ảnh ở giây thứ 1 (CMTime)
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        
        do {
            let (cgImage, _) = try await imageGenerator.image(at: time)
            return UIImage(cgImage: cgImage)
        } catch {
            print("Không lấy được thumbnail: \(error)")
            // Nếu lỗi thì trả về một cái ảnh mặc định màu xám
            return UIImage(systemName: "play.rectangle.fill")
        }
    }
    
    // 5. Xóa Video
    func deleteVideo(item: VideoItem) throws {
        try FileManager.default.removeItem(at: item.fileURL)
    }
}