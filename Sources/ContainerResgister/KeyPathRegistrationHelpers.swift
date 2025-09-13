//
//  KeyPathRegistrationHelpers.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - Convenient Registration Extensions

extension ContainerRegister {
    
    // MARK: - Environment-based Registration
    
    /// Debug 환경에서만 등록
    nonisolated public static func registerIfDebug<T>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        factory: @escaping @Sendable () -> T,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let keyPathName = extractKeyPathName(keyPath)
        #logInfo("🐛 [ContainerRegister] Debug-only registration: \(keyPathName)")
        register(keyPath, factory: factory, file: file, function: function, line: line)
        #else
        let keyPathName = extractKeyPathName(keyPath)
        #logInfo("🚫 [ContainerRegister] Skipping debug registration: \(keyPathName) (Release build)")
        #endif
    }
    
    /// Release 환경에서만 등록
    nonisolated public static func registerIfRelease<T>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        factory: @escaping @Sendable () -> T,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let keyPathName = extractKeyPathName(keyPath)
        #logInfo("🚫 [ContainerRegister] Skipping release registration: \(keyPathName) (Debug build)")
        #else
        let keyPathName = extractKeyPathName(keyPath)
        #logInfo("🚀 [ContainerRegister] Release-only registration: \(keyPathName)")
        register(keyPath, factory: factory, file: file, function: function, line: line)
        #endif
    }
    
    // MARK: - Conditional Registration with Predicates
    
    /// 플랫폼별 조건부 등록
    nonisolated public static func registerIf<T>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        platform: SupportedPlatform,
        factory: @escaping @Sendable () -> T,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        let condition = platform.isCurrentPlatform
        let keyPathName = extractKeyPathName(keyPath)
        
        if condition {
            #logInfo("📱 [ContainerRegister] Platform match (\(platform)): \(keyPathName)")
        } else {
            #logInfo("🚫 [ContainerRegister] Platform mismatch (\(platform)): \(keyPathName)")
        }
        
        registerIf(keyPath, condition: condition, factory: factory, file: file, function: function, line: line)
    }
    
    /// 사용자 정의 조건으로 등록
    nonisolated public static func registerWhen<T>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        condition: @autoclosure () -> Bool,
        factory: @escaping @Sendable () -> T,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        registerIf(keyPath, condition: condition(), factory: factory, file: file, function: function, line: line)
    }
    
    // MARK: - Lazy Registration
    
    /// 지연 등록 (첫 번째 접근 시까지 팩토리 실행 지연)
    nonisolated public static func registerLazy<T>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        factory: @escaping @Sendable () -> T,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        let keyPathName = extractKeyPathName(keyPath)
        #logInfo("💤 [ContainerRegister] Lazy registration: \(keyPathName)")
        
        let lazyFactory: @Sendable () -> T = {
            #logInfo("⚡ [ContainerRegister] Lazy factory executing for: \(keyPathName)")
            return factory()
        }
        
        register(keyPath, factory: lazyFactory, file: file, function: function, line: line)
    }
    
    // MARK: - Singleton Registration
    
    /// 싱글톤 등록 (한 번만 생성, 이후 재사용)
    nonisolated public static func registerSingleton<T>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        factory: @escaping @Sendable () -> T,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        let keyPathName = extractKeyPathName(keyPath)
        #logInfo("🏛️ [ContainerRegister] Singleton registration: \(keyPathName)")
        
        let singletonFactory = SingletonFactory(factory: factory, keyPathName: keyPathName)
        register(keyPath, factory: singletonFactory.getInstance, file: file, function: function, line: line)
    }
}

// MARK: - Platform Support

public enum SupportedPlatform: String, CaseIterable {
    case iOS = "iOS"
    case macOS = "macOS"
    case watchOS = "watchOS"
    case tvOS = "tvOS"
    case visionOS = "visionOS"
    
    var isCurrentPlatform: Bool {
        #if os(iOS)
        return self == .iOS
        #elseif os(macOS)
        return self == .macOS
        #elseif os(watchOS)
        return self == .watchOS
        #elseif os(tvOS)
        return self == .tvOS
        #elseif os(visionOS)
        return self == .visionOS
        #else
        return false
        #endif
    }
}

// MARK: - Singleton Factory

private final class SingletonFactory<T>: @unchecked Sendable {
    private let factory: @Sendable () -> T
    private let keyPathName: String
    private var instance: T?
    private let lock = NSLock()
    
    init(factory: @escaping @Sendable () -> T, keyPathName: String) {
        self.factory = factory
        self.keyPathName = keyPathName
    }
    
    func getInstance() -> T {
        lock.lock()
        defer { lock.unlock() }
        
        if let instance = instance {
            #logInfo("♻️ [ContainerRegister] Reusing singleton: \(keyPathName)")
            return instance
        }
        
        #logInfo("🆕 [ContainerRegister] Creating singleton: \(keyPathName)")
        let newInstance = factory()
        instance = newInstance
        return newInstance
    }
}

// MARK: - Registration DSL Extensions

extension ContainerRegister {
    /// DSL 스타일 등록
    nonisolated public static func configure(@RegistrationConfigBuilder _ configuration: () -> [RegistrationConfig]) {
        let configs = configuration()
        
        #logInfo("⚙️ [ContainerRegister] Starting DSL configuration (\(configs.count) items)...")
        
        Task {
            for config in configs {
                await config.execute()
            }
            #logInfo("✅ [ContainerRegister] DSL configuration complete")
        }
    }
}

/// Registration Configuration
public struct RegistrationConfig {
    private let executeBlock: @Sendable () async -> Void
    
    public init<T>(
        keyPath: KeyPath<DependencyContainer, T?>,
        factory: @escaping @Sendable () -> T,
        condition: Bool = true,
        singleton: Bool = false,
        lazy: Bool = false
    ) {
        self.executeBlock = {
            guard condition else {
                let keyPathName = ContainerRegister.extractKeyPathName(keyPath)
                #logInfo("⏭️ [ContainerRegister] Skipping \(keyPathName) (condition: false)")
                return
            }
            
            if singleton {
                await ContainerRegister.registerSingleton(keyPath, factory: factory)
            } else if lazy {
                await ContainerRegister.registerLazy(keyPath, factory: factory)
            } else {
                await ContainerRegister.register(keyPath, factory: factory)
            }
        }
    }
    
    func execute() async {
        await executeBlock()
    }
}

/// Registration Config Result Builder
@resultBuilder
public enum RegistrationConfigBuilder {
    public static func buildBlock(_ components: RegistrationConfig...) -> [RegistrationConfig] {
        Array(components)
    }
}

// MARK: - KeyPath Name Extraction Helper

extension ContainerRegister {
    /// KeyPath에서 이름 추출 (내부 사용을 위해 public으로 노출)
    nonisolated public static func extractKeyPathName<T>(_ keyPath: KeyPath<DependencyContainer, T?>) -> String {
        let keyPathString = String(describing: keyPath)
        
        // KeyPath 문자열에서 프로퍼티 이름 추출
        // 예: \DependencyContainer.userService -> userService
        if let dotIndex = keyPathString.lastIndex(of: ".") {
            let propertyName = String(keyPathString[keyPathString.index(after: dotIndex)...])
            return propertyName
        }
        
        return keyPathString
    }
}