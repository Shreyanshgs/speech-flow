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
    // MARK: - App State Variables

    // Emotion detection timeline
    @State private var emotionTimeline: [(String, TimeInterval)] = []
    @State private var currentEmotion: String = ""

    // Video playback and timer
    @State private var player: AVPlayer?
    @State private var timer: Timer?

    // Video picker state
    @State private var showPicker = false

    // Eye contact data
    @State private var eyeContactTimestamps: [TimeInterval] = []
    @State private var eyeContactDetected: Bool = false
    @State private var currentPlaybackTime: TimeInterval = 0.0
    @State private var currentEyeContact: Bool = false

    // Live AR state (eye contact tracking using ARKit)
    @State private var navigateToAR = false
    @State private var lookAtPoint: CGPoint? = nil
    @State private var isWinking = false
    @State private var eyeGazeActive = false
    @State private var liveEyeContact: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Top action buttons
                HStack(spacing: 20) {
                    Button("Analyze Bundled Video") {
                        analyzeBundledVideo()
                    }
                    .font(.system(size: 19))
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                    Button("Pick Video from Library") {
                        reset()
                        showPicker = true
                    }
                    .font(.system(size: 19))
                    .buttonStyle(.borderedProminent)

                    Button("Live Eye Contact Camera") {
                        eyeGazeActive = true
                        navigateToAR = true
                    }
                    .font(.system(size: 19))
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }

                // If a video is loaded, show it along with live emotion/eye contact data
                if let player = player {
                    VideoPlayer(player: player)
                        .frame(height: 300)
                        .onAppear {
                            do {
                                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                                try AVAudioSession.sharedInstance().setActive(true)
                            } catch {
                                print("Failed to set audio session category: \(error)")
                            }

                            player.play()
                        }

                    VStack {
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
            .navigationDestination(isPresented: $navigateToAR) {
                LiveEyeContactView(
                    eyeGazeActive: $eyeGazeActive,
                    lookAtPoint: $lookAtPoint,
                    isWinking: $isWinking,
                    isLookingAtCamera: $liveEyeContact,
                    onDismiss: {
                        navigateToAR = false
                    }
                )
            }

            .padding()
            // Sheet for selecting video from photo library
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

                            // Run eye contact analysis and wait until it's done
                            analyzeEyeContact(in: pickedURL) { timestamps in
                                DispatchQueue.main.async {
                                    eyeContactTimestamps = timestamps
                                    print("✅ Eye contact timestamps finished:", timestamps)

                                    Task {
                                        // Continue only after eye contact analysis is done
                                        do {
                                            let convertedAudioURL = try await convertVideoToCompatibleM4A(from: pickedURL)

                                            let analyzer = EmotionFileAnalyzer { emotion, time in
                                                DispatchQueue.main.async {
                                                    emotionTimeline.append((emotion, time))
                                                }
                                            }
                                            await analyzer.analyzeVideoAudio(from: convertedAudioURL)

                                            DispatchQueue.main.async {
                                                player = AVPlayer(url: pickedURL)
                                                player?.isMuted = false
                                                startEmotionSync()
                                            }
                                        } catch {
                                            print("❌ Audio/emotion pipeline failed:", error)
                                        }
                                    }
                                }
                            }

                        } catch {
                            print("❌ Error during asset check:", error.localizedDescription)
                        }
                    }
                }
            }

        }
    }

    // MARK: - Helper Methods

    // Converts video to audio-only M4A format for analysis
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

    // Analyzes a bundled sample video included in the app
    func analyzeBundledVideo() {
        reset()
        if let path = Bundle.main.path(forResource: "test_video", ofType: "mp4") {
            let url = URL(fileURLWithPath: path)

            // Run eye contact analysis first
            analyzeEyeContact(in: url) { timestamps in
                DispatchQueue.main.async {
                    eyeContactTimestamps = timestamps
                    print("Eye contact timestamps loaded from bundled video:", timestamps)

                    // Then run emotion analysis
                    analyzeVideo(from: url)
                }
            }
        } else {
            print("Bundled video not found.")
        }
    }


    // Starts analysis on a given video URL
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

    // Resets all emotion/eye contact data and clears player
    func reset() {
        emotionTimeline.removeAll()
        currentEmotion = ""
        timer?.invalidate()
        player = nil
    }

    // Syncs emotion and eye contact with video playback
    func startEmotionSync() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            guard let currentTime = player?.currentTime().seconds else { return }

            // Get latest emotion before current playback time
            if let latest = emotionTimeline.filter({ $0.1 <= currentTime }).last {
                currentEmotion = latest.0
            }

            // Check if eye contact was detected at current time
            currentEyeContact = eyeContactTimestamps.contains { abs($0 - currentTime) < 0.1 }
        }
    }
}

// MARK: - Live AR Eye Contact View

struct LiveEyeContactView: View {
    @Binding var eyeGazeActive: Bool
    @Binding var lookAtPoint: CGPoint?
    @Binding var isWinking: Bool
    @Binding var isLookingAtCamera: Bool

    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Camera + ARKit view for live eye tracking
            CustomARViewContainer(
                eyeGazeActive: $eyeGazeActive,
                lookAtPoint: $lookAtPoint,
                isWinking: $isWinking,
                isLookingAtCamera: $isLookingAtCamera,
            )
            .ignoresSafeArea()

            VStack {
                // Top back button
                HStack {
                    Button(action: {
                        eyeGazeActive = false
                        onDismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.top, 50)
                .padding(.horizontal, 16)

                Spacer()

                // Eye contact status text
                Text(isLookingAtCamera ? "Maintaining Eye Contact 👀" : "Not Looking ❌")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)

                Spacer().frame(height: 60)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}


#Preview {
    ContentView()
}
