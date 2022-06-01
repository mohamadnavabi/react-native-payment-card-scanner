//
//  NationalCardFrontRecognizer.swift
//  PaymentCardScanner
//
//  Created by Amir Abbas Mousavian on 2/28/00.
//  Copyright © 1400 AP Anurag Ajwani. All rights reserved.
//

import Foundation
import Combine
import AVFoundation
import Vision

public struct IdentityCard {
    internal init(type: IdentityCard.CardType, image: Image, faceImage: Image? = nil, id: String? = nil, serial: String? = nil) {
        self.type = type
        self.image = image
        self.faceImage = faceImage
        self.id = id
        self.serial = serial
    }
    
    public enum CardType {
        case unspecified
        case iranNationalCardFront(dropFramesCount: Int)
        case iranNationalCardBack(forceDetectId: Bool)
    }
    
    public let type: CardType
    public let image: Image
    public private(set) var imageWithInset: Image?
    public let faceImage: Image?
    public let id: String?
    public let serial: String?
    
    fileprivate func adding(imageWithInset: Image) -> Self {
        var result = self
        result.imageWithInset = imageWithInset
        return result
    }
}

extension IdentityCardRecognizer {
    public struct Configuration: RecognizerConfiguration {
        
        public enum CorrectionMode {
            case arctanRotation(ratioTolerance: CGFloat)
            case cornerDetection
        }
        
        public let type: IdentityCard.CardType
        
        fileprivate let correctionMode: CorrectionMode
        
        public let quadratureTolerance: CGFloat // Radians
        
        public let minimumSize: CGFloat
        
        public let edgeInsetPercent: CGFloat
        
        public typealias ResultType = IdentityCard
        
        public let resultsHandler: (Image, ResultType) -> Void
        
        public let errorHandler: (Error) -> Void
        
        public init(type: IdentityCard.CardType,
                    quadratureTolerance: CGFloat = .pi / 16,
                    minimumSize: CGFloat = 0.4,
                    edgeInsetPercent: CGFloat = 0.0,
                    resultsHandler: @escaping (Image, ResultType) -> Void = { _, _ in },
                    errorHandler: @escaping (Error) -> Void = { _ in }) {
            self.type = type
            self.correctionMode = .cornerDetection
            self.quadratureTolerance = quadratureTolerance
            self.minimumSize = minimumSize
            self.edgeInsetPercent = edgeInsetPercent
            self.resultsHandler = resultsHandler
            self.errorHandler = errorHandler
        }
    }
}

public enum NationalCardRecognitionError: Error & Hashable {
    case faceIsCovered
    case serialIsCovered
    case barcodeIsCovered
}

public class IdentityCardRecognizer: RecognizerVisionImpl {
    
    let requestHandler = VNSequenceRequestHandler()
    
    @Atomic internal var processStates: [ProcessState] = []
    
    var hint: Hint<NationalCardRecognitionError>?
    
    public let configuration: Configuration
    
    public let subject: PassthroughSubject<Result<(Image, ConfigurationType.ResultType), Error>, Never> = .init()
    
    @Atomic private var lastRectObservations: [VNRectangleObservation] = []
    
    // MARK: - Initializers
    
    required public init(configuration: Configuration) {
        self.configuration = configuration
    }
    
    private func rotateAngle(cardRect: RectBoundary, leftObjectRect: RectBoundary? = nil) -> CGFloat {
        let ratio = RectRecognizer.Configuration.cr80AspectRatio
        let k = cardRect.boundingBox.width / cardRect.boundingBox.height
        let angle = atan((k - ratio) / (1 - ratio * k))
        guard let leftObjectRect = leftObjectRect else {
            return angle
        }
        if (leftObjectRect.topLeft.x > cardRect.boundingBox.width / 2) ||
            (leftObjectRect.topLeft.y > cardRect.boundingBox.height / 2) {
            return .pi + angle
        } else {
            return angle
        }
    }
    
    fileprivate func rectifyByAngle(_ image: Image, rect: RectBoundary, ratioTolerance: CGFloat) -> Image? {
        let image = image.crop(rect.boundingBox)
        let angle = rotateAngle(cardRect: rect)
        
        if let clockwise = recognizeCard(image.rotate(angle), ratioTolerance: ratioTolerance) {
            return clockwise
        } else if let counterClockwise = recognizeCard(image.rotate(.pi - angle).rotate(.pi), ratioTolerance: ratioTolerance) {
            return counterClockwise
        } else {
            return nil
        }
    }
    
    fileprivate func recognizeCard(_ image: Image, ratioTolerance: CGFloat) -> Image? {
        let request = makeRecognizerRequests().first!
        try? requestHandler.perform([request], on: image)
        guard let result = (request.results as? [VNRectangleObservation])?.first else {
            return nil
        }
        let bound = image.size.imageRect(normalized: result.boundingBox)
        let finalImage = image.crop(bound)
        let ratio = finalImage.size.width / finalImage.size.height
        if ratio.within(mean: RectRecognizer.Configuration.cr80AspectRatio, tolerance: 0.02) {
            return finalImage
        } else {
            return nil
        }
    }
    
    @Atomic fileprivate var faceQualities: [Float] = []
    
    fileprivate func recognizeFront(_ image: Image, dropFramesCount: Int) throws -> IdentityCard? {
        let faceRecognizer = FaceImageRecognizer(configuration: .init(resultsHandler: { (_, _) in }))
        guard let faceRect = try? faceRecognizer.syncProcess(.init(image: image))?.first else {
            throw NationalCardRecognitionError.faceIsCovered
        }
        _faceQualities.update { faceQualities in
            var result = faceQualities ?? []
            result.append(faceRect.quality)
            faceQualities = result.suffix(max(dropFramesCount, 1))
        }
        let faceQualitiesValue = faceQualities
        if faceQualitiesValue.count >= dropFramesCount && faceRect.quality >= (faceQualitiesValue.max() ?? 0) * 0.8 {
            let isRotated = faceRect.bound.midX > image.bounds.midX
            let faceImage = image
                .crop(faceRect.bound, withInset: 0.3)
                .rotate(isRotated ? .pi : 0)
            return .init(type: .iranNationalCardFront(dropFramesCount: dropFramesCount),
                         image: image.rotate(isRotated ? .pi : 0),
                         faceImage: faceImage)
        } else {
            return nil
        }
    }
    
    fileprivate func detectIdFromBarcode(_ image: Image) throws -> String {
        let barcodeConfig = BarcodeRecognizer.Configuration.init(
            symbologies: [.Code128],
            validator: { $0.value.matches(regex: #"^\d{10}$"#) },
            resultsHandler: { (_, _) in })
        let idRecognizer = BarcodeRecognizer(configuration: barcodeConfig)
        guard let result = try? idRecognizer.syncProcess(.init(image: image, focusPoint: .zero))?.first?.value else {
            throw NationalCardRecognitionError.barcodeIsCovered
        }
        return result
    }
    
    fileprivate func detectSerial(_ image: Image) throws -> String {
        let serialRecognizer = NationalCardSerialRecognizer(configuration: .init(resultsHandler: { (_, _) in }))
        guard let result = try? serialRecognizer.syncProcess(.init(image: image, focusPoint: .zero)) else {
            throw NationalCardRecognitionError.serialIsCovered
        }
        return result
    }
    
    fileprivate func detectSerialAndId(_ image: Image) throws -> (serial: String, id: String) {
        let serial = try detectSerial(image)
        let id = try detectIdFromBarcode(image)
        return (serial, id)
    }
    
    fileprivate func recognizeBack(_ image: Image, forceDetectId: Bool) throws -> IdentityCard {
        let rotatedImage: Image
        let serial: String
        let id: String?
        
        switch forceDetectId {
        case true:
            if let result = try? detectSerialAndId(image) {
                rotatedImage = image
                serial = result.serial
                id = result.id
            } else {
                rotatedImage = image.rotate(.pi)
                let result = try detectSerialAndId(rotatedImage)
                serial = result.serial
                id = result.id
            }
        case false:
            if let result = try? detectSerial(image) {
                rotatedImage = image
                serial = result
            } else {
                rotatedImage = image.rotate(.pi)
                serial = try detectSerial(rotatedImage)
            }
            id = try? detectIdFromBarcode(rotatedImage)
        }
        
        return .init(type: .iranNationalCardBack(forceDetectId: forceDetectId), image: rotatedImage,
                     id: id, serial: serial)
    }
    
    func makeRecognizerRequests() -> [VNRequest] {
        let aspectRatio: CGFloat = RectRecognizer.Configuration.cr80AspectRatio
        let aspectTolerance: CGFloat = 0.03
        let quadratureTolerance = configuration.quadratureTolerance * 180 / .pi
        let minimumConfidence: CGFloat = 0.75
        let maximumRects: Int = 1
        let minimumSize: CGFloat = 0.4
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = VNAspectRatio(aspectRatio * (1 - aspectTolerance))
        request.maximumAspectRatio = VNAspectRatio(aspectRatio * (1 + aspectTolerance))
        request.quadratureTolerance = VNDegrees(quadratureTolerance)
        request.maximumObservations = maximumRects
        request.minimumSize = Float(minimumSize)
        request.minimumConfidence = VNConfidence(minimumConfidence)
        return [request]
    }
    
    public func resetTracking() {
        lastRectObservations = []
    }
    
    func recognize(_ capture: CaptureImage, observations: [VNRectangleObservation]) throws -> Configuration.ResultType? {
        let size = capture.image.size
        
        lastRectObservations = observations
        let rects = observations
            .map {
                RectBoundary(rectangeObservation: $0).normalize(to: size)
            }
        guard let rect = rects.first else { return nil }
        
        let rectifiedImage: Image
        let rectifiedImageWithInset: Image
        
        switch configuration.correctionMode {
        case let .arctanRotation(ratioTolerance: ratioTolerance):
            guard let rectifiedResult = rectifyByAngle(capture.image, rect: rect, ratioTolerance: ratioTolerance)?.oriented(to: .horizontal) else {
                return nil
            }
            rectifiedImage = rectifiedResult
            rectifiedImageWithInset = rectifiedImage
        case .cornerDetection:
            // Fix distortion
            rectifiedImage = capture.image
                .perspectiveCorrection(to: rect)
                .oriented(to: .horizontal)
            rectifiedImageWithInset = capture.image
                .perspectiveCorrection(to: rect.withInset(percent: configuration.edgeInsetPercent))
                .oriented(to: .horizontal)
            
            // Check ratio to be within CR80 card ratio
            let rectifiedRatio = rectifiedImage.size.width / rectifiedImage.size.height
            if !rectifiedRatio.within(mean: RectRecognizer.Configuration.cr80AspectRatio, tolerance: 0.02) {
                return nil
            }
        }
        
        switch configuration.type {
        case .unspecified:
			return Configuration
				.ResultType
				.init(type: .unspecified, image: rectifiedImage)
				.adding(imageWithInset: rectifiedImageWithInset)
        case let .iranNationalCardFront(dropFramesCount: dropFramesCount):
            return try recognizeFront(rectifiedImage, dropFramesCount: dropFramesCount)?
                .adding(imageWithInset: rectifiedImageWithInset)
        case .iranNationalCardBack(let forceDetectId):
            return try recognizeBack(rectifiedImage, forceDetectId: forceDetectId)
                .adding(imageWithInset: rectifiedImageWithInset)
        }
    }
}
