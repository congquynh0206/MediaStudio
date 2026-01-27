//
//  MediaItemObject.swift
//  MediaStudio
//
//  Created by Trangptt on 23/1/26.
//

import Foundation
import RealmSwift

class MediaItemObject: Object {
    @Persisted(primaryKey: true) var id: String
    @Persisted var name: String
    @Persisted var typeString: String
    @Persisted var relativePath: String
    @Persisted var duration: Double
    @Persisted var createdAt: Date
    @Persisted var isFavorite: Bool = false
    @Persisted var isDeleted: Bool = false      
    @Persisted var deletedDate: Date? = nil
    // Chuyển từ Struct sang Realm Object
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
    
    // Chuyển từ Realm Object về Struct
    func toDomain() -> MediaItem {
        return MediaItem(
            id: self.id,
            name: self.name,
            type: MediaType(rawValue: self.typeString) ?? .audio,
            relativePath: self.relativePath,
            duration: self.duration,
            createdAt: self.createdAt,
            isFavorite: self.isFavorite,
            isDeleted: self.isDeleted,
            deletedDate: self.deletedDate ?? Date()
        )
    }
}
