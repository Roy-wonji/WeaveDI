//
//  DIContainer.swift
//  DiContainer
//
//  Created by 서원지 on 6/8/24.
//

import LogMacro
import Combine



#if swift(>=5.9)
@available(iOS 17.0, *)
/// DependencyContainer는 애플리케이션 내 의존성을 등록, 조회 및 해제하는 역할을 하며,
/// 내부적으로 의존성을 String(타입 이름) 키로 관리합니다.
/// 동기화를 위해 concurrent queue와 barrier 플래그를 사용해 thread safe하게 구현되었습니다.
@Observable
public final class DependencyContainer: @unchecked Sendable {
  
  // 의존성(또는 팩토리 클로저)을 저장하는 딕셔너리.
  private var registry = [String: Any]()
  
  // 등록된 의존성을 해제하기 위한 핸들러들을 저장하는 딕셔너리.
  private var releaseHandlers = [String: () -> Void]()
  
  // 동기화 전용 concurrent DispatchQueue.
  private let syncQueue = DispatchQueue(label: "com.diContainer.syncQueue", attributes: .concurrent)
  
  public init() {}
  
  /// 주어진 타입의 의존성을 등록합니다.
  /// - Parameters:
  ///   - type: 등록할 의존성의 타입 (예: AuthRepositoryProtocol.self)
  ///   - build: 해당 타입의 인스턴스를 생성하는 팩토리 클로저
  /// - Returns: 나중에 해당 의존성을 해제할 때 사용할 해제 클로저
  @discardableResult
  public func register<T>(
    _ type: T.Type,
    build: @escaping () -> T
  ) -> () -> Void {
    let key = String(describing: type)
    
    // 동기적으로 registry에 build 클로저를 저장합니다.
    syncQueue.sync(flags: .barrier) {
      self.registry[key] = build
    }
    Log.debug("Registered", key)
    
    // 해제 클로저: 해당 키의 값을 제거합니다.
    let releaseHandler: () -> Void = { [weak self] in
      self?.syncQueue.sync(flags: .barrier) {
        self?.registry[key] = nil
        self?.releaseHandlers[key] = nil
      }
      Log.debug("Released", key)
    }
    
    // 동기적으로 releaseHandlers에도 저장합니다.
    syncQueue.sync(flags: .barrier) {
      self.releaseHandlers[key] = releaseHandler
    }
    
    return releaseHandler
  }
  
  /// 주어진 타입의 의존성을 조회하여 인스턴스를 생성합니다.
  /// - Parameter type: 조회할 의존성의 타입
  /// - Returns: 등록된 의존성이 있으면 생성된 인스턴스, 없으면 nil
  public func resolve<T>(_ type: T.Type) -> T? {
    let key = String(describing: type)
    return syncQueue.sync { [unowned self] in
      guard let factory = self.registry[key] as? () -> T else {
        #logError("No registered dependency found for \(String(describing: T.self))")
        return nil
      }
      return factory()
    }
  }
  
  /// 주어진 타입의 의존성을 조회하거나, 등록되어 있지 않으면 기본값을 반환합니다.
  public func resolveOrDefault<T>(
    _ type: T.Type,
    default defaultValue: @autoclosure () -> T
  ) -> T {
    resolve(type) ?? defaultValue()
  }
  
  /// 특정 타입의 의존성을 해제합니다.
  public func release<T>(_ type: T.Type) {
    let key = String(describing: type)
    syncQueue.async(flags: .barrier) { [unowned self] in
      self.releaseHandlers[key]?()
    }
  }
  
  /// KeyPath 기반 접근: 타입 기반 resolve를 호출합니다.
  public subscript<T>(keyPath: KeyPath<DependencyContainer, T>) -> T? {
    get { resolve(T.self) }
  }
  
  /// 이미 생성된 인스턴스를 클로저로 래핑하여 등록합니다.
  /// Sendable 제약을 제거하여, instance가 Sendable하지 않아도 등록할 수 있습니다.
  public func register<T: Sendable>(
    _ type: T.Type,
    instance: T
  ) {
    let key = String(describing: type)
    syncQueue.async(flags: .barrier) { [unowned self] in
      // @Sendable 캐스트를 제거하여 instance 캡처 오류 해결
      self.registry[key] = { instance }
    }
    #logDebug("Registered instance for", key)
  }
}

@available(iOS 17.0, *)
public extension DependencyContainer {
  /// 전역적으로 사용 가능한 DependencyContainer 인스턴스 (live container)
  static let live = DependencyContainer()
}

#else
// MARK: - Box 클래스
// non‑Sendable 타입도 안전하게 캡슐화하기 위한 래퍼입니다.
private final class Box<T> {
  let value: T
  init(_ value: T) {
    self.value = value
  }
}

/// DependencyContainer는 애플리케이션 내 의존성(또는 팩토리 클로저)을 등록, 조회 및 해제하는 역할을 하며,
/// 내부적으로 의존성을 String(타입 이름) 키로 관리하고, 동기화를 위해 concurrent queue와 barrier 플래그를 사용하여 thread safe하게 구현되었습니다.
public final class DependencyContainer: ObservableObject {
  
  // 의존성(또는 팩토리 클로저)을 저장하는 딕셔너리.
  // key: 타입 이름(String), value: 인스턴스를 생성하는 클로저(Any)
  private var registry = [String: Any]()
  
  // 등록된 의존성을 해제하기 위한 핸들러들을 저장하는 딕셔너리.
  // key: 타입 이름(String), value: 해제 클로저 (() -> Void)
  private var releaseHandlers = [String: () -> Void]()
  
  // 동기화 전용 concurrent DispatchQueue.
  // 읽기는 sync, 쓰기는 async(flags: .barrier)를 사용하여 동시성 문제를 방지합니다.
  private let syncQueue = DispatchQueue(label: "com.diContainer.syncQueue", attributes: .concurrent)
  
  public init() {}
  
  /// 주어진 타입의 의존성을 등록합니다.
  /// - Parameters:
  ///   - type: 등록할 의존성의 타입 (예: AuthRepositoryProtocol.self)
  ///   - build: 해당 타입의 인스턴스를 생성하는 팩토리 클로저
  /// - Returns: 나중에 해당 의존성을 해제할 때 호출할 해제 클로저
  @discardableResult
  public func register<T>(
    _ type: T.Type,
    build: @escaping () -> T
  ) -> () -> Void {
    let key = String(describing: type)
    
    // registry에 build 클로저를 barrier 플래그를 사용해 비동기적으로 저장합니다.
    syncQueue.async(flags: .barrier) {
      self.registry[key] = build
    }
    #logDebug("Registered", String(describing: type))
    
    // 해제 클로저: 해당 키의 값을 제거합니다.
    let releaseHandler: () -> Void = { [weak self] in
      self?.syncQueue.async(flags: .barrier) {
        self?.registry[key] = nil
        self?.releaseHandlers[key] = nil
      }
      #logDebug("Released", String(describing: type))
    }
    
    // releaseHandlers에도 barrier 플래그를 사용해 비동기적으로 저장합니다.
    syncQueue.async(flags: .barrier) {
      self.releaseHandlers[key] = releaseHandler
    }
    
    return releaseHandler
  }
  
  /// 주어진 타입의 의존성을 조회하여 인스턴스를 생성합니다.
  /// - Parameter type: 조회할 의존성의 타입
  /// - Returns: 등록된 의존성이 있으면 생성된 인스턴스, 없으면 nil
  public func resolve<T>(_ type: T.Type) -> T? {
    let key = String(describing: type)
    return syncQueue.sync {
      guard let factory = self.registry[key] as? () -> T else {
        #logError("No registered dependency found for \(String(describing: T.self))")
        return nil
      }
      return factory()
    }
  }
  
  /// 주어진 타입의 의존성을 조회하거나, 등록되어 있지 않으면 기본값을 반환합니다.
  /// - Parameters:
  ///   - type: 조회할 의존성의 타입
  ///   - defaultValue: 의존성이 없을 때 사용할 기본값 (자동 클로저로 전달됨)
  /// - Returns: 조회된 의존성 또는 기본값
  public func resolveOrDefault<T>(
    _ type: T.Type,
    default defaultValue: @autoclosure () -> T
  ) -> T {
    return resolve(type) ?? defaultValue()
  }
  
  /// 특정 타입의 의존성을 해제합니다.
  /// - Parameter type: 해제할 의존성의 타입
  public func release<T>(_ type: T.Type) {
    let key = String(describing: type)
    syncQueue.async(flags: .barrier) {
      self.releaseHandlers[key]?()
    }
  }
  
  /// KeyPath 기반 접근: 단순히 타입 기반 resolve를 호출합니다.
  public subscript<T>(keyPath: KeyPath<DependencyContainer, T>) -> T? {
    get { resolve(T.self) }
  }
  
  /// 이미 생성된 인스턴스를 클로저로 래핑하여 등록합니다.
  /// 여기서는 non‑Sendable 타입도 처리하기 위해 instance를 Box에 담아 캡처합니다.
  public func register<T>(
    _ type: T.Type,
    instance: T
  ) {
    let key = String(describing: type)
    let box = Box(instance)
    syncQueue.async(flags: .barrier) { [unowned self, box] in
      self.registry[key] = { box.value }
    }
    #logDebug("Registered instance for", String(describing: type))
  }
}

public extension DependencyContainer {
  /// 전역적으로 사용 가능한 DependencyContainer 인스턴스 (live container)
  static let live = DependencyContainer()
}
#endif
