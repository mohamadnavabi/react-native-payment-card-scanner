//
//  CameraViewController.swift
//  PaymentCardScanner
//
//  Created by Amir Abbas Mousavian  on 12/06/2020.
//  Copyright © 2020 Saman Solutions. All rights reserved.
//

#if canImport(UIKit)
import UIKit
import AVFoundation
import CoreVideo
import Combine

public class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private var cancellables: Set<AnyCancellable> = []
    
    private lazy var captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.usesApplicationAudioSession = false
        session.commitConfiguration()
        return session
    }()
    
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let preview = AVCaptureVideoPreviewLayer(session: self.captureSession)
        preview.videoGravity = .resizeAspectFill
        return preview
    }()
    
    private let videoOutput = AVCaptureVideoDataOutput()
    
    public var videoGravity: AVLayerVideoGravity {
        get { previewLayer.videoGravity }
        set { previewLayer.videoGravity = newValue}
    }
    
    public var focusOnTouch: Bool = false
	
    private var _isCapturePaused: Bool = false {
        willSet {
            captureStateSubject.send(.init(session: captureSession, isPaused: newValue))
        }
    }
    
    public var captureState: CaptureState {
        get {
            .init(session: captureSession, isPaused: _isCapturePaused)
        }
        set {
            newValue.update(session: captureSession, isPaused: &_isCapturePaused)
        }
    }
    
    private var captureStateSubject: PassthroughSubject<CaptureState, Never> = .init()
    
    public var captureStatePublisher: AnyPublisher<CaptureState, Never> {
        captureStateSubject.eraseToAnyPublisher()
    }
    
    @Published
    fileprivate var currentBrightness: CGFloat = 0
    
    public func averageBrightnessPublisher(_ last: Int) -> AnyPublisher<CGFloat, Never> {
        (0..<last)
            .map {
                $currentBrightness
                    .dropFirst($0)
                    .collect(last)
                    .map { $0.reduce(0, +) / CGFloat($0.count) }
            }
            .merge()
    }
    
    public var flashMode: Bool = false {
        didSet {
            guard let device = AVCaptureDevice.default(for: .video) else { return }
            
            if device.hasTorch {
                do {
                    try device.lockForConfiguration()
                    
                    if self.flashMode == true {
                        device.torchMode = .on
                    } else {
                        device.torchMode = .off
                    }
                    
                    device.unlockForConfiguration()
                } catch {
                    preconditionFailure("Torch could not be used")
                }
            } else {
                preconditionFailure("Torch is not available")
            }
        }
    }
    
    public var flashTorch: Float {
        get {
            guard let device = AVCaptureDevice.default(for: .video) else { return 0 }
            switch device.torchMode {
            case .on, .auto:
                return device.torchLevel
            case .off:
                return 0
            @unknown default:
                return 0
            }
        }
        set {
            guard let device = AVCaptureDevice.default(for: .video) else { return }
            switch newValue {
            case 0:
                device.torchMode = .off
            case 0...1:
                try? device.lockForConfiguration()
                try? device.setTorchModeOn(level: newValue)
                device.unlockForConfiguration()
            default:
                preconditionFailure("Torch level must be between 0 and 1.")
            }
        }
    }
    
    // MARK: - Initializers
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.setupCaptureSession()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.captureSession.startRunning()
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        captureSession.stopRunning()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer.frame = self.view.bounds
    }
    
    open func cameraDevice() -> AVCaptureDevice {
        AVCaptureDevice.default(for: .video)!
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    
    public private(set) var lastCapture: CaptureImage?

    final public func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard captureState == .running,
              CMSampleBufferDataIsReady(sampleBuffer),
              cameraIsReady() else {
            return
        }
        switch sampleBuffer.formatDescription?.mediaType {
        case .some(.video):
            guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }
            let normalizedBrightness = sampleBuffer.brightness.map(Self.normalizeBrightness)
            let focusPoint = Image.buffer(buffer).bounds.size.imagePoint(normalzied: cameraDevice().focusPointOfInterest)
            let capture = CaptureImage(
                image: .buffer(buffer),
                focusPoint: focusPoint,
                time: sampleBuffer.presentationTimeStamp,
                brightness: normalizedBrightness
            )
            normalizedBrightness.map { currentBrightness = $0 }
            lastCapture = capture
            process(captureImage: capture)
        case .some(.audio):
            break
        default:
            break
        }
    }
    
    private static func normalizeBrightness(_ value: CGFloat) -> CGFloat {
        // iOS usually returns values between -7 and +15.
        //  We normalize this value to become betwwen 0.0 and 1.0.
        (value + 10) / 25
    }
    
    open func process(captureImage: CaptureImage) {
        
    }

    // MARK: - Camera setup
    
    @available(*, deprecated, message: "Use captureState instead")
    public func startCapturing() {
        captureState = .running
    }
    
    @available(*, deprecated, message: "Use captureState instead")
    public func stopCapturing() {
        captureState = .stopped
    }
	
    @available(*, deprecated, message: "Use captureState instead")
	public func pauseCapturing() {
        captureState = .paused
	}
    
    private func setupCaptureSession() {
        captureSession.beginConfiguration()
        self.addCameraInput()
        self.addPreviewLayer()
        self.addVideoOutput()
        captureSession.commitConfiguration()
		
		captureSession
			.publisher(for: \.isRunning)
			.sink { [weak self] _ in
				guard let self = self else { return }
				self.captureStateSubject.send(self.captureState)
			}
			.store(in: &cancellables)
		captureSession
			.publisher(for: \.isInterrupted)
			.sink { [weak self] _ in
				guard let self = self else { return }
				self.captureStateSubject.send(self.captureState)
			}
			.store(in: &cancellables)
    }
    
    private func addCameraInput() {
        let cameraInput = try! AVCaptureDeviceInput(device: cameraDevice())
        self.captureSession.addInput(cameraInput)
    }
    
    private func addPreviewLayer() {
        self.view.layer.addSublayer(self.previewLayer)
    }
    
    private func addVideoOutput() {
        self.videoOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
        self.videoOutput.alwaysDiscardsLateVideoFrames = true
        self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "image.handling.queue", attributes: []))
        self.captureSession.addOutput(self.videoOutput)
        guard let connection = self.videoOutput.connection(with: AVMediaType.video),
            connection.isVideoOrientationSupported else { return }
        connection.videoOrientation = .portrait
    }
    
    fileprivate func cameraIsReady() -> Bool {
        DispatchQueue.main.sync {
            let device = cameraDevice()
            return !(device.isAdjustingFocus || device.isAdjustingExposure || device.isAdjustingWhiteBalance)
        }
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard focusOnTouch, let point = touches.first?.location(in: view) else { return }
        try? setFocusAndExposure(to: convertPointInViewToDevicePoint(point))
    }
}

extension CameraViewController {
    public enum CaptureState {
        case stopped, running, paused, interrupted
        
        public mutating func toggle() {
            switch self {
            case .stopped:
                self = .running
            case .running:
                self = .stopped
            case .paused:
                self = .running
            case .interrupted:
                break
            }
        }
        
        init (session: AVCaptureSession, isPaused: Bool) {
            switch (session.isRunning, session.isInterrupted, isPaused) {
            case (false, _, _):
                self = .stopped
            case (_, true, _):
                self = .interrupted
            case (_, _, false):
                self = .running
            case (_, _, true):
                self = .paused
            }
        }
        
        func update(session: AVCaptureSession, isPaused: inout Bool) {
            switch self {
            case .running:
                isPaused = false
                session.startRunning()
            case .stopped:
                isPaused = false
                session.stopRunning()
            case .paused:
                isPaused = true
            case .interrupted:
                preconditionFailure("Interrupting a video session is not possible programmatically.")
            }
        }
    }
}

extension CameraViewController {
    public func convertPointInViewToDevicePoint(_ point: CGPoint) -> CGPoint {
        let previewLayerPoint = previewLayer.convert(point, from: view.layer)
        return previewLayer
            .captureDevicePointConverted(fromLayerPoint: previewLayerPoint)
    }
    
    public func setFocusAndExposure(to focusPoint: CGPoint) throws {
        guard CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0).contains(focusPoint) else {
            assertionFailure("Invalid focus point.")
            return
        }
        let device = cameraDevice()
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        if device.isFocusPointOfInterestSupported {
            device.focusPointOfInterest = focusPoint
            device.focusMode = .continuousAutoFocus
        }
        if device.isExposurePointOfInterestSupported {
            device.exposurePointOfInterest = focusPoint
            device.exposureMode = .continuousAutoExposure
        }
        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }
    }
}
#endif
