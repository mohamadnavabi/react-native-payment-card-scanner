//
//  FaceImageRecognizer.swift
//  PaymentCardScanner
//
//  Created by Amir Abbas Mousavian on 01/10/00.
//  Copyright © 1400 AP Saman Solutions. All rights reserved.
//

import Foundation
import Combine
import AVFoundation
import Vision

public struct FaceImageRect {
    internal init(bound: CGRect, quality: Float) {
        self.bound = bound
        self.quality = quality
    }
    
    public let bound: CGRect
    public let quality: Float
}

extension FaceImageRecognizer {
    public struct Configuration: RecognizerConfiguration {
        
        public typealias ResultType = [FaceImageRect]
        
        public init(minimumQuality: CGFloat = 0.4,
                    resultsHandler: @escaping (Image, ResultType) -> Void = { _, _ in },
                    errorHandler: @escaping (Error) -> Void = { _ in }) {
            self.minimumQuality = minimumQuality
            self.resultsHandler = resultsHandler
            self.errorHandler = errorHandler
        }
        
        public let minimumQuality: CGFloat
        
        public let resultsHandler: (Image, ResultType) -> Void
        
        public let errorHandler: (Error) -> Void
    }
}

public class FaceImageRecognizer: RecognizerVisionImpl {
    
    internal let requestHandler = VNSequenceRequestHandler()
    
    // MARK: - Instance dependencies
    
    @Atomic internal var processStates: [ProcessState] = []
    
    var hint: Hint<Never>?
    
    public let configuration: Configuration
    
    public let subject: PassthroughSubject<Result<(Image, ConfigurationType.ResultType), Error>, Never> = .init()
    
    // MARK: - Initializers
    
    required public init(configuration: Configuration) {
        self.configuration = configuration
    }
    
    func makeRecognizerRequests() -> [VNRequest] {
        [VNDetectFaceRectanglesRequest()]
    }
    
    func recognize(_ capture: CaptureImage, observations: [VNFaceObservation]) throws -> Configuration.ResultType? {
        let rects: [FaceImageRect]? = try? observations
            .compactMap {
                let qualityRequest = VNDetectFaceCaptureQualityRequest()
                qualityRequest.inputFaceObservations = [$0]
                try requestHandler.perform([qualityRequest], on: capture.image)
                guard let quality = (qualityRequest.results?.first as? VNFaceObservation)?.faceCaptureQuality else { return nil }
                
                let box = RectBoundary
                    .init(boundingBox: $0.boundingBox)
                    .normalize(to: capture.image.size)
                    .boundingBox
                return .init(bound: box,
                             quality: quality)
            }
        
        return !rects.isNullOrEmpty ? rects : nil
    }
}


