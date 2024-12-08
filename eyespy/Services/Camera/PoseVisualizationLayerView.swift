//
//  PoseVisualizationLayerView.swift
//  eyespy
//
//  Created by Alex Huynh on 12/8/24.
//

import SwiftUI
import UIKit
import QuartzCore

struct PoseVisualizationLayerView: UIViewRepresentable {
    let pose: PoseDetectionResult

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let visualizationLayer = PoseVisualizationLayer()

        // Configure the visualization layer
        visualizationLayer.frame = view.bounds

        // Set layer properties for automatic resizing
        visualizationLayer.contentsGravity = .resizeAspectFill
        visualizationLayer.needsDisplayOnBoundsChange = true

        // Add the layer to the view's layer hierarchy
        view.layer.addSublayer(visualizationLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let visualizationLayer = uiView.layer.sublayers?.first as? PoseVisualizationLayer else { return }

        // Update layer frame and pose
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        visualizationLayer.frame = uiView.bounds
        visualizationLayer.pose = pose
        CATransaction.commit()
    }
}
