//
//  RecognizerCameraViewController.swift
//  PaymentCardScanner
//
//  Created by Amir Abbas Mousavian  on 12/06/2020.
//  Copyright © 2020 Saman Solutions. All rights reserved.
//

#if canImport(UIKit)
import UIKit
import AVFoundation
import Combine

public class RecognizerCameraViewController: CameraViewController {

    // MARK: - Instance dependencies
    
    public var recognizers: [Recognizer]
    
    public var hintPublisher: AnyPublisher<Error, Never> {
        Publishers.MergeMany(recognizers.map(\.hintPublisher))
            .eraseToAnyPublisher()
    }
    
    // MARK: - Initializers
    
    public init(recognizers: [Recognizer]) {
        self.recognizers = recognizers
        super.init(nibName: nil, bundle: nil)
    }
    
    public convenience init(recognizers: Recognizer...) {
        self.init(recognizers: recognizers)
    }
    
    required init?(coder: NSCoder) {
        recognizers = []
        super.init(coder: coder)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        try? setFocusAndExposure(to: .init(x: 0.5, y: 0.5))
    }
    
    final public override
    func process(captureImage: CaptureImage) {
        recognizers.forEach { $0.process(captureImage) }
    }
    
	public func addOverlayViewController(_ viewController: UIViewController) {
		addChild(viewController)
        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(viewController.view)
        NSLayoutConstraint.activate([
            viewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            viewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor),
            view.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
        ])
		viewController.didMove(toParent: self)
	}
}
#endif
