//
//  EyeTracker.swift
//  SpeechFlow
//
//  Created by Shreyansh Singh on 5/28/25.
//


import Vision
import UIKit
import AVFoundation

//func analyzeEyeContact(in videoURL: URL, interval: TimeInterval = 0.5, resultHandler: @escaping ([TimeInterval]) -> Void) async {
//    let asset = AVURLAsset(url: videoURL)
//    var duration: Double = 0
//    do {
//        let durationCMTime = try await asset.load(.duration)
//        let duration = CMTimeGetSeconds(durationCMTime)
//        // continue with frame generation logic here
//    } catch {
//        print("❌ Failed to load duration:", error.localizedDescription)
//        return
//    }
//    let generator = AVAssetImageGenerator(asset: asset)
//    generator.appliesPreferredTrackTransform = true
//    
//    var times: [NSValue] = []
//    var t = CMTime.zero
//    while CMTimeGetSeconds(t) < duration {
//        times.append(NSValue(time: t))
//        t = CMTimeAdd(t, CMTimeMakeWithSeconds(interval, preferredTimescale: 600))
//    }
//
//    var eyeContactTimes: [TimeInterval] = []
//
//    generator.generateCGImagesAsynchronously(forTimes: times) { requestedTime, image, _, _, _ in
//        guard let cgImage = image else { return }
//
//        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
//        let request = VNDetectFaceLandmarksRequest { request, _ in
//            guard let results = request.results as? [VNFaceObservation] else { return }
//            for face in results {
//                if isMakingEyeContact(face: face) {
//                    eyeContactTimes.append(CMTimeGetSeconds(requestedTime))
//                }
//            }
//        }
//
//        try? handler.perform([request])
//
//        // When done with all frames
//        if requestedTime == times.last?.timeValue {
//            DispatchQueue.main.async {
//                resultHandler(eyeContactTimes)
//            }
//        }
//    }
//}

func analyzeEyeContact(in videoURL: URL, interval: TimeInterval = 0.5, resultHandler: @escaping ([TimeInterval]) -> Void) {
    Task {
        let asset = AVURLAsset(url: videoURL)

        var duration: Double = 0
        do {
            let durationCMTime = try await asset.load(.duration)
            duration = CMTimeGetSeconds(durationCMTime)
        } catch {
            print("❌ Failed to load duration:", error.localizedDescription)
            return
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        var times: [NSValue] = []
        var t = CMTime.zero
        while CMTimeGetSeconds(t) < duration {
            times.append(NSValue(time: t))
            t = CMTimeAdd(t, CMTimeMakeWithSeconds(interval, preferredTimescale: 600))
        }

        let lastRequestedTime = times.last?.timeValue
        var eyeContactTimes: [TimeInterval] = []

        generator.generateCGImagesAsynchronously(forTimes: times) { requestedTime, image, _, _, _ in
            guard let cgImage = image else { return }
            
            

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNDetectFaceLandmarksRequest { req, _ in
                guard let results = req.results as? [VNFaceObservation] else { return }
                for face in results {
                    if isMakingEyeContact(face: face) {
                        eyeContactTimes.append(CMTimeGetSeconds(requestedTime))
                        print("👁️ leftPupil count:", face.landmarks?.leftPupil?.pointCount ?? 0)
                        print("👁️ rightPupil count:", face.landmarks?.rightPupil?.pointCount ?? 0)
                    }
                }
            }

            try? handler.perform([request])
            print("🔄 Checking frame at time:", CMTimeGetSeconds(requestedTime))

            if requestedTime == lastRequestedTime {
                DispatchQueue.main.async {
                    resultHandler(eyeContactTimes)
                }
            }
        }
    }
}

func isMakingEyeContact(face: VNFaceObservation) -> Bool {
    // 🚫 Skip turned faces
    if let yaw = face.yaw?.doubleValue, abs(yaw) > 0.4 {
        print("⛔ Skipping due to yaw angle:", yaw)
        return false
    }

    guard let landmarks = face.landmarks,
          let leftPupil = landmarks.leftPupil,
          let rightPupil = landmarks.rightPupil,
          let leftEye = landmarks.leftEye,
          let rightEye = landmarks.rightEye else {
        return false
    }

    func isCentered(pupil: VNFaceLandmarkRegion2D, eye: VNFaceLandmarkRegion2D) -> Bool {
        guard pupil.pointCount > 0, eye.pointCount >= 2 else { return false }

        let pupilPoint = pupil.normalizedPoints[0]

        // Eye vertical boundaries
        let eyeYs = eye.normalizedPoints.map { $0.y }
        let eyeMinY = eyeYs.min() ?? 0
        let eyeMaxY = eyeYs.max() ?? 0
        let eyeHeight = eyeMaxY - eyeMinY

        // Strict check: reject if pupil is near the bottom of the eye
        let lowerCutoff = eyeMinY + eyeHeight * 0.65
        let upperCutoff = eyeMinY + eyeHeight * 0.35
        let isOutsideVerticalZone = pupilPoint.y < upperCutoff || pupilPoint.y > lowerCutoff

        // Horizontal center
        let eyeXs = eye.normalizedPoints.map { $0.x }
        let eyeCenterX = eyeXs.reduce(0, +) / CGFloat(eye.pointCount)
        let deltaX = abs(pupilPoint.x - eyeCenterX)

        print("👁️ ΔX:", deltaX, "👁️ pupilY:", pupilPoint.y, "TooLow:", isOutsideVerticalZone)

        return deltaX < 0.02 && !isOutsideVerticalZone
    }




    return isCentered(pupil: leftPupil, eye: leftEye) && isCentered(pupil: rightPupil, eye: rightEye)
}

