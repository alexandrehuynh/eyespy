//
//  ContentView.swift
//  eyespy
//
//  Created by Alex Huynh on 11/18/24.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()

    var body: some View {
        ZStack {
            // Camera Preview Layer
            CameraPreviewView(session: viewModel.captureSession)
                .edgesIgnoringSafeArea(.all)

            // Loading State
            if !viewModel.isRunning {
                Color.black
                Text("Starting camera...")
                    .foregroundColor(.white)
            }

            // Pose Visualization Layer
            if let pose = viewModel.currentPose {
                PoseVisualizationLayerView(pose: pose) // Use the new wrapper
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
            }
        }
        .onAppear {
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.stopSession()
        }
    }
}
