//
//  ContainerResgister.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/27/25.
//

import Foundation

// MARK: - ContainerRegister

/// 전역 ``DependencyContainer``에서 의존성을 주입하는 프로퍼티 래퍼입니다.
///
/// `ContainerRegister`는 전역 의존성 컨테이너에서 KeyPath 기반의 의존성 주입을
/// 선언적으로 수행할 수 있도록 하는 프로퍼티 래퍼입니다. 타입 안전성을 보장하며,
/// 기본 팩토리가 제공된 경우 자동 등록 기능을 제공합니다.
///
/// ## 개요
///
/// 이 프로퍼티 래퍼는 전역 컨테이너(`DependencyContainer.live`)에서 KeyPath를
/// 기반으로 의존성을 해결합니다. 의존성이 등록되지 않았고 기본 팩토리가 제공되지
/// 않은 경우, 의존성 구성 문제를 조기에 발견할 수 있도록 애플리케이션을 즉시 종료합니다.
///
/// ### 스레드 안전성
///
/// `DependencyContainer`가 스레드 안전하게 설계되었으므로, `ContainerRegister`는
/// 동시성 컨텍스트에서 안전하게 접근할 수 있습니다. 다만, 의존성들은 동시 접근이
/// 발생하기 전인 애플리케이션 초기화 시점에 등록되어야 합니다.
///
/// ### 자동 등록
///
/// `defaultFactory`와 함께 초기화될 때, `ContainerRegister`는 누락된 의존성을
/// 자동으로 등록할 수 있어서 옵셔널하거나 모킹된 의존성에 대한 폴백 메커니즘을
/// 제공합니다.
///
/// ## 사용법
///
/// ### 기본 의존성 주입
///
/// 먼저 `DependencyContainer`를 확장하여 의존성에 대한 계산 프로퍼티를 제공합니다:
///
/// ```swift
/// extension DependencyContainer {
///     var networkService: NetworkServiceProtocol? {
///         resolve(NetworkServiceProtocol.self)
///     }
///
///     var authRepository: AuthRepositoryProtocol? {
///         resolve(AuthRepositoryProtocol.self)
///     }
/// }
/// ```
///
/// 앱 초기화 중에 의존성을 등록합니다:
///
/// ```swift
/// // 앱의 부트스트랩/설정 단계에서
/// DependencyContainer.live.register(NetworkServiceProtocol.self) {
///     DefaultNetworkService()
/// }
///
/// DependencyContainer.live.register(AuthRepositoryProtocol.self) {
///     DefaultAuthRepository()
/// }
/// ```
///
/// 마지막으로 타입에서 의존성을 주입합니다:
///
/// ```swift
/// final class APIClient {
///     @ContainerRegister(\.networkService)
///     private var networkService: NetworkServiceProtocol
///
///     @ContainerRegister(\.authRepository)
///     private var authRepository: AuthRepositoryProtocol
///
///     func performAuthenticatedRequest() async throws -> Data {
///         let token = try await authRepository.getAccessToken()
///         return try await networkService.request("/api/data", headers: ["Authorization": "Bearer \(token)"])
///     }
/// }
/// ```
///
/// ### 기본 팩토리를 이용한 자동 등록
///
/// 테스트나 개발 환경에서는 기본 구현체를 제공할 수 있습니다:
///
/// ```swift
/// final class TestableService {
///     @ContainerRegister(\.networkService, defaultFactory: { MockNetworkService() })
///     private var networkService: NetworkServiceProtocol
///
///     // 실제 구현체가 등록되지 않은 경우 MockNetworkService를 사용합니다
/// }
/// ```
///
/// ## 주제
///
/// ### 초기화자
/// - ``init(_:)``
/// - ``init(_:defaultFactory:)``
///
/// ### 프로퍼티
/// - ``wrappedValue``
///
@propertyWrapper
public struct ContainerRegister<T: Sendable> {

    // MARK: - 프로퍼티

    /// `DependencyContainer` 내부의 `T?` 프로퍼티를 가리키는 KeyPath입니다.
    private let keyPath: KeyPath<DependencyContainer, T?>

    /// 의존성이 등록되지 않은 경우 기본 인스턴스를 생성하는 옵셔널 팩토리 클로저입니다.
    private let defaultFactory: (() -> T)?

    // MARK: - 초기화자

    /// KeyPath를 사용하여 의존성 주입 프로퍼티 래퍼를 생성합니다.
    ///
    /// 엄격한 의존성 등록 강제를 원할 때 이 초기화자를 사용하세요.
    /// 의존성에 접근할 때 등록되지 않은 경우, 애플리케이션이 fatal error와 함께
    /// 종료됩니다.
    ///
    /// - Parameter keyPath: 주입할 의존성을 나타내는 `DependencyContainer`의
    ///   `T?` 프로퍼티를 가리키는 KeyPath입니다.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// final class UserService {
    ///     @ContainerRegister(\.authRepository)
    ///     private var authRepository: AuthRepositoryProtocol
    ///
    ///     func getCurrentUser() async throws -> User {
    ///         return try await authRepository.getCurrentUser()
    ///     }
    /// }
    /// ```
    public init(_ keyPath: KeyPath<DependencyContainer, T?>) {
        self.keyPath = keyPath
        self.defaultFactory = nil
    }

    /// 자동 등록 폴백 기능을 가진 의존성 주입 프로퍼티 래퍼를 생성합니다.
    ///
    /// 이 초기화자는 컨테이너에서 의존성을 찾을 수 없을 때 자동으로 의존성을
    /// 등록할 수 있도록 하는 안전 메커니즘을 제공합니다. 테스트 시나리오나
    /// 모킹 구현체를 제공하려는 경우에 특히 유용합니다.
    ///
    /// - Parameters:
    ///   - keyPath: `DependencyContainer`의 `T?` 프로퍼티를 가리키는 KeyPath입니다.
    ///   - defaultFactory: 컨테이너에 의존성이 등록되지 않은 경우 `T`의 기본
    ///     인스턴스를 생성하는 클로저입니다.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// final class WeatherService {
    ///     @ContainerRegister(\.locationService, defaultFactory: { MockLocationService() })
    ///     private var locationService: LocationServiceProtocol
    ///
    ///     func getCurrentWeather() async throws -> Weather {
    ///         let location = try await locationService.getCurrentLocation()
    ///         return try await fetchWeather(for: location)
    ///     }
    /// }
    /// ```
    ///
    /// - Important: 기본 팩토리는 의존성이 이미 등록되지 않은 경우에만 호출됩니다.
    ///   한 번 등록된 후(수동 또는 자동 등록)에는 후속 접근에서 등록된 인스턴스를
    ///   사용합니다.
    public init(_ keyPath: KeyPath<DependencyContainer, T?>, defaultFactory: @escaping () -> T) {
        self.keyPath = keyPath
        self.defaultFactory = defaultFactory
    }

    // MARK: - 래핑된 값

    /// 주입된 의존성 인스턴스입니다.
    ///
    /// 이 프로퍼티는 지정된 KeyPath를 사용하여 전역 `DependencyContainer.live`에서
    /// 의존성을 해결합니다. 해결 순서는 다음과 같습니다:
    ///
    /// 1. 등록된 의존성이 있는 경우 반환
    /// 2. 등록되지 않았고 `defaultFactory`가 존재하는 경우, 기본 인스턴스를 생성하고 등록
    /// 3. `defaultFactory`가 제공되지 않은 경우, `fatalError`로 애플리케이션 종료
    ///
    /// - Returns: `T` 타입의 해결된 의존성 인스턴스를 반환합니다.
    ///
    /// - Important: 의존성이 등록되지 않았고 기본 팩토리가 제공되지 않은 상태에서
    ///   이 프로퍼티에 접근하면 애플리케이션이 즉시 종료됩니다. 애플리케이션
    ///   부트스트랩 중에 모든 필수 의존성이 등록되었는지 확인하세요.
    ///
    /// ## 스레드 안전성
    ///
    /// 이 프로퍼티는 하위 `DependencyContainer`의 동시성 큐 구현으로 인해
    /// 스레드 안전합니다. 여러 스레드에서 동일한 의존성에 동시에 안전하게
    /// 접근할 수 있습니다.
    public var wrappedValue: T {
        // 먼저 의존성이 이미 등록되어 있는지 확인
        if let value = DependencyContainer.live[keyPath: keyPath] {
            return value
        }

        // 등록되지 않은 경우, 기본 팩토리 사용 시도
        guard let factory = defaultFactory else {
            fatalError("""
            \(T.self) 타입의 등록된 의존성을 찾을 수 없으며, 기본 팩토리도 제공되지 않았습니다.
            
            사용하기 전에 이 의존성을 등록해 주세요:
            DependencyContainer.live.register(\(T.self).self) { YourImplementation() }
            
            또는 기본 팩토리를 제공해 주세요:
            @ContainerRegister(\\.yourDependency, defaultFactory: { DefaultImplementation() })
            """)
        }

        // 기본 인스턴스를 생성하고 등록
        let instance = factory()
        DependencyContainer.live.register(T.self, instance: instance)

        // 새로 등록된 인스턴스 반환
        guard let registeredValue = DependencyContainer.live[keyPath: keyPath] else {
            fatalError("\(T.self) 의존성 등록에 실패했습니다. 이는 심각한 컨테이너 문제를 나타냅니다.")
        }

        return registeredValue
    }
}
