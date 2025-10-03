//
//  DirectCallRegistry.swift
//  WeaveDI
//
//  Created by Wonji Suh on 2025.
//

import Foundation

// MARK: - 직접 호출 경로 (코스트리 반영)

/// 팩토리 체이닝 없는 직접 호출 레지스트리
///
/// 기존: Factory → Factory → Factory (체이닝)
/// 개선: Type → 직접 인스턴스 생성 (No 체이닝)
public final class DirectCallRegistry: @unchecked Sendable {
  
  // MARK: - 단순한 저장 방식
  
  /// 타입별 직접 생성자
  @usableFromInline
  internal var directCreators: [ObjectIdentifier: Any] = [:]
  @usableFromInline
  internal let lock = NSLock()
  
  // MARK: - 직접 호출 등록
  
  /// 직접 인스턴스 저장 (싱글톤)
  @inlinable
  @inline(__always)
  @_alwaysEmitIntoClient
  public func storeDirect<T>(_ type: T.Type, instance: T) {
    let key = ObjectIdentifier(type)
    
    lock.lock()
    directCreators[key] = instance
    lock.unlock()
  }
  
  /// 직접 팩토리 저장 (트랜지언트) - 체이닝 없음
  @inlinable
  @inline(__always)
  @_alwaysEmitIntoClient
  public func storeDirect<T>(_ type: T.Type, creator: @escaping () -> T) {
    let key = ObjectIdentifier(type)
    
    lock.lock()
    // 래핑 없이 직접 저장
    directCreators[key] = creator
    lock.unlock()
  }
  
  /// 직접 해결 (체이닝 없는 호출)
  @inlinable
  @inline(__always)
  @_alwaysEmitIntoClient
  public func getDirect<T>(_ type: T.Type) -> T? {
    let key = ObjectIdentifier(type)
    
    // 락-프리 읽기
    guard let stored = directCreators[key] else {
      return nil
    }
    
    // 1. 직접 인스턴스인 경우
    if let instance = stored as? T {
      return instance
    }
    
    // 2. 직접 팩토리인 경우
    if let creator = stored as? () -> T {
      return creator() // 직접 호출 (체이닝 없음)
    }
    
    return nil
  }
  
  /// 제거
  public func removeDirect<T>(_ type: T.Type) {
    let key = ObjectIdentifier(type)
    
    lock.lock()
    directCreators[key] = nil
    lock.unlock()
  }
}

// MARK: - 의존성 그래프 플래튼화

/// 의존성 체인을 플래튼화하는 최적화
public final class FlattenedDependencyRegistry: @unchecked Sendable {
  
  @usableFromInline
  internal var flattenedFactories: [ObjectIdentifier: () -> Any] = [:]
  @usableFromInline
  internal let lock = NSLock()
  
  /// 의존성 체인을 플래튼화하여 등록
  @inlinable
  public func registerFlattened<T>(_ type: T.Type, buildChain: @escaping () -> T) {
    let key = ObjectIdentifier(type)
    
    lock.lock()
    // 체인 전체를 하나의 팩토리로 플래튼화
    flattenedFactories[key] = { buildChain() }
    lock.unlock()
  }
  
  /// 플래튼화된 해결 (한 번의 호출)
  @inlinable
  @inline(__always)
  @_alwaysEmitIntoClient
  public func resolveFlattened<T>(_ type: T.Type) -> T? {
    let key = ObjectIdentifier(type)
    
    guard let factory = flattenedFactories[key] else {
      return nil
    }
    
    return factory() as? T
  }
}

// MARK: - 통합 최적화 DI

/// 모든 최적화를 통합한 DI 컨테이너
public final class UltimateDI: @unchecked Sendable {
  
  // MARK: - 최적화된 저장소들
  
  @usableFromInline
  internal let directRegistry = DirectCallRegistry()
  @usableFromInline
  internal let flattenedRegistry = FlattenedDependencyRegistry()
  
  public static let shared = UltimateDI()
  
  // MARK: - 통합 등록 API
  
  /// 최적화된 등록 - 자동으로 최적 경로 선택
  @inlinable
  @inline(__always)
  @_alwaysEmitIntoClient
  public func register<T>(_ type: T.Type, instance: T) {
    // 인스턴스는 직접 저장이 가장 빠름
    directRegistry.storeDirect(type, instance: instance)
  }
  
  /// 최적화된 등록 - 단순 팩토리
  @inlinable
  @inline(__always)
  @_alwaysEmitIntoClient
  public func register<T>(_ type: T.Type, factory: @escaping () -> T) {
    // 단순 팩토리는 직접 호출
    directRegistry.storeDirect(type, creator: factory)
  }
  
  /// 최적화된 등록 - 복잡한 의존성 체인
  @inlinable
  public func registerComplex<T>(_ type: T.Type, dependencies: [Any.Type], buildChain: @escaping () -> T) {
    // 복잡한 의존성은 플래튼화
    flattenedRegistry.registerFlattened(type, buildChain: buildChain)
  }
  
  // MARK: - 통합 해결 API
  
  /// 최적화된 해결 - 자동으로 최적 경로 시도
  @inlinable
  @inline(__always)
  @_alwaysEmitIntoClient
  public func resolve<T>(_ type: T.Type) -> T? where T: Sendable {
    // 1. 직접 호출 시도 (가장 빠름)
    if let result = directRegistry.getDirect(type) {
      return result
    }
    
    // 2. 플래튼화된 팩토리 시도
    if let result = flattenedRegistry.resolveFlattened(type) {
      return result
    }
    
    return nil
  }
  
  /// 강제 직접 호출 해결
  @inlinable
  @inline(__always)
  @_alwaysEmitIntoClient
  public func resolveDirect<T>(_ type: T.Type) -> T? {
    return directRegistry.getDirect(type)
  }
  
  /// 제거
  public func remove<T>(_ type: T.Type) {
    directRegistry.removeDirect(type)
  }
  
  /// 모든 저장소 클리어
  public func clear() {
    // 각 저장소 클리어 로직
  }
}

// MARK: - 편의 전역 함수 (체이닝 없는 직접 호출)

/// 직접 등록
@inlinable
@inline(__always)
@_alwaysEmitIntoClient
public func setDirect<T>(_ type: T.Type, to instance: T) {
  UltimateDI.shared.register(type, instance: instance)
}

/// 직접 팩토리 등록
@inlinable
@inline(__always)
@_alwaysEmitIntoClient
public func setDirect<T>(_ type: T.Type, factory: @escaping () -> T) {
  UltimateDI.shared.register(type, factory: factory)
}

/// 직접 해결
@inlinable
@inline(__always)
@_alwaysEmitIntoClient
public func getDirect<T>(_ type: T.Type) -> T? where T: Sendable {
  return UltimateDI.shared.resolve(type)
}

/// 복잡한 의존성 등록 (플래튼화)
@inlinable
public func setComplex<T>(_ type: T.Type, dependencies: [Any.Type], build: @escaping () -> T) {
  UltimateDI.shared.registerComplex(type, dependencies: dependencies, buildChain: build)
}

// MARK: - 기존 DIContainer 통합

extension DIContainer {
  
  /// 최적화 모드 활성화
  public func enableUltimateOptimization() {
    // 기존 등록을 UltimateDI로 마이그레이션
    // 구현 필요시 추가
  }
  
  /// 최적화된 해결 (fallback 체인)
  @inlinable
  @inline(__always)
  public func ultimateResolve<T>(_ type: T.Type) -> T? where T: Sendable {
    // 1. 최적화된 경로 시도
    if let result = UltimateDI.shared.resolve(type) {
      return result
    }
    
    // 2. 기존 경로 fallback
    return resolve(type)
  }
}
