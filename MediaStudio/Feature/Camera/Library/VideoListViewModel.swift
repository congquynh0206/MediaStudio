//
//  VideoListViewModel.swift
//  MediaStudio
//
//  Created by Trangptt on 29/1/26.
//


import Foundation
import AVFoundation

class VideoListViewModel {
    
    private(set) var videos: [VideoItem] = []
    
    // Callback báo cho View reload
    var onDataLoaded: (() -> Void)?
    
    // Lấy dữ liệu từ kho
    func loadVideos() {
        Task {
            self.videos = await VideoRepository.shared.fetchAllVideos()
            
            // Báo ra UI
            await MainActor.run {
                self.onDataLoaded?()
            }
        }
    }
    
    // Xóa video
    func deleteVideo(at index: Int) {
        let item = videos[index]
        do {
            try VideoRepository.shared.deleteVideo(item: item)
            videos.remove(at: index)
        } catch {
            print("Lỗi xóa video: \(error)")
        }
    }
    
    // Đổi tên
    func renameVideo(at index: Int, newName: String) {
        let video = videos[index]
        do {
            let newVideo = try VideoRepository.shared.renameVideo(video, newName: newName)
            // Cập nhật lại danh sách dữ liệu
            videos[index] = newVideo
            // Reload
            onDataLoaded?()
        } catch {
            print("Lỗi đổi tên: \(error)")
        }
    }
    
    // Hàm tách âm
    func extractAudio(at index: Int, completion: @escaping (String) -> Void) {
        let video = videos[index]
        
        Task {
            do {
                // Tách file
                let audioURL = try await VideoRepository.shared.extractAudio(from: video)
                
                //  Path
                let audioFileName = audioURL.lastPathComponent
                
                // Logic đặt tên hiển thị
                let displayName = "Audio_separation_" + video.name.replacingOccurrences(of: ".mov", with: "").replacingOccurrences(of: ".mp4", with: "") + ".m4a"
                
                let asset = AVURLAsset(url: audioURL)
                // Load thời lượng
                let duration = try await asset.load(.duration).seconds
                
                // Tạo MediaItem
                let newAudioItem = MediaItem(
                    id: UUID().uuidString,
                    name: displayName,
                    type: .audio,
                    relativePath: audioFileName,
                    duration: duration,
                    createdAt: Date(),
                    isFavorite: false,
                    isDeleted: false,
                    deletedDate: Date()
                )
                
                // Dùng hàm save có sẵn
                try await MediaRepository.shared.save(item: newAudioItem)
                
                await MainActor.run {
                    completion("Audio separation successful! File saved to the Recordings folder")
                }
            } catch {
                await MainActor.run {
                    completion("Lỗi: \(error.localizedDescription)")
                }
            }
        }
    }
}
