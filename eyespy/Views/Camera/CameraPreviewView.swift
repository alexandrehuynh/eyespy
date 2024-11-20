//
//  CameraPreviewView.swift
//  eyespy
//
//  Created by Alex Huynh on 11/18/24.
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: CameraManager
    
    // Add orientation observer
    @ObservedObject private var orientationObserver = DeviceOrientationObserver()
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        // Set initial orientation
        updatePreviewLayerOrientation(previewLayer)
        
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            updatePreviewLayerOrientation(previewLayer)
        }
    }
    
    private func updatePreviewLayerOrientation(_ previewLayer: AVCaptureVideoPreviewLayer) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let interfaceOrientation = windowScene.interfaceOrientation
            let rotationAngle: Double
            
            switch interfaceOrientation {
            case .portrait:
                rotationAngle = 0
            case .portraitUpsideDown:
                rotationAngle = .pi
            case .landscapeLeft:
                rotationAngle = -.pi / 2
            case .landscapeRight:
                rotationAngle = .pi / 2
            default:
                rotationAngle = 0
            }
            
            previewLayer.setAffineTransform(CGAffineTransform(rotationAngle: rotationAngle))
        }
    }
}

// Device orientation observer class
private class DeviceOrientationObserver: ObservableObject {
    @Published var orientation: UIDeviceOrientation = .portrait
    
    init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    deinit {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func orientationChanged() {
        orientation = UIDevice.current.orientation
    }
}

// Placeholder for pose visualization
struct PoseVisualizationView: View {
    var body: some View {
        // This will be implemented later to show pose landmarks
        Color.clear
    }
}

// Preview provider for SwiftUI canvas
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
