//
//  CameraManager.swift
//  eyespy
//
//  Created by Alex Huynh on 11/18/24.
//

import AVFoundation
import UIKit
import Combine

// NEW: Added error enum for better error handling
enum CameraError: Error {
    case deviceNotFound
    case inputError
    case permissionDenied
    case setupFailed
}

class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, ObservableObject {
    public let captureSession = AVCaptureSession()
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var frameMetrics = (
        processed: 0,
        skipped: 0,
        total: 0
    )
    private var lastProcessedFrameTime: CFTimeInterval = 0
    private let minimumFrameInterval: CFTimeInterval = 1.0 / 30.0 // 30 FPS
    private let mediaPipeService: MediaPipeService
    
    @Published var isRunning: Bool = false
    @Published var currentFrame: CMSampleBuffer?
    @Published var error: CameraError?
    
    init(mediaPipeService: MediaPipeService) {
        self.mediaPipeService = mediaPipeService
        super.init()
        checkCameraPermissions { [weak self] granted in
            if granted {
                self?.setupCaptureSession()
            } else {
                self?.error = .permissionDenied
            }
        }
    }
    
    @objc func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRunning else { return }
        
        DispatchQueue.main.async {
            self.currentFrame = sampleBuffer
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Error: Could not get pixel buffer from sampleBuffer.")
            return
        }
        
        let timestamp = Int64(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1000)
        
        frameMetrics.total += 1
        
        let currentTime = CACurrentMediaTime()
        if currentTime - lastProcessedFrameTime >= minimumFrameInterval {
            frameMetrics.processed += 1
            print("Processing frame at timestamp: \(timestamp) (Total: \(frameMetrics.processed)/\(frameMetrics.total))")
            mediaPipeService.processFrame(pixelBuffer, timestamp: timestamp)
            lastProcessedFrameTime = currentTime
        } else {
            frameMetrics.skipped += 1
            print("Skipping frame to maintain 30 FPS (Skipped: \(frameMetrics.skipped)/\(frameMetrics.total))")
        }
    }
    
    func getFrameMetrics() -> (processed: Int, skipped: Int, total: Int) {
        return frameMetrics
    }
    
    func resetMetrics() {
        frameMetrics = (processed: 0, skipped: 0, total: 0)
        lastProcessedFrameTime = 0
    }
    
    // Added permission handling
    private func checkCameraPermissions(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    // Modified setupCaptureSession with error handling and completion
    private func setupCaptureSession(completion: ((Result<Void, CameraError>) -> Void)? = nil) {
        // NEW: Added session preset
        captureSession.sessionPreset = .high
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            error = .deviceNotFound
            completion?(.failure(.deviceNotFound))
            return
        }
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if captureSession.canAddInput(videoDeviceInput) {
                captureSession.addInput(videoDeviceInput)
            } else {
                error = .inputError
                completion?(.failure(.inputError))
                return
            }
            
            let videoDataOutput = AVCaptureVideoDataOutput()
            
            // Added video settings
            videoDataOutput.videoSettings = [
                (kCVPixelBufferPixelFormatTypeKey as String): Int(kCVPixelFormatType_32BGRA)
            ]
            
            videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            
            if captureSession.canAddOutput(videoDataOutput) {
                captureSession.addOutput(videoDataOutput)
                self.videoDataOutput = videoDataOutput
                completion?(.success(()))
            } else {
                error = .setupFailed
                completion?(.failure(.setupFailed))
            }
            
        } catch {
            self.error = .setupFailed
            completion?(.failure(.setupFailed))
        }
    }
    
    // Enhanced session control methods with completion handlers
    func startSession(completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.isRunning = true
                completion?(true)
            }
        }
    }
    
    func stopSession(completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
                completion?(true)
            }
        }
    }
    
    // Added method to reset session
    func resetSession(completion: ((Result<Void, CameraError>) -> Void)? = nil) {
        stopSession { [weak self] _ in
            self?.captureSession.beginConfiguration()
            
            // Remove all inputs and outputs
            for input in self?.captureSession.inputs ?? [] {
                self?.captureSession.removeInput(input)
            }
            for output in self?.captureSession.outputs ?? [] {
                self?.captureSession.removeOutput(output)
            }
            
            self?.captureSession.commitConfiguration()
            
            // Reset metrics
            self?.resetMetrics()
            
            // Reconfigure the session
            self?.setupCaptureSession(completion: completion)
        }
    }
}
