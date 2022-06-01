//
//  Image.swift
//  PaymentCardScanner
//
//  Created by Amir Abbas Mousavian on 11/26/99.
//  Copyright © 2020 Saman Solutions. All rights reserved.
//

import Foundation
import CoreVideo
import CoreImage
import Vision

public struct RectBoundary {
    public var topLeft: CGPoint
    public var topRight: CGPoint
    public var bottomLeft: CGPoint
    public var bottomRight: CGPoint
    public var boundingBox: CGRect
    
    public init(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint, boundingBox: CGRect) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
        self.boundingBox = boundingBox
    }
    
    public init(boundingBox: CGRect) {
        self.topLeft = .init(x: boundingBox.origin.x,
                             y: boundingBox.origin.y)
        self.topRight = .init(x: boundingBox.origin.x + boundingBox.width,
                              y: boundingBox.origin.y)
        self.bottomLeft = .init(x: boundingBox.origin.x,
                                y: boundingBox.origin.y + boundingBox.height)
        self.bottomRight = .init(x: boundingBox.origin.x + boundingBox.width,
                                 y: boundingBox.origin.y + boundingBox.height)
        self.boundingBox = boundingBox
    }
    
    public init(rectangeObservation: VNRectangleObservation) {
        self.topLeft = rectangeObservation.topLeft
        self.topRight = rectangeObservation.topRight
        self.bottomLeft = rectangeObservation.bottomLeft
        self.bottomRight = rectangeObservation.bottomRight
        self.boundingBox = rectangeObservation.boundingBox
    }
    
    public func normalize(to size: CGSize) -> RectBoundary {
        return .init(topLeft: size.imagePoint(normalzied: topLeft),
                     topRight: size.imagePoint(normalzied: topRight),
                     bottomLeft: size.imagePoint(normalzied: bottomLeft),
                     bottomRight: size.imagePoint(normalzied: bottomRight),
                     boundingBox: size.imageRect(normalized: boundingBox))
    }
    
    public func angles() -> [CGFloat] {
        let topLeftAngle = CGVector(topLeft, to: topRight).angle - CGVector(topLeft, to: bottomLeft).angle
        let topRightAngle = CGVector(topRight, to: topLeft).angle - CGVector(topRight, to: bottomRight).angle - .pi
        let bottomLeftAngle = CGVector(bottomLeft, to: topLeft).angle - CGVector(bottomLeft, to: bottomRight).angle
        let bottomRightAngle = CGVector(bottomRight, to: bottomLeft).angle - CGVector(bottomRight, to: topRight).angle
        return [topLeftAngle, topRightAngle,
                bottomLeftAngle, bottomRightAngle]
    }
    
    public func withInset(percent: CGFloat) -> RectBoundary {
        guard percent != 0 else { return self }
        var result = self
        result.topLeft += CGVector(bottomRight, to: topLeft) * percent
        result.topRight += CGVector(bottomLeft, to: topRight) * percent
        result.bottomLeft += CGVector(topRight, to: bottomLeft) * percent
        result.bottomRight += CGVector(topLeft, to: bottomRight) * percent
        return result
    }
}

public struct CaptureImage {
    public private(set) var image: Image
    public let focusPoint: CGPoint?
    public let time: CMTime
    public let brightness: CGFloat?

    internal init(
        image: Image,
        focusPoint: CGPoint? = nil,
        time: CMTime = .invalid,
        brightness: CGFloat? = nil
    ) {
        self.image = image
        self.focusPoint = focusPoint
        self.time = time
        self.brightness = brightness
    }
    
    func replace(_ image: Image) -> Self {
        var result = self
        result.image = image
        return result
    }
}

public enum Image {
    case buffer(CVImageBuffer)
    case cgImage(CGImage)
    case ciImage(CIImage)
    case fileUrl(URL)
    case data(Data)
    
    public var ciImage: CIImage? {
        switch self {
        case let .buffer(buffer):
            return CIImage(cvPixelBuffer: buffer)
        case let .cgImage(cgImage):
            return CIImage(cgImage: cgImage)
        case let .ciImage(ciImage):
            return ciImage
        case let .fileUrl(url):
            guard url.isFileURL else { return nil }
            return CIImage(contentsOf: url)
        case let .data(data):
            return CIImage(data: data)
        }
    }
    
    public var cgImage: CGImage? {
        switch self {
        case .buffer, .ciImage, .fileUrl, .data:
            let image = ciImage
            return image.flatMap { CIContext().createCGImage($0, from: $0.extent)! }
        case let .cgImage(cgImage):
            return cgImage
        }
    }
    
    public var size: CGSize {
        ciImage?.extent.standardized.size ?? .zero
    }
    
    public var bounds: CGRect {
        return .init(origin: .zero, size: size)
    }
    
    public func crop(_ rect: CGRect, withInset inset: CGFloat = 0) -> Image {
        switch self {
        case let .cgImage(cgImage):
            return cgImage.cropping(to: rect).map(Image.cgImage) ?? self
        default:
            guard let ciImage = self.ciImage else { return self }
            var rect = rect
            rect.origin.x += ciImage.extent.origin.x
            rect.origin.y += ciImage.extent.origin.y
            rect = rect.insetBy(dx: -rect.width * inset,
                                dy: -rect.height * inset)
            return .ciImage(ciImage.cropped(to: rect))
        }
    }
    
    public func rotate(_ radianAngle: CGFloat) -> Image {
        guard radianAngle != 0 else { return self }
        switch self {
        case let .cgImage(cgImage):
            return cgImage
                .rotated(radians: radianAngle, flipOverHorizontalAxis: true, flipOverVerticalAxis: false)
                .map(Image.cgImage) ?? self
        case let .ciImage(ciImage):
            let transform = CGAffineTransform(translationX: ciImage.extent.midX, y: ciImage.extent.midY)
                .rotated(by: radianAngle)
                .translatedBy(x: -ciImage.extent.midX, y: -ciImage.extent.midY)
//            return .ciImage(ciImage.transformed(by: transform))
            return .ciImage(ciImage.applyingFilter("CIAffineTransform", parameters: [kCIInputTransformKey: transform]))

        default:
            return ciImage.map(Image.ciImage)?.rotate(radianAngle) ?? self
        }
    }
    
    public enum Orientation {
        case horizontal, vertical
    }
    
    public func oriented(to orientation: Orientation) -> Image {
        let ratio = size.width / size.height
        guard ratio != 1 else { return self }
        let isOriented = (orientation == .horizontal && ratio > 1) || (orientation == .vertical && ratio < 1)
        return isOriented ? self : rotate(-.pi / 2)
    }
    
    public func perspectiveCorrection(to bound: RectBoundary) -> Image {
        guard let ciImage = self.ciImage else { return self }
        let perspectiveTransform = CIFilter(name: "CIPerspectiveCorrection")!
        perspectiveTransform.setValue(CIVector(cgPoint: bound.topLeft),forKey: "inputTopLeft")
        perspectiveTransform.setValue(CIVector(cgPoint: bound.topRight),forKey: "inputTopRight")
        perspectiveTransform.setValue(CIVector(cgPoint: bound.bottomLeft),forKey: "inputBottomLeft")
        perspectiveTransform.setValue(CIVector(cgPoint: bound.bottomRight),forKey: "inputBottomRight")
        perspectiveTransform.setValue(ciImage,forKey: kCIInputImageKey)
        
        return perspectiveTransform.outputImage.flatMap(Image.ciImage) ?? self
    }
}

extension VNSequenceRequestHandler {
    func perform(_ requests: [VNRequest], on image: Image) throws {
        switch image {
        case let .buffer(buffer):
            try perform(requests, on: buffer)
        case let .cgImage(cgImage):
            try perform(requests, on: cgImage)
        case let .ciImage(ciImage):
            try perform(requests, on: ciImage)
        case let .fileUrl(url):
            try perform(requests, onImageURL: url)
        case let .data(data):
            try perform(requests, onImageData: data)
        }
    }
}
