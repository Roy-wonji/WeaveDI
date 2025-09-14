//
//  DependencyContainer.swift
//  DiContainer
//
//  Created by 서원지 on 6/8/24.
//

import Foundation
import LogMacro
import Combine

// MARK: - DependencyContainer

/// ## 개요
///
/// `DependencyContainer`는 Swift 애플리케이션에서 의존성 주입(Dependency Injection)을
/// 관리하기 위한 스레드 안전한 컨테이너입니다. 이 컨테이너는 타입 기반의 의존성 등록과
/// 조회를 제공하며, Swift Concurrency와 완벽하게 호환됩니다.
///
/// ## 핵심 특징
///
/// ### 🔒 스레드 안전성
/// - **동시성 큐**: `DispatchQueue(attributes: .concurrent)`를 사용하여 읽기 작업 최적화
/// - **배리어 플래그**: 쓰기 작업 시 `.barrier` 플래그로 스레드 안전성 보장
/// - **다중 스레드 지원**: 여러 스레드에서 동시에 안전하게 접근 가능
///
/// ### 📝 타입 기반 등록 시스템
/// - **키 생성**: `String(describing: Type.self)`를 통한 타입별 고유 키 생성
/// - **팩토리 패턴**: 지연 생성을 통한 메모리 효율성
/// - **인스턴스 등록**: 이미 생성된 객체의 직접 등록 지원
///
/// ### 🚀 생명 주기 관리
/// - **부트스트랩**: 앱 시작 시 의존성 초기화
/// - **런타임 업데이트**: 실행 중 의존성 교체 및 업데이트
/// - **정리**: 메모리 누수 방지를 위한 등록 해제 기능
public final class DependencyContainer: @unchecked Sendable, ObservableObject {

    // MARK: - Stored Properties

    /// 타입 안전한 의존성 저장소입니다.
    /// 기존 String 키 방식 대신 타입 안전한 키를 사용합니다.
    private let typeSafeRegistry = TypeSafeRegistry()

    // NOTE: 동기화는 TypeSafeRegistry가 담당하므로 별도의 GCD 큐는 사용하지 않습니다.

    // MARK: - Init

    /// 빈 컨테이너를 생성합니다.
    public init() {}

    // MARK: - Register

    /// 주어진 타입의 의존성을 팩토리 클로저로 등록합니다.
    ///
    /// 이 메서드는 지연 생성(lazy creation) 패턴을 사용하여 의존성을 등록합니다.
    /// 팩토리 클로저는 실제로 `resolve(_:)` 호출 시에만 실행되어 메모리 효율성을 제공합니다.
    @discardableResult
    public func register<T>(
        _ type: T.Type,
        build: @Sendable @escaping () -> T
    ) -> @Sendable () -> Void {
        // 타입 안전한 레지스트리 사용
        let releaseHandler = typeSafeRegistry.register(type, factory: build)

        Log.debug("Registered (TypeSafe)", String(describing: type))

        // 통합 레지스트리에도 동기 팩토리 등록 (비차단)
        Task.detached { @Sendable in
            await GlobalUnifiedRegistry.register(type, factory: build)
        }

        return releaseHandler
    }

    // MARK: - Resolve

    /// 주어진 타입의 의존성을 조회하여 인스턴스를 반환합니다.
    ///
    /// 이 메서드는 컨테이너에 등록된 팩토리 클로저를 실행하여 인스턴스를 생성합니다.
    /// 팩토리 패턴으로 등록된 경우 매번 새로운 인스턴스가 생성되며,
    /// 인스턴스로 등록된 경우 동일한 객체가 반환됩니다.
    public func resolve<T>(_ type: T.Type) -> T? {
        // 타입 안전한 레지스트리에서 조회
        if let result = typeSafeRegistry.resolve(type) {
            Log.debug("Resolved (TypeSafe)", String(describing: type))
            return result
        }

        Log.error("No registered dependency found for \(String(describing: T.self))")
        return nil
    }

    /// 주어진 타입의 의존성을 조회하거나, 없으면 **기본값**을 반환합니다.
    ///
    /// - Parameters:
    ///   - type: 조회할 타입
    ///   - defaultValue: 없을 때 사용할 기본값(지연 생성)
    /// - Returns: 등록 결과 또는 기본값
    public func resolveOrDefault<T>(
        _ type: T.Type,
        default defaultValue: @autoclosure () -> T
    ) -> T {
        resolve(type) ?? defaultValue()
    }

    // MARK: - Release

    /// 특정 타입의 의존성 등록을 **해제**합니다.
    ///
    /// - Parameter type: 해제할 타입
    /// - Note: 등록 시 반환된 클로저를 호출한 것과 동일합니다.
    public func release<T>(_ type: T.Type) {
        // 타입 안전한 레지스트리에서 해제
        typeSafeRegistry.release(type)
        Log.debug("Released", String(describing: type))

        // 통합 레지스트리에서도 해제 (비차단)
        Task.detached { @Sendable in
            await GlobalUnifiedRegistry.release(type)
        }
    }

    // MARK: - KeyPath-based Access

    /// KeyPath 기반 의존성 조회 서브스크립트입니다.
    ///
    /// - Parameter keyPath: `DependencyContainer`의 `T?`를 가리키는 키패스
    /// - Returns: `resolve(T.self)` 결과
    /// - Important: 내부적으로 타입 기반 레지스트리를 사용하므로
    ///   실제 저장 프로퍼티가 없어도 동작합니다.
    public subscript<T>(keyPath: KeyPath<DependencyContainer, T?>) -> T? {
        get { resolve(T.self) }
    }

    // MARK: - Register Instance

    /// 이미 생성된 **인스턴스**를 등록합니다.
    ///
    /// - Parameters:
    ///   - type: 등록할 타입
    ///   - instance: 등록할 인스턴스
    /// - Note: 이후 ``resolve(_:)``는 항상 이 인스턴스를 반환합니다.
    public func register<T>(
        _ type: T.Type,
        instance: T
    ) {
        // 타입 안전한 레지스트리에 인스턴스 등록
        typeSafeRegistry.register(type, instance: instance)
        Log.debug("Registered instance (TypeSafe) for", String(describing: type))

        // 통합 레지스트리에 싱글톤으로도 등록 (비차단)
        let boxed = unsafeSendable(instance)
        Task.detached { @Sendable in
            await GlobalUnifiedRegistry.registerSingleton(type, instance: boxed.value)
        }
    }
}
