//
//  EyeTracker.swift
//  SpeechFlow
//
//  Created by Shreyansh Singh on 5/28/25.
//

import Vision
import UIKit
import AVFoundation

// Analyzes eye contact in a video by sampling frames at fixed intervals.
// Uses Vision to detect face landmarks and identify whether eye contact is being made.
func analyzeEyeContact(in videoURL: URL, interval: TimeInterval = 0.1, resultHandler: @escaping ([TimeInterval]) -> Void) {
    Task {
        let asset = AVURLAsset(url: videoURL)

        var duration: Double = 0
        do {
            // Asynchronously load the duration of the video
            let durationCMTime = try await asset.load(.duration)
            duration = CMTimeGetSeconds(durationCMTime)
        } catch {
            print("❌ Failed to load duration:", error.localizedDescription)
            return
        }

        // Create an image generator to extract frames from the video
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true // Ensure correct video orientation
        generator.requestedTimeToleranceBefore = .zero  // Request exact frame time (no leeway)
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: 720, height: 720) // Reduce resolution for memory safety

        // Create an array of times at which to extract frames
        var times: [NSValue] = []
        var t = CMTime.zero
        while CMTimeGetSeconds(t) < duration {
            times.append(NSValue(time: t))
            t = CMTimeAdd(t, CMTimeMakeWithSeconds(interval, preferredTimescale: 600))
        }

        // Keep track of the last time to know when analysis is complete
        let lastRequestedTime = times.last?.timeValue
        var eyeContactTimes: [TimeInterval] = []

        // Limit concurrent Vision requests to avoid crashing due to memory pressure
        let semaphore = DispatchSemaphore(value: 2)

        // Start processing frames
        generator.generateCGImagesAsynchronously(forTimes: times) { requestedTime, image, _, _, _ in
            semaphore.wait() // Wait until allowed to continue

            defer { semaphore.signal() } // Always release the semaphore when done

            // Ensure the image is valid and non-zero size before passing to Vision
            guard let cgImage = image,
                  cgImage.width > 0,
                  cgImage.height > 0 else {
                print("⚠️ Skipping invalid frame at \(CMTimeGetSeconds(requestedTime)) — empty or nil image.")
                return
            }

            // Create a Vision request handler for the extracted frame
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            // Create a request to detect face landmarks
            let request = VNDetectFaceLandmarksRequest { req, _ in
                if let results = req.results as? [VNFaceObservation] {
                    for face in results {
                        // Run custom logic to determine if face is making eye contact
                        if isMakingEyeContact(face: face) {
                            // Save timestamp if eye contact is detected
                            eyeContactTimes.append(CMTimeGetSeconds(requestedTime))
                        }
                    }
                }

                // If this is the last frame, return the results on the main thread
                if requestedTime == lastRequestedTime {
                    DispatchQueue.main.async {
                        resultHandler(eyeContactTimes)
                    }
                }
            }

            // Try performing the Vision request safely
            do {
                try handler.perform([request])
            } catch {
                print("❌ Vision request failed at time \(CMTimeGetSeconds(requestedTime)): \(error)")
            }
        }
    }
}



// Determines if a given face is making eye contact based on its yaw and landmark positions
func isMakingEyeContact(face: VNFaceObservation) -> Bool {
    // Skip faces that are turned too far away from the camera
    if let yaw = face.yaw?.doubleValue, abs(yaw) > 0.4 {
        print("⛔ Skipping due to yaw angle:", yaw)
        return false
    }

    // Ensure all required landmarks are available
    guard let landmarks = face.landmarks,
          let leftPupil = landmarks.leftPupil,
          let rightPupil = landmarks.rightPupil,
          let leftEye = landmarks.leftEye,
          let rightEye = landmarks.rightEye else {
        return false
    }

    // Checks if a pupil is horizontally and vertically centered within its eye
    func isCentered(pupil: VNFaceLandmarkRegion2D, eye: VNFaceLandmarkRegion2D) -> Bool {
        guard pupil.pointCount > 0, eye.pointCount >= 2 else { return false }

        let pupilPoint = pupil.normalizedPoints[0]

        // Vertical range of the eye
        let eyeYs = eye.normalizedPoints.map { $0.y }
        let eyeMinY = eyeYs.min() ?? 0
        let eyeMaxY = eyeYs.max() ?? 0
        let eyeHeight = eyeMaxY - eyeMinY

        // Define vertical zone where the pupil should fall
        let lowerCutoff = eyeMinY + eyeHeight * 0.65
        let upperCutoff = eyeMinY + eyeHeight * 0.35
        let isOutsideVerticalZone = pupilPoint.y < upperCutoff || pupilPoint.y > lowerCutoff

        // Horizontal center of the eye
        let eyeXs = eye.normalizedPoints.map { $0.x }
        let eyeCenterX = eyeXs.reduce(0, +) / CGFloat(eye.pointCount)
        let deltaX = abs(pupilPoint.x - eyeCenterX)

        print("👁️ ΔX:", deltaX, "👁️ pupilY:", pupilPoint.y, "TooLow:", isOutsideVerticalZone)

        return deltaX < 0.02 && !isOutsideVerticalZone
    }

    // Both eyes must be centered for it to count as eye contact
    return isCentered(pupil: leftPupil, eye: leftEye) && isCentered(pupil: rightPupil, eye: rightEye)
}
