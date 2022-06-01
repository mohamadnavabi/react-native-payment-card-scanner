//
//  NationalCardSerialRecognizer.swift
//  PaymentCardScanner
//
//  Created by Amir Abbas Mousavian on 12/26/99.
//  Copyright © 1399 AP Saman Solutions. All rights reserved.
//

import Foundation
import Combine
import AVFoundation
import Vision

extension NationalCardSerialRecognizer {
    public struct Configuration: RecognizerConfiguration {
        
        public typealias ResultType = String
        
        public init(resultsHandler: @escaping (Image, ResultType) -> Void = { _, _ in },
                    errorHandler: @escaping (Error) -> Void = { _ in }) {
            self.resultsHandler = resultsHandler
            self.errorHandler = errorHandler
        }
        
        public let resultsHandler: (Image, ResultType) -> Void
        
        public let errorHandler: (Error) -> Void
    }
}

public class NationalCardSerialRecognizer: RecognizerVisionImpl {
    
    let requestHandler = VNSequenceRequestHandler()
    
    @Atomic internal var processStates: [ProcessState] = []
    
    var hint: Hint<Never>?
    
    public let configuration: Configuration
    
    public let subject: PassthroughSubject<Result<(Image, ConfigurationType.ResultType), Error>, Never> = .init()
    
    // MARK: - Initializers
    
    required public init(configuration: Configuration) {
        self.configuration = configuration
    }
    
    func makeRecognizerRequests() -> [VNRequest] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        return [request]
    }
    
    func preprocess(image: Image) -> Image {
        let image = image.oriented(to: .horizontal)
        let cropSize = image.size.applying(.init(scaleX: 0.11, y: 1))
        return image
            .crop(.init(origin: .zero, size: cropSize))
            .oriented(to: .vertical)
    }
    
    func recognize(_ capture: CaptureImage, observations: [VNRecognizedTextObservation]) -> Configuration.ResultType? {
        let filteredTexts = observations
            .texts()
            .map(replaceSerialChar)
            .filter(isNationalCardSerial)
        return filteredTexts.count == 1 ? filteredTexts.first : nil
    }
    
    private func isNationalCardSerial(_ serial: String) -> Bool {
        serial.matches(regex: #"^\d{1}[A-Z]\d{8}$"#)
    }
    
    private func replaceSerialChar(_ serial: String) -> String {
        switch true {
        case _ where serial.matches(regex: #"^\d{1}6\d{8}$"#):
            return serial.prefix(1) + "G" + serial.suffix(8)
        default:
            return serial
        }
    }
}
