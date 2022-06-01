//
//  BarcodeInfo.swift
//  PaymentCardScanner
//
//  Created by Amir Abbas Mousavian on 11/26/99.
//  Copyright © 2020 Saman Solutions. All rights reserved.
//

import UIKit
import CoreVideo
import Vision

public struct BarcodeInfo {
    public let symbology: VNBarcodeSymbology
    public let value: String
}
