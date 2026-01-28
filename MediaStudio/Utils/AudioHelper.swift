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
}
