//
//  MediaType.swift
//  MediaStudio
//
//  Created by Trangptt on 23/1/26.
//

import Foundation

// Loại file
enum MediaType: String, Codable {
    case audio
    case video
}


struct MediaItem: Identifiable, Hashable {
    let id: String
    let name: String
    let type: MediaType
    let relativePath: String
    let duration: TimeInterval
    let createdAt: Date
    var isFavorite: Bool
    var isDeleted : Bool
    var deletedDate : Date
    
    // Helper lấy đường dẫn file vật lý thực tế
    var fullFileURL: URL? {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documents?.appendingPathComponent(relativePath)
    }
}
