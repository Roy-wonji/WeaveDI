//
//  SimpleAutoRegister.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

/// 완전 범용 자동 등록 시스템
/// 사용자가 어떤 인터페이스든 만들면 자동으로 동작합니다.
///
/// ## 사용법:
/// ```swift
/// // 사용자가 자신의 인터페이스와 구현체를 만듭니다:
/// protocol MyServiceInterface { ... }
/// class MyServiceImpl: MyServiceInterface { ... }
/// 
/// // 이후 아무 설정 없이 바로 사용:
/// let service = ContainerRegister(\.myServiceInterface).wrappedValue
/// ```
public struct SimpleAutoRegister {
    
    /// 이 메서드는 더 이상 필요하지 않습니다.
    /// ContainerRegister가 자동으로 모든 것을 처리합니다.
    @available(*, deprecated, message: "No longer needed. ContainerRegister handles everything automatically.")
    public static func registerDefaults() {
        #logInfo("⚠️ SimpleAutoRegister.registerDefaults() is deprecated and no longer needed")
    }
}