//
//  SimpleAutoRegister.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

/// 가장 간단한 자동 등록 방법
/// 
/// ## 사용법:
/// ```swift
/// // 앱 시작 시 한 번만
/// SimpleAutoRegister.registerDefaults()
/// 
/// // 이후 어디서든 자동으로 동작
/// let repo = ContainerRegister(\.bookListInterface).wrappedValue
/// ```
public struct SimpleAutoRegister {
    
    /// 기본적인 인터페이스들을 자동 등록합니다.
    /// 사용자는 이 메서드를 앱 시작 시 한 번만 호출하면 됩니다.
    public static func registerDefaults() {
        AutoRegistrationRegistry.shared.registerTypes {
            // BookListInterface 자동 등록
            TypeRegistration(BookListInterface.self) {
                // 여기서 사용자의 실제 구현체를 반환
                // 사용자가 BookListRepositoryImpl을 만들었다면 여기서 사용
                DefaultBookListImpl()
            }
            
            // 다른 인터페이스들도 필요시 추가
            // TypeRegistration(UserServiceProtocol.self) {
            //     UserServiceImpl()
            // }
        }
        
        #logInfo("✅ SimpleAutoRegister: Default types registered")
    }
}

// MARK: - 기본 구현체들 (사용자가 실제 구현체를 만들면 대체됨)

public protocol BookListInterface {
    func fetchBooks() async throws -> [String]
}

/// BookListInterface의 기본 구현체
/// 사용자가 실제 BookListRepositoryImpl을 만들면 이것 대신 사용됩니다.
public struct DefaultBookListImpl: BookListInterface {
    public init() {}
    
    public func fetchBooks() async throws -> [String] {
        #logInfo("📚 Using DefaultBookListImpl - consider creating BookListRepositoryImpl")
        return ["Default Book 1", "Default Book 2", "Default Book 3"]
    }
}