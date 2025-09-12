//
//  BookListSetup.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - BookList DI 설정

/// BookList 관련 의존성을 설정하는 헬퍼
public struct BookListSetup {
    
    /// 자동 등록 설정
    public static func setupAutoRegistration() {
        AutoRegistrationRegistry.shared.registerTypes {
            TypeRegistration(BookListInterface.self) {
                BookListRepositoryImpl()
            }
        }
        #logInfo("✅ BookList auto registration setup complete")
    }
    
    /// 수동 모듈 등록
    public static func setupManualRegistration() async {
        let registerModule = RegisterModule()
        
        await AppDIContainer.shared.registerDependencies { container in
            // 새로운 방식: 한번에 등록
            for moduleFactory in registerModule.bookListModules {
                await container.register(moduleFactory())
            }
        }
        
        #logInfo("✅ BookList manual registration complete")
    }
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