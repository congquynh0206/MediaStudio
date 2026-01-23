//
//  MediaRepositoryType.swift
//  MediaStudio
//
//  Created by Trangptt on 23/1/26.
//


// Data/MediaRepository.swift
import Foundation
import RealmSwift

// Protocol để sau này dễ Mocking/Testing
protocol MediaRepositoryType {
    func fetchAll() async -> [MediaItem]
    func save(item: MediaItem) async throws
    func delete(id: String) async throws
}

final class MediaRepository: MediaRepositoryType {
    
    static let shared = MediaRepository()
    
    // Init private để đảm bảo Singleton
    private init() {
        printRealmPath()
    }
    
    // Helper: In đường dẫn DB để debug (Dùng Realm Studio mở xem)
    private func printRealmPath() {
        if let url = Realm.Configuration.defaultConfiguration.fileURL {
            print("📂 Realm Database Path: \(url.path)")
        }
    }
    
    // MARK: - Read
    func fetchAll() async -> [MediaItem] {
        // Chạy trên MainActor để an toàn khi map data, nhưng Realm thao tác rất nhanh
        return await Task { @MainActor in
            do {
                let realm = try Realm()
                let results = realm.objects(MediaItemObject.self)
                    .sorted(byKeyPath: "createdAt", ascending: false)
                
                // Convert Realm Object -> Struct ngay lập tức
                return results.map { $0.toDomain() }
            } catch {
                print("❌ Realm Fetch Error: \(error)")
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
            print("✅ Saved to Realm: \(item.name)")
        }.value
    }
    
    func delete(id: String) async throws {
        try await Task { @MainActor in
            let realm = try Realm()
            guard let object = realm.object(ofType: MediaItemObject.self, forPrimaryKey: id) else { return }
            
            try realm.write {
                realm.delete(object)
            }
            print("🗑 Deleted from Realm: \(id)")
        }.value
    }
}