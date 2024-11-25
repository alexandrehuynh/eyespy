//
//  CameraPreviewView.swift
//  eyespy
//
//  Created by Alex Huynh on 11/18/24.
//

import SwiftUI
import AVFoundation

// Added PermissionState enum
enum CameraPermissionState {
    case granted
    case denied
    case notDetermined
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    // Add orientation observer
    @ObservedObject private var orientationObserver = DeviceOrientationObserver()
    
    // Move state to StateObject to avoid view update conflicts
    @StateObject private var permissionHandler = CameraPermissionHandler()
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
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
    
    // Coordinator to handle view lifecycle
    class Coordinator {
        let parent: CameraPreviewView
        
        init(_ parent: CameraPreviewView) {
            self.parent = parent
        }
    }

// Separate permission handler class
class CameraPermissionHandler: ObservableObject {
    @Published var permissionState: CameraPermissionState = .notDetermined
    
    func checkCameraPermission() {
        // Move to background thread to avoid publishing during view updates
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.permissionState = .granted
                case .denied, .restricted:
                    self?.permissionState = .denied
                    self?.showPermissionDeniedView()
                case .notDetermined:
                    self?.requestCameraPermission()
                @unknown default:
                    self?.permissionState = .denied
                    self?.showPermissionDeniedView()
                }
            }
        }
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionState = granted ? .granted : .denied
                if !granted {
                    self?.showPermissionDeniedView()
                }
            }
        }
    }
    
    private func showPermissionDeniedView() {
        DispatchQueue.main.async {
            let deniedView = UIHostingController(rootView: CameraPermissionDeniedView())
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(deniedView, animated: true)
            }
        }
    }
}// Permission denied view
struct CameraPermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Camera Access Required")
                .font(.title2)
                .bold()
            
            Text("EyeSpy needs camera access to analyze your movements. Please enable camera access in Settings.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }) {
                Text("Open Settings")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
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

// pose visualization
struct PoseVisualizationView: View {
  let pose: PoseDetectionResult

  init(pose: PoseDetectionResult) {
      self.pose = pose
  }

  var body: some View {
      GeometryReader { geometry in
          ZStack {
              // Draw connections
              ForEach(pose.connections.indices, id: \.self) { index in
                  let connection = pose.connections[index]
                  Path { path in
                      path.move(to: scaledPoint(connection.from.position, in: geometry))
                      path.addLine(to: scaledPoint(connection.to.position, in: geometry))
                  }
                  .stroke(Color.green, lineWidth: 3)
              }

              // Draw landmarks
              ForEach(pose.landmarks.indices, id: \.self) { index in
                  let landmark = pose.landmarks[index]
                  Circle()
                      .fill(Color.blue)
                      .frame(width: 10, height: 10)
                      .position(scaledPoint(landmark.position, in: geometry))
              }
          }
      }
  }

  private func scaledPoint(_ point: CGPoint, in geometry: GeometryProxy) -> CGPoint {
      CGPoint(
          x: point.x * geometry.size.width,
          y: point.y * geometry.size.height
      )
  }
}

// Preview provider for SwiftUI canvas
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
