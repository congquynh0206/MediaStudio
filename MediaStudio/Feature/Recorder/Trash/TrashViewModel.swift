//
//  TrashViewModel.swift
//  MediaStudio
//
//  Created by Trangptt on 27/1/26.
//


import Foundation

@MainActor
class TrashViewModel {
    
    var items: [MediaItem] = []
    var onDataLoaded: (() -> Void)?
    
    private let repository = MediaRepository.shared
    
    func loadTrashItems() {
        Task {
            try? await repository.cleanupOldTrashItems()
            
            let allItems = await repository.fetchAll()
            self.items = allItems.filter { $0.isDeleted == true }
            self.items.sort { $0.createdAt > $1.createdAt }
            
            self.onDataLoaded?()
        }
    }
    
    // Khôi phục
    func restoreItem(at index: Int) {
        let item = items[index]
        Task {
            try? await repository.restoreFromTrash(id: item.id)
            loadTrashItems() 
        }
    }
    
    // Xóa vĩnh viễn
    func deletePermanently(at index: Int) {
        let item = items[index]
        Task {
            try? await repository.deletePermanently(id: item.id)
            loadTrashItems()
        }
    }
}
