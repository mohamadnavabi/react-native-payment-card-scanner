//
//  Extensions.swift
//  PaymentCardScanner
//
//  Created by Amir Abbas Mousavian on 11/19/99.
//  Copyright © 1399 AP Anurag Ajwani. All rights reserved.
//

import Foundation
import CoreGraphics
import CoreVideo
import Vision
import CoreImage
import Combine

extension StringProtocol {
    func subsetOf(_ sets: [CharacterSet]) -> Bool {
        sets.reduce(CharacterSet()) {
            $0.union($1)
        }.isSuperset(of: CharacterSet(charactersIn: String(self)))
    }
    
    var isNumeric: Bool {
        subsetOf([.decimalDigits])
    }
    
    var isAlphabetic: Bool {
        subsetOf([.letters])
    }
    
    var isNumericOrWhitespace: Bool {
        subsetOf([.decimalDigits, .whitespaces])
    }
    
    func numeric() -> String {
        compactMap { $0.isNumber ? String($0) : nil }.joined()
    }
    
    func numericPunc() -> String {
        compactMap { $0.isNumber || $0.isPunctuation ? String($0) : nil }.joined()
    }
    
    func numericSlash() -> String {
        compactMap { $0.isNumber || String($0) == "/" ? String($0) : nil }.joined()
    }
    
    func matches(regex: String) -> Bool {
        range(of: regex, options: .regularExpression) != nil
    }
}

extension Optional where Wrapped: Collection {
    var isNullOrEmpty: Bool {
        self == nil || self!.isEmpty
    }
}

extension Array where Element == VNRecognizedTextObservation {
    func texts(minConfidence: VNConfidence = 0.8, trimming: Bool = true) -> [String] {
        let textsRecognized = flatMap { $0.topCandidates(1) }
        
        let maxConfidence: VNConfidence
        if #available(iOS 14.0, macOS 11.0, *) {
            maxConfidence = 1
        } else {
            maxConfidence = 0.3
        }
        return textsRecognized
            .filter { ($0.confidence / maxConfidence) > minConfidence }
            .map { trimming ? $0.string.trimmingCharacters(in:  .whitespaces) : $0.string }
    }
}

class AtomicValue<Value> {
    private var _value: Value?
    private let queue = DispatchQueue(label: "Atomic", qos: .userInitiated)
    
    var value: Value? {
        get { queue.sync { _value }}
        set { queue.async { self._value = newValue }}
    }
    
    init() {
        self._value = nil
    }
    
    init(_ initialValue: Value) {
        self._value = initialValue
    }
    
    func assignIfNil(_ value: Value) {
        queue.async {
            if self._value == nil {
                self._value = value
            }
        }
    }
    
    func update(_ handler: @escaping (inout Value?) -> Void) {
        queue.async {
            handler(&self._value)
        }
    }
}

@propertyWrapper
public struct Atomic<Value> {
    
    private var atomicValue: AtomicValue<Value>

    public init(wrappedValue defaultValue: Value) {
        atomicValue = .init(defaultValue)
    }
    
    public var wrappedValue: Value {
        get { atomicValue.value! }
        set { atomicValue.value = newValue }
    }
    
    public func update(_ handler: @escaping (inout Value?) -> Void) {
        atomicValue.update(handler)
    }
}

extension CGFloat {
    func within(mean: CGFloat, tolerance: CGFloat) -> Bool {
        return mean * (1 - tolerance) <= self && self <= mean * (1 + tolerance)
    }
}

extension CGSize {
    func imagePoint(normalzied point: CGPoint) -> CGPoint {
        guard height > 0, width > 0 else { return .zero }
        return VNImagePointForNormalizedPoint(point, Int(width), Int(height))
    }
    
    func imageRect(normalized rect: CGRect) -> CGRect {
        guard height > 0, width > 0 else { return .zero }
        return VNImageRectForNormalizedRect(rect, Int(width), Int(height))
    }
}

extension CGVector {
    init(_ startPoint: CGPoint, to endPoint: CGPoint) {
        self.init(dx: endPoint.x - startPoint.x,
                  dy: endPoint.y - startPoint.y)
      }
    
    var length: CGFloat {
        return sqrt(dx*dx + dy*dy)
    }
    
    var angle: CGFloat {
        return atan2(dy, dx)
    }
    
    static func *(_ lhs: CGVector, _ rhs: CGFloat) -> CGVector {
        return .init(dx: lhs.dx * rhs, dy: lhs.dy * rhs)
    }
    
    static func +(_ lhs: CGPoint, rhs: CGVector) -> CGPoint {
        .init(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
    }
    
    static func +=(_ lhs: inout CGPoint, rhs: CGVector) {
        lhs = .init(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
    }
}

extension CGImage {
    public func rotated(radians: CGFloat, flipOverHorizontalAxis: Bool = false, flipOverVerticalAxis: Bool = false) -> CGImage?
    {
        let width = CGFloat(self.width)
        let height = CGFloat(self.height)
        
        let rotatedRect = CGRect(x: 0, y: 0, width: width, height: height)
            .applying(.init(rotationAngle: radians))

        guard let bmContext = CGContext(data: nil,
                                        width: Int(rotatedRect.width),
                                        height: Int(rotatedRect.height),
                                        bitsPerComponent: bitsPerComponent,
                                        bytesPerRow: 0,
                                        space: colorSpace!,
                                        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        else {
            return nil
        }
        bmContext.setShouldAntialias(true)
        bmContext.setAllowsAntialiasing(true)
        bmContext.interpolationQuality = .high
        let imageRect = CGRect(x: 0, y: 0, width: width, height: height)
        bmContext.translateBy(x: imageRect.origin.x, y: imageRect.origin.y)
        bmContext.rotate(by: radians)
        bmContext.translateBy(x: -width/2, y: -height/2)
        bmContext.draw(self, in: .init(origin: .init(x: -width/2, y: height/2), size: imageRect.size))
        
        return bmContext.makeImage()
    }
}

extension CMSampleBuffer {
    var brightness: CGFloat? {
        let exif = attachments.propagated[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let brightness = (exif?[kCGImagePropertyExifBrightnessValue as String] as? Double).map { CGFloat($0) }
        return brightness
    }
}

extension Collection where Element: Publisher {
    func merge() -> AnyPublisher<Element.Output, Element.Failure> {
        Publishers.MergeMany(self).eraseToAnyPublisher()
    }
}
