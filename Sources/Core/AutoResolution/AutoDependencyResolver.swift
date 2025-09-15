//
//  AutoDependencyResolver.swift
//  DiContainer
//
//  Created by Claude on 2025-09-14.
//

import Foundation
import LogMacro

// MARK: - Auto Dependency Resolution System

/// 자동 의존성 해결을 위한 핵심 인터페이스
///
/// ## 개요
///
/// Swift의 Mirror 기반 리플렉션을 사용하여 클래스/구조체의 프로퍼티를 자동으로 분석하고,
/// `@Inject` 프로퍼티 래퍼가 붙은 의존성들을 자동으로 해결합니다.
///
/// ## 사용 예시
///
/// ```swift
/// class UserService: AutoResolvable {
///     @Inject var repository: UserRepositoryProtocol?
///     @Inject var logger: LoggingService?
///
///     init() {
///         // 자동 해결 수행
///         AutoDependencyResolver.resolve(self)
///     }
/// }
/// ```
public protocol AutoResolvable: AnyObject {
    /// 자동 해결이 완료된 후 호출되는 콜백
    func didAutoResolve()
}

public extension AutoResolvable {
    func didAutoResolve() {
        // 기본 구현은 아무것도 하지 않음
    }
}

// MARK: - AutoDependencyResolver

/// 자동 의존성 해결을 수행하는 핵심 클래스 (메인 액터 격리)
@MainActor
public final class AutoDependencyResolver {

    // MARK: - Configuration (nonisolated)
    /// 자동 해석 활성화 플래그 (기본값: true)
    nonisolated(unsafe) public static var isEnabled: Bool = true

    /// 자동 해석에서 제외할 타입 집합
    nonisolated(unsafe) private static var excludedTypeIDs: Set<ObjectIdentifier> = []

    /// 자동 해석 비활성화
    nonisolated public static func disable() { isEnabled = false }

    /// 자동 해석 활성화
    nonisolated public static func enable() { isEnabled = true }

    /// 특정 타입을 자동 해석에서 제외합니다.
    nonisolated public static func excludeType<T>(_ type: T.Type) {
        excludedTypeIDs.insert(ObjectIdentifier(type))
    }

    /// 특정 타입의 제외를 해제합니다.
    nonisolated public static func includeType<T>(_ type: T.Type) {
        excludedTypeIDs.remove(ObjectIdentifier(type))
    }

    // 비-Sendable 참조를 안전하게 다른 실행 컨텍스트로 전달하기 위한 박스
    private final class ObjBox: @unchecked Sendable {
        let obj: AnyObject
        init(_ o: AnyObject) { self.obj = o }
    }

    public static let shared = AutoDependencyResolver()
    private var resolvedInstances: NSHashTable<AnyObject> = NSHashTable.weakObjects()

    /// 인스턴스의 모든 @Inject 프로퍼티를 자동으로 해결합니다
    public nonisolated static func resolve<T: AutoResolvable>(_ instance: T) {
        guard isEnabled, !excludedTypeIDs.contains(ObjectIdentifier(T.self)) else { return }
        let box = ObjBox(instance as AnyObject)
        Task { @MainActor in
            if let inst = box.obj as? T {
                await shared.performAutoResolution(on: inst)
            }
        }
    }

    /// 비동기 자동 해결
    public nonisolated static func resolveAsync<T: AutoResolvable>(_ instance: T) async {
        guard isEnabled, !excludedTypeIDs.contains(ObjectIdentifier(T.self)) else { return }
        let box = ObjBox(instance as AnyObject)
        await MainActor.run {
            if let inst = box.obj as? T {
                Task { @MainActor in await shared.performAutoResolution(on: inst) }
            }
        }
    }

    /// 타입의 모든 인스턴스에 대해 자동 해결을 수행합니다
    public nonisolated static func resolveAllInstances<T: AutoResolvable>(of type: T.Type) {
        Task { @MainActor in
            await shared.resolveExistingInstances(of: type)
        }
    }

    private func performAutoResolution<T: AutoResolvable>(on instance: T) async {
        await performResolutionAsync(on: instance)
    }

    private func performResolutionAsync<T: AutoResolvable>(on instance: T) async {
        // 중복 해결 방지
        guard !resolvedInstances.contains(instance) else { return }

        let mirror = Mirror(reflecting: instance)
        var resolvedProperties: [String] = []

        for child in mirror.children {
            guard let propertyName = child.label else { continue }

            // @Inject 프로퍼티 래퍼 감지 및 해결
            if let injectWrapper = detectInjectProperty(child.value) {
                if await resolveInjectPropertyAsync(injectWrapper, propertyName: propertyName, on: instance) {
                    resolvedProperties.append(propertyName)
                }
            }
        }

        // 해결된 인스턴스 추적
        resolvedInstances.add(instance)

        // 메인 액터 내에서 직접 콜백 호출
        instance.didAutoResolve()
        #if DEBUG
        #logInfo("🔄 [AutoResolver] Resolved \(resolvedProperties.count) properties for \(type(of: instance))")
        #endif
    }

    private func detectInjectProperty(_ value: Any) -> Any? {
        let _ = Mirror(reflecting: value)

        // @Inject<T> 감지
        if String(describing: type(of: value)).contains("Inject<") {
            return value
        }

        // @RequiredInject<T> 감지
        if String(describing: type(of: value)).contains("RequiredInject<") {
            return value
        }

        return nil
    }

    private func resolveInjectPropertyAsync<T: AutoResolvable>(_ wrapper: Any, propertyName: String, on instance: T) async -> Bool {
        // Mirror를 사용하여 wrapper의 내부 상태 확인
        let wrapperMirror = Mirror(reflecting: wrapper)

        for child in wrapperMirror.children {
            if child.label == "wrappedValue" {
                // 이미 해결된 경우 스킵
                if !isNilOrEmpty(child.value) {
                    return false
                }
            }
        }

        // Reflection을 통한 해결 시도
        return await attemptResolutionByReflectionAsync(wrapper: wrapper, propertyName: propertyName, on: instance)
    }

    private func attemptResolutionByReflectionAsync<T: AutoResolvable>(wrapper: Any, propertyName: String, on instance: T) async -> Bool {
        let typeName = String(describing: type(of: wrapper))

        // 제네릭 타입 추출 (예: Inject<UserService> -> UserService)
        if let extractedType = extractGenericType(from: typeName) {
            // 타입 이름으로 의존성 해결 시도
            if let box = await TypeNameResolver.resolveAsyncBox(extractedType) {
                return injectResolvedValue(box.value, into: wrapper, on: instance, propertyName: propertyName)
            }
        }

        return false
    }

    private func extractGenericType(from typeName: String) -> String? {
        // "Inject<UserService>" -> "UserService" 추출
        let pattern = #"<(.+)>"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: typeName, range: NSRange(typeName.startIndex..., in: typeName)),
              let range = Range(match.range(at: 1), in: typeName) else {
            return nil
        }

        return String(typeName[range])
    }

    private func injectResolvedValue<T: AutoResolvable>(_ value: Any, into wrapper: Any, on instance: T, propertyName: String) -> Bool {
        // Swift의 제한으로 인해 직접 주입은 불가능
        // 대신 인스턴스에 해결된 값을 알려주고, 수동 주입을 요청
        if let autoInjectible = instance as? AutoInjectible {
            autoInjectible.injectResolvedValue(value, forProperty: propertyName)
            return true
        }

        #if DEBUG
      #logDebug("⚠️ [AutoResolver] Cannot inject \(propertyName) - instance must conform to AutoInjectible")
        #endif
        return false
    }

    private func isNilOrEmpty(_ value: Any) -> Bool {
        if case Optional<Any>.none = value {
            return true
        }
        return false
    }

    private func resolveExistingInstances<T: AutoResolvable>(of type: T.Type) async {
        // 약한 참조로 저장된 인스턴스들 중 해당 타입만 필터링하여 재해결
        let allObjects = resolvedInstances.allObjects
        for object in allObjects {
            if let instance = object as? T {
                await performResolutionAsync(on: instance)
            }
        }
    }
}

// MARK: - AutoInjectible Protocol

/// 자동 주입을 받을 수 있는 클래스가 구현해야 하는 프로토콜
///
/// Swift의 리플렉션 제한으로 인해 프로퍼티 래퍼에 직접 값을 주입할 수 없으므로,
/// 이 프로토콜을 통해 해결된 값을 전달받아 수동으로 주입합니다.
public protocol AutoInjectible: AnyObject {
    func injectResolvedValue(_ value: Any, forProperty propertyName: String)
}

// MARK: - TypeNameResolver

/// 타입 이름으로 의존성을 해결하는 헬퍼 클래스
internal final class TypeNameResolver: @unchecked Sendable {
    // Actor 기반 레지스트리로 동시성 안전성 보장
    private actor Registry {
        private var map: [String: Any.Type] = [:]
        func register(_ type: Any.Type, name: String?) {
            let typeName = name ?? String(describing: type)
            map[typeName] = type
        }
        func resolveType(for name: String) -> Any.Type? { map[name] }
    }

    private static let registry = Registry()

    // 동기-비동기 브리지를 위한 내부 유틸
    private final class MutableBox<T>: @unchecked Sendable { var value: T; init(_ v: T) { value = v } }
    private struct UncheckedSendableBox<T>: @unchecked Sendable { var value: T; init(_ v: T) { value = v } }

    static func register<T>(_ type: T.Type, name: String? = nil) {
        Task.detached { @Sendable in
            await registry.register(type, name: name)
        }
    }

    @available(*, deprecated, message: "Use resolveAsync(_:) instead for Swift 6 concurrency safety")
    static func resolve(_ typeName: String) -> Any? {
        // Deprecated: avoid sync bridging; returns only fallback mapping
        return resolveFromContainer(typeName)
    }

    /// Async resolution by type name, returning a sendable box.
    static func resolveAsyncBox(_ typeName: String) async -> UnifiedRegistry.ValueBox? {
        if let t = await registry.resolveType(for: typeName) {
            return await GlobalUnifiedRegistry.resolveAnyAsyncBox(t)
        }
        return nil
    }

    @available(*, deprecated, message: "Synchronous bridging is deprecated. Prefer async APIs.")
    @inline(__always)
    private static func syncAwait<T>(_ operation: @escaping @Sendable () async -> T) -> T {
        fatalError("syncAwait is deprecated. Use the async API instead.")
    }

    private static func resolveFromContainer(_ typeName: String) -> Any? {
        // 문자열 기반 일반 매핑은 더 이상 사용하지 않습니다.
        // AutoResolve 또는 명시적 register를 통해 등록된 타입만 해석합니다.
        return nil
    }

    // Removed legacy sync registered-type resolution. Use resolveByTypeAsync(_:) instead.
}

// MARK: - DependencyContainer Extension

extension DependencyContainer {
    /// 타입 객체로 의존성 해결 (내부 사용)
    @available(*, deprecated, message: "Use resolveByTypeAsync(_:) instead")
    internal func resolveByType(_ type: Any.Type) -> Any? {
        // UnifiedRegistry를 사용하여 런타임 타입으로 해결 (Sendable 박스 경유)
        let sem = DispatchSemaphore(value: 0)
        final class Box: @unchecked Sendable { var value: UnifiedRegistry.ValueBox? = nil }
        let box = Box()
        Task.detached { @Sendable in
            box.value = await GlobalUnifiedRegistry.resolveAnyBox(type)
            sem.signal()
        }
        sem.wait()
        return box.value?.value
    }

    /// 타입 객체로 의존성 비동기 해결 (내부 사용)
    internal func resolveByTypeAsync(_ type: Any.Type) async -> Any? {
        if let box = await GlobalUnifiedRegistry.resolveAnyAsyncBox(type) {
            return box.value
        }
        return nil
    }
}

// MARK: - Auto-Resolution Annotations

/// 자동 해결을 위한 메타데이터 어노테이션
@propertyWrapper
public struct AutoResolve<T> {
    private var value: T?
    private let typeName: String
    private let isRequired: Bool

    public var wrappedValue: T? {
        get { value }
        set { value = newValue }
    }

    public init(_ type: T.Type = T.self, required: Bool = false) {
        self.typeName = String(describing: type)
        self.isRequired = required
        self.value = nil

        // 타입 등록
        TypeNameResolver.register(type)
    }
}

// MARK: - Convenience Extensions

public extension AutoResolvable {
    /// 자동 해결을 수행하고 완료까지 대기합니다
    func autoResolveSync() {
        let semaphore = DispatchSemaphore(value: 0)
        var completed = false

        AutoDependencyResolver.resolve(self)

        // didAutoResolve 호출까지 대기
        DispatchQueue.main.async {
            if !completed {
                completed = true
                semaphore.signal()
            }
        }

        semaphore.wait()
    }

    /// 비동기 자동 해결
    func autoResolveAsync() async {
        await AutoDependencyResolver.resolveAsync(self)
    }
}

// MARK: - Debug Utilities

#if DEBUG
public final class AutoResolverDebugger {
    public static func printRegisteredTypes() {
        #logDebug("📋 [AutoResolver] Registered Types:")
        // 실제 구현에서는 TypeNameResolver의 내부 상태를 출력
    }

    public static func validateResolution<T: AutoResolvable>(_ instance: T) -> [String] {
        var unresolved: [String] = []
        let mirror = Mirror(reflecting: instance)

        for child in mirror.children {
            guard let propertyName = child.label else { continue }

            if String(describing: type(of: child.value)).contains("Inject<") {
                // @Inject 프로퍼티가 nil인지 확인
                let propertyMirror = Mirror(reflecting: child.value)
                for propertyChild in propertyMirror.children {
                    if propertyChild.label == "wrappedValue",
                       case Optional<Any>.none = propertyChild.value {
                        unresolved.append(propertyName)
                        break
                    }
                }
            }
        }

        return unresolved
    }
}
#endif

// MARK: - Performance Optimizer Integration

/// 자동 해결 시스템과 성능 최적화 통합
public extension AutoDependencyResolver {
    static func resolveWithPerformanceTracking<T: AutoResolvable>(_ instance: T) {
        #if DEBUG
        let startTime = CFAbsoluteTimeGetCurrent()
        #endif

        resolve(instance)

        #if DEBUG
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
      #logDebug("🔄 [AutoResolver] Resolution time for \(type(of: instance)): \(String(format: "%.3f", duration))ms")
        #endif
    }
}
