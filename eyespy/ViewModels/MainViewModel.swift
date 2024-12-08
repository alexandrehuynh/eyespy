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

    @Published var isRunning: Bool = false
    @Published var currentPose: PoseDetectionResult?
    @Published private(set) var cameraState: CameraState = .setup
    @Published private(set) var processingState: ProcessingStatus = .idle

    let errorSubject = PassthroughSubject<ViewModelError, Never>()

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
        cameraManager.$isRunning
            .assign(to: &$isRunning)

        cameraManager.$currentFrame
            .compactMap { \$0 }
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .sink { [weak self] sampleBuffer in
                guard let self = self,
                      let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
                let timestamp = Int64(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1000)
                self.mediaPipeService.processFrame(pixelBuffer, timestamp: timestamp)
            }
            .store(in: &cancellables)

        mediaPipeService.$currentPoseResult
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pose in
                self?.currentPose = pose
            }
            .store(in: &cancellables)

        mediaPipeService.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.processingState = status
            }
            .store(in: &cancellables)

        mediaPipeService.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.handleMediaPipeError(error)
            }
            .store(in: &cancellables)
    }

    private func handleMediaPipeError(_ error: MediaPipeServiceError) {
        switch error {
        case .modelLoadError, .processingError, .invalidInput:
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
