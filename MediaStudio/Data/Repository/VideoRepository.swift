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
    
    // Tạo folder nếu chưa có
    private func createFolderIfNeeded() {
        if !FileManager.default.fileExists(atPath: videoFolderURL.path) {
            try? FileManager.default.createDirectory(at: videoFolderURL, withIntermediateDirectories: true)
        }
    }
    
    // Lưu Video
    func saveVideo(from tempURL: URL) throws -> URL  {
        // Tạo tên file dựa trên ngày giờ
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "VIDEO_\(dateFormatter.string(from: Date())).mov"
        
        let destinationURL = videoFolderURL.appendingPathComponent(fileName)
        
        // Di chuyển file
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        
        return destinationURL
    }
    
    // Lấy toàn bộ danh sách Video
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
                
                // Lấy thumbnail
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
            
            // Sắp xếp mới nhất lên đầu
            return videos.sorted(by: { $0.createdAt > $1.createdAt })
            
        } catch {
            print("Lỗi lấy danh sách video: \(error)")
            return []
        }
    }
    
    // Hàm tạo ảnh Thumbnail từ Video
    private func generateThumbnail(for url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true // Để ảnh không bị xoay ngang/dọc sai
        imageGenerator.maximumSize = CGSize(width: 500, height: 500)
        
        // Lấy ảnh ở giây thứ 1
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
    
    // Xóa Video
    func deleteVideo(item: VideoItem) throws {
        try FileManager.default.removeItem(at: item.fileURL)
    }
    
    // Biến path của Recorder
    private var audioFolderURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("Recordings") // Tên folder bạn dùng bên Recorder
    }
    
    // Tách âm thanh
    func extractAudio(from video: MediaItem) async throws -> URL {
        // Kiểm tra file gốc
        guard let sourceURL = video.fullFileURL else {
            throw NSError(domain: "App", code: -404, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy file video gốc (File path is nil)"])
        }
        
        // Kiểm tra/Tạo thư mục đích
        if !FileManager.default.fileExists(atPath: audioFolderURL.path) {
            try? FileManager.default.createDirectory(at: audioFolderURL, withIntermediateDirectories: true)
        }
        
        let asset = AVURLAsset(url: sourceURL)
        
        // Tạo Export Session
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "App", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không tạo được ExportSession"])
        }
        
        // Tạo tên file mới
        let cleanName = video.name.replacingOccurrences(of: ".mov", with: "")
            .replacingOccurrences(of: ".mp4", with: "")
        
        let audioFileName = "Audio_\(cleanName).m4a"
        let outputURL = audioFolderURL.appendingPathComponent(audioFileName)
        
        // Xóa file cũ nếu trùng tên
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        // Thực hiện Export
        try await exportSession.export(to: outputURL, as: .m4a)
        return outputURL
    }
    
    // Rename
    func renameVideo(_ video: VideoItem, newName: String) throws -> VideoItem {
        // Giữ nguyên đuôi file
        let fileExtension = video.fileURL.pathExtension
        let finalName = newName.hasSuffix(fileExtension) ? newName : "\(newName).\(fileExtension)"
        
        let destinationURL = videoFolderURL.appendingPathComponent(finalName)
        
        // Thực hiện đổi tên di chuyển file sang đường dẫn mới
        try FileManager.default.moveItem(at: video.fileURL, to: destinationURL)
        
        // Trả về object VideoItem đã cập nhật thông tin
        return VideoItem(
            id: video.id, 
            name: finalName,
            fileURL: destinationURL,
            createdAt: video.createdAt,
            duration: video.duration,
            thumbnail: video.thumbnail
        )
    }
}
