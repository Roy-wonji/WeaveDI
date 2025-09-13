//
//  RegisterAndReturnKeyPath.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

/// 등록과 동시에 값을 반환하는 KeyPath 기반 시스템
/// 
/// ## 사용법:
/// ```swift
/// public static var liveValue: BookListInterface = {
///     let repository = ContainerRegister.register(\.bookListInterface) {
///         BookListRepositoryImpl()
///     }
///     return BookListUseCaseImpl(repository: repository)
/// }()
/// ```
public enum RegisterAndReturn {
    
    // MARK: - Register and Return Methods
    
    /// KeyPath 기반 등록 및 인스턴스 반환
    /// - Parameters:
    ///   - keyPath: 의존성을 식별하는 KeyPath
    ///   - factory: 인스턴스를 생성하는 팩토리 클로저
    /// - Returns: 생성된 인스턴스
    @discardableResult
    public static func register<T: Sendable>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        factory: @escaping @Sendable () -> T,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) -> T {
        let keyPathName = extractKeyPathName(keyPath)
        #logInfo("📝 [RegisterAndReturn] Registering and returning \(keyPathName) -> \(T.self)")
        
        // 1. 인스턴스 생성
        let instance = factory()
        #logInfo("✅ [RegisterAndReturn] Created instance for \(keyPathName): \(type(of: instance))")
        
        // 2. AutoRegister 시스템에 등록 (나중에 다른 곳에서 재사용 가능)
      DI.register(T.self) { instance }

        // 3. 생성된 인스턴스 반환
        return instance
    }
    
    /// KeyPath 기반 등록 및 인스턴스 반환 (비동기)
    /// - Parameters:
    ///   - keyPath: 의존성을 식별하는 KeyPath
    ///   - factory: 인스턴스를 생성하는 비동기 팩토리 클로저
    /// - Returns: 생성된 인스턴스
    @discardableResult
    public static func registerAsync<T: Sendable>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        factory: @escaping @Sendable () async -> T,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) async -> T {
        let keyPathName = extractKeyPathName(keyPath)
        #logInfo("🔄 [RegisterAndReturn] Async registering and returning \(keyPathName) -> \(T.self)")
        
        // 1. 비동기로 인스턴스 생성
        let instance = await factory()
        #logInfo("✅ [RegisterAndReturn] Created async instance for \(keyPathName): \(type(of: instance))")
        
        // 2. AutoRegister 시스템에 등록
      DI.register(T.self) { instance }
        
        // 3. 생성된 인스턴스 반환
        return instance
    }
    
    /// KeyPath 기반 조건부 등록 및 인스턴스 반환
    /// - Parameters:
    ///   - keyPath: 의존성을 식별하는 KeyPath
    ///   - condition: 등록 조건
    ///   - factory: 인스턴스를 생성하는 팩토리 클로저
    ///   - fallback: 조건이 false일 때 사용할 기본값
    /// - Returns: 생성된 인스턴스 또는 기본값
    @discardableResult
    public static func registerIf<T: Sendable>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        condition: Bool,
        factory: @escaping @Sendable () -> T,
        fallback: @autoclosure () -> T,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) -> T {
        let keyPathName = extractKeyPathName(keyPath)
        
        if condition {
            #logInfo("✅ [RegisterAndReturn] Condition met for \(keyPathName) -> \(T.self)")
            return register(keyPath, factory: factory, file: file, function: function, line: line)
        } else {
            let fallbackInstance = fallback()
            #logInfo("⏭️ [RegisterAndReturn] Using fallback for \(keyPathName) -> \(type(of: fallbackInstance))")
            return fallbackInstance
        }
    }
    
    /// KeyPath 기반 싱글톤 등록 및 인스턴스 반환
    /// - Parameters:
    ///   - keyPath: 의존성을 식별하는 KeyPath
    ///   - factory: 인스턴스를 생성하는 팩토리 클로저 (한 번만 실행됨)
    /// - Returns: 싱글톤 인스턴스
    @discardableResult
    public static func registerSingleton<T: Sendable>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        factory: @escaping @Sendable () -> T,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) -> T {
        let keyPathName = extractKeyPathName(keyPath)
        
        // 이미 등록된 싱글톤이 있는지 확인
        if let existingInstance = getSingleton(for: keyPathName, type: T.self) {
            #logInfo("♻️ [RegisterAndReturn] Returning existing singleton for \(keyPathName)")
            return existingInstance
        }
        
        #logInfo("🏛️ [RegisterAndReturn] Creating new singleton for \(keyPathName)")
        
        // 새 싱글톤 인스턴스 생성
        let instance = factory()
        #logInfo("✅ [RegisterAndReturn] Created singleton instance for \(keyPathName): \(type(of: instance))")
        
        // 싱글톤으로 저장
        setSingleton(for: keyPathName, instance: instance)
        
        // AutoRegister 시스템에도 등록
        AutoRegister.add(T.self) { instance }
        
        return instance
    }
    
    // MARK: - Utility Methods
    
    /// KeyPath에서 이름 추출
    public static func extractKeyPathName<T>(_ keyPath: KeyPath<DependencyContainer, T?>) -> String {
        let keyPathString = String(describing: keyPath)
        
        // KeyPath 문자열에서 프로퍼티 이름 추출
        // 예: \DependencyContainer.userService -> userService
        if let dotIndex = keyPathString.lastIndex(of: ".") {
            let propertyName = String(keyPathString[keyPathString.index(after: dotIndex)...])
            return propertyName
        }
        
        return keyPathString
    }
    
    /// 등록된 의존성 확인
    public static func isRegistered<T>(_ keyPath: KeyPath<DependencyContainer, T?>) -> Bool {
        // DI 컨테이너에 인스턴스가 등록되어 있는지 확인
        return DependencyContainer.live.resolve(T.self) != nil
    }
    
    // MARK: - Private Singleton Management
    
    private static func getSingleton<T>(for keyPath: String, type: T.Type) -> T? {
        // 싱글톤은 컨테이너 인스턴스 등록으로 대체합니다.
        return DependencyContainer.live.resolve(T.self)
    }
    
    private static func setSingleton<T>(for keyPath: String, instance: T) {
        // 컨테이너 인스턴스 등록을 통해 싱글톤을 보장합니다.
        DependencyContainer.live.register(T.self, instance: instance)
    }
}

// MARK: - Singleton Registry

/// 싱글톤 인스턴스들을 관리하는 레지스트리
actor KeyPathSingletonRegistry {
    static let shared = KeyPathSingletonRegistry()
    private var singletons: [String: Any] = [:]
    func getSingleton(for keyPath: String) -> Any? { singletons[keyPath] }
    func setSingleton(for keyPath: String, instance: Any) { singletons[keyPath] = instance }
    func hasSingleton(for keyPath: String) -> Bool { singletons[keyPath] != nil }
    func clearAllSingletons() { singletons.removeAll() }
}

// MARK: - Environment Extensions

extension RegisterAndReturn {
    
    /// Debug 환경에서만 등록 및 반환
    @discardableResult
    public static func registerIfDebug<T: Sendable>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        factory: @escaping @Sendable () -> T,
        fallback: @autoclosure () -> T,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) -> T {
        #if DEBUG
        let keyPathName = extractKeyPathName(keyPath)
        #logInfo("🐛 [RegisterAndReturn] Debug registration for \(keyPathName)")
        return register(keyPath, factory: factory, file: file, function: function, line: line)
        #else
        let fallbackInstance = fallback()
        let keyPathName = extractKeyPathName(keyPath)
        #logInfo("🚫 [RegisterAndReturn] Using fallback for \(keyPathName) (Release build)")
        return fallbackInstance
        #endif
    }
    
    /// Release 환경에서만 등록 및 반환
    @discardableResult
    public static func registerIfRelease<T: Sendable>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        factory: @escaping @Sendable () -> T,
        fallback: @autoclosure () -> T,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) -> T {
        #if DEBUG
        let fallbackInstance = fallback()
        let keyPathName = extractKeyPathName(keyPath)
        #logInfo("🚫 [RegisterAndReturn] Using fallback for \(keyPathName) (Debug build)")
        return fallbackInstance
        #else
        let keyPathName = extractKeyPathName(keyPath)
        #logInfo("🚀 [RegisterAndReturn] Release registration for \(keyPathName)")
        return register(keyPath, factory: factory, file: file, function: function, line: line)
        #endif
    }
}
