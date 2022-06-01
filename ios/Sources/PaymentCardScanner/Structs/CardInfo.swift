//
//  CardInfo.swift
//  PaymentCardScanner
//
//  Created by Amir Abbas Mousavian on 11/26/99.
//  Copyright © 2020 Saman Solutions. All rights reserved.
//

import Foundation

public struct CardInfo {
    public let pan: String?
    public let cvv2: String?
    public let exp: String?
    public let iban: String?
    
    init(pan: String?, cvv2: String?, exp: String?, iban: String?) {
        self.pan = pan
        self.cvv2 = cvv2
        self.exp = exp
        self.iban = iban
    }
    
    init(textsRecognized: [String], elements: CardInfoElements = [.pan, .expDate, .iban, .cvv2]) {
        self.pan = elements.contains(.pan) ? Self.findPan(textsRecognized) : nil
        self.cvv2 = elements.contains(.cvv2) ? Self.findCVV2(textsRecognized) : nil
        self.exp = elements.contains(.expDate) ? Self.findExp(textsRecognized) : nil
        self.iban = elements.contains(.iban) ? Self.findIBAN(textsRecognized) : nil
    }
    
    private static func panIsValid(_ digits: String) -> Bool {
        guard digits.count == 16, digits.isNumeric else {
            return false
        }
        var digits = digits
        let checksum = digits.removeLast()
        let sum = digits.reversed()
            .enumerated()
            .map({ (index, element) -> Int in
                if (index % 2) == 0 {
                   let doubled = Int(String(element))!*2
                   return doubled > 9
                       ? Int(String(String(doubled).first!))! + Int(String(String(doubled).last!))!
                       : doubled
                } else {
                    return Int(String(element))!
                }
            })
            .reduce(0, { (res, next) in res + next })
        let checkDigitCalc = (sum * 9) % 10
        return Int(String(checksum))! == checkDigitCalc
    }
    
    private static func ibanIsValid(_ iban: String) -> Bool {
        /// Modulo-97 validation according to ISO-13616.
        var a = iban.utf8.map{ $0 }
        while a.count < 4 {
            a.append(0)
        }
        let b = a[4..<a.count] + a[0..<4]
        let c = b.reduce(0) { (r, u) -> Int in
            let i = Int(u)
            return i > 64 ? (100 * r + i - 55) % 97: (10 * r + i - 48) % 97
        }
        return c == 1
    }
    
    private static func expIsValid(_ exp: String) -> Bool {
        return
            !exp.isEmpty &&
            exp.contains("/") &&
            ((exp.count == 7 &&
                ["13", "14"].contains(exp.prefix(2)) &&
                exp.prefix(4).isNumeric &&
                exp.suffix(2).isNumeric) ||
            (exp.count == 5 &&
                exp.prefix(2).isNumeric &&
                exp.suffix(2).isNumeric))
    }
    
    private static func findPan(_ textsRecognized: [String]) -> String? {
        var digitsRecognized = textsRecognized
            .filter { $0.isNumericOrWhitespace }
            .flatMap { $0.components(separatedBy: " ") }
            .map { $0.numeric() }
        
        while !digitsRecognized.isEmpty {
            let digits = String(digitsRecognized.joined().prefix(16))
            if panIsValid(digits) {
                return digits
            }
            digitsRecognized.removeFirst()
        }
        
        return nil
    }
    
    private static func findCVV2(_ textsRecognized: [String]) -> String? {
        
        func isCVV(_ str: String) -> Bool {
            let str = str.lowercased().trimmingCharacters(in: .whitespaces)
            return str.dropFirst().hasPrefix("vv") || str.dropLast().hasSuffix("vv")
        }
        
        guard let cvvIndex = textsRecognized
                .firstIndex(where: isCVV) else {
            return nil
        }
        let directCVV = textsRecognized[cvvIndex]
            .replacingOccurrences(of: "vv2", with: "", options: [.caseInsensitive])
            .numeric()
        
        if (3...4).contains(directCVV.count) {
            return directCVV
        }
        
        return textsRecognized[cvvIndex...]
            .dropFirst()
            .first{
                (3...4).contains($0.numeric().count)
            }?
            .numeric()
    }
    
    private static func findExp(_ textsRecognized: [String]) -> String? {
        return textsRecognized
            .map {
                $0.numericSlash().lowercased().replacingOccurrences(of: "vv2", with: "")
            }
            .first(where: expIsValid)
    }
    
    private static func findIBAN(_ textsRecognized: [String]) -> String? {
        textsRecognized.first {
            let bban = $0.numeric()
            return bban.count == 24 && $0.hasPrefix("IR") && Self.ibanIsValid("IR" + bban)
        }.map {
            "IR" + $0.numeric()
        }
    }
    
    func panConformsTo(iins: [String]) -> Bool {
		//It must has `pan`, and THEN check for `iins`
		guard let pan = pan else { return false }
        guard !iins.isEmpty else { return true }
        return nil != iins.firstIndex {
            pan.starts(with: $0)
        }
    }
}

public struct CardInfoElements: OptionSet {
    public var rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let pan = Self(rawValue: 1 << 1)
    public static let cvv2 = Self(rawValue: 1 << 2)
    public static let expDate = Self(rawValue: 1 << 3)
    public static let iban = Self(rawValue: 1 << 4)
}

extension CardInfo {
    func hasAllElements(_ elements: CardInfoElements) -> Bool {
        !(elements.contains(.pan) && pan.isNullOrEmpty) &&
            !(elements.contains(.expDate) && exp.isNullOrEmpty) &&
            !(elements.contains(.iban) && iban.isNullOrEmpty) &&
            !(elements.contains(.cvv2) && cvv2.isNullOrEmpty)
    }
}
