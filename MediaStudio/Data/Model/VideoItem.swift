//
//  VideoItem.swift
//  MediaStudio
//
//  Created by Trangptt on 29/1/26.
//


import Foundation
import UIKit

struct VideoItem: Identifiable {
    let id: String
    let name: String
    let fileURL: URL
    let createdAt: Date
    let duration: Double
    var thumbnail: UIImage? // Ảnh đại diện video
}