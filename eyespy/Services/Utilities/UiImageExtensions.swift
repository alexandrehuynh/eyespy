//
//  UiImageExtensions.swift
//  eyespy
//
//  Created by Alex Huynh on 12/24/24.
//

import UIKit
import CoreVideo

extension UIImage {
    func toPixelBuffer() -> CVPixelBuffer? {
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        var pixelBuffer: CVPixelBuffer?
        let width = Int(self.size.width)
        let height = Int(self.size.height)
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        let data = CVPixelBufferGetBaseAddress(buffer)
        
        guard let context = CGContext(data: data,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
            return nil
        }
        
        guard let cgImage = self.cgImage else {
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        
        return buffer
    }
}
