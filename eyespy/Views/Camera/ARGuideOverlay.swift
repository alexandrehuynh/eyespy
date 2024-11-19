//
//  ARGuideOverlay.swift
//  eyespy
//
//  Created by Alex Huynh on 11/18/24.
//

import SwiftUI

struct ARGuideOverlay: View {
    var body: some View {
        VStack {
            // Your overlay content here
            Text("AR Guide")
                .foregroundColor(.white)
                .padding()
            
            // Add more UI elements as needed
        }
    }
}

// Preview provider for SwiftUI preview
struct ARGuideOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ARGuideOverlay()
            .background(Color.black.opacity(0.5))
    }
}
