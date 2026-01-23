//
//  MediaType.swift
//  MediaStudio
//
//  Created by Trangptt on 23/1/26.
//


// Domain/MediaItem.swift
import Foundation

// Loại file: Audio hoặc Video
enum MediaType: String, Codable {
    case audio
    case video
}

// Struct này dùng trong ViewModel và UI (An toàn giữa các threads)
struct MediaItem: Identifiable, Hashable {
    let id: String
    let name: String
    let type: MediaType
    let relativePath: String // Đường dẫn tương đối trong Documents
    let duration: TimeInterval
    let createdAt: Date
    var isFavorite: Bool
    
    // Helper lấy đường dẫn file vật lý thực tế
    var fullFileURL: URL? {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documents?.appendingPathComponent(relativePath)
    }
}