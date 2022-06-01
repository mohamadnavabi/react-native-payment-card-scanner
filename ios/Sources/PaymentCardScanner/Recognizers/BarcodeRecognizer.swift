//
//  BarcodeRecognizer.swift
//  PaymentCardScanner
//
//  Created by Amir Abbas Mousavian on 11/26/99.
//  Copyright © 2020 Saman Solutions. All rights reserved.
//

import Foundation
import Combine
import AVFoundation
import Vision

public enum BarcodeError: Error & Equatable {
    case notValidBarcode
}

extension BarcodeRecognizer {
    public struct Configuration: RecognizerConfiguration {
        
        public typealias ResultType = [BarcodeInfo]
        
        public init(
			symbologies: [VNBarcodeSymbology] = [],
			validator: @escaping (BarcodeInfo) -> Bool = { _ in true },
            resultsHandler: @escaping (Image, ResultType) -> Void = { _, _ in },
            errorHandler: @escaping (_ error: Error) -> Void = { _ in }
		) {
            self.symbologies = symbologies
            self.validator = validator
            self.resultsHandler = resultsHandler
            self.errorHandler = errorHandler
        }
        
        public let symbologies: [VNBarcodeSymbology]
        
        public let validator: (BarcodeInfo) -> Bool
        
        public let resultsHandler: (Image, ResultType) -> Void
        
        public let errorHandler: (_ error: Error) -> Void
    }
}

public class BarcodeRecognizer: RecognizerVisionImpl {
    
    internal let requestHandler = VNSequenceRequestHandler()
    
    // MARK: - Instance dependencies
    
    public let configuration: Configuration
    
    public let subject: PassthroughSubject<Result<(Image, ConfigurationType.ResultType), Error>, Never> = .init()
    
    @Atomic internal var processStates: [ProcessState] = []
    
    var hint: Hint<BarcodeError>?
    
    // MARK: - Initializers
    
    required public init(configuration: Configuration) {
        self.configuration = configuration
    }
    
    func makeRecognizerRequests() -> [VNRequest] {
        let request = VNDetectBarcodesRequest()
        if !configuration.symbologies.isEmpty {
            request.symbologies = configuration.symbologies
        }
        
        return [request]
    }
    
    func recognize(_ capture: CaptureImage, observations: [VNBarcodeObservation]) throws -> Configuration.ResultType? {
        let barcodes: [BarcodeInfo] = try observations
            .filter {
                guard let payloadString = $0.payloadStringValue, !payloadString.isEmpty else { return false }
                return $0.confidence > 0.8
                    && (self.configuration.symbologies.isEmpty || self.configuration.symbologies.contains($0.symbology))
            }
            .map {
                let barcode = BarcodeInfo(symbology: $0.symbology, value: $0.payloadStringValue!)
                if !self.configuration.validator(barcode) {
                    throw BarcodeError.notValidBarcode
                }
                return barcode
            }
        return !barcodes.isEmpty ? barcodes : nil
    }
}


