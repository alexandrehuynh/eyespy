//
//  PoseDetectionResult.swift
//  eyespy
//
//  Created by Alex Huynh on 11/18/24.
//

import Vision

struct PoseDetectionResult {
    var landmarks: [PoseLandmark]
    var connections: [(from: PoseLandmark, to: PoseLandmark)]
}

struct PoseLandmark {
    var position: CGPoint
    var confidence: Float
    var type: LandmarkType
}

enum LandmarkType {
    case nose, leftEye, rightEye, leftEar, rightEar
    case leftShoulder, rightShoulder
    case leftElbow, rightElbow
    case leftWrist, rightWrist
    case leftHip, rightHip
    case leftKnee, rightKnee
    case leftAnkle, rightAnkle
    // Add other landmark types as needed
}
