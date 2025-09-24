//
//  PropertyWrappers.swift
//  DiContainer
//
//  Created by Wonji Suh on 2024.
//  Copyright © 2024 Wonji Suh. All rights reserved.
//

import Foundation
import LogMacro

// MARK: - 핵심 Property Wrappers

/// ## 🔧 @Inject - 기본 의존성 주입
///
/// 가장 많이 사용하는 기본 의존성 주입 Property Wrapper입니다.
/// 옵셔널과 필수 타입을 모두 지원합니다.
///
/// ### 사용법:
/// ```swift
/// class UserViewController {
///     @Inject var repository: UserRepository?    // 옵셔널 - 없어도 됨
///     @Inject var logger: Logger                 // 필수 - 반드시 있어야 함
///     @Inject(\.customService) var custom: CustomService?  // KeyPath 사용
/// }
/// ```
@propertyWrapper
public struct Inject<T> {

    // MARK: - Properties

    private let keyPath: KeyPath<DependencyContainer, T?>?
    private let type: T.Type

    // MARK: - Initialization

    /// KeyPath를 사용한 초기화
    /// - Parameter keyPath: DependencyContainer의 KeyPath
    public init(_ keyPath: KeyPath<DependencyContainer, T?>) {
        self.keyPath = keyPath
        self.type = T.self
    }

    /// 타입 추론을 사용한 기본 초기화
    public init() {
        self.keyPath = nil
        self.type = T.self
    }

    /// 명시적 타입을 사용한 초기화
    /// - Parameter type: 주입받을 타입
    public init(_ type: T.Type) {
        self.keyPath = nil
        self.type = type
    }

    // MARK: - Property Wrapper Implementation

    /// 옵셔널 타입용 wrappedValue
    /// 의존성이 없어도 nil을 반환하므로 안전합니다.
    public var wrappedValue: T? {
        if let keyPath = keyPath {
            return DependencyContainer.live[keyPath: keyPath]
        }
        return DependencyContainer.live.resolve(type)
    }
}

// MARK: - Non-Optional Type Support

extension Inject where T: AnyObject {
    /// Non-optional 타입용 wrappedValue
    /// 의존성이 반드시 있어야 하며, 없으면 명확한 에러와 함께 앱이 종료됩니다.
    public var wrappedValue: T {
        if let keyPath = keyPath {
            guard let resolved = DependencyContainer.live[keyPath: keyPath] else {
                fatalError("""
                🚨 [Inject] 필수 의존성을 찾을 수 없습니다!

                KeyPath: \(keyPath)
                타입: \(T.self)

                💡 해결방법:
                   UnifiedDI.register(\\.keyPath) { YourImplementation() }
                """)
            }
            return resolved
        }

        guard let resolved = DependencyContainer.live.resolve(type) else {
            fatalError("""
            🚨 [Inject] 필수 의존성을 찾을 수 없습니다!

            타입: \(type)

            💡 해결방법:
               UnifiedDI.register(\(type).self) { YourImplementation() }
            """)
        }
        return resolved
    }
}

/// ## 🏭 @Factory - 팩토리 패턴 주입
///
/// 매번 새로운 인스턴스를 생성하는 팩토리 패턴 Property Wrapper입니다.
/// 상태를 공유하지 않는 독립적인 객체가 필요할 때 사용합니다.
///
/// ### 사용법:
/// ```swift
/// class ReportService {
///     @Factory var pdfGenerator: PDFGenerator          // 매번 새 인스턴스
///     @Factory(\.emailSender) var email: EmailSender   // KeyPath로 팩토리
/// }
/// ```
@propertyWrapper
public struct Factory<T> {

    // MARK: - Properties

    private let keyPath: KeyPath<DependencyContainer, T?>?
    private let directFactory: (() -> T)?

    // MARK: - Initialization

    /// KeyPath를 사용한 팩토리 초기화
    /// - Parameter keyPath: 팩토리가 등록된 KeyPath
    public init(_ keyPath: KeyPath<DependencyContainer, T?>) {
        self.keyPath = keyPath
        self.directFactory = nil
    }

    /// 직접 팩토리 함수를 제공하는 초기화
    /// - Parameter factory: 인스턴스를 생성하는 클로저
    public init(factory: @escaping () -> T) {
        self.keyPath = nil
        self.directFactory = factory
    }

    // MARK: - Property Wrapper Implementation

    /// 매번 새로운 인스턴스를 반환합니다
    public var wrappedValue: T {
        // 직접 팩토리가 있으면 실행
        if let factory = directFactory {
            return factory()
        }

        // KeyPath를 통한 팩토리 실행
        if let keyPath = keyPath {
            guard let instance = DependencyContainer.live[keyPath: keyPath] else {
                fatalError("""
                🚨 [Factory] 팩토리를 찾을 수 없습니다!

                KeyPath: \(keyPath)
                타입: \(T.self)

                💡 해결방법:
                   UnifiedDI.register(\\.keyPath) { YourImplementation() }
                """)
            }
            return instance
        }

        fatalError("🚨 [Factory] 잘못된 설정입니다. KeyPath 또는 직접 팩토리가 필요합니다.")
    }
}

/// ## 🛡️ @SafeInject - 안전한 의존성 주입
///
/// fatalError 대신 에러를 던지는 안전한 의존성 주입 Property Wrapper입니다.
/// 프로덕션 환경에서 앱이 크래시되지 않도록 안전하게 처리할 수 있습니다.
///
/// ### 사용법:
/// ```swift
/// class UserService {
///     @SafeInject var apiClient: APIClient?
///
///     func loadData() {
///         do {
///             let client = try apiClient.getValue()
///             // 안전하게 사용
///         } catch {
///             // 에러 처리
///             print("API 클라이언트를 로드할 수 없습니다: \(error)")
///         }
///     }
/// }
/// ```
@propertyWrapper
public struct SafeInject<T> {

    // MARK: - Properties

    private let keyPath: KeyPath<DependencyContainer, T?>?
    private let type: T.Type
    private var cachedValue: T?

    // MARK: - Initialization

    /// KeyPath를 사용한 안전한 초기화
    /// - Parameter keyPath: DependencyContainer의 KeyPath
    public init(_ keyPath: KeyPath<DependencyContainer, T?>) {
        self.keyPath = keyPath
        self.type = T.self
    }

    /// 타입 추론을 사용한 기본 초기화
    public init() {
        self.keyPath = nil
        self.type = T.self
    }

    /// 명시적 타입을 사용한 초기화
    /// - Parameter type: 주입받을 타입
    public init(_ type: T.Type) {
        self.keyPath = nil
        self.type = type
    }

    // MARK: - Property Wrapper Implementation

    /// 안전한 결과를 반환합니다 (성공 또는 에러)
    public var wrappedValue: SafeInjectResult<T> {
        mutating get {
            do {
                let value = try getValue()
                return .success(value)
            } catch {
                return .failure(error as? SafeInjectError ?? .unknown(error))
            }
        }
    }

    /// 값을 안전하게 가져옵니다 (throws)
    /// - Returns: 해결된 의존성
    /// - Throws: SafeInjectError
    public mutating func getValue() throws -> T {
        // 캐시된 값이 있으면 반환
        if let cached = cachedValue {
            return cached
        }

        let resolved: T?

        if let keyPath = keyPath {
            resolved = DependencyContainer.live[keyPath: keyPath]
        } else {
            resolved = DependencyContainer.live.resolve(type)
        }

        guard let value = resolved else {
            throw SafeInjectError.dependencyNotFound(type: String(describing: type))
        }

        self.cachedValue = value
        return value
    }
}

// MARK: - Supporting Types

/// 안전한 주입 결과
public enum SafeInjectResult<T> {
    case success(T)
    case failure(SafeInjectError)

    /// 값을 안전하게 추출
    public func get() throws -> T {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }

    /// nil 허용 값 추출
    public var value: T? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
}

/// 안전한 주입 에러
public enum SafeInjectError: Error, LocalizedError {
    case dependencyNotFound(type: String)
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .dependencyNotFound(let type):
            return "의존성을 찾을 수 없습니다: \(type)"
        case .unknown(let error):
            return "알 수 없는 에러: \(error.localizedDescription)"
        }
    }
}

// MARK: - 편의 확장

public extension SafeInjectResult {

    /// 성공한 경우에만 실행
    func onSuccess(_ action: (T) throws -> Void) rethrows {
        if case .success(let value) = self {
            try action(value)
        }
    }

    /// 실패한 경우에만 실행
    func onFailure(_ action: (SafeInjectError) throws -> Void) rethrows {
        if case .failure(let error) = self {
            try action(error)
        }
    }

    /// 값 변환
    func map<U>(_ transform: (T) throws -> U) rethrows -> SafeInjectResult<U> {
        switch self {
        case .success(let value):
            return .success(try transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }
}

// MARK: - 레거시 호환성

/// 기존 코드와의 호환성을 위한 타입 별칭들
public typealias InjectOptional<T> = Inject<T>
public typealias InjectRequired<T> = Inject<T>
public typealias RequiredInject<T> = Inject<T>