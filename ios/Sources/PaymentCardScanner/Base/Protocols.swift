//
//  Protocols.swift
//  PaymentCardScanner
//
//  Created by Amir Abbas Mousavian on 11/27/99.
//  Copyright © 1399 AP Anurag Ajwani. All rights reserved.
//

import Foundation
import Vision
import Combine

/// An abstract for entities that processes an image and returned information
/// via calling `resultHandler` closure in configuration.
public protocol Recognizer {
    // Passes event when a hint occurs.
    var hintPublisher: AnyPublisher<Error, Never> { get }
    
    /// Runs recognizer on image and invokes `resultHandler()` if any result output
    /// is returned by recognizer.
    ///
    /// - Note: A recognizer may handle a series of image (e.g. video) by calling this method
    ///    sequentially with images.
    func process(_ capture: CaptureImage)
    
    /// Resets state of recognizer by previous recognitions if there is any.
    func resetTracking()
}

public extension Recognizer {
    func resetTracking() { }
}

public protocol TypedRecognizer: Recognizer {
    associatedtype ConfigurationType: RecognizerConfiguration
    
    /// Configuration and settings of recognizer.
    var configuration: ConfigurationType { get }
    
    /// Initialize recognizer with defined settings in configuration.
    init(configuration: ConfigurationType)
    
    var subject: PassthroughSubject<Result<(Image, ConfigurationType.ResultType), Error>, Never> { get }
    
    func syncProcess(_ capture: CaptureImage) throws -> ConfigurationType.ResultType?
    
    func syncProcess(_ image: Image) throws -> ConfigurationType.ResultType?
}

extension TypedRecognizer {
    public var hintPublisher: AnyPublisher<Error, Never> {
        subject
            .compactMap { result -> Error? in
                switch result {
                case .success:
                    return nil
                case .failure(let error):
                    return error
                }
            }
            .eraseToAnyPublisher()
    }
    
    public func syncProcess(_ image: Image) throws -> ConfigurationType.ResultType? {
        try syncProcess(CaptureImage(image: image))
    }
}

public protocol RecognizerConfiguration {
    associatedtype ResultType
    
    /// Invoked by recognizer when any information is extracted from image
    /// using recognizer.
    ///
    /// No additional call will be occured until the closure returns.
    var resultsHandler: (_ image: Image, _ result: ResultType) -> Void { get }
    
    /// Error to be shown to user, e.g. when object is far or unrecognizable.
    var errorHandler: (_ error: Error) -> Void { get }
}

struct ProcessState: RawRepresentable, Equatable {
    var rawValue: String
    
    init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    static let async = ProcessState(rawValue: "Async Process")
    static let sync = ProcessState(rawValue: "Sync Process")
    static let result = ProcessState(rawValue: "Result Handler")
    static let error = ProcessState(rawValue: "Error Handler")
}

struct Hint<ErrorType>: Equatable where ErrorType: Error & Equatable {
    internal init(error: ErrorType) {
        self.error = error
        self.startTime = .init()
        self.counter = 0
    }
    
    let error: ErrorType
    let startTime: Date
    @Atomic var counter: Int
    
    static func == (lhs: Hint, rhs: Hint) -> Bool {
        lhs.error == rhs.error
    }
}

protocol RecognizerImpl: AnyObject & TypedRecognizer {
    associatedtype ErrorType: Error & Equatable
    
    /// Determines if the given image is processing, in order to block simultaneous
    /// request processing.
    var processStates: [ProcessState] { get set }
    
    var hint: Hint<ErrorType>? { get set }
    
    func shouldProcess(image: Image) -> Bool
    func preprocess(image: Image) -> Image
}

protocol RecognizerVisionImpl: RecognizerImpl {
    associatedtype ObservationType: VNObservation
    
    /// Vision request handler.
    var requestHandler: VNSequenceRequestHandler { get }
    
    func makeRecognizerRequests() -> [VNRequest]
    
    func recognize(_ capture: CaptureImage, observations: [ObservationType]) throws -> ConfigurationType.ResultType?
}

extension RecognizerImpl {
    func setHint(to error: ErrorType) {
        if hint != nil, error == hint!.error {
            hint!.counter += 1
        } else {
            self.hint = .init(error: error)
        }
    }
    
    func getHint(minInterval: TimeInterval, minCount: Int) -> Error? {
        if let hint = hint, abs(hint.startTime.distance(to: .init())) >= minInterval && hint.counter >= minCount {
            return hint.error
        }
        return nil
    }
    
    func appendState(_ process: ProcessState) {
        processStates.append(.sync)
    }
    
    func hasState(_ process: ProcessState) -> Bool {
        processStates.contains(.async)
    }
    
    func removeState(_ process: ProcessState) {
        processStates.removeAll(where: { $0 == process })
    }
    
    func shouldProcess(image: Image) -> Bool {
        return true
    }
    
    func preprocess(image: Image) -> Image {
        return image
    }
}

extension RecognizerVisionImpl {
    public func syncProcess(_ capture: CaptureImage) throws -> ConfigurationType.ResultType? {
        guard !hasState(.sync), shouldProcess(image: capture.image) else {
            return nil
        }
        appendState(.sync)
        defer { removeState(.sync) }
        
        let requests = makeRecognizerRequests()
        guard !requests.isEmpty else { return nil }
        
        let image = preprocess(image: capture.image)
        try? requestHandler.perform(requests, on: image)
        
        let observations = requests.flatMap({$0.results as? [ObservationType] ?? []})
        guard !observations.isEmpty, let result = try recognize(capture.replace(image), observations: observations) else {
            return nil
        }
        return result
    }
    
    public func process(_ capture: CaptureImage) {
        guard !hasState(.async) else { return }
        appendState(.async)
        do {
            guard let result = try syncProcess(capture) else { return }
            appendState(.result)
            DispatchQueue.main.async { [self] in
                guard !hasState(.result) else { return }
                subject.send(.success((capture.image, result)))
                configuration.resultsHandler(capture.image, result)
                removeState(.result)
                removeState(.async)
            }
        } catch {
            appendState(.error)
            DispatchQueue.main.async { [self] in
                guard !hasState(.error) else { return }
                if let error = error as? ErrorType { setHint(to: error) }
                if let persistentError = getHint(minInterval: 0.3, minCount: 0) {
                    configuration.errorHandler(persistentError)
                    subject.send(.failure(persistentError))
                }
                removeState(.error)
                removeState(.async)
            }
        }
    }
}
