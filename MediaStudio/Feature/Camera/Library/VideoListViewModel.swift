//
//  VideoListViewModel.swift
//  MediaStudio
//
//  Created by Trangptt on 29/1/26.
//


import Foundation

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
}
