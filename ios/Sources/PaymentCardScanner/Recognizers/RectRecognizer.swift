//
//  RectRecognizer.swift
//  PaymentCardScanner
//
//  Created by Amir Abbas Mousavian on 01/12/00.
//  Copyright © 2020 Saman Solutions. All rights reserved.
//

import Foundation
import Combine
import AVFoundation
import CoreImage
import Vision

public struct RectData {
    public init(boundry: RectBoundary, croppedImage: Image) {
        self.boundry = boundry
        self.croppedImage = croppedImage
    }
    
    public let boundry: RectBoundary
    public let croppedImage: Image
}

extension RectRecognizer {
    public struct Configuration: RecognizerConfiguration {
        
        public typealias ResultType = RectData
        
        public init(tracking: Bool,
                    aspectRatio: CGFloat,
                    aspectTolerance: CGFloat = 0.05,
                    quadratureTolerance: CGFloat = 45,
                    maximumRects: Int = 0,
                    minimumRectProportion: CGFloat = 0.2,
                    minimumConfidence: CGFloat = 0.6,
                    resultsHandler: @escaping (Image, ResultType) -> Void = { _, _ in },
                    errorHandler: @escaping (Error) -> Void = { _ in }) {
            guard aspectTolerance >= 0 && aspectTolerance < 1,
                  minimumRectProportion >= 0 && minimumRectProportion < 1,
                  minimumConfidence >= 0 && minimumConfidence < 1,
                  quadratureTolerance >= 0 && quadratureTolerance <= 45
            else {
                preconditionFailure("tolerancePercentage must be between 0.0 and 1.0")
            }
            self.tracking = tracking
            self.aspectRatio = aspectRatio
            self.aspectTolerance = aspectTolerance
            self.quadratureTolerance = quadratureTolerance
            self.maximumRects = maximumRects
            self.minimumRectProportion = minimumRectProportion
            self.minimumConfidence = minimumConfidence
            self.resultsHandler = resultsHandler
            self.errorHandler = errorHandler
        }
        
        public let tracking: Bool
        
        public let aspectRatio: CGFloat
        
        public let aspectTolerance: CGFloat
        
        public let quadratureTolerance: CGFloat
        
        public let maximumRects: Int
        
        public let minimumRectProportion: CGFloat
        
        public let minimumConfidence: CGFloat
        
        public let resultsHandler: (Image, ResultType) -> Void
        
        public let errorHandler: (Error) -> Void
        
        public static let cr80AspectRatio: CGFloat = 27/17
    }
}

public class RectRecognizer: RecognizerVisionImpl {
    
    let requestHandler = VNSequenceRequestHandler()
    
    @Atomic internal var processStates: [ProcessState] = []
    
    var hint: Hint<Never>?
    
    public let configuration: Configuration
    
    public let subject: PassthroughSubject<Result<(Image, ConfigurationType.ResultType), Error>, Never> = .init()
    
    @Atomic private var lastRectObservations: [VNRectangleObservation] = []
    
    // MARK: - Initializers
    
    required public init(configuration: Configuration) {
        self.configuration = configuration
    }
    
    private func request(with aspectRatio: CGFloat) -> VNDetectRectanglesRequest {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = VNAspectRatio(aspectRatio * (1 - configuration.aspectTolerance))
        request.maximumAspectRatio = VNAspectRatio(aspectRatio * (1 + configuration.aspectTolerance))
        request.quadratureTolerance = VNDegrees(configuration.quadratureTolerance)
        request.maximumObservations = configuration.maximumRects
        request.minimumSize = Float(configuration.minimumRectProportion)
        request.minimumConfidence = VNConfidence(configuration.minimumConfidence)
        return request
    }
    
    func makeRecognizerRequests() -> [VNRequest] {
        if !configuration.tracking || lastRectObservations.isEmpty {
            return [request(with: configuration.aspectRatio)]
        } else {
            return lastRectObservations
                .map(VNTrackRectangleRequest.init(rectangleObservation:))
        }
    }
    
    public func resetTracking() {
        lastRectObservations = []
    }
    
    public func recognize(_ capture: CaptureImage, observations: [VNRectangleObservation]) -> Configuration.ResultType? {
        lastRectObservations = observations
        let rects = observations
            .map {
                RectBoundary(rectangeObservation: $0).normalize(to: capture.image.size)
            }
        print(rects)
        guard let rect = rects.first else { return nil }
        
        return .init(boundry: rect, croppedImage: capture.image.perspectiveCorrection(to: rect))
    }
}
