//
//  PoseDetectionResult.swift
//  eyespy
//
//  Created by Alex Huynh on 11/18/24.
//

import Vision
import CoreGraphics

// NEW: Added analysis structures
struct PoseAnalysis {
  let angles: JointAngles
  let positions: JointPositions
  let symmetry: SymmetryAnalysis
}

// NEW: Added joint angles structure
struct JointAngles {
  let kneeAngle: CGFloat
  let hipAngle: CGFloat
  let elbowAngle: CGFloat
}

// NEW: Added joint positions structure
struct JointPositions {
  let shoulders: (left: CGPoint, right: CGPoint)
  let hips: (left: CGPoint, right: CGPoint)
  let knees: (left: CGPoint, right: CGPoint)
}

// NEW: Added symmetry analysis structure
struct SymmetryAnalysis {
  let shoulderAlignment: CGFloat
  let hipAlignment: CGFloat
}

struct PoseDetectionResult: Codable {
  var landmarks: [PoseLandmark]
  var connections: [(from: PoseLandmark, to: PoseLandmark)]

  private enum CodingKeys: String, CodingKey {
      case landmarks
      case connections
  }

  func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(landmarks, forKey: .landmarks)

      // Convert connections to a codable format
      let codableConnections = connections.map { connection in
          [connection.from, connection.to]
      }
      try container.encode(codableConnections, forKey: .connections)
  }

  init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.landmarks = try container.decode([PoseLandmark].self, forKey: .landmarks)

      // Decode connections from the codable format
      let codableConnections = try container.decode([[PoseLandmark]].self, forKey: .connections)
      self.connections = codableConnections.map { pair in
          (from: pair[0], to: pair[1])
      }
  }

  // Standard initializer
  init(landmarks: [PoseLandmark], connections: [(from: PoseLandmark, to: PoseLandmark)]) {
      self.landmarks = landmarks
      self.connections = connections
  }
}

struct PoseLandmark: Codable {
  var position: CGPoint
  var confidence: Float
  var type: LandmarkType

  init(position: CGPoint, confidence: Float, type: LandmarkType) {
      self.position = position
      self.confidence = confidence
      self.type = type
  }
}

enum LandmarkType: Int, Codable {
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
