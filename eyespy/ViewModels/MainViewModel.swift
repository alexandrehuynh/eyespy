//
//  MainViewModel.swift
//  eyespy
//
//  Created by Alex Huynh on 11/21/24.
//
import Combine
import AVFoundation

class MainViewModel: ObservableObject {
    private let cameraManager = CameraManager()
    private let mediaPipeService = MediaPipeService()
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isRunning: Bool = false
    @Published var currentPose: PoseDetectionResult?
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind camera state
        cameraManager.$isRunning
            .assign(to: \.isRunning, on: self)
            .store(in: &cancellables)
        
        // Connect camera frames to MediaPipeService
        cameraManager.$currentFrame
            .compactMap { \$0 }
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .sink { [weak self] sampleBuffer in
                guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
                let timestamp = Int64(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1000)
                self?.mediaPipeService.processFrame(pixelBuffer, timestamp: timestamp)
            }
            .store(in: &cancellables)
        
        // Bind pose results
        mediaPipeService.$currentPoseResult
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentPose, on: self)
            .store(in: &cancellables)
    }
    
    func startSession() {
        cameraManager.startSession()
    }
    
    func stopSession() {
        cameraManager.stopSession()
    }
    
    // Expose camera manager for preview view
    var captureSession: AVCaptureSession {
        cameraManager.captureSession
    }
}
