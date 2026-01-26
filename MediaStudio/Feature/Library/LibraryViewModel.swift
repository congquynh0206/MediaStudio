//
//  LibraryViewModel.swift
//  MediaStudio
//
//  Created by Trangptt on 23/1/26.
//


import Foundation
import AVFoundation

@MainActor
class LibraryViewModel: NSObject {
    
    // Data Source
    private(set) var items: [MediaItem] = []
    
    // Callbacks
    var onDataLoaded: (() -> Void)?
    var onPlaybackStatusChanged: ((Bool) -> Void)? // True = Playing, False = Stopped
    
    // Dependencies
    private let repository = MediaRepository.shared
    private var audioPlayer: AVAudioPlayer?
    
    // Load all item
    func loadData() {
        Task {
            let allItems = await repository.fetchAll()
            self.items = allItems.sorted(by: { $0.createdAt > $1.createdAt })
            self.onDataLoaded?()
        }
    }
    
    // Logic phát nhạc
    func playItem(at index: Int) {
        let item = items[index]
        
        // Lấy đường dẫn file thật
        guard let fileURL = item.fullFileURL else {
            print("Không tìm thấy file: \(item.relativePath)")
            return
        }
        
        // Setup Player
        do {
            // Cấu hình Session để phát loa ngoài (playback)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            print("Đang phát: \(item.name)")
            onPlaybackStatusChanged?(true)
        } catch {
            print("Lỗi phát file: \(error)")
        }
    }
    
    func stopPlaying() {
        audioPlayer?.stop()
        onPlaybackStatusChanged?(false)
    }
    
    func deleteItem(at index: Int) {
        let item = items[index]
        Task {
            // Xóa file vật lý
            try? FileManager.default.removeItem(at: item.fullFileURL!)
            
            // Xóa trong DB
            try? await repository.delete(id: item.id)
            
            // Reload
            loadData()
        }
    }
    
    func renameItem (index : Int, newName : String) {
        let item = items[index]
        Task{
            do{
                try await repository.rename(id: item.id, newName: newName)
                loadData()
            }catch{
                print("Lỗi đổi tên")
            }
        }
    }
    
}

extension LibraryViewModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.onPlaybackStatusChanged?(false)
        }
    }
}
