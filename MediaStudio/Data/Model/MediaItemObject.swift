//
//  MediaItemObject.swift
//  MediaStudio
//
//  Created by Trangptt on 23/1/26.
//


// Data/MediaItemObject.swift
import Foundation
import RealmSwift

// Class này CHỈ dùng nội bộ trong Repository để lưu xuống DB
class MediaItemObject: Object {
    @Persisted(primaryKey: true) var id: String
    @Persisted var name: String
    @Persisted var typeString: String // Realm không lưu Enum trực tiếp, lưu String
    @Persisted var relativePath: String
    @Persisted var duration: Double
    @Persisted var createdAt: Date
    @Persisted var isFavorite: Bool = false
    // Convert từ Domain Struct sang Realm Object
    convenience init(from item: MediaItem) {
        self.init()
        self.id = item.id
        self.name = item.name
        self.typeString = item.type.rawValue
        self.relativePath = item.relativePath
        self.duration = item.duration
        self.createdAt = item.createdAt
        self.isFavorite = item.isFavorite
    }
    
    // Convert từ Realm Object về Domain Struct
    func toDomain() -> MediaItem {
        return MediaItem(
            id: self.id,
            name: self.name,
            type: MediaType(rawValue: self.typeString) ?? .audio,
            relativePath: self.relativePath,
            duration: self.duration,
            createdAt: self.createdAt,
            isFavorite: self.isFavorite
        )
    }
}
