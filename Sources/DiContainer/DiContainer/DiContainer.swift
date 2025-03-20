//
//  DIContainer.swift
//  DiContainer
//
//  Created by 서원지 on 6/8/24.
//

import Foundation
import Combine

import LogMacro

#if swift(>=5.9)
@available(iOS 17.0, *)
/// DependencyContainer는 애플리케이션 내 의존성(또는 팩토리 클로저)을 등록, 조회 및 해제하는 역할을 합니다.
/// 내부적으로 의존성을 ObjectIdentifier를 키로 관리하며, 이를 통해 타입 기반 의존성 주입을 구현합니다.
@Observable
public final class DependencyContainer: @unchecked Sendable {
  
  /// 의존성(또는 팩토리 클로저)을 저장하는 딕셔너리입니다.
  /// - 키: ObjectIdentifier (등록할 타입의 식별자)
  /// - 값: Any (보통은 해당 타입의 인스턴스를 생성하는 클로저)
  private var registry = [ObjectIdentifier: Any]()
  
  /// 등록된 의존성을 해제(release)하기 위한 핸들러들을 저장하는 딕셔너리입니다.
  /// 이 핸들러들을 호출하면 registry에서 해당 의존성이 제거됩니다.
  private var releaseHandlers = [ObjectIdentifier: () -> Void]()
  
  /// 기본 생성자. 이 컨테이너는 빈 registry와 releaseHandlers로 시작합니다.
  public init() {}
  
  /// 주어진 타입의 의존성을 등록합니다.
  ///
  /// - Parameters:
  ///   - type: 등록할 의존성의 타입 (예: AuthRepositoryProtocol.self)
  ///   - build: 해당 타입의 인스턴스를 생성하는 팩토리 클로저
  /// - Returns: 나중에 해당 의존성을 해제할 때 호출할 해제 핸들러 클로저
  ///
  /// 등록 시, DependencyContainer.live에 의존성을 추가하고, 등록 성공 메시지를 기록합니다.
  @discardableResult
  public func register<T>(
    _ type: T.Type,
    build: @escaping () -> T
  ) -> () -> Void {
    let key = ObjectIdentifier(type)
    registry[key] = build
    Log.debug("Registered", String(describing: type))
    
    let releaseHandler = { [weak self] in
      self?.registry[key] = nil
      self?.releaseHandlers[key] = nil
      Log.debug("Released", String(describing: type))
    }
    
    releaseHandlers[key] = releaseHandler
    return releaseHandler
  }
  
  /// 주어진 타입의 의존성을 registry에서 조회하여 인스턴스를 생성합니다.
  ///
  /// - Parameter type: 조회할 의존성의 타입
  /// - Returns: 등록된 의존성이 있으면 생성된 인스턴스, 없으면 nil
  public func resolve<T>(
    _ type: T.Type
  ) -> T? {
    let key = ObjectIdentifier(type)
    guard let factory = registry[key] as? () -> T else {
      Log.error("No registered dependency found for \(String(describing: T.self))")
      return nil
    }
    return factory()
  }
  
  /// 의존성을 조회하거나, 등록되어 있지 않으면 기본값을 반환합니다.
  ///
  /// - Parameters:
  ///   - type: 조회할 의존성의 타입
  ///   - defaultValue: 의존성이 없을 때 사용할 기본값 (자동 클로저로 전달됨)
  /// - Returns: 조회된 의존성 또는 기본값
  public func resolveOrDefault<T>(
    _ type: T.Type,
    default defaultValue: @autoclosure () -> T
  ) -> T {
    resolve(type) ?? defaultValue()
  }
  
  /// 특정 타입의 의존성을 해제합니다.
  ///
  /// - Parameter type: 해제할 의존성의 타입
  public func release<T>(
    _ type: T.Type
  ) {
    let key = ObjectIdentifier(type)
    releaseHandlers[key]?()
  }
  
  /// KeyPath 기반 접근을 위한 서브스크립트.
  /// 이 예제에서는 단순히 타입 기반 resolve를 호출합니다.
  public subscript<T>(
    keyPath: KeyPath<DependencyContainer, T>
  ) -> T? {
    get { resolve(T.self) }
  }
  
  /// 인스턴스를 직접 등록하는 메서드입니다.
  ///
  /// - Parameters:
  ///   - type: 등록할 의존성의 타입
  ///   - instance: 등록할 인스턴스
  ///
  /// 이미 생성된 인스턴스를 클로저로 래핑하여 registry에 저장합니다.
  public func register<T>(
    _ type: T.Type,
    instance: T
  ) {
    let key = ObjectIdentifier(type)
    registry[key] = { instance }
    Log.debug("Registered instance for", String(describing: type))
  }
}

@available(iOS 17.0, *)
public extension DependencyContainer {
  static let live = DependencyContainer()
}

#else
public final class DependencyContainer: ObservableObject {
  private var registry = [ObjectIdentifier: Any]()
  private var releaseHandlers = [ObjectIdentifier: () -> Void]()
  
  public init() {}
  
  /// Registers a dependency with a factory closure
  @discardableResult
  public func register<T>(
    _ type: T.Type,
    build: @escaping () -> T
  ) -> () -> Void {
    let key = ObjectIdentifier(type)
    registry[key] = build
    Log.debug("Registered", String(describing: type))
    
    let releaseHandler = { [weak self] in
      self?.registry[key] = nil
      self?.releaseHandlers[key] = nil
      Log.debug("Released", String(describing: type))
    }
    
    releaseHandlers[key] = releaseHandler
    return releaseHandler
  }
  
  /// Resolves a dependency by type
  public func resolve<T>(
    _ type: T.Type
  ) -> T? {
    let key = ObjectIdentifier(type)
    guard let factory = registry[key] as? () -> T else {
      Log.error("No registered dependency found for \(String(describing: T.self))")
      return nil
    }
    return factory()
  }
  
  /// Resolves a dependency or provides a default value
  public func resolveOrDefault<T>(
    _ type: T.Type,
    default defaultValue: @autoclosure () -> T
  ) -> T {
    resolve(type) ?? defaultValue()
  }
  
  /// Releases a dependency by type
  public func release<T>(
    _ type: T.Type
  ) {
    let key = ObjectIdentifier(type)
    releaseHandlers[key]?()
  }
  
  /// Subscript for KeyPath-based access
  public subscript<T>(keyPath: KeyPath<DependencyContainer, T>) -> T? {
    get { resolve(T.self) }
  }
  
  /// Registers an instance directly
  public func register<T>(
    _ type: T.Type,
    instance: T
  ) {
    let key = ObjectIdentifier(type)
    registry[key] = { instance }
    Log.debug("Registered instance for", String(describing: type))
  }
}

public extension DependencyContainer {
  static let live = DependencyContainer()
}
#endif
