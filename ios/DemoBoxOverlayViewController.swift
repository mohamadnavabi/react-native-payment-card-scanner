//
//  DemoBoxOverlayViewController.swift
//  PaymentCardScanner
//
//  Created by Amir Abbas Mousavian on 1/12/00.
//  Copyright © 1400 AP Anurag Ajwani. All rights reserved.
//

import UIKit
import AVFoundation

class DemoBoxOverlayView: UIView {
    var originalSize: CGSize = .init(width: CGFloat.infinity, height: .infinity)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
    }
    
    var boundaries: [RectBoundary] = [] {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var videoGravity: AVLayerVideoGravity = .resizeAspect
    
    private func scale(point: CGPoint, corner: UIRectCorner, destinationRect: CGRect) -> CGPoint {
        let xProportion = destinationRect.width / originalSize.width
        let yProportion = destinationRect.height / originalSize.height
        
        switch videoGravity {
        case .resize:
            break
        case .resizeAspect:
            switch corner {
            case .topLeft:
                break
            case .topRight:
                break
            case .bottomLeft:
                break
            case .bottomRight:
                break
            default:
                fatalError("not implemented")
            }
        default:
            fatalError("not implemented")
        }
        
        let x = (point.x * xProportion + destinationRect.origin.x)
        let y = (point.y * yProportion + destinationRect.origin.y)
        return .init(x: x, y: destinationRect.height - y)
    }
    
    private func draw(_ box: RectBoundary, rect: CGRect, on context: CGContext) {
        let normalizedTopLeft = scale(point: box.topLeft, corner: .topLeft, destinationRect: rect)
        let normalizedBottomLeft = scale(point: box.bottomLeft, corner: .bottomLeft, destinationRect: rect)
        let normalizedTopRight = scale(point: box.topRight, corner: .topRight, destinationRect: rect)
        let normalizedBottomRight = scale(point: box.bottomRight, corner: .bottomRight, destinationRect: rect)
        
        context.move(to: normalizedTopLeft)
        context.addLine(to: normalizedTopRight)
        context.addLine(to: normalizedBottomRight)
        context.addLine(to: normalizedBottomLeft)
        context.addLine(to: normalizedTopLeft)
        context.strokePath()
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.clear(rect)
        context.setStrokeColor(UIColor.orange.cgColor)
        context.setLineWidth(3)
        
        boundaries.forEach {
            draw($0, rect: rect, on: context)
        }
    }
}

class DemoBoxOverlayViewController: UIViewController {
    
    var originalSize: CGSize {
        get {
            (view as! DemoBoxOverlayView).originalSize
        }
        set {
            (view as! DemoBoxOverlayView).originalSize = newValue
        }
    }
    
    var boundaries: [RectBoundary] {
        get {
            (view as! DemoBoxOverlayView).boundaries
        }
        set {
            (view as! DemoBoxOverlayView).boundaries = newValue
        }
    }
    
    override func loadView() {
        self.view = DemoBoxOverlayView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
}
