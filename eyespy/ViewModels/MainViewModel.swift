//
//  MainViewModel.swift
//  eyespy
//
//  Created by Alex Huynh on 11/21/24.
//
import AVFoundation
import CoreMedia
import Combine

class MainViewModel: ObservableObject {
  private let mediaPipeService: MediaPipeService
  private let cameraManager: CameraManager
  private var cancellables = Set<AnyCancellable>()

    init() {
        self.mediaPipeService = MediaPipeService()
        self.cameraManager = CameraManager(mediaPipeService: mediaPipeService)
        setupBindings()
    }

  // NEW: Added additional state management properties
  @Published var isRunning: Bool = false
  @Published var currentPose: PoseDetectionResult?
  @Published private(set) var cameraState: CameraState = .setup
  @Published private(set) var processingState: ProcessingStatus = .idle

  // NEW: Added error handling
  let errorSubject = PassthroughSubject<ViewModelError, Never>()

  // NEW: Added state enums
  enum CameraState {
      case setup
      case running
      case paused
      case error(Error)
  }

  enum ViewModelError: Error {
      case cameraSetupFailed
      case processingFailed
      case poseDetectionFailed
  }

    private func setupBindings() {
        // Fix the isRunning binding
        cameraManager.$isRunning
            .assign(to: &$isRunning)

        // Fix the currentFrame binding
        cameraManager.$currentFrame
            .compactMap { $0 } // Ensure non-nil frames
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .sink { [weak self] sampleBuffer in
                guard let self = self,
                      let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
                let timestamp = Int64(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1000)
                self.mediaPipeService.processFrame(pixelBuffer, timestamp: timestamp)
            }
            .store(in: &cancellables)

        // Bind pose results
        mediaPipeService.$currentPoseResult
            .receive(on: DispatchQueue.main)
            .sink { pose in
                if let pose = pose {
                    print("Pose received in MainViewModel: \(pose)")
                } else {
                    print("Received nil pose")
                }
            }
            .store(in: &cancellables)

        // Bind processing state
        mediaPipeService.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.processingState = status
            }
            .store(in: &cancellables)

        // Bind error handling
        mediaPipeService.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.handleMediaPipeError(error)
            }
            .store(in: &cancellables)
    }
    
  // NEW: Error handling method
  private func handleMediaPipeError(_ error: MediaPipeServiceError) {
      switch error {
      case .modelLoadError:
          errorSubject.send(.processingFailed)
      case .processingError:
          errorSubject.send(.processingFailed)
      case .invalidInput:
          errorSubject.send(.processingFailed)
      }
  }

  func startSession() {
      cameraManager.startSession()
      cameraState = .running
  }

  func stopSession() {
      cameraManager.stopSession()
      cameraState = .paused
  }

  var captureSession: AVCaptureSession {
      cameraManager.captureSession
  }
}
