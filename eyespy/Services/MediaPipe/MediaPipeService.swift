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

enum MediaPipeServiceError: Error {
  case modelLoadError
  case processingError
  case invalidInput
}

enum ProcessingStatus {
  case idle
  case processing
  case error(String)
}

protocol MediaPipeServiceDelegate: AnyObject {
  func mediaPipeService(_ service: MediaPipeService, didEncounterError error: Error)
  func mediaPipeService(_ service: MediaPipeService, didUpdateProcessingStatus status: ProcessingStatus)
}

class MediaPipeService: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private var poseLandmarker: PoseLandmarker?
    @Published var currentPoseResult: PoseDetectionResult?
    
    // NEW: Added dedicated queues for processing and updates
    private let processingQueue = DispatchQueue(label: "com.eyespy.mediapipe.processing", qos: .userInitiated)
    private let updateQueue = DispatchQueue.main
    
    // NEW: Added Combine publishers for better state management
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
        // NEW: Run setup on processing queue
        processingQueue.async { [weak self] in
            let options = PoseLandmarkerOptions()
            options.baseOptions.modelAssetPath = "pose_landmarker_lite.task"
            options.runningMode = .video
            options.numPoses = 1
            
            do {
                self?.poseLandmarker = try PoseLandmarker(options: options)
            } catch {
                self?.updateQueue.async {
                    let modelError = MediaPipeServiceError.modelLoadError
                    self?.delegate?.mediaPipeService(self!, didEncounterError: modelError)
                    self?.processingStatus = .error("Failed to load pose detection model")
                    self?.delegate?.mediaPipeService(self!, didUpdateProcessingStatus: self!.processingStatus)
                    self?.errorPublisher.send(.modelLoadError)
                }
                print("Error setting up pose landmarker: \(error)")
            }
        }
    }
    
    private func updateProcessingMetrics(processingDuration: CFTimeInterval) {
        frameCount += 1
        averageProcessingTime = (averageProcessingTime * Double(frameCount - 1) + processingDuration) / Double(frameCount)
        lastProcessingTime = CACurrentMediaTime()
    }
    
    func getPerformanceMetrics() -> (averageTime: CFTimeInterval, lastFrameTime: CFTimeInterval, frameCount: Int) {
        return (averageProcessingTime, lastProcessingTime, frameCount)
    }
    
    // NEW: Updated process frame with proper queue management
    func processFrame(_ pixelBuffer: CVPixelBuffer, timestamp: Int64) {
        // Lock and copy the pixel buffer before entering the async block
        let copiedBuffer = copyPixelBuffer(pixelBuffer)
        
        guard let landmarker = poseLandmarker else {
            updateQueue.async { [weak self] in
                guard let self = self else { return }
                self.processingStatus = .error("Pose landmarker not initialized")
                self.delegate?.mediaPipeService(self, didUpdateProcessingStatus: self.processingStatus)
            }
            return
        }

        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Process copiedBuffer in the async block
            self.updateQueue.async {
                self.processingStatus = .processing
                self.statusPublisher.send(.processing)
                self.delegate?.mediaPipeService(self, didUpdateProcessingStatus: self.processingStatus)
            }

            let startTime = CACurrentMediaTime()

            do {
                let mpImage = try MPImage(pixelBuffer: copiedBuffer)
                let result = try landmarker.detect(image: mpImage)

                if let firstPose = result.landmarks.first {
                    let landmarks = self.convertToLandmarks(firstPose)
                    let poseResult = PoseDetectionResult(
                        landmarks: landmarks,
                        connections: self.getConnections(landmarks)
                    )

                    self.updateQueue.async {
                        self.currentPoseResult = poseResult
                        self.posePublisher.send(poseResult)
                        self.processingStatus = .idle
                        self.statusPublisher.send(.idle)
                        self.delegate?.mediaPipeService(self, didUpdateProcessingStatus: self.processingStatus)
                    }
                }

                let processingDuration = CACurrentMediaTime() - startTime
                self.updateProcessingMetrics(processingDuration: processingDuration)

            } catch {
                self.updateQueue.async {
                    let processingError = MediaPipeServiceError.processingError
                    self.delegate?.mediaPipeService(self, didEncounterError: processingError)
                    self.processingStatus = .error("Failed to process frame")
                    self.errorPublisher.send(.processingError)
                    self.statusPublisher.send(.error("Failed to process frame"))
                    self.delegate?.mediaPipeService(self, didUpdateProcessingStatus: self.processingStatus)
                }
                print("Error processing frame: \(error)")
            }
        }
    }
    
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
