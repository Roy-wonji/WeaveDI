//
//  Double+.swift
//  AppleStoreProductKiosk
//
//  Created by 홍석현 on 9/17/25.
//

import Foundation

public extension Double {
  private static let currencyFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.maximumFractionDigits = 0
    return formatter
  }()
  
  var formattedKRWCurruncy: String {
    return Self.currencyFormatter.string(from: NSNumber(value: self)) ?? ""
  }
}
