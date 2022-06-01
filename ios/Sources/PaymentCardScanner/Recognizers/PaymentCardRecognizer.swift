//
//  PaymentCardRecognizer.swift
//  PaymentCardScanner
//
//  Created by Anurag Ajwani, Amir Abbas Mousavian  on 12/06/2020.
//  Copyright © 2020 Saman Solutions. All rights reserved.
//

import Foundation
import Combine
import AVFoundation
import Vision

extension PaymentCardRecognizer {
    public struct Configuration: RecognizerConfiguration {

        public typealias ResultType = CardInfo
        
        public init(requiredElements: CardInfoElements = .pan,
                    detectingElements: CardInfoElements = [.pan, .expDate, .iban, .cvv2],
                    iins: [String] = [],
                    resultsHandler: @escaping (Image, ResultType) -> Void = { _, _ in },
                    errorHandler: @escaping (Error) -> Void = { _ in }) {
            self.requiredElements = requiredElements
            self.detectingElements = detectingElements
            self.iins = iins
            self.resultsHandler = resultsHandler
            self.errorHandler = errorHandler
        }
        
        public let requiredElements: CardInfoElements
        
        public let detectingElements: CardInfoElements
        
        public let iins: [String]
        
        public let resultsHandler: (Image, ResultType) -> Void
        
        public let errorHandler: (Error) -> Void
    }
}

public class PaymentCardRecognizer: RecognizerVisionImpl {
    
    let requestHandler = VNSequenceRequestHandler()
    
    // MARK: - Instance dependencies
    
    public let configuration: Configuration
    
    public let subject: PassthroughSubject<Result<(Image, ConfigurationType.ResultType), Error>, Never> = .init()
    
    @Atomic private var lastIbanDetected: String?
    @Atomic private var lastPanDetected: String?
    @Atomic private var lastCVV2Detected: String?
    @Atomic private var lastExpDateDetected: String?
    @Atomic private var startedDetectionDate: Date?
    
    @Atomic internal var processStates: [ProcessState] = []
    
    var hint: Hint<Never>?
    
    private var extractedCard: CardInfo? {
        guard lastPanDetected != nil else { return nil }
        return .init(pan: lastPanDetected,
                     cvv2: lastCVV2Detected,
                     exp: lastExpDateDetected,
                     iban: lastIbanDetected)
    }
    
    // MARK: - Initializers
    
    required public init(configuration: Configuration) {
        self.configuration = configuration
    }
    
    func makeRecognizerRequests() -> [VNRequest] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.customWords = ["CVV2", "Cvv2", "cvv2"]
        request.usesLanguageCorrection = false
        return [request]
    }
    
    func shouldProcess(image: Image) -> Bool {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        
        try? requestHandler.perform([request], on: image)
        
        guard let texts = request.results as? [VNRecognizedTextObservation], texts.count > 0 else {
            // no text detected
            return false
        }
        return true
    }
    
    public func resetTracking() {
        lastPanDetected = .init()
        lastIbanDetected = .init()
        lastCVV2Detected = .init()
        lastExpDateDetected = .init()
    }
    
    func recognize(_ capture: CaptureImage, observations: [VNRecognizedTextObservation]) -> Configuration.ResultType? {
        let newInfo = CardInfo(textsRecognized: observations.texts(), elements: configuration.detectingElements)
        
        guard newInfo.panConformsTo(iins: configuration.iins) else { return nil }
        newInfo.pan.map(syncInfo(.pan, \.lastPanDetected))
        newInfo.cvv2.map(syncInfo(.cvv2, \.lastCVV2Detected))
        newInfo.exp.map(syncInfo(.expDate, \.lastExpDateDetected))
        newInfo.iban.map(syncInfo(.iban, \.lastIbanDetected))
        
        guard let currentCardInfo = self.extractedCard,
            currentCardInfo.hasAllElements(configuration.requiredElements),
            (currentCardInfo.hasAllElements(configuration.detectingElements) ||
                ((startedDetectionDate?.timeIntervalSinceNow).map(abs) ?? 0 > 1))
        else { return nil }
        return currentCardInfo
    }
    
    private func syncInfo(_ element: CardInfoElements,_ keyPath: ReferenceWritableKeyPath<PaymentCardRecognizer, String?>) -> (_ value: String) -> Void {
        return {
            guard self.configuration.detectingElements.contains(element) else { return }
			self[keyPath: keyPath] = $0
            if self.startedDetectionDate == nil { self.startedDetectionDate = .init() }
        }
    }
}


