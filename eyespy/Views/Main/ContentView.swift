//
//  ContentView.swift
//  eyespy
//
//  Created by Alex Huynh on 11/18/24.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        ZStack {
            CameraPreviewView(cameraManager: cameraManager)
                .edgesIgnoringSafeArea(.all)
            
            // Optional: Add an overlay to show when camera is starting
            if !cameraManager.isRunning {
                Color.black
                Text("Starting camera...")
                    .foregroundColor(.white)
            }
            
            // Optional: Add a pose visualization overlay here later
            PoseVisualizationView()
                .edgesIgnoringSafeArea(.all)
        }
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
}

