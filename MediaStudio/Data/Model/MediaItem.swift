//
//  MediaType.swift
//  MediaStudio
//
//  Created by Trangptt on 23/1/26.
//

import Foundation
import RealmSwift

// Loại file
enum MediaType: String, Codable, PersistableEnum {
    case audio
    case video
}


struct MediaItem: Identifiable, Hashable {
    let id: String
    var name: String
    let type: MediaType
    let relativePath: String
    var duration: TimeInterval
    let createdAt: Date
    var isDeleted : Bool
    var deletedDate : Date?
    
    // Helper lấy đường dẫn file vật lý thực tế
    var fullFileURL: URL? {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documents?.appendingPathComponent(relativePath)
    }
}
