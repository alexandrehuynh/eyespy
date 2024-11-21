import MediaPipeTasksVision
import Metal
import MetalKit
import CoreGraphics

// Added error enum
enum MediaPipeServiceError: Error {
    case modelLoadError
    case processingError
    case invalidInput
}

// Added ProcessingStatus enum before it's used
enum ProcessingStatus {
    case idle
    case processing
    case error(String)
}

// Updated delegate protocol with separate methods
protocol MediaPipeServiceDelegate: AnyObject {
    func mediaPipeService(_ service: MediaPipeService, didEncounterError error: Error)
    func mediaPipeService(_ service: MediaPipeService, didUpdateProcessingStatus status: ProcessingStatus)
}

class MediaPipeService: ObservableObject {
    private var poseLandmarker: PoseLandmarker?
    @Published var currentPoseResult: PoseDetectionResult?
    
    // Added status tracking
    @Published var processingStatus: ProcessingStatus = .idle
    
    // Added delegate
    weak var delegate: MediaPipeServiceDelegate?
    
    // Added performance metrics
    private var lastProcessingTime: CFTimeInterval = 0
    private var averageProcessingTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    
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
            // Enhanced error handling
            let modelError = MediaPipeServiceError.modelLoadError
            delegate?.mediaPipeService(self, didEncounterError: modelError)
            processingStatus = .error("Failed to load pose detection model")
            delegate?.mediaPipeService(self, didUpdateProcessingStatus: processingStatus)
            print("Error setting up pose landmarker: \(error)")
        }
    }
    
    // Added performance tracking method
    private func updateProcessingMetrics(processingDuration: CFTimeInterval) {
        frameCount += 1
        averageProcessingTime = (averageProcessingTime * Double(frameCount - 1) + processingDuration) / Double(frameCount)
        lastProcessingTime = CACurrentMediaTime()
    }
    
    // Added method to get performance metrics
    func getPerformanceMetrics() -> (averageTime: CFTimeInterval, lastFrameTime: CFTimeInterval, frameCount: Int) {
        return (averageProcessingTime, lastProcessingTime, frameCount)
    }
    
    func processFrame(_ pixelBuffer: CVPixelBuffer, timestamp: Int64) {
        guard let landmarker = poseLandmarker else {
            processingStatus = .error("Pose landmarker not initialized")
            delegate?.mediaPipeService(self, didUpdateProcessingStatus: processingStatus)
            return
        }
        
        // Added processing status update
        processingStatus = .processing
        delegate?.mediaPipeService(self, didUpdateProcessingStatus: processingStatus)
        
        // Added performance tracking
        let startTime = CACurrentMediaTime()
        
        do {
            let mpImage = try MPImage(pixelBuffer: pixelBuffer)
            let result = try landmarker.detect(image: mpImage)
            
            if let firstPose = result.landmarks.first {
                let landmarks = convertToLandmarks(firstPose)
                currentPoseResult = PoseDetectionResult(
                    landmarks: landmarks,
                    connections: getConnections(landmarks)
                )
                
                // Update processing status to idle after successful processing
                processingStatus = .idle
                delegate?.mediaPipeService(self, didUpdateProcessingStatus: processingStatus)
            }
            
            // Update performance metrics
            let processingDuration = CACurrentMediaTime() - startTime
            updateProcessingMetrics(processingDuration: processingDuration)
            
        } catch {
            // Enhanced error handling
            let processingError = MediaPipeServiceError.processingError
            delegate?.mediaPipeService(self, didEncounterError: processingError)
            processingStatus = .error("Failed to process frame")
            delegate?.mediaPipeService(self, didUpdateProcessingStatus: processingStatus)
            print("Error processing frame: \(error)")
        }
    }
    
    // Added method to reset metrics
    func resetPerformanceMetrics() {
        frameCount = 0
        averageProcessingTime = 0
        lastProcessingTime = 0
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
