//
//  NeedleStyleComponents.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/24/25.
//

import Foundation

// MARK: - Needle Style Components

/// Needle 스타일의 Dependency 프로토콜입니다.
/// 
/// 이 프로토콜은 상위 스코프에서 제공받을 의존성들을 정의합니다.
/// Needle의 핵심 개념 중 하나로, 계층적 의존성 구조를 명시적으로 표현합니다.
public protocol Dependency {
    // Marker protocol - 실제 의존성들은 이를 상속하여 정의
}

/// Needle 스타일의 Component 기반 클래스입니다.
/// 
/// ## Needle의 핵심 개념:
/// - **Component**: 의존성 스코프를 정의하는 단위
/// - **Dependency**: 상위 스코프에서 받아올 의존성들
/// - **Hierarchical**: 계층적 구조로 의존성 관리
/// 
/// ## 사용 방법:
/// ```swift
/// // 1. Dependency 프로토콜 정의
/// protocol MyDependency: Dependency {
///     var networkService: NetworkServiceProtocol { get }
///     var logger: LoggerProtocol { get }
/// }
/// 
/// // 2. Component 구현
/// class MyComponent: Component<MyDependency> {
///     var userService: UserServiceProtocol {
///         return UserServiceImpl(
///             networkService: dependency.networkService,
///             logger: dependency.logger
///         )
///     }
/// }
/// ```
open class Component<DependencyType: Dependency> {
    
    /// 상위 스코프에서 주입받은 의존성들
    public let dependency: DependencyType
    
    /// RegisterModule 인스턴스 (기존 코드와의 호환성)
    public let registerModule = RegisterModule()
    
    /// 초기화자
    /// - Parameter dependency: 상위 스코프에서 주입받을 의존성
    public init(dependency: DependencyType) {
        self.dependency = dependency
    }
    
    /// 이 컴포넌트에서 생성할 모든 모듈들을 반환합니다.
    /// 
    /// 서브클래스에서 오버라이드하여 실제 모듈들을 정의해야 합니다.
    open func makeAllModules() -> [Module] {
        return []
    }
    
    /// 컴포넌트를 DI 컨테이너에 등록합니다.
    public func register(in container: Container) async {
        for module in makeAllModules() {
            await container.register(module)
        }
    }
}

// MARK: - Root Component

/// 루트 수준의 컴포넌트를 위한 특별한 Dependency입니다.
/// 
/// 최상위 컴포넌트는 외부 의존성이 없으므로 이 타입을 사용합니다.
public struct RootDependency: Dependency {
    public init() {}
}

/// 루트 컴포넌트 기반 클래스입니다.
/// 
/// 애플리케이션의 최상위 의존성 스코프를 정의할 때 사용합니다.
open class RootComponent: Component<RootDependency> {
    
    public init() {
        super.init(dependency: RootDependency())
    }
}

// MARK: - Convenient Component Builders

/// 컴포넌트들을 간편하게 등록할 수 있는 빌더입니다.
public struct NeedleComponentBuilder {
    
    private var components: [any NeedleComponentProtocol] = []
    
    public init() {}
    
    /// 컴포넌트를 추가합니다.
    public mutating func add<T: Dependency>(_ component: Component<T>) {
        components.append(ComponentWrapper(component))
    }
    
    /// 모든 컴포넌트를 DI 컨테이너에 등록합니다.
    public func register(in container: Container) async {
        for component in components {
            await component.register(in: container)
        }
    }
}

/// 타입 소거를 위한 ComponentProtocol
private protocol NeedleComponentProtocol {
    func register(in container: Container) async
    func makeModule() -> Module
}

/// Component를 래핑하는 구조체
private struct ComponentWrapper<T: Dependency>: NeedleComponentProtocol {
    let component: Component<T>
    
    init(_ component: Component<T>) {
        self.component = component
    }
    
    func register(in container: Container) async {
        await component.register(in: container)
    }

    func makeModule() -> Module {
        let modules = component.makeAllModules()
        // 첫 번째 모듈을 반환하거나, 필요에 따라 로직 수정
        return modules.first ?? Module(Any.self, factory: { () as Any })
    }
}

// MARK: - RegisterModule Integration

public extension RegisterModule {
    
    /// Needle 스타일 컴포넌트를 RegisterModule과 통합하는 메서드입니다.
    /// 
    /// - Parameter component: 등록할 컴포넌트
    /// - Returns: 컴포넌트의 모든 모듈을 생성하는 클로저 배열
    func makeComponentModules<T: Dependency>(_ component: Component<T>) -> [() -> Module] {
        let modules = component.makeAllModules()
        return modules.map { module in
            return { module }
        }
    }
    
    /// 여러 컴포넌트를 한번에 통합하는 메서드입니다.
    ///
    /// - Parameter components: 등록할 컴포넌트들
    /// - Returns: 모든 컴포넌트의 모듈을 생성하는 클로저 배열
    fileprivate func makeMultipleComponentModules(_ components: [any NeedleComponentProtocol]) -> [() -> Module] {
        return components.map { component in
            // 타입 안전성 개선: 각 컴포넌트의 makeModule 메서드 사용
            return {
                component.makeModule()
            }
        }
    }
}

// MARK: - 실제 사용 예시

/// 네트워크 관련 의존성을 정의하는 Dependency
public protocol NetworkDependency: Dependency {
    // 이 스코프는 외부 의존성이 없음
}



