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
        AutoRegistrationRegistry.shared.registerTypes {
            // BookList 관련
            TypeRegistration(BookListInterface.self) {
                BookListRepositoryImpl()
            }
            
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
        }
        #logInfo("✅ AutoRegister setup - ContainerRegister now works automatically")
    }
    
    /// 개별 타입 등록
    public static func add<T>(_ type: T.Type, factory: @escaping () -> T) {
        AutoRegistrationRegistry.shared.register(type, factory: factory)
        #logInfo("✅ \(String(describing: type)) registered")
    }
    
    /// 앱 시작 시 자동으로 설정되는 싱글톤 (선택적)
    public static let autoSetup: Void = {
        setup()
    }()
}

// MARK: - DependencyContainer 확장

public extension DependencyContainer {
    var bookListInterface: BookListInterface? {
        resolve(BookListInterface.self)
    }
}

// MARK: - BookList 타입 정의 (예시)

public protocol BookListInterface {
    func fetchBooks() async throws -> [String]
}

public struct BookListRepositoryImpl: BookListInterface {
    public init() {}
    
    public func fetchBooks() async throws -> [String] {
        #logDebug("📚 BookListRepository: Fetching books")
        return ["Book 1", "Book 2", "Book 3"]
    }
}

public struct BookListUseCaseImpl: BookListInterface {
    private let repository: BookListInterface
    
    public init(repository: BookListInterface) {
        self.repository = repository
    }
    
    public func fetchBooks() async throws -> [String] {
        #logDebug("🎯 BookListUseCase: Processing book fetch")
        return try await repository.fetchBooks()
    }
}

public struct DefaultBookListRepositoryImpl: BookListInterface {
    public init() {}
    
    public func fetchBooks() async throws -> [String] {
        #logDebug("🔒 Default BookListRepository: Mock books")
        return ["Default Book 1", "Default Book 2"]
    }
}