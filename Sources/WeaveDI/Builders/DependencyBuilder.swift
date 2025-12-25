//
//  DependencyBuilder.swift
//  WeaveDI
//
//  Created by AI Assistant on 2024.
//  SwiftUI-Style Result Builder for Declarative Dependency Registration
//

import Foundation

// MARK: - Result Builder

/// 🎨 **SwiftUI 스타일 Result Builder**
///
/// SwiftUI의 ViewBuilder처럼 선언적으로 의존성을 등록할 수 있습니다.
///
/// ### 사용법:
/// ```swift
/// @DependencyConfiguration
/// var appDependencies {
///     UserServiceImpl()           // UserService로 자동 등록
///     RepositoryImpl()            // Repository로 자동 등록
///     if isDebug {
///         DebugLogger()           // 조건부 등록
///     } else {
///         ProductionLogger()
///     }
/// }
/// ```
@resultBuilder
public struct DependencyBuilder {

    // MARK: - Basic Building Blocks

    /// 단일 의존성 빌딩
    public static func buildBlock<T: Sendable>(_ dependency: T) -> [DependencyRegistration] {
        [TypedDependency(dependency)]
    }

    /// 여러 의존성 빌딩
    public static func buildBlock(_ dependencies: DependencyRegistration...) -> [DependencyRegistration] {
        dependencies
    }

    /// 배열 의존성 빌딩
    public static func buildArray(_ components: [[DependencyRegistration]]) -> [DependencyRegistration] {
        components.flatMap { $0 }
    }

    // MARK: - Conditional Building

    /// 조건부 의존성 (if 문 지원)
    public static func buildOptional(_ component: [DependencyRegistration]?) -> [DependencyRegistration] {
        component ?? []
    }

    /// 조건부 의존성 (if-else 문 지원)
    public static func buildEither(first component: [DependencyRegistration]) -> [DependencyRegistration] {
        component
    }

    /// 조건부 의존성 (if-else 문 지원)
    public static func buildEither(second component: [DependencyRegistration]) -> [DependencyRegistration] {
        component
    }

    // MARK: - Expression Building

    /// 단일 인스턴스를 DependencyRegistration으로 변환
    public static func buildExpression<T: Sendable>(_ expression: T) -> DependencyRegistration {
        TypedDependency(expression)
    }

    /// 이미 DependencyRegistration인 경우 그대로 반환
    public static func buildExpression(_ expression: DependencyRegistration) -> DependencyRegistration {
        expression
    }
}

// MARK: - Dependency Registration Protocol

/// 의존성 등록을 위한 프로토콜
public protocol DependencyRegistration: Sendable {
    /// 의존성을 실제로 등록하는 메서드
    func register()
}

// MARK: - Typed Dependency Implementation

/// 타입이 지정된 의존성 구현체
public struct TypedDependency<T: Sendable>: DependencyRegistration, Sendable {
    private let instance: T
    private let type: T.Type

    /// 인스턴스로 초기화
    public init(_ instance: T) {
        self.instance = instance
        self.type = T.self
    }

    /// 실제 등록 수행
    public func register() {
        _ = WeaveDI.register { self.instance }
    }
}

// MARK: - Property Wrapper for Configuration

/// 🎨 **@DependencyConfiguration Property Wrapper**
///
/// SwiftUI의 @ViewBuilder처럼 의존성 설정을 선언적으로 관리합니다.
///
/// ### 사용법:
/// ```swift
/// @DependencyConfiguration
/// var appDependencies {
///     UserServiceImpl()
///     RepositoryImpl()
///     if ProcessInfo.processInfo.environment["DEBUG"] != nil {
///         DebugLogger() as Logger
///     } else {
///         ProductionLogger() as Logger
///     }
/// }
///
/// // 등록 실행
/// appDependencies.configure()
/// ```
@propertyWrapper
public struct DependencyConfiguration {
    private let builder: () -> [DependencyRegistration]

    /// Result Builder를 사용한 초기화
    public init(@DependencyBuilder _ builder: @escaping () -> [DependencyRegistration]) {
        self.builder = builder
    }

    /// 의존성 목록 반환
    public var wrappedValue: [DependencyRegistration] {
        builder()
    }

    /// 🚀 **모든 의존성을 실제로 등록**
    ///
    /// 이 메서드를 호출하면 선언된 모든 의존성이 WeaveDI에 등록됩니다.
    public func configure() {
        let dependencies = builder()
        for dependency in dependencies {
            dependency.register()
        }
    }
}

// MARK: - Environment-based Configuration

/// 🌍 **환경별 의존성 설정**
///
/// 개발/테스트/프로덕션 환경에 따라 다른 구현체를 자동으로 선택합니다.
public struct DependencyEnvironment: Sendable {
    private let dependencies: [DependencyRegistration]

    /// Result Builder를 사용한 환경별 설정
    public init(@DependencyBuilder _ builder: () -> [DependencyRegistration]) {
        self.dependencies = builder()
    }

    /// 환경별 설정을 실제로 등록
    public func configure() {
        for dependency in dependencies {
            dependency.register()
        }
    }
}

// MARK: - Predefined Environments

public extension DependencyEnvironment {

    /// 🏭 **프로덕션 환경 설정**
    ///
    /// 실제 구현체들을 등록합니다.
    static func production(@DependencyBuilder _ builder: () -> [DependencyRegistration]) -> DependencyEnvironment {
        DependencyEnvironment(builder)
    }

    /// 🧪 **개발 환경 설정**
    ///
    /// Mock 객체와 디버그 도구들을 등록합니다.
    static func development(@DependencyBuilder _ builder: () -> [DependencyRegistration]) -> DependencyEnvironment {
        DependencyEnvironment(builder)
    }

    /// 🔬 **테스트 환경 설정**
    ///
    /// 모든 Mock 객체들을 등록합니다.
    static func testing(@DependencyBuilder _ builder: () -> [DependencyRegistration]) -> DependencyEnvironment {
        DependencyEnvironment(builder)
    }

    /// 📱 **SwiftUI 프리뷰 환경 설정**
    ///
    /// 프리뷰에서 사용할 Mock 객체들을 등록합니다.
    static func preview(@DependencyBuilder _ builder: () -> [DependencyRegistration]) -> DependencyEnvironment {
        DependencyEnvironment(builder)
    }
}

// MARK: - Convenience Extensions

public extension DependencyRegistration {
    /// 스코프를 지정하여 등록
    func scoped(_ scope: ProvideScope) -> DependencyRegistration {
        return ScopedDependency(base: self, scope: scope)
    }
}

/// 스코프가 지정된 의존성
private struct ScopedDependency: DependencyRegistration {
    let base: DependencyRegistration
    let scope: ProvideScope

    func register() {
        // TODO: 스코프 지원 구현
        base.register()
    }
}

// MARK: - 사용 예시 주석

/*

 ## 🎨 사용 예시

 ### 1. 기본 선언적 등록

 ```swift
 @DependencyConfiguration
 var appDependencies {
     UserServiceImpl()        // UserService로 자동 등록
     RepositoryImpl()         // Repository로 자동 등록
     NetworkClient()          // NetworkClient로 자동 등록
 }

 // 앱 시작 시
 appDependencies.configure()
 ```

 ### 2. 조건부 등록

 ```swift
 @DependencyConfiguration
 var appDependencies {
     UserServiceImpl()

     // 환경에 따른 조건부 등록
     if ProcessInfo.processInfo.environment["DEBUG"] != nil {
         DebugLogger() as Logger
         MockPaymentService() as PaymentService
     } else {
         ProductionLogger() as Logger
         RealPaymentService() as PaymentService
     }

     // 플랫폼별 조건부 등록
     #if os(iOS)
     IOSSpecificService()
     #elseif os(macOS)
     MacOSSpecificService()
     #endif
 }
 ```

 ### 3. 환경별 설정

 ```swift
 // 프로덕션 환경
 let productionDeps = DependencyEnvironment.production {
     UserServiceImpl()
     ProductionLogger() as Logger
     RealNetworkClient() as NetworkClient
 }

 // 개발 환경
 let developmentDeps = DependencyEnvironment.development {
     UserServiceImpl()
     ConsoleLogger() as Logger
     MockNetworkClient() as NetworkClient
 }

 // 환경에 따라 선택
 #if DEBUG
 developmentDeps.configure()
 #else
 productionDeps.configure()
 #endif
 ```

 ### 4. SwiftUI 통합

 ```swift
 struct ContentView: View {
     @Injected var userService: UserService
     @Injected var logger: Logger

     var body: some View {
         Text("Hello WeaveDI!")
     }
 }

 #Preview {
     // 프리뷰용 의존성 설정
     DependencyEnvironment.preview {
         MockUserService() as UserService
         NoOpLogger() as Logger
     }.configure()

     return ContentView()
 }
 ```

 */