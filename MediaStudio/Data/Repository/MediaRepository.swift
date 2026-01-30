//
//  MediaRepositoryType.swift
//  MediaStudio
//
//  Created by Trangptt on 23/1/26.
//

import Foundation
import RealmSwift

// Protocol để sau này dễ Mocking/Testing
protocol MediaRepositoryType {
    func fetchAll() async -> [MediaItem]
    func save(item: MediaItem) async throws
    func moveToTrash(id: String) async throws
    func restoreFromTrash(id: String) async throws
    func deletePermanently(id: String) async throws
}

final class MediaRepository: MediaRepositoryType {
    
    static let shared = MediaRepository()
    
    private init() {
        printRealmPath()
    }

    private func printRealmPath() {
        if let url = Realm.Configuration.defaultConfiguration.fileURL {
            print("Realm Database Path: \(url.path)")
        }
    }
    
    // MARK: - Read
    func fetchAll() async -> [MediaItem] {
        return await Task { @MainActor in
            do {
                let realm = try Realm()
                let results = realm.objects(MediaItemObject.self)
                    .sorted(byKeyPath: "createdAt", ascending: false)
                
                // Convert Realm Object thành Struct
                return results.map { $0.toDomain() }
            } catch {
                print("Realm Fetch Error: \(error)")
                return []
            }
        }.value
    }
    
    // MARK: - Write
    func save(item: MediaItem) async throws {
        try await Task { @MainActor in
            let realm = try Realm()
            let object = MediaItemObject(from: item)
            
            try realm.write {
                realm.add(object, update: .modified)
            }
            print("Saved to Realm: \(item.name)")
        }.value
    }
    
    // soft delete
    func moveToTrash(id: String) async throws {
        try await Task { @MainActor in
            let realm = try await Realm()
            if let item = realm.object(ofType: MediaItemObject.self, forPrimaryKey: id) {
                try realm.write {
                    item.isDeleted = true
                    item.deletedDate = Date() // Lưu thời điểm xóa
                }
            }
        }.value
    }
    
    // Hàm khôi phục
    func restoreFromTrash(id: String) async throws {
        try await Task { @MainActor in
            let realm = try await Realm()
            if let item = realm.object(ofType: MediaItemObject.self, forPrimaryKey: id) {
                try realm.write {
                    item.isDeleted = false
                    item.deletedDate = nil
                }
            }
        }.value
    }
    
    // xoá vĩnh viễn
    func deletePermanently(id: String) async throws {
        try await Task { @MainActor in
            let realm = try Realm()
            guard let object = realm.object(ofType: MediaItemObject.self, forPrimaryKey: id) else { return }
            // Xoá file vật lý
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documents.appendingPathComponent(object.relativePath)
            
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("Đã xóa file vật lý tại: \(fileURL.lastPathComponent)")
            } catch {
                print("Không tìm thấy file hoặc lỗi xóa: \(error)")
            }
            
            try realm.write {
                realm.delete(object)
            }
            print("Deleted from Realm: \(id)")
        }.value
    }
    
    // Xoá sau 30 ngày
    func cleanupOldTrashItems() async throws {
        try await Task { @MainActor in
            let realm = try await Realm()
            
            // Tính thời điểm 30 ngày trước
//            guard let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else { return }
            guard let thresholdDate = Calendar.current.date(byAdding: .minute, value: -1, to: Date()) else { return }
            
            // Tìm các file: Đang trong thùng rác và Ngày xóa < 30 ngày trước
            let itemsToDelete = realm.objects(MediaItemObject.self)
                .filter("isDeleted == true AND deletedDate < %@", thresholdDate)
            
            if itemsToDelete.isEmpty { return }
            
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            // Xóa sạch
            try realm.write {
                for item in itemsToDelete {
                    // Xóa file vật lý
                    let fileURL = documents.appendingPathComponent(item.relativePath)
                    try? FileManager.default.removeItem(at: fileURL)
                    
                    // Xóa record
                    realm.delete(item)
                }
            }
            print("Đã dọn dẹp \(itemsToDelete.count) file rác quá hạn.")
        }.value
    }
    
    // Đổi tên
    func rename (id : String, newName : String) async throws {
        try await Task { @MainActor in
            let realm = try Realm()
            guard let item = realm.object(ofType: MediaItemObject.self, forPrimaryKey: id) else {return}
            try realm.write{
                item.name = newName
            }
        }.value
    }
    
    // Thay thế sau khi cut
    func updateAfterTrim(itemID: String, newRelativePath: String, newDuration: Double) async throws {
        try await Task { @MainActor in
            let realm = try await Realm()
            // Tìm bản ghi cũ
            guard let item = realm.object(ofType: MediaItemObject.self, forPrimaryKey: itemID) else { return }
            
            if item.relativePath != newRelativePath {
                let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let oldFileURL = documents.appendingPathComponent(item.relativePath)
                try? FileManager.default.removeItem(at: oldFileURL)
            }
            
            // Cập nhật thông tin
            try realm.write {
                item.relativePath = newRelativePath
                item.duration = newDuration
            }
        }.value
    }
    
    // Tạo bản ghi mới
    func saveAsNewItem(originalName: String, relativePath: String, duration: Double, isTrimmed : Bool) async throws {
        try await Task { @MainActor in
            let realm = try await Realm()
            
            let newItem = MediaItemObject()
            newItem.id = UUID().uuidString
            newItem.name = isTrimmed ? "\(originalName) (Trimmed)" : "\(originalName)" 
            newItem.relativePath = relativePath
            newItem.duration = duration
            newItem.createdAt = Date()
            
            try realm.write {
                realm.add(newItem)
            }
        }.value
    }
}
