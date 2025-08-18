//
//  DIContainer.swift
//  DiContainer
//
//  Created by 서원지 on 6/8/24.
//

import Foundation
import LogMacro
import Combine

// MARK: - DependencyContainer

/// 애플리케이션 전반에서 **의존성을 등록·조회·해제**할 수 있는 싱글턴 DI 컨테이너.
///
/// # 개요
/// - 의존성을 `String`(타입 이름) 키로 관리합니다.
/// - thread-safe 하도록 **concurrent `DispatchQueue` + `.barrier`** 를 이용해 동기화합니다.
/// - `@ObservableObject`를 채택하여 외부에서 변경을 감지할 수 있습니다.
///
/// ## 동시성
/// - 의존성 레지스트리는 `DispatchQueue`로 보호됩니다.
///   - 읽기: `sync`
///   - 쓰기: `async(flags: .barrier)`
/// - 따라서 다중 스레드 환경에서도 안전하게 등록/조회/해제가 가능합니다.
///
/// ## Example
///
/// ### 의존성 등록 & 조회
/// ```swift
/// protocol UserRepositoryProtocol {
///     func fetchUser(id: String) -> String
/// }
///
/// struct DefaultUserRepository: UserRepositoryProtocol {
///     func fetchUser(id: String) -> String { "User(\(id))" }
/// }
///
/// // 등록
/// DependencyContainer.live.register(UserRepositoryProtocol.self) {
///     DefaultUserRepository()
/// }
///
/// // 조회
/// let repo: UserRepositoryProtocol? = DependencyContainer.live.resolve(UserRepositoryProtocol.self)
/// print(repo?.fetchUser(id: "123") ?? "nil") // User(123)
/// ```
///
/// ### 등록 해제
/// ```swift
/// let release = DependencyContainer.live.register(LoggerProtocol.self) {
///     ConsoleLogger()
/// }
///
/// // 해제
/// release()
///
/// print(DependencyContainer.live.resolve(LoggerProtocol.self) == nil) // true
/// ```
///
/// ### 인스턴스 직접 등록
/// ```swift
/// let service = NetworkService(baseURL: URL(string: "https://api.example.com")!)
/// DependencyContainer.live.register(NetworkService.self, instance: service)
///
/// let ns = DependencyContainer.live.resolve(NetworkService.self)!
/// ns.request(endpoint: "posts/1")
/// ```
public final class DependencyContainer: @unchecked Sendable, ObservableObject {

  // MARK: - 저장 프로퍼티

  /// 등록된 의존성(또는 팩토리 클로저)을 저장하는 딕셔너리
  private var registry = [String: Any]()

  /// 등록된 의존성 해제를 위한 핸들러 딕셔너리
  private var releaseHandlers = [String: () -> Void]()

  /// 읽기·쓰기를 동기화하기 위한 concurrent `DispatchQueue`
  private let syncQueue = DispatchQueue(label: "com.diContainer.syncQueue", attributes: .concurrent)

  // MARK: - 초기화

  /// 기본 초기화자
  /// - 설명: 빈 상태의 `registry`와 `releaseHandlers`로 시작합니다.
  public init() {}

  // MARK: - 의존성 등록

  /// 주어진 타입의 의존성을 팩토리 클로저로 등록합니다.
  ///
  /// - Parameters:
  ///   - type: 등록할 의존성 타입 (예: `AuthRepositoryProtocol.self`)
  ///   - build: 해당 타입의 인스턴스를 생성하는 팩토리 클로저
  /// - Returns: 나중에 호출하면 등록을 해제하는 클로저
  @discardableResult
  public func register<T>(
    _ type: T.Type,
    build: @escaping () -> T
  ) -> () -> Void {
    let key = String(describing: type)

    syncQueue.sync(flags: .barrier) {
      self.registry[key] = build
    }

    Log.debug("Registered", key)

    let releaseHandler: () -> Void = { [weak self] in
      self?.syncQueue.sync(flags: .barrier) {
        self?.registry[key] = nil
        self?.releaseHandlers[key] = nil
      }
      Log.debug("Released", key)
    }

    syncQueue.sync(flags: .barrier) {
      self.releaseHandlers[key] = releaseHandler
    }

    return releaseHandler
  }

  // MARK: - 의존성 조회

  /// 주어진 타입의 의존성을 조회하여 인스턴스를 생성합니다.
  ///
  /// - Parameter type: 조회할 의존성 타입
  /// - Returns: 등록된 의존성이 있으면 인스턴스, 없으면 `nil`
  public func resolve<T>(_ type: T.Type) -> T? {
    let key = String(describing: type)
    return syncQueue.sync {
      guard let factory = self.registry[key] as? () -> T else {
        Log.error("No registered dependency found for \(String(describing: T.self))")
        return nil
      }
      return factory()
    }
  }

  /// 주어진 타입의 의존성을 조회하거나, 없으면 기본값을 반환합니다.
  ///
  /// - Parameters:
  ///   - type: 조회할 타입
  ///   - defaultValue: 없을 때 사용할 기본값
  public func resolveOrDefault<T>(
    _ type: T.Type,
    default defaultValue: @autoclosure () -> T
  ) -> T {
    resolve(type) ?? defaultValue()
  }

  // MARK: - 의존성 해제

  /// 특정 타입의 의존성을 해제합니다.
  ///
  /// - Parameter type: 해제할 타입
  public func release<T>(_ type: T.Type) {
    let key = String(describing: type)
    syncQueue.async(flags: .barrier) {
      self.releaseHandlers[key]?()
    }
  }

  // MARK: - KeyPath 기반 접근

  /// KeyPath를 기반으로 의존성 조회
  public subscript<T>(keyPath: KeyPath<DependencyContainer, T>) -> T? {
    get { resolve(T.self) }
  }

  // MARK: - 인스턴스 직접 등록

  /// 이미 생성된 인스턴스를 등록합니다.
  ///
  /// - Parameters:
  ///   - type: 등록할 인스턴스 타입
  ///   - instance: 직접 생성된 인스턴스
  /// - Note: `Sendable` 제약은 제거되었으며, 모든 타입을 등록할 수 있습니다.
  public func register<T: Sendable>(
    _ type: T.Type,
    instance: T
  ) {
    let key = String(describing: type)
    syncQueue.async(flags: .barrier) { [unowned self] in
      self.registry[key] = { instance }
    }
    Log.debug("Registered instance for", key)
  }
}

// MARK: - Live Container

public extension DependencyContainer {
  /// 애플리케이션 전역에서 사용하는 live 컨테이너
  static let live = DependencyContainer()
}
