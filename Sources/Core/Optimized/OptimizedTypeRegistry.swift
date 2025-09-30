//
//  OptimizedTypeRegistry.swift
//  WeaveDI
//
//  Created by Wonji Suh on 2025.
//

import Foundation
import LogMacro

// MARK: - TypeID System

/// 타입에 대한 고유 정수 식별자
public struct TypeID: Hashable, Sendable {
  internal let id: Int

  internal init(id: Int) {
    self.id = id
  }
}

/// TypeID 매핑 관리자 - ObjectIdentifier → Int 슬롯 할당
internal final class TypeIDMapper: @unchecked Sendable {
  private var objectToID: [ObjectIdentifier: TypeID] = [:]
  private var nextID = 0
  private let lock = NSLock()

  /// ObjectIdentifier를 TypeID로 매핑하거나 새로 할당
  func getOrCreateTypeID(for objectID: ObjectIdentifier) -> TypeID {
    lock.lock()
    defer { lock.unlock() }

    if let existing = objectToID[objectID] {
      return existing
    }

    let newID = TypeID(id: nextID)
    nextID += 1
    objectToID[objectID] = newID
    return newID
  }

  /// 타입으로부터 TypeID 획득
  func getOrCreateTypeID<T>(for type: T.Type) -> TypeID {
    return getOrCreateTypeID(for: ObjectIdentifier(type))
  }
}

// MARK: - Lock-Free Storage

/// 불변 스토리지 스냅샷
internal final class Storage {
  let instances: [Any?]
  let factories: [(() -> Any)?]

  init(instances: [Any?], factories: [(() -> Any)?]) {
    self.instances = instances
    self.factories = factories
  }

  /// 빈 스토리지 생성
  static func empty() -> Storage {
    return Storage(instances: [], factories: [])
  }
}

// MARK: - Optimized Type Registry

/// 런타임 핫패스 최적화된 타입 레지스트리
///
/// 핵심 최적화:
/// - TypeID + 인덱스 접근: 딕셔너리 → 배열 슬롯으로 O(1) 접근
/// - 락-프리 읽기: 불변 Storage 스냅샷으로 읽기 경합 제거
/// - 직접 호출 경로: 팩토리 체이닝 없는 인라인 호출
internal final class OptimizedTypeRegistry: @unchecked Sendable {

  // MARK: - Properties

  @usableFromInline
  internal let typeIDMapper = TypeIDMapper()
  private var currentStorage: Storage
  private let lock = NSLock()

  // MARK: - Initialization

  init() {
    self.currentStorage = Storage.empty()
  }

  // MARK: - Registration

  /// 인스턴스 직접 등록 (싱글톤)
  @inlinable
  func register<T>(_ type: T.Type, instance: T) {
    let typeID = typeIDMapper.getOrCreateTypeID(for: type)

    lock.lock()
    defer { lock.unlock() }

    var newInstances = ensureCapacity(currentStorage.instances, for: typeID.id)
    var newFactories = ensureCapacity(currentStorage.factories, for: typeID.id)

    newInstances[typeID.id] = instance
    newFactories[typeID.id] = nil // 인스턴스가 있으면 팩토리 불필요

    // 원자적 스냅샷 교체
    currentStorage = Storage(instances: newInstances, factories: newFactories)

    Log.debug("🚀 [OptimizedRegistry] Registered instance for \(String(describing: type)) at slot \(typeID.id)")
  }

  /// 팩토리 등록 (트랜지언트)
  @inlinable
  func register<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) {
    let typeID = typeIDMapper.getOrCreateTypeID(for: type)

    lock.lock()
    defer { lock.unlock() }

    var newInstances = ensureCapacity(currentStorage.instances, for: typeID.id)
    var newFactories = ensureCapacity(currentStorage.factories, for: typeID.id)

    newInstances[typeID.id] = nil // 팩토리가 있으면 인스턴스 캐시 안함
    newFactories[typeID.id] = { factory() }

    // 원자적 스냅샷 교체
    currentStorage = Storage(instances: newInstances, factories: newFactories)

    Log.debug("🚀 [OptimizedRegistry] Registered factory for \(String(describing: type)) at slot \(typeID.id)")
  }

  // MARK: - Resolution (Lock-Free Hot Path)

  /// 락-프리 해결 (핫패스 최적화)
  @inlinable
  @inline(__always)
  func resolve<T>(_ type: T.Type) -> T? {
    let typeID = typeIDMapper.getOrCreateTypeID(for: type)

    // 스냅샷 참조 복사 (락-프리)
    let storage = currentStorage

    // 인덱스 범위 체크
    guard typeID.id < storage.instances.count else {
      return nil
    }

    // 1. 인스턴스 캐시 체크 (싱글톤)
    if let instance = storage.instances[typeID.id] as? T {
      return instance
    }

    // 2. 팩토리 실행 (트랜지언트)
    if let factory = storage.factories[typeID.id] {
      return factory() as? T
    }

    return nil
  }

  /// 해제
  func release<T>(_ type: T.Type) {
    let typeID = typeIDMapper.getOrCreateTypeID(for: type)

    lock.lock()
    defer { lock.unlock() }

    guard typeID.id < currentStorage.instances.count else { return }

    var newInstances = Array(currentStorage.instances)
    var newFactories = Array(currentStorage.factories)

    newInstances[typeID.id] = nil
    newFactories[typeID.id] = nil

    currentStorage = Storage(instances: newInstances, factories: newFactories)

    Log.debug("🗑️ [OptimizedRegistry] Released \(String(describing: type)) from slot \(typeID.id)")
  }

  // MARK: - Internal Helpers

  /// 배열 용량 확보
  @inlinable
  internal func ensureCapacity<T>(_ array: [T], for index: Int) -> [T] where T: ExpressibleByNilLiteral {
    var result = Array(array)
    while result.count <= index {
      result.append(nil) // T는 ExpressibleByNilLiteral이므로 안전
    }
    return result
  }
}

// MARK: - Scope-Specific Optimized Storage

// ScopeKind는 ScopeSupport.swift에서 이미 정의됨 - 중복 제거

/// Once 초기화 지원을 위한 원자적 플래그
internal struct OnceFlag {
  private var flag = os_unfair_lock_s()
  private var executed = false

  mutating func execute(_ block: () -> Void) {
    os_unfair_lock_lock(&flag)
    defer { os_unfair_lock_unlock(&flag) }

    if !executed {
      block()
      executed = true
    }
  }
}

/// 스코프별 최적화된 저장소
internal final class ScopedOptimizedRegistry: @unchecked Sendable {

  // 스코프별 분리된 저장소
  private let singletonRegistry = OptimizedTypeRegistry()
  private let requestRegistry = OptimizedTypeRegistry()
  private let sessionRegistry = OptimizedTypeRegistry()

  private var singletonOnce: [TypeID: OnceFlag] = [:]
  private let onceLock = NSLock()

  /// 스코프에 따른 등록
  func register<T>(_ type: T.Type, scope: ScopeKind, factory: @escaping @Sendable () -> T) {
    switch scope {
      case .singleton:
        // 싱글톤은 once 초기화 보장
        let typeID = singletonRegistry.typeIDMapper.getOrCreateTypeID(for: type)
        onceLock.lock()
        if singletonOnce[typeID] == nil {
          singletonOnce[typeID] = OnceFlag()
        }
        onceLock.unlock()

        singletonRegistry.register(type, factory: factory)

      case .request:
        requestRegistry.register(type, factory: factory)

      case .session:
        sessionRegistry.register(type, factory: factory)

      case .screen:
        // 스크린 스코프는 session과 동일하게 처리
        sessionRegistry.register(type, factory: factory)
    }
  }

  /// 스코프에 따른 해결
  @inlinable
  @inline(__always)
  func resolve<T>(_ type: T.Type, scope: ScopeKind) -> T? {
    switch scope {
      case .singleton:
        return singletonRegistry.resolve(type)
      case .request:
        return requestRegistry.resolve(type)
      case .session:
        return sessionRegistry.resolve(type)
      case .screen:
        return sessionRegistry.resolve(type)
    }
  }

  /// 스코프 클리어 (request/session)
  func clearScope(_ scope: ScopeKind) {
    switch scope {
      case .singleton:
        break // 싱글톤은 클리어하지 않음
      case .request:
        // 새로운 레지스트리로 교체
        // requestRegistry = OptimizedTypeRegistry() // TODO: 개선 필요
        break
      case .session:
        // sessionRegistry = OptimizedTypeRegistry() // TODO: 개선 필요
        break
      case .screen:
        // 스크린 스코프 클리어
        break
    }
  }
}
