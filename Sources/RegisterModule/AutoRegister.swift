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
        #logInfo("✅ AutoRegister setup - ContainerRegister now works automatically")
        #logInfo("💡 사용자는 AutoRegister.addMany { } 또는 AutoRegister.add()로 의존성을 등록하세요")
    }
    
    /// 병렬 일괄 등록을 위한 편의 메서드
    /// 여러 의존성을 한번에 등록할 때 사용하세요
    ///
    /// ## 사용법:
    /// ```swift
    /// AutoRegister.addMany {
    ///     (BookListInterface.self, { BookListRepositoryImpl() })
    ///     (UserServiceInterface.self, { UserServiceImpl() })
    ///     (NetworkInterface.self, { NetworkServiceImpl() })
    /// }
    /// ```
    public static func addMany(@RegistrationBuilder _ registrations: () -> [Registration]) {
        let allRegistrations = registrations()
        
        #logInfo("🔧 [AutoRegister] Batch registering \(allRegistrations.count) dependencies")
        
        // 병렬로 등록 (AutoRegistrationRegistry는 이미 thread-safe)
        DispatchQueue.global(qos: .userInitiated).async {
            for registration in allRegistrations {
                registration.execute()
            }
            DispatchQueue.main.async {
                #logInfo("✅ [AutoRegister] Batch registration completed: \(allRegistrations.count) types")
            }
        }
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

// MARK: - 병렬 등록을 위한 Result Builder

@resultBuilder
public struct RegistrationBuilder {
    public static func buildBlock(_ components: Registration...) -> [Registration] {
        Array(components)
    }
}

/// 개별 등록을 나타내는 구조체
public struct Registration: @unchecked Sendable {
    private let executeBlock: @Sendable () -> Void
    
    public init<T>(_ type: T.Type, factory: @Sendable @escaping () -> T) {
        self.executeBlock = {
            AutoRegistrationRegistry.shared.register(type, factory: factory)
        }
    }
    
    func execute() {
        executeBlock()
    }
}


