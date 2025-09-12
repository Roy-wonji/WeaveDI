//
//  RegisterModule+EasyScopes.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - Easy Scope DSL

public extension RegisterModule {
    
    /// 타입 안전한 간편 스코프 등록
    ///
    /// ## 사용법:
    /// ```swift
    /// let modules = registerModule.easyScopes {
    ///   register(NetworkServiceProtocol.self) { DefaultNetworkService() }
    ///   register(CacheServiceProtocol.self) { InMemoryCacheService() }
    ///   register(LoggerProtocol.self) { ConsoleLogger() }
    /// }
    /// ```
    func easyScopes(@EasyScopeBuilder _ builder: () -> [RegisterEasyScopeEntry]) -> [() -> Module] {
        let entries = builder()
        return entries.map { entry in
            return { entry.createModule() }
        }
    }
}

/// 간편한 스코프 등록을 위한 빌더
@resultBuilder
public struct EasyScopeBuilder {
    public static func buildBlock(_ components: RegisterEasyScopeEntry...) -> [RegisterEasyScopeEntry] {
        Array(components)
    }
    
    public static func buildArray(_ components: [[RegisterEasyScopeEntry]]) -> [RegisterEasyScopeEntry] {
        components.flatMap { $0 }
    }
    
    public static func buildOptional(_ component: [RegisterEasyScopeEntry]?) -> [RegisterEasyScopeEntry] {
        component ?? []
    }
}

/// 간편한 스코프 엔트리
public struct RegisterEasyScopeEntry {
    private let moduleFactory: () -> Module
    
    public init<T>(type: T.Type, factory: @Sendable @escaping () -> T) {
        self.moduleFactory = { Module(type, factory: factory) }
    }
    
    public func createModule() -> Module {
        moduleFactory()
    }
}

/// 전역 함수로 더욱 간편한 등록
public func register<T>(_ type: T.Type, factory: @Sendable @escaping () -> T) -> RegisterEasyScopeEntry {
    RegisterEasyScopeEntry(type: type, factory: factory)
}

// MARK: - DependencyScope 확장 (Needle 스타일)

// DependencyScope 확장은 다른 파일에 이미 있으므로 제거