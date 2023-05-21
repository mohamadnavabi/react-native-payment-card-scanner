import UIKit
import AVFoundation

@available(iOS 13.0, *)
class DemoScannerNavigationController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        modalPresentationStyle = .fullScreen
        
        setupNavigationBar()
    }
    
    private func setupNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        
        navigationBar.standardAppearance = appearance
        navigationBar.barStyle = .black
        navigationBar.isTranslucent = true
        navigationBar.tintColor = .white
    }
    
/*
    func closeButton() -> UIBarButtonItem {
        let icon = UIButton()
        icon.setImage(UIImage(named: "back"), for: .normal)
        icon.contentVerticalAlignment = .fill
        icon.contentHorizontalAlignment = .fill
        icon.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        return UIBarButtonItem(customView: icon)
    }
*/

    func closeButton() -> UIBarButtonItem {
        let barButtonItem = UIBarButtonItem(title: "❯", style: .plain, target: self, action: #selector(closeTapped))
        let font = UIFont.systemFont(ofSize: 36.0)
        let textAttributes: [NSAttributedString.Key: Any] = [.font: font]
        barButtonItem.setTitleTextAttributes(textAttributes, for: .normal)
        barButtonItem.setTitleTextAttributes(textAttributes, for: .selected)
        
        return barButtonItem
    }
    
    @objc
    func closeTapped() {
        DispatchQueue.main.async {
            let topController = UIApplication.topMostViewController()
            topController?.dismiss(animated: false)
            PaymentCardScanner.navController.dismiss(animated: false, completion: nil)
        }
    }
}
