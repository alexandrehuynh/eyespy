//
//  PoseVisualizationLayer.swift
//  eyespy
//
//  Created by Alex Huynh on 11/18/24.
//

import QuartzCore
import UIKit

class PoseVisualizationLayer: CALayer {
    func updateWithPoseResults(_ results: CustomPoseResult) {  // Changed to CustomPoseResult
        sublayers?.removeAll()
        
        drawPoseLandmarks(results)
        drawPoseConnections(results)
    }
    
    private func drawPoseLandmarks(_ results: CustomPoseResult) {  // Changed to CustomPoseResult
        for landmark in results.landmarks {
            // Only draw landmarks with sufficient visibility
            if landmark.visibility > 0.5 {
                let dot = CALayer()
                dot.frame = CGRect(x: landmark.position.x - 4,
                                 y: landmark.position.y - 4,
                                 width: 8,
                                 height: 8)
                dot.cornerRadius = 4
                dot.backgroundColor = UIColor.green.cgColor
                addSublayer(dot)
            }
        }
    }
    
    private func drawPoseConnections(_ results: CustomPoseResult) {  // Changed to CustomPoseResult
        for connection in results.connections {
            let path = UIBezierPath()
            path.move(to: connection.from.position)
            path.addLine(to: connection.to.position)
            
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = path.cgPath
            shapeLayer.strokeColor = UIColor.blue.cgColor
            shapeLayer.lineWidth = 2
            shapeLayer.fillColor = nil
            
            addSublayer(shapeLayer)
        }
    }
}
