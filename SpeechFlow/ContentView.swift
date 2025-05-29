//
//  ContentView.swift
//  SpeechFlow
//
//  Created by Shreyansh Singh on 5/13/25.
//

import SwiftUI
import AVKit
import PhotosUI
import AVFoundation

struct ContentView: View {
    @State private var emotionTimeline: [(String, TimeInterval)] = []
    @State private var currentEmotion: String = ""
    @State private var player: AVPlayer?
    @State private var timer: Timer?
    @State private var showPicker = false
    @State private var eyeContactTimestamps: [TimeInterval] = []
    @State private var eyeContactDetected: Bool = false
    @State private var currentPlaybackTime: TimeInterval = 0.0
    @State private var currentEyeContact: Bool = false



    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                Button("Analyze Bundled Video") {
                    analyzeBundledVideo()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button("Pick Video from Library") {
                    reset()
                    showPicker = true
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            if let player = player {
                VideoPlayer(player: player)
                    .frame(height: 300)
                    .onAppear {
                        player.play()
                    }
                VStack{
                    Text("Emotions: \(currentEmotion.capitalized)")
                        .font(.title2)
                    Text("Eye Contact: \(currentEyeContact ? "Yes" : "No")")
                            .font(.title2)
                            .foregroundColor(currentEyeContact ? .green : .orange)
                }
                
                
            } else {
                Text("No video loaded")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .sheet(isPresented: $showPicker) {
            VideoPicker { pickedURL in
                Task {
                    let asset = AVURLAsset(url: pickedURL)
                    do {
                        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                        guard !audioTracks.isEmpty else {
                            print("❌ No audio track found in video.")
                            return
                        }

                        let convertedAudioURL = try await convertVideoToCompatibleM4A(from: pickedURL)
                        let analyzer = EmotionFileAnalyzer { emotion, time in
                            DispatchQueue.main.async {
                                emotionTimeline.append((emotion, time))
                            }
                        }
                        await analyzer.analyzeVideoAudio(from: convertedAudioURL)

                        analyzeEyeContact(in: pickedURL) { timestamps in
                            print("Eye contact timestamps:", timestamps)
                            DispatchQueue.main.async {
                                eyeContactTimestamps = timestamps
                                eyeContactDetected = true
                            }
                        }

                        DispatchQueue.main.async {
                            player = AVPlayer(url: pickedURL)
                            startEmotionSync()
                        }
                    } catch {
                        print("❌ Error during analysis pipeline:", error.localizedDescription)
                    }
                }
            }
        }
    }
    
//    func isCurrentlyMakingEyeContact() -> Bool {
//        guard let currentTime = player?.currentTime().seconds else { return false }
//        return eyeContactTimestamps.contains { abs($0 - currentTime) < 0.3 }
//    }

    
    func isCurrentlyMakingEyeContact() -> Bool {
        guard let currentTime = player?.currentTime().seconds else { return false }
        let isContact = eyeContactTimestamps.contains { abs($0 - currentTime) < 0.3 }
        print("🕒 Current time:", currentTime, "Eye contact:", isContact)
        return isContact
    }
    
    func convertVideoToCompatibleM4A(from url: URL) async throws -> URL {
        let asset = AVURLAsset(url: url)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "ExportError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot create export session"])
        }

        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        try await exportSession.export(to: outputURL, as: .m4a)
        
        return outputURL
    }

    func analyzeBundledVideo() {
        reset()
        if let path = Bundle.main.path(forResource: "test_video", ofType: "mp4") {
            let url = URL(fileURLWithPath: path)
            analyzeVideo(from: url)
        } else {
            print("Bundled video not found.")
        }
    }

    func analyzeVideo(from url: URL) {
        Task {
            let analyzer = EmotionFileAnalyzer { emotion, time in
                DispatchQueue.main.async {
                    emotionTimeline.append((emotion, time))
                }
            }
            await analyzer.analyzeVideoAudio(from: url)
            DispatchQueue.main.async {
                player = AVPlayer(url: url)
                startEmotionSync()
            }
        }
    }

    func reset() {
        emotionTimeline.removeAll()
        currentEmotion = ""
        timer?.invalidate()
        player = nil
    }

    func startEmotionSync() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            guard let currentTime = player?.currentTime().seconds else { return }

            // Emotion
            if let latest = emotionTimeline.filter({ $0.1 <= currentTime }).last {
                currentEmotion = latest.0
            }

            // Eye contact
            currentEyeContact = eyeContactTimestamps.contains { abs($0 - currentTime) < 0.3 }
        }
    }
}


#Preview {
    ContentView()
}
