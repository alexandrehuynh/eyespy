//
//  MediaPipeService.swift
//  eyespy
//
//  Created by Alex Huynh on 11/18/24.
//

import MediaPipeTasksVision
import Metal
import MetalKit
import CoreGraphics
import Combine
import UIKit

enum MediaPipeServiceError: Error {
  case modelLoadError
  case processingError
  case invalidInput
}

enum ProcessingStatus: Equatable {
  case idle
  case processing
  case error(String)

  static func == (lhs: ProcessingStatus, rhs: ProcessingStatus) -> Bool {
      switch (lhs, rhs) {
      case (.idle, .idle):
          return true
      case (.processing, .processing):
          return true
      case (.error(let lhsError), .error(let rhsError)):
          return lhsError == rhsError
      default:
          return false
      }
  }
}

protocol MediaPipeServiceDelegate: AnyObject {
  func mediaPipeService(_ service: MediaPipeService, didEncounterError error: Error)
  func mediaPipeService(_ service: MediaPipeService, didUpdateProcessingStatus status: ProcessingStatus)
}

class MediaPipeService: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private var poseLandmarker: PoseLandmarker?
    
    @Published var currentPoseResult: PoseDetectionResult?
    
    // Added dedicated queues for processing and updates
    private let processingQueue = DispatchQueue(label: "com.eyespy.mediapipe.processing", qos: .userInitiated)
    private let updateQueue = DispatchQueue.main
    
    // Add initialization flag
    private var isLandmarkerInitialized = false
    private let initializationQueue = DispatchQueue(label: "com.eyespy.mediapipe.initialization")
    
    private var processingMetrics = (
        processed: 0,
        skipped: 0,
        total: 0
    )
    
    // Added Combine publishers for better state management
    let posePublisher = PassthroughSubject<PoseDetectionResult, Never>()
    let statusPublisher = PassthroughSubject<ProcessingStatus, Never>()
    let errorPublisher = PassthroughSubject<MediaPipeServiceError, Never>()
    
    @Published var processingStatus: ProcessingStatus = .idle
    weak var delegate: MediaPipeServiceDelegate?
    
    private var lastProcessingTime: CFTimeInterval = 0
    private var averageProcessingTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    
    init() {
        setupPoseLandmarker()
    }
    
    private func setupPoseLandmarker() {
        initializationQueue.async { [weak self] in
            guard let self = self else { return }
            
            let options = PoseLandmarkerOptions()
            options.baseOptions.modelAssetPath = "pose_landmarker_lite.task"
            options.runningMode = .video  // Explicitly set video mode
            options.numPoses = 1
            
            do {
                self.poseLandmarker = try PoseLandmarker(options: options)
                self.isLandmarkerInitialized = true
                print("PoseLandmarker initialized successfully in .video mode")
                
                self.updateQueue.async {
                    self.processingStatus = .idle
                    self.statusPublisher.send(.idle)
                }
            } catch {
                print("Error initializing PoseLandmarker: \(error)")
                self.updateQueue.async {
                    self.errorPublisher.send(.modelLoadError)
                    self.processingStatus = .error("Failed to load pose detection model")
                    self.statusPublisher.send(.error("Failed to load pose detection model"))
                }
            }
        }
    }
    
    func processFrame(_ pixelBuffer: CVPixelBuffer, timestamp: Int64) {
        guard isLandmarkerInitialized else {
            print("PoseLandmarker not yet initialized")
            processingMetrics.skipped += 1
            processingMetrics.total += 1
            return
        }
        
        guard let landmarker = poseLandmarker else {
            print("PoseLandmarker is nil")
            processingMetrics.skipped += 1
            processingMetrics.total += 1
            return
        }

        do {
            let mpImage = try MPImage(pixelBuffer: pixelBuffer)
            print("MPImage created successfully.")

            processingQueue.async { [weak self, mpImage] in
                guard let self = self else { return }

                self.updateQueue.async {
                    self.processingStatus = .processing
                    self.statusPublisher.send(.processing)
                }

                let startTime = CACurrentMediaTime()

                do {
                    let result = try landmarker.detect(image: mpImage)
                    print("PoseLandmarker returned results: \(result.landmarks.count) poses detected.")

                    if let firstPose = result.landmarks.first {
                        let landmarks = self.convertToLandmarks(firstPose)
                        let poseResult = PoseDetectionResult(
                            landmarks: landmarks,
                            connections: self.getConnections(landmarks)
                        )
                        print("Detected pose: \(poseResult.landmarks.count) landmarks.")

                        self.updateQueue.async {
                            self.currentPoseResult = poseResult
                            self.posePublisher.send(poseResult)
                            self.processingStatus = .idle
                            self.statusPublisher.send(.idle)
                        }
                    } else {
                        print("No pose landmarks detected.")
                        self.processingMetrics.skipped += 1
                    }

                    let processingDuration = CACurrentMediaTime() - startTime
                    self.updateProcessingMetrics(processingDuration: processingDuration)

                } catch {
                    self.processingMetrics.skipped += 1
                    self.updateQueue.async {
                        self.processingStatus = .error("Failed to process frame")
                        self.errorPublisher.send(.processingError)
                    }
                    print("Error processing frame: \(error)")
                }
            }
        } catch {
            processingMetrics.skipped += 1
            processingMetrics.total += 1
            updateQueue.async {
                self.processingStatus = .error("Failed to create MPImage")
                self.errorPublisher.send(.processingError)
            }
            print("Error creating MPImage: \(error)")
        }
    }
    
    private func updateProcessingMetrics(processingDuration: CFTimeInterval) {
        processingMetrics.processed += 1
        processingMetrics.total += 1
        frameCount += 1
        averageProcessingTime = (averageProcessingTime * Double(frameCount - 1) + processingDuration) / Double(frameCount)
        lastProcessingTime = CACurrentMediaTime()
    }

    func getProcessingMetrics() -> (processed: Int, skipped: Int, total: Int) {
        return processingMetrics
    }

    func resetProcessingMetrics() {
        processingMetrics = (processed: 0, skipped: 0, total: 0)
        frameCount = 0
        lastProcessingTime = 0
        averageProcessingTime = 0
    }
    
    // MARK: - Future Implementation
    /// Buffer copying functionality - may be needed for future recording/playback features
    /// Currently unused in Phase 1 (Core Features Implementation)
    /*
    private func copyPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let pixelFormat = kCVPixelFormatType_32BGRA // Ensure compatible format
        var newPixelBuffer: CVPixelBuffer?

        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        CVPixelBufferCreate(nil, width, height, pixelFormat, attributes as CFDictionary, &newPixelBuffer)

        guard let buffer = newPixelBuffer,
              let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer),
              let newBaseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            fatalError("Failed to create and copy pixel buffer.")
        }

        memcpy(newBaseAddress, baseAddress, CVPixelBufferGetDataSize(pixelBuffer))
        return buffer
    }
     */
    
    func processStaticImage(_ image: UIImage) {
        let options = PoseLandmarkerOptions()
        options.baseOptions.modelAssetPath = "pose_landmarker_lite.task"
        options.runningMode = .image // Set to image mode for static processing

        do {
            let landmarker = try PoseLandmarker(options: options)
            let pixelBuffer = image.toPixelBuffer()!
            let mpImage = try MPImage(pixelBuffer: pixelBuffer)
            let result = try landmarker.detect(image: mpImage)
            print("Static image pose detected: \(result.landmarks.count) poses")
        } catch {
            print("Error processing static image: \(error)")
        }
    }
    
    private func createPixelBuffer(from originalPixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        var newPixelBuffer: CVPixelBuffer?
        let width = CVPixelBufferGetWidth(originalPixelBuffer)
        let height = CVPixelBufferGetHeight(originalPixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(originalPixelBuffer)
        let attributes: CFDictionary? = nil

        CVPixelBufferCreate(nil, width, height, pixelFormat, attributes, &newPixelBuffer)
        return newPixelBuffer
    }

     private func convertToLandmarks(_ landmarks: [NormalizedLandmark]) -> [PoseLandmark] {
         return landmarks.enumerated().map { (index, landmark) in
             PoseLandmark(
                 position: CGPoint(
                     x: CGFloat(landmark.x),
                     y: CGFloat(landmark.y)
                 ),
                 confidence: Float(truncating: landmark.visibility ?? 0.0),
                 type: LandmarkType(rawValue: index) ?? .nose
             )
         }
     }

     private func getConnections(_ landmarks: [PoseLandmark]) -> [(from: PoseLandmark, to: PoseLandmark)] {
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
