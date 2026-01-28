//
//  AudioHelper.swift
//  MediaStudio
//
//  Created by Trangptt on 28/1/26.
//

import AVFoundation

class AudioHelper {
    
    static func createAudioMix(for asset: AVAsset, volume: Float) async throws -> AVAudioMix? {
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        
        guard let audioTrack = audioTracks.first else { return nil }
        
        let audioMix = AVMutableAudioMix()
        let inputParams = AVMutableAudioMixInputParameters(track: audioTrack)
        
        inputParams.setVolume(volume, at: .zero)
        
        audioMix.inputParameters = [inputParams]
        return audioMix
    }
    
    // Merge file
    static func mergeAudioFiles(audioURLs: [URL], outputName: String) async throws -> URL? {
        let composition = AVMutableComposition()
        
        // Tạo đường ray âm thanh (Track)
        guard let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return nil
        }
        
        var currentTime = CMTime.zero
        
        // Duyệt qua từng file để nối đuôi nhau
        for url in audioURLs {
            let asset = AVURLAsset(url: url)
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            guard let assetTrack = tracks.first else { continue }
            
            // Lấy thời lượng
            let duration = try await asset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: duration)
            
            // Chèn vào đường ray chính
            try compositionAudioTrack.insertTimeRange(timeRange, of: assetTrack, at: currentTime)
            
            // Dịch chuyển con trỏ thời gian
            currentTime = CMTimeAdd(currentTime, duration)
        }
        
        // Xuất file
        let fileName = "\(outputName).m4a"
        let outputURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
        
        // Xóa file cũ nếu trùng tên
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else { return nil }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        try await exportSession.export(to: outputURL, as: .m4a)
        
        return outputURL
    }
}
