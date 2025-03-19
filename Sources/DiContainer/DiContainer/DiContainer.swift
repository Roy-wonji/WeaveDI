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
@Observable
public final class DependencyContainer: Sendable {
  private var registry = [ObjectIdentifier: Any]()
  private var releaseHandlers = [ObjectIdentifier: () -> Void]()
  
  public init() {}
  
  /// Registers a dependency with a factory closure
  @discardableResult
  public func register<T>(_ type: T.Type, build: @escaping () -> T) -> () -> Void {
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
  public func resolve<T>(_ type: T.Type) -> T? {
    let key = ObjectIdentifier(type)
    guard let factory = registry[key] as? () -> T else {
      Log.error("No registered dependency found for \(String(describing: T.self))")
      return nil
    }
    return factory()
  }
  
  /// Resolves a dependency or provides a default value
  public func resolveOrDefault<T>(_ type: T.Type, default defaultValue: @autoclosure () -> T) -> T {
    resolve(type) ?? defaultValue()
  }
  
  /// Releases a dependency by type
  public func release<T>(_ type: T.Type) {
    let key = ObjectIdentifier(type)
    releaseHandlers[key]?()
  }
  
  /// Subscript for KeyPath-based access
  public subscript<T>(keyPath: KeyPath<DependencyContainer, T>) -> T? {
    get { resolve(T.self) }
  }
  
  /// Registers an instance directly
  public func register<T>(_ type: T.Type, instance: T) {
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
public final class DependencyContainer: ObservableObject, Sendable {
  private var registry = [ObjectIdentifier: Any]()
  private var releaseHandlers = [ObjectIdentifier: () -> Void]()
  
  public init() {}
  
  /// Registers a dependency with a factory closure
  @discardableResult
  public func register<T>(_ type: T.Type, build: @escaping () -> T) -> () -> Void {
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
  public func resolve<T>(_ type: T.Type) -> T? {
    let key = ObjectIdentifier(type)
    guard let factory = registry[key] as? () -> T else {
      Log.error("No registered dependency found for \(String(describing: T.self))")
      return nil
    }
    return factory()
  }
  
  /// Resolves a dependency or provides a default value
  public func resolveOrDefault<T>(_ type: T.Type, default defaultValue: @autoclosure () -> T) -> T {
    resolve(type) ?? defaultValue()
  }
  
  /// Releases a dependency by type
  public func release<T>(_ type: T.Type) {
    let key = ObjectIdentifier(type)
    releaseHandlers[key]?()
  }
  
  /// Subscript for KeyPath-based access
  public subscript<T>(keyPath: KeyPath<DependencyContainer, T>) -> T? {
    get { resolve(T.self) }
  }
  
  /// Registers an instance directly
  public func register<T>(_ type: T.Type, instance: T) {
    let key = ObjectIdentifier(type)
    registry[key] = { instance }
    Log.debug("Registered instance for", String(describing: type))
  }
}

public extension DependencyContainer {
  static let live = DependencyContainer()
}
#endif
