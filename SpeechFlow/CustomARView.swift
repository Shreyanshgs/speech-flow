//
//  CustomARView.swift
//  SpeechFlow
//
//  Created by Shreyansh Singh on 6/27/25.
//

import SwiftUI
import ARKit
import RealityKit

// A SwiftUI wrapper for the custom ARView that handles eye gaze tracking
struct CustomARViewContainer: UIViewRepresentable {
    @Binding var eyeGazeActive: Bool
    @Binding var lookAtPoint: CGPoint?
    @Binding var isWinking: Bool
    @Binding var isLookingAtCamera: Bool

    func makeUIView(context: Context) -> CustomARView {
        // Initialize and return the custom AR view
        return CustomARView(
            eyeGazeActive: $eyeGazeActive,
            lookAtPoint: $lookAtPoint,
            isWinking: $isWinking,
            isLookingAtCamera: $isLookingAtCamera
        )
    }

    func updateUIView(_ uiView: CustomARView, context: Context) {
        // No update logic needed yet
    }
}

// Custom AR view that tracks eye gaze and eye contact using ARKit
class CustomARView: ARView, ARSessionDelegate {
    @Binding var eyeGazeActive: Bool
    @Binding var lookAtPoint: CGPoint?
    @Binding var isWinking: Bool
    @Binding var isLookingAtCamera: Bool

    // Custom initializer for binding SwiftUI state
    init(
        eyeGazeActive: Binding<Bool>,
        lookAtPoint: Binding<CGPoint?>,
        isWinking: Binding<Bool>,
        isLookingAtCamera: Binding<Bool>
    ) {
        _eyeGazeActive = eyeGazeActive
        _lookAtPoint = lookAtPoint
        _isWinking = isWinking
        _isLookingAtCamera = isLookingAtCamera

        super.init(frame: .zero)

        // Automatically configure AR session (no manual config needed later)
        self.automaticallyConfigureSession = true

        // Improve performance by disabling unnecessary render options
        self.renderOptions = [.disableDepthOfField, .disableMotionBlur, .disablePersonOcclusion]

        // Set up face tracking configuration
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        self.session.delegate = self
        self.session.run(config, options: [])

        // Add a placeholder anchor
        let anchor = AnchorEntity(world: .zero)
        self.scene.anchors.append(anchor)
    }

    // Delegate callback: called when ARKit updates face anchors
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard eyeGazeActive,
              let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }

        // Run gaze detection and eye contact logic
        detectGazePoint(faceAnchor: faceAnchor)
        detectEyeContact(faceAnchor: faceAnchor)
    }

    // Convert ARKit's lookAtPoint into a screen coordinate for feedback
    private func detectGazePoint(faceAnchor: ARFaceAnchor) {
        let lookAtPoint = faceAnchor.lookAtPoint
        let worldLookAtPoint = faceAnchor.transform * simd_float4(lookAtPoint, 1)

        // Try projecting the 3D point to screen space
        guard let projected = self.project(worldLookAtPoint.xyz) else {
            return  // Projection failed
        }

        DispatchQueue.main.async {
            self.lookAtPoint = CGPoint(
                x: CGFloat(projected.x).clamped(to: Ranges.widthRange),
                y: CGFloat(projected.y).clamped(to: Ranges.heightRange)
            )
        }
    }


    // Use angle between face direction and gaze to detect eye contact
    private func detectEyeContact(faceAnchor: ARFaceAnchor) {
        let headPosition = simd_make_float3(faceAnchor.transform.columns.3)
        let lookTarget = faceAnchor.lookAtPoint
        let lookDir = simd_normalize(lookTarget - headPosition)

        let headForward = simd_make_float3(faceAnchor.transform.columns.2)

        let dot = simd_dot(headForward, lookDir)
        let clampedDot = min(max(dot, -1.0), 1.0)
        let angle = acos(clampedDot)

        // Consider eye contact if angle is less than ~18 degrees
        let isLooking = angle < .pi / 10

        DispatchQueue.main.async {
            self.isLookingAtCamera = isLooking
            print("Eye Contact:", isLooking, "| angle:", angle * 180 / .pi, "°")
        }
    }

    // Required but unused initializers (not used in SwiftUI context)
    @MainActor required dynamic init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @MainActor required dynamic init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

// Utility to estimate screen size in physical units for better gaze mapping
struct Device {
    static var frameSize: CGSize {
            // Subtracting for safe area or tab bar height
            return CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 82)
        }
}

// Define clamping bounds for projected screen gaze coordinates
struct Ranges {
    static let widthRange: ClosedRange<CGFloat> = 0...Device.frameSize.width
    static let heightRange: ClosedRange<CGFloat> = 0...Device.frameSize.height
}

// Extension to clamp CGFloat values within a valid range
extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

extension simd_float4 {
    var xyz: simd_float3 {
        return simd_make_float3(x, y, z)
    }
}
