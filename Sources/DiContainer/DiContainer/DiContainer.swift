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
  
  private var registry = [String: Any]()
  private var releaseHandlers = [String: @Sendable () -> Void]()
  
  private let syncQueue = DispatchQueue(label: "com.diContainer.syncQueue", attributes: .concurrent)
  
  public init() {}
  
  @discardableResult
  public func register<T: Sendable>(
    _ type: T.Type,
    build: @escaping @Sendable () -> T
  ) -> @Sendable () -> Void {
    let key = String(describing: type)
    let safeBuild: @Sendable () -> T = build
    // barrier 클로저에서 self를 unowned로 캡처
    syncQueue.async(flags: .barrier) { [unowned self] in
      self.registry[key] = safeBuild
    }
    Log.debug("Registered", key)
    
    let releaseHandler: @Sendable () -> Void = { [weak self] in
      self?.syncQueue.async(flags: .barrier) { [unowned self] in
        self?.registry[key] = nil
        self?.releaseHandlers[key] = nil
      }
      Log.debug("Released", key)
    }
    
    syncQueue.async(flags: .barrier) { [unowned self] in
      self.releaseHandlers[key] = releaseHandler
    }
    return releaseHandler
  }
  
  public func resolve<T>(_ type: T.Type) -> T? {
    let key = String(describing: type)
    return syncQueue.sync {
      guard let factory = self.registry[key] as? @Sendable () -> T else {
        Log.error("No registered dependency found for \(String(describing: T.self))")
        return nil
      }
      return factory()
    }
  }
  
  public func resolveOrDefault<T>(
    _ type: T.Type,
    default defaultValue: @autoclosure () -> T
  ) -> T {
    resolve(type) ?? defaultValue()
  }
  
  public func release<T>(_ type: T.Type) {
    let key = String(describing: type)
    syncQueue.async(flags: .barrier) {
      self.releaseHandlers[key]?()
    }
  }
  
  public subscript<T>(keyPath: KeyPath<DependencyContainer, T>) -> T? {
    get { resolve(T.self) }
  }
  
  public func register<T: Sendable>(
    _ type: T.Type,
    instance: T
  ) {
    let key = String(describing: type)
    syncQueue.async(flags: .barrier) {
      // 클로저를 @Sendable으로 캐스팅
      self.registry[key] = { instance } as @Sendable () -> T
    }
    Log.debug("Registered instance for", key)
  }
}

@available(iOS 17.0, *)
public extension DependencyContainer {
  static let live = DependencyContainer()
}

#else
public final class DependencyContainer: ObservableObject {
  
  private var registry = [String: Any]()
  private var releaseHandlers = [String: () -> Void]()
  private let syncQueue = DispatchQueue(label: "com.diContainer.syncQueue", attributes: .concurrent)
  
  public init() {}
  
  /// Registers a dependency with a factory closure
  @discardableResult
  public func register<T>(
    _ type: T.Type,
    build: @escaping () -> T
  ) -> () -> Void {
    let key = String(describing: type)
    let safeBuild:  () -> T = build
    syncQueue.async(flags: .barrier) {
      self.registry[key] = safeBuild
    }
    Log.debug("Registered", String(describing: type))
    
    let releaseHandler:  () -> Void = { [weak self] in
      self?.syncQueue.async(flags: .barrier) {
        self?.registry[key] = nil
        self?.releaseHandlers[key] = nil
      }
      Log.debug("Released", String(describing: type))
    }
    
    syncQueue.async(flags: .barrier) {
      self.releaseHandlers[key] = releaseHandler
    }
    return releaseHandler
  }
  
  /// Resolves a dependency by type
  public func resolve<T>(
    _ type: T.Type
  ) -> T? {
    let key = String(describing: type)
    return syncQueue.sync {
      guard let factory = self.registry[key] as?  () -> T else {
        Log.error("No registered dependency found for \(String(describing: T.self))")
        return nil
      }
      return factory()
    }
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
    let key = String(describing: type)
    syncQueue.async(flags: .barrier) {
      self.releaseHandlers[key]?()
    }
  }
  
  public subscript<T>(keyPath: KeyPath<DependencyContainer, T>) -> T? {
    get { resolve(T.self) }
  }
  
  public func register<T: Sendable>(
    _ type: T.Type,
    instance: T
  ) {
    let key = String(describing: type)
    syncQueue.async(flags: .barrier) {
      self.registry[key] = { instance } as () -> T
    }
    Log.debug("Registered instance for", String(describing: type))
  }
}

public extension DependencyContainer {
  static let live = DependencyContainer()
}
#endif
