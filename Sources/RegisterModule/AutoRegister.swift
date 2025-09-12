//
//  AutoRegister.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - 자동 등록
//
// ## 사용법:
// ```swift
// // 1. 앱 시작 시 한번만 호출 (AppDelegate 또는 App.swift에서)
// AutoRegister.setup()
//
// // 2. 이후 어디서든 간편하게 사용
// @ContainerRegister(\.bookListInterface)
// private var repository: BookListInterface
//
// @ContainerRegister(\.userService)
// private var userService: UserServiceProtocol
//
// // 또는
// public static var liveValue: BookListInterface = {
//     let repository = ContainerRegister(\.bookListInterface).wrappedValue
//     return BookListUseCaseImpl(repository: repository)
// }()
// ```

/// 자동 등록 설정
/// 이제 ContainerRegister(\.keyPath)만 사용해도 자동으로 등록된 타입을 찾습니다.
public struct AutoRegister {
    
    /// 앱에서 자주 사용하는 인터페이스들을 미리 등록
    /// 이후 ContainerRegister(\.bookListInterface).wrappedValue 사용 시 자동으로 찾아줍니다.
    public static func setup() {
        
            
            // 다른 인터페이스들도 여기에 추가
            // TypeRegistration(UserServiceProtocol.self) {
            //     UserServiceImpl()
            // }
            
            // TypeRegistration(NetworkServiceProtocol.self) {
            //     NetworkServiceImpl()
            // }
            
            // TypeRegistration(AuthInterface.self) {
            //     AuthRepositoryImpl()
            // }
//        }
        #logInfo("✅ AutoRegister setup - ContainerRegister now works automatically")
    }
    
    /// 개별 타입 등록 (static 메서드)
    public static func add<T>(_ type: T.Type, factory: @Sendable @escaping () -> T) {
        AutoRegistrationRegistry.shared.register(type, factory: factory)
        #logInfo("✅ \(String(describing: type)) registered")
    }
    
    /// 개별 타입 등록 (인스턴스 메서드)
    public func add<T>(_ type: T.Type, factory: @Sendable @escaping () -> T) {
        AutoRegister.add(type, factory: factory)
    }
    
    /// 앱 시작 시 자동으로 설정되는 싱글톤 (선택적)
    public static let autoSetup: Void = {
        setup()
    }()
}


