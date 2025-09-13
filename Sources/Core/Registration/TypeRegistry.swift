//
//  TypeRegistry.swift
//  DiContainer
//
//  Created by OpenAI on 2025-09-14.
//

import Foundation
import LogMacro

// MARK: - AsyncTypeRegistry

/// Actor-based async registry for DIAsync.
/// Stores async factories and singleton instances without using GCD/locks.
public actor AsyncTypeRegistry {
    // Type-erased, sendable box to safely move values across concurrency domains
    public struct AnySendableBox: @unchecked Sendable {
        public let value: Any
        public init(_ v: Any) { self.value = v }
    }

    private var asyncFactories: [AnyTypeIdentifier: (@Sendable () async -> AnySendableBox)] = [:]
    private var singletons: [AnyTypeIdentifier: AnySendableBox] = [:]

    public init() {}

    // MARK: Register

    /// Register an async factory for a type (transient resolution)
    public func register<T>(
        _ type: T.Type,
        factory: @Sendable @escaping () async -> T
    ) {
        let key = AnyTypeIdentifier(type)
        asyncFactories[key] = { AnySendableBox(await factory()) }
    }

    /// Register a singleton instance for a type
    public func registerInstance<T>(
        _ type: T.Type,
        instance: T
    ) {
        let key = AnyTypeIdentifier(type)
        singletons[key] = AnySendableBox(instance)
    }

    /// Register a pre-boxed singleton instance (avoid sending non-Sendable across boundary)
    public func registerInstanceBoxed<T>(
        _ type: T.Type,
        boxed: AnySendableBox
    ) {
        let key = AnyTypeIdentifier(type)
        singletons[key] = boxed
    }

    // MARK: Resolve

    /// Resolve a type and return a sendable box
    public func resolveBox<T>(_ type: T.Type) async -> AnySendableBox? {
        let key = AnyTypeIdentifier(type)
        if let box = singletons[key] { return box }
        if let maker = asyncFactories[key] {
            let box = await maker()
            return box
        }
        return nil
    }

    /// Get an existing singleton box, or create/store one using the provided factory
    public func getOrCreateBox<T>(
        _ type: T.Type,
        orMake make: @Sendable () async -> AnySendableBox
    ) async -> AnySendableBox {
        let key = AnyTypeIdentifier(type)
        if let box = singletons[key] { return box }
        let newBox = await make()
        singletons[key] = newBox
        return newBox
    }

    // MARK: Maintenance

    /// Release a registration (singleton and factory)
    public func release<T>(_ type: T.Type) {
        let key = AnyTypeIdentifier(type)
        singletons[key] = nil
        asyncFactories[key] = nil
    }

    /// Clear all registrations (test-only recommended)
    public func clearAll() {
        singletons.removeAll()
        asyncFactories.removeAll()
    }
}

// MARK: - AutoRegistrationRegistry

/// Needle 스타일의 자동 등록을 위한 타입 매핑 레지스트리입니다.
public final class AutoRegistrationRegistry: @unchecked Sendable {
    public static let shared = AutoRegistrationRegistry()

    // 내부적으로 타입-안전 레지스트리를 사용하여 GCD 의존 제거
    private let registry = TypeSafeRegistry()

    private init() {}

    /// 타입과 그 구현체를 등록합니다.
    public func register<T>(_ protocolType: T.Type, factory: @Sendable @escaping () -> T) {
        _ = registry.register(protocolType, factory: factory)
        #logInfo("✅ [AutoRegistry] Registered type: \(String(describing: protocolType))")
    }

    /// 등록된 타입에 대한 인스턴스를 생성합니다.
    public func createInstance<T>(for type: T.Type) -> T? {
        registry.resolve(type)
    }

    /// 타입이 등록되어 있는지 확인합니다.
    public func isRegistered<T>(_ type: T.Type) -> Bool {
        return registry.resolve(type) != nil
    }

    /// 등록된 타입에 대한 인스턴스를 해결합니다.
    public func resolve<T>(_ type: T.Type) -> T? {
        return registry.resolve(type)
    }

    /// 모든 등록된 타입을 출력합니다 (디버깅용)
    public func debugPrintRegisteredTypes() {
        let names = registry.allTypeNames()
        #logDebug("🔍 AutoRegistrationRegistry - Registered Types:")
        for (index, typeName) in names.enumerated() {
            #logDebug("   [\(index + 1)] \(typeName)")
        }
    }

    /// 등록된 타입 개수를 반환합니다.
    public var registeredCount: Int {
        registry.registeredCount()
    }

    /// 등록된 모든 타입 이름을 반환합니다 (디버깅용)
    public func getAllRegisteredTypeNames() -> [String] {
        registry.allTypeNames()
    }

    /// 여러 타입을 한번에 등록하는 편의 메서드입니다.
    func registerTypes(@TypeRegistrationBuilder _ builder: () -> [TypeRegistration]) {
        let registrations = builder()
        for registration in registrations {
            registration.register(in: self)
        }
    }
}

// MARK: - Type Registration Builder

/// 타입 등록을 위한 Result Builder입니다.
@resultBuilder
public struct TypeRegistrationBuilder {
    public static func buildBlock(_ components: TypeRegistration...) -> [TypeRegistration] {
        components
    }
}

/// 개별 타입 등록을 나타내는 구조체입니다.
public struct TypeRegistration {
    private let registerFunc: (AutoRegistrationRegistry) -> Void

    public init<T>(_ type: T.Type, factory: @Sendable @escaping () -> T) {
        self.registerFunc = { registry in
            registry.register(type, factory: factory)
        }
    }

    func register(in registry: AutoRegistrationRegistry) {
        registerFunc(registry)
    }
}

// MARK: - Global Registration Functions

/// 전역 함수로 자동 등록 설정을 간편하게 할 수 있습니다.
public func setupAutoRegistration() {
    // 사용자가 필요에 따라 타입들을 등록할 수 있습니다.
    // AutoRegistrationRegistry.shared.registerTypes {
    //     TypeRegistration(NetworkServiceProtocol.self) { DefaultNetworkService() }
    // }
}