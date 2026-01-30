//
//  VideoListViewModel.swift
//  MediaStudio
//
//  Created by Trangptt on 29/1/26.
//


import Foundation
import AVFoundation

enum VideoListMode {
    case normal
    case trash
}

class VideoListViewModel {
    
    private(set) var videos: [MediaItem] = []
    
    private var originalVideos: [MediaItem] = []
    private var currentSearchText: String = ""
    
    // Callback báo cho View reload
    var onDataLoaded: (() -> Void)?
    
    var currentMode: VideoListMode = .normal
    
    // Lấy dữ liệu từ kho
    func loadVideos() {
        Task {
            if currentMode == .trash {
                try? await MediaRepository.shared.cleanupOldTrashItems()
            }
            
            let allItems = await MediaRepository.shared.fetchAll()
            
            let filteredByMode: [MediaItem]
            switch currentMode {
            case .normal:
                filteredByMode = allItems.filter { $0.type == .video && $0.isDeleted == false }
            case .trash:
                filteredByMode = allItems.filter { $0.type == .video && $0.isDeleted == true }
            }
            
            self.originalVideos = filteredByMode.sorted(by: { $0.createdAt > $1.createdAt })
            
            self.filterVideos(by: self.currentSearchText)
            await MainActor.run {
                self.onDataLoaded?()
            }
        }
    }
    
    // Hàm search
    func search(query: String) {
        self.currentSearchText = query
        filterVideos(by: query)
        self.onDataLoaded?()
    }
    
    // Logic search
    private func filterVideos(by query: String) {
        if query.isEmpty {
            self.videos = self.originalVideos
        } else {
            self.videos = self.originalVideos.filter { item in
                return item.name.localizedCaseInsensitiveContains(query)
            }
        }
    }
    
    // Chuyển đổi chế độ 
    func toggleMode() {
        currentMode = (currentMode == .normal) ? .trash : .normal
        loadVideos()
    }
    
    // Xoaa mềm
    func moveToTrash(at index: Int) {
        let item = videos[index]
        Task {
            try? await MediaRepository.shared.moveToTrash(id: item.id)
            loadVideos()
        }
    }
    
    // Restore
    func restoreVideo(at index: Int) {
        let item = videos[index]
        Task {
            try? await MediaRepository.shared.restoreFromTrash(id: item.id)
            loadVideos()
        }
    }
    
    // Xóa vĩnh viễn
    func deletePermanently(at index: Int) {
        let item = videos[index]
        Task {
            try? await MediaRepository.shared.deletePermanently(id: item.id)
            loadVideos()
        }
    }
    
    // Đổi tên
    func renameVideo(at index: Int, newName: String) {
        let item = videos[index]
        Task {
            try? await MediaRepository.shared.rename(id: item.id, newName: newName)
            self.loadVideos()
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
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                 let audioFileName = audioURL.path.replacingOccurrences(of: documentsURL.path + "/", with: "")
                
                // Logic đặt tên
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
