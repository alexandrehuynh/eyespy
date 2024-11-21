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
            CameraPreviewView(session: viewModel.captureSession)
                .edgesIgnoringSafeArea(.all)
            
            if !viewModel.isRunning {
                Color.black
                Text("Starting camera...")
                    .foregroundColor(.white)
            }
            
            if let pose = viewModel.currentPose {
                PoseVisualizationView(pose: pose)
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
