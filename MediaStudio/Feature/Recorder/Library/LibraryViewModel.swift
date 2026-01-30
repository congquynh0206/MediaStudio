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
    private var allItems: [MediaItem] = []
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
            let processedItems = allItems
                .filter { item in
                    return item.type == .audio && item.isDeleted == false
                }
                .sorted { $0.createdAt > $1.createdAt }
            
            // Update UI
            await MainActor.run {
                self.items = processedItems
                self.onDataLoaded?()
            }
        }
    }
    
    // Search
    func search(query: String) {
        if query.isEmpty {
            items = allItems
        } else {
            // Lọc theo tên
            items = allItems.filter { item in
                return item.name.localizedCaseInsensitiveContains(query)
            }
        }
        // UI reload
        onDataLoaded?()
    }
    
    enum SortType {
        case newest // Mới nhất
        case oldest // Cũ nhất
        case nameAZ // Tên A-Z
        case nameZA
    }
    
    func sort(by type: SortType) {
        switch type {
        case .newest:
            items.sort { $0.createdAt > $1.createdAt }
            
        case .oldest:
            items.sort { $0.createdAt < $1.createdAt }
            
        case .nameAZ:
            items.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            
        case .nameZA:
            items.sort { $0.name.localizedStandardCompare($1.name) == .orderedDescending }
        }
        onDataLoaded?()
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
    
    // Xoá 1 item
    func deleteItem(at index: Int) {
        let item = items[index]
        Task {
            try? await repository.moveToTrash(id: item.id)
            // Reload
            loadData()
        }
    }
    
    // Xoá tất cả item trong list
    func deleteAllItem (list : [MediaItem]){
        for item in list {
            if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                self.deleteItem(at: index)
            }
        }
    }
    
    // Đổi tên
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
    
    // Merge
    func mergeItems(selectedItems: [MediaItem], outputName: String, completion: @escaping (Bool, String?) -> Void) {
        let urls = selectedItems.compactMap { $0.fullFileURL }
        
        Task {
            do {
                if let newURL = try await AudioHelper.mergeAudioFiles(audioURLs: urls, outputName: outputName) {
                    let newDuration = try await AVURLAsset(url: newURL).load(.duration).seconds
                    try await repository.saveAsNewItem(
                        originalName: outputName,
                        relativePath: newURL.lastPathComponent,
                        duration: newDuration,
                        isTrimmed: false
                    )
                    // Reload
                    loadData()
                    
                    // Báo về cho View là thành công
                    await MainActor.run { completion(true, nil) }
                }
            } catch {
                await MainActor.run { completion(false, error.localizedDescription) }
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
