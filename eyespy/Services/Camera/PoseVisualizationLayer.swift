//
//  PoseVisualizationLayer.swift
//  eyespy
//
//  Created by Alex Huynh on 11/18/24.
//

import QuartzCore
import UIKit

class PoseVisualizationLayer: CALayer {
    private let pointSize: CGFloat = 10.0
    private let lineWidth: CGFloat = 3.0
    private let pointColor = UIColor.green.cgColor
    private let lineColor = UIColor.yellow.cgColor

    var pose: PoseDetectionResult? {
        didSet {
            setNeedsDisplay()
        }
    }

    override func draw(in ctx: CGContext) {
        super.draw(in: ctx)

        guard let pose = pose else { return }

        // Draw landmarks
        for landmark in pose.landmarks {
            let point = CGPoint(
                x: landmark.position.x * bounds.width,
                y: landmark.position.y * bounds.height
            )

            ctx.setFillColor(pointColor)
            let rect = CGRect(
                x: point.x - pointSize/2,
                y: point.y - pointSize/2,
                width: pointSize,
                height: pointSize
            )
            ctx.fillEllipse(in: rect)
        }

        // Draw connections
        ctx.setStrokeColor(lineColor)
        ctx.setLineWidth(lineWidth)

        for connection in pose.connections {
            let startPoint = CGPoint(
                x: connection.from.position.x * bounds.width,
                y: connection.from.position.y * bounds.height
            )
            let endPoint = CGPoint(
                x: connection.to.position.x * bounds.width,
                y: connection.to.position.y * bounds.height
            )

            ctx.move(to: startPoint)
            ctx.addLine(to: endPoint)
            ctx.strokePath()
        }
    }
}
