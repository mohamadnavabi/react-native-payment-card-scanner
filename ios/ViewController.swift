import UIKit

@objc
class ViewController:  UIViewController {
    var topText: NSString
    var bottomText: NSString
    var topTextFont: NSString
    var bottomTextFont: NSString
    var resolve: RCTPromiseResolveBlock? = nil
    
    init(topText: NSString, bottomText: NSString, topTextFont: NSString, bottomTextFont: NSString, resolve: RCTPromiseResolveBlock?) {
        self.topText = topText
        self.bottomText = bottomText
        self.topTextFont = topTextFont
        self.bottomTextFont = bottomTextFont
        self.resolve = resolve

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        presentCamera(for: [paymentCardRecognizer()])
    }
    
    private var cameraViewController: RecognizerCameraViewController?
        
    func presentCamera(for recognizers: [Recognizer]) {
        let extractionViewController = RecognizerCameraViewController(recognizers: recognizers)
        
        let vc = OverlayViewController(topText: topText, bottomText: bottomText, topTextFont: topTextFont, bottomTextFont: bottomTextFont)
        let nvc = DemoScannerNavigationController(rootViewController: extractionViewController)

        extractionViewController.addOverlayViewController(vc)
        extractionViewController.modalPresentationStyle = .overFullScreen
        extractionViewController.navigationItem.leftBarButtonItem = nvc.closeButton()
        
        cameraViewController = extractionViewController
        self.present(nvc, animated: false, completion: nil)
    }

    func dismissCamera() {
        cameraViewController?.captureState = .stopped
        dismiss(animated: false, completion: nil)
    }
}

extension ViewController {
    fileprivate func paymentCardRecognizer() -> PaymentCardRecognizer {
        let config = PaymentCardRecognizer.Configuration(
            detectingElements: [.pan, .expDate, .cvv2, .iban],
            resultsHandler: cardResultsHandler
        )
        return PaymentCardRecognizer(configuration: config)
    }
    
    fileprivate func cardResultsHandler(_ image: Image, _ cardInfo: CardInfo) {
        let data = ["PAN": cardInfo.pan, "CVV2": cardInfo.cvv2, "EXP": cardInfo.exp, "IBAN": cardInfo.iban]

        if resolve != nil {
            resolve!(data)
            self.dismissCamera()
        }
    }
}
