//
//  RegistrationAPI.swift
//  DiContainer
//
//  Created by Wonji Suh on 9/24/25.
//

import Foundation
import LogMacro

// MARK: - RegisterAndReturn

/// 등록과 동시에 값을 반환하는 KeyPath 기반 시스템
public enum RegisterAndReturn {

    @discardableResult
    public static func register<T: Sendable>(
        _ keyPath: KeyPath<WeaveDI.Container, T?>,
        factory: @escaping @Sendable () -> T,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) -> T {
        let keyPathName = extractKeyPathName(keyPath)
        #logInfo("📝 [RegisterAndReturn] Registering and returning \(keyPathName) -> \(T.self)")

        let instance = factory()
        #logInfo("✅ [RegisterAndReturn] Created instance for \(keyPathName): \(type(of: instance))")

        _ = DI.register(T.self) { instance }
        return instance
    }

    @discardableResult
    public static func registerAsync<T: Sendable>(
        _ keyPath: KeyPath<WeaveDI.Container, T?>,
        factory: @escaping @Sendable () async -> T,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) async -> T {
        let keyPathName = extractKeyPathName(keyPath)
        #logInfo("🔄 [RegisterAndReturn] Async registering and returning \(keyPathName) -> \(T.self)")

        let instance = await factory()
        #logInfo("✅ [RegisterAndReturn] Created async instance for \(keyPathName): \(type(of: instance))")

        _ = DI.register(T.self) { instance }
        return instance
    }

    public static func extractKeyPathName<T>(_ keyPath: KeyPath<WeaveDI.Container, T?>) -> String {
        let keyPathString = String(describing: keyPath)
        if let dotIndex = keyPathString.lastIndex(of: ".") {
            let propertyName = String(keyPathString[keyPathString.index(after: dotIndex)...])
            return propertyName
        }
        return keyPathString
    }

    public static func isRegistered<T>(_ keyPath: KeyPath<WeaveDI.Container, T?>) -> Bool {
        return WeaveDI.Container.live.resolve(T.self) != nil
    }
}

// MARK: - RegistrationToken

/// 의존성 등록을 추적하고 자동으로 해제할 수 있는 토큰입니다.
public final class RegistrationToken: @unchecked Sendable {

    private var releaseHandler: (() -> Void)?
    private let typeName: String
    private let registrationTime: Date
    private var isCancelled: Bool = false
    private var cancellationTime: Date?

    internal init(typeName: String, releaseHandler: @escaping () -> Void) {
        self.typeName = typeName
        self.releaseHandler = releaseHandler
        self.registrationTime = Date()

        #if DEBUG
        #logDebug("🔗 [RegistrationToken] Created for \(typeName) at \(registrationTime)")
        #endif
    }

    deinit {
        if !isCancelled {
            #if DEBUG
            #logDebug("♻️  [RegistrationToken] Auto-releasing \(typeName) on deinit")
            #endif
            releaseHandler?()
        }
    }

    public func cancel() {
        guard !isCancelled else {
            #if DEBUG
            #logError("⚠️ [RegistrationToken] Already cancelled: \(typeName)")
            #endif
            return
        }

        isCancelled = true
        cancellationTime = Date()

        #if DEBUG
        #logDebug("🚫 [RegistrationToken] Manually cancelled \(typeName) at \(cancellationTime!)")
        #endif

        releaseHandler?()
        releaseHandler = nil
    }

    public var isValid: Bool {
        return !isCancelled && releaseHandler != nil
    }

    public var registeredTypeName: String {
        return typeName
    }

    public var registeredAt: Date {
        return registrationTime
    }

    public var cancelledAt: Date? {
        return cancellationTime
    }
}

// MARK: - RegisterModuleError

public enum RegisterModuleError: Error, LocalizedError, CustomStringConvertible {
    case typeCastFailure(from: String, to: String, reason: String? = nil)
    case dependencyResolutionFailure(type: String, reason: String? = nil)
    case circularDependency(involved: [String])
    case factoryExecutionError(type: String, underlyingError: Error)
    case configurationError(message: String)

    public var errorDescription: String? {
        return description
    }

    public var description: String {
        switch self {
        case .typeCastFailure(let from, let to, let reason):
            let reasonText = reason.map { " Reason: \($0)" } ?? ""
            return "타입 캐스팅 실패: \(from) -> \(to)로 변환할 수 없습니다.\(reasonText)"
        case .dependencyResolutionFailure(let type, let reason):
            let reasonText = reason.map { " Reason: \($0)" } ?? ""
            return "의존성 해결 실패: \(type) 타입을 해결할 수 없습니다.\(reasonText)"
        case .circularDependency(let involved):
            return "순환 의존성 감지: \(involved.joined(separator: " -> "))"
        case .factoryExecutionError(let type, let underlyingError):
            return "팩토리 실행 오류: \(type) 생성 중 오류 발생 - \(underlyingError.localizedDescription)"
        case .configurationError(let message):
            return "설정 오류: \(message)"
        }
    }
}

public typealias RegisterModuleResult<T> = Result<T, RegisterModuleError>

// MARK: - Safe Registration Functions

public extension RegisterModule {

    /// 타입 안전한 의존성 생성 (컴파일 타임 체크 권장)
    func makeTypeSafeDependency<T>(
        _ protocolType: T.Type,
        factory: @Sendable @escaping () -> T
    ) -> @Sendable () -> Module where T: Sendable {
        return {
            self.makeModule(protocolType, factory: factory)
        }
    }

    /// 기존 makeDependency를 유지하되 더 안전하게 개선
    func makeDependencyImproved<T, U>(
        _ protocolType: T.Type,
        factory: @Sendable @escaping () -> U
    ) -> @Sendable () -> Module where T: Sendable {
        return {
            self.makeModule(protocolType) {
                let instance = factory()

                guard let dependency = instance as? T else {
                    let error = RegisterModuleError.typeCastFailure(
                        from: String(describing: U.self),
                        to: String(describing: T.self),
                        reason: "The factory produces \(type(of: instance)) which cannot be cast to \(T.self)"
                    )

                    #if DEBUG
                    preconditionFailure(error.description)
                    #else
                    fatalError(error.description)
                    #endif
                }

                return dependency
            }
        }
    }
}

// MARK: - DI Extension for Token Support

public extension WeaveDI {

    static func registerWithToken<T>(
        _ type: T.Type,
        factory: @escaping @Sendable () -> T
    ) -> RegistrationToken where T: Sendable {
        let releaseHandler = WeaveDI.Container.live.register(type, build: factory)
        let typeName = String(describing: type)
        return RegistrationToken(typeName: typeName, releaseHandler: releaseHandler)
    }

}
