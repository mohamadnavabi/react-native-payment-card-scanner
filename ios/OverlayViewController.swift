//
//  OverlayViewController.swift
//  PaymentCardScanner
//
//  Created by Mohammad Navabi on 3/8/1401 AP.
//  Copyright © 1401 AP Facebook. All rights reserved.
//

import UIKit
import AVFoundation
import SwiftUI
import SafariServices

class OverlayViewController: UIViewController {
    let borderRadius: CGFloat = 25.0
    var topText: NSString
    var bottomText: NSString
    var topTextFont: NSString
    var bottomTextFont: NSString
    
    init(topText: NSString, bottomText: NSString, topTextFont: NSString, bottomTextFont: NSString) {
        self.topText = topText
        self.bottomText = bottomText
        self.topTextFont = topTextFont
        self.bottomTextFont = bottomTextFont

        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
    
    let backgroundView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        return v
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(backgroundView)
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let maskLayer = CAShapeLayer()
        maskLayer.frame = backgroundView.bounds
        maskLayer.fillColor = UIColor.black.cgColor
        maskLayer.lineWidth = 20
        maskLayer.strokeColor = UIColor.white.cgColor
        
        var frm: CGRect = self.view.bounds
        // TODO: get height base ratio
        frm.size.width = frm.size.width * 0.90
        frm.size.height = frm.size.height * 0.65
        frm.origin.x = (self.view.frame.size.width - frm.size.width) / 2
        frm.origin.y = (self.view.frame.size.height - frm.size.height) / 2
        
        let path = UIBezierPath(rect: backgroundView.bounds)
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        path.append(UIBezierPath(roundedRect: frm, cornerRadius: borderRadius))
        maskLayer.path = path.cgPath
        
        let borderView = UIView()
        frm.size.width = frm.size.width - 12
        frm.size.height = frm.size.height - 12
        frm.origin.x = (self.view.frame.size.width - frm.size.width) / 2
        frm.origin.y = (self.view.frame.size.height - frm.size.height) / 2
        borderView.frame = frm
        borderView.backgroundColor = UIColor.clear
        borderView.layer.borderColor = UIColor.white.cgColor
        borderView.layer.borderWidth = 3
        borderView.layer.cornerRadius = borderRadius
        self.view.addSubview(borderView)

        let topTextLabel = UILabel(frame: CGRect(x: self.view.frame.size.width / 2, y: self.view.frame.size.height / 2, width: 300, height: 20))
        topTextLabel.center = CGPoint(x: self.view.center.x, y: frm.origin.y - 30)
        topTextLabel.textAlignment = .center
        topTextLabel.text = "\(topText)"
        topTextLabel.textColor = UIColor.white
        topTextLabel.font = UIFont(name: "\(topTextFont)", size: 18.0)
        self.view.addSubview(topTextLabel)
        
        let bottomTextLabel = UILabel(frame: CGRect(x: self.view.frame.size.width / 2, y: self.view.frame.size.height / 2, width: self.view.frame.size.width, height: 20))
        bottomTextLabel.center = CGPoint(x: self.view.center.x, y: frm.origin.y + frm.size.height + 30)
        bottomTextLabel.textAlignment = .center
        bottomTextLabel.text = "\(bottomText)"
        bottomTextLabel.textColor = UIColor.white
        bottomTextLabel.font = UIFont(name: "\(bottomTextFont)", size: 16.0)
        self.view.addSubview(bottomTextLabel)
        
        backgroundView.layer.mask = maskLayer
    }
}
