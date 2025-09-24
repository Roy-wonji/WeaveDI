//
//  KioskProductService.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/16/25.
//


import Foundation


enum KioskProductService {
  case getAllProducts
}

extension KioskProductService: BaseTargetType {
  var endpoint: any APIEndpoint {
    switch self {
      case .getAllProducts:
        return KioskAPI.Product.list
    }
  }
  
  var parameters: [String : Any]? {
    switch self {
      case .getAllProducts:
        return nil
    }
  }
  
  var method: HTTPMethod {
    switch self {
      case .getAllProducts:
        return .get
    }
  }
}
