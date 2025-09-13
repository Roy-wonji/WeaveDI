//
//  QuickStartExample.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

/// 빠른 시작 가이드 및 예제
/// 
/// ## 사용법:
/// 
/// 1. 앱 시작 시 (AppDelegate 또는 App.swift):
/// ```swift
/// // 의존성 등록 - 사용자가 정의한 인터페이스 사용
/// AutoRegister.add(MyServiceProtocol.self) { MyServiceImpl() }
/// AutoRegister.add(DataRepositoryInterface.self) { DatabaseRepository() }
/// ```
///
/// 2. 어디서든 사용:
/// ```swift
/// @ContainerInject(\.myService)
/// private var service: MyServiceProtocol?
///
/// // 또는 (필수 의존성인 경우)
/// @RequiredDependency(\.myService)
/// private var service: MyServiceProtocol
/// ```
///
/// ## 권장 패턴:
/// - 사용자가 직접 프로토콜/인터페이스 정의
/// - 구현체는 Protocol, Interface 등의 접미사에 따라 Impl, Implementation 등으로 명명
/// - 앱 시작 시 한번에 모든 의존성 등록

public enum QuickStartGuide {
    
    /// 앱 시작 시 호출할 의존성 등록 예제
    /// 사용자는 이것을 참고해서 자신의 타입들을 등록하면 됩니다.
    public static func registerCommonDependencies() {
        #logInfo("📝 [QuickStart] 이것은 예제입니다. 사용자의 실제 타입으로 바꿔주세요:")
        
        // 방법 1: 개별 등록
        #logInfo("📝 [QuickStart] AutoRegister.add(YourProtocol.self) { YourImplementation() }")
        
        // 방법 2: 병렬 일괄 등록 (권장)
        #logInfo("📝 [QuickStart] AutoRegister.addMany { ... }")
        
        // 실제 사용 예시 (주석 해제해서 사용):
        /*
        AutoRegister.addMany {
            Registration(MyServiceProtocol.self) { MyServiceImpl() }
            Registration(DataRepositoryInterface.self) { DatabaseRepository() }
            Registration(NetworkServiceProtocol.self) { NetworkServiceImpl() }
        }
        */
        
        // 또는 개별 등록:
        // AutoRegister.add(MyServiceProtocol.self) { MyServiceImpl() }
        // AutoRegister.add(DataRepositoryInterface.self) { DatabaseRepository() }
    }
}