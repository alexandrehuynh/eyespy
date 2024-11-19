//
//  CameraTypes.swift
//  eyespy
//
//  Created by Alex Huynh on 11/18/24.
//

enum DistanceStatus {
    case tooClose
    case optimal
    case tooFar
}

enum LightingStatus {
    case tooLow
    case good
    case tooBright
    case checking
}

enum FrameAlignment {
    case left
    case center
    case right
    case tooHigh
    case tooLow
}
