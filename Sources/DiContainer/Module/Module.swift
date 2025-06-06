//
//  Module.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/19/25.
//

import Foundation

#if swift(>=5.9)
@available(iOS 17.0, *)
/// `Module`는 의존성 주입(Dependency Injection)을 위한 단일 모듈을 나타내는 구조체입니다.
/// 각 `Module` 인스턴스는 특정 타입의 의존성을 `DependencyContainer`에 등록할 수 있는 비동기 클로저(`registrationClosure`)를 래핑합니다.
public struct Module: Sendable {
    // MARK: - 저장 프로퍼티

    /// `registrationClosure`는 비동기 클로저로, 해당 모듈의 의존성을 `DependencyContainer`에 등록하는 작업을 수행합니다.
    private let registrationClosure: @Sendable () async -> Void

    // MARK: - 초기화

    /// 생성자
    ///
    /// - Parameters:
    ///   - type: 등록할 의존성의 타입 (예: `AuthRepositoryProtocol.self`)
    ///   - factory: 해당 타입의 인스턴스를 생성하는 팩토리 클로저
    ///
    /// 이 생성자는 전달받은 타입과 팩토리 클로저를 사용하여,
    /// `DependencyContainer.live`에 의존성을 등록하는 비동기 클로저를 생성하여 `registrationClosure`에 저장합니다.
    public init<T>(
        _ type: T.Type,
        factory: @escaping @Sendable () -> T
    ) {
        self.registrationClosure = {
            // `DependencyContainer.live`에 의존성을 등록합니다.
            // 이때, `factory` 클로저를 전달하여 인스턴스를 생성하고 등록합니다.
            DependencyContainer.live.register(type, build: factory)
        }
    }

    // MARK: - 메서드

    /// `register()` 메서드는 `registrationClosure`를 실행하여, 비동기적으로 의존성을 등록합니다.
    /// 호출 시 `await`를 사용하여 완료될 때까지 대기합니다.
    public func register() async {
        await registrationClosure()
    }
}
#else
/// `Module`는 의존성 주입(Dependency Injection)을 위한 단일 모듈을 나타내는 구조체입니다.
/// 각 `Module` 인스턴스는 특정 타입의 의존성을 `DependencyContainer`에 등록할 수 있는 비동기 클로저(`registrationClosure`)를 래핑합니다.
public struct Module {
    // MARK: - 저장 프로퍼티

    /// `registrationClosure`는 비동기 클로저로, 해당 모듈의 의존성을 `DependencyContainer`에 등록하는 작업을 수행합니다.
    private let registrationClosure: () async -> Void

    // MARK: - 초기화

    /// 생성자
    ///
    /// - Parameters:
    ///   - type: 등록할 의존성의 타입 (예: `AuthRepositoryProtocol.self`)
    ///   - factory: 해당 타입의 인스턴스를 생성하는 팩토리 클로저
    ///
    /// 이 생성자는 전달받은 타입과 팩토리 클로저를 사용하여,
    /// `DependencyContainer.live`에 의존성을 등록하는 비동기 클로저를 생성하여 `registrationClosure`에 저장합니다.
    public init<T>(
        _ type: T.Type,
        factory: @escaping () -> T
    ) {
        self.registrationClosure = {
            DependencyContainer.live.register(type, build: factory)
        }
    }

    // MARK: - 메서드

    /// `register()` 메서드는 `registrationClosure`를 실행하여, 비동기적으로 의존성을 등록합니다.
    /// 호출 시 `await`를 사용하여 완료될 때까지 대기합니다.
    public func register() async {
        await registrationClosure()
    }
}
#endif
