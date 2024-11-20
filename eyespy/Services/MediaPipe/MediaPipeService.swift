//
//  MediaPipService.swift
//  eyespy
//
//  Created by Alex Huynh on 11/18/24.
//

import MediaPipeTasksVision
import CoreGraphics

// Rename our custom types to avoid conflicts
class MediaPipeService: ObservableObject {
    private var poseLandmarker: PoseLandmarker?
    @Published var currentPoseResult: CustomPoseResult?
    
    init() {
        setupPoseLandmarker()
    }
    
    private func setupPoseLandmarker() {
        let options = PoseLandmarkerOptions()
        options.baseOptions.modelAssetPath = "pose_landmarker_lite.task"
        options.runningMode = .video
        options.numPoses = 1
        
        do {
            poseLandmarker = try PoseLandmarker(options: options)
        } catch {
            print("Error setting up pose landmarker: \(error)")
        }
    }
    
    func processFrame(_ pixelBuffer: CVPixelBuffer, timestamp: Int64) {
        guard let landmarker = poseLandmarker else { return }
        
        do {
            let mpImage = try MPImage(pixelBuffer: pixelBuffer)
            let result = try landmarker.detect(image: mpImage)
            
            // Convert MediaPipe results to our CustomPoseResult model
            if let firstPose = result.landmarks.first {
                let landmarks = convertToLandmarks(firstPose)
                currentPoseResult = CustomPoseResult(landmarks: landmarks,
                                                   connections: getConnections(landmarks))
            }
        } catch {
            print("Error processing frame: \(error)")
        }
    }
    
    private func convertToLandmarks(_ landmarks: [NormalizedLandmark]) -> [CustomPoseLandmark] {
        return landmarks.enumerated().map { (index, landmark) in
            CustomPoseLandmark(
                type: CustomPoseLandmarkType(rawValue: Int(truncating: NSNumber(value: index))) ?? .nose,
                position: CGPoint(
                    x: CGFloat(landmark.x),
                    y: CGFloat(landmark.y)
                ),
                visibility: CGFloat(truncating: landmark.visibility ?? 0.0)
            )
        }
    }
    
    private func getConnections(_ landmarks: [CustomPoseLandmark]) -> [(from: CustomPoseLandmark, to: CustomPoseLandmark)] {
        let connections: [(from: Int, to: Int)] = [
            // Torso
            (11, 12), // shoulders
            (11, 23), // left shoulder to left hip
            (12, 24), // right shoulder to right hip
            (23, 24), // hips
            
            // Left arm
            (11, 13), // shoulder to elbow
            (13, 15), // elbow to wrist
            
            // Right arm
            (12, 14), // shoulder to elbow
            (14, 16), // elbow to wrist
            
            // Left leg
            (23, 25), // hip to knee
            (25, 27), // knee to ankle
            
            // Right leg
            (24, 26), // hip to knee
            (26, 28)  // knee to ankle
        ]
        
        return connections.compactMap { connection in
            guard connection.from < landmarks.count,
                  connection.to < landmarks.count else {
                return nil
            }
            return (from: landmarks[connection.from],
                    to: landmarks[connection.to])
        }
    }
}

// Supporting types with renamed structures
struct CustomPoseResult {
    let landmarks: [CustomPoseLandmark]
    let connections: [(from: CustomPoseLandmark, to: CustomPoseLandmark)]
}

struct CustomPoseLandmark {
    let type: CustomPoseLandmarkType
    let position: CGPoint
    let visibility: CGFloat
}

enum CustomPoseLandmarkType: Int {
    case nose = 0
    case leftEye = 1
    case rightEye = 2
    case leftEar = 3
    case rightEar = 4
    case leftShoulder = 11
    case rightShoulder = 12
    case leftElbow = 13
    case rightElbow = 14
    case leftWrist = 15
    case rightWrist = 16
    case leftHip = 23
    case rightHip = 24
    case leftKnee = 25
    case rightKnee = 26
    case leftAnkle = 27
    case rightAnkle = 28
}
