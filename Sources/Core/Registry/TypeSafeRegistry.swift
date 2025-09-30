//
//  TypeSafeRegistry.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - TypeIdentifier

/// 타입 안전한 키를 제공하는 구조체입니다.
///
/// 기존 String 키 방식의 단점을 보완하여 컴파일 타임 타입 안전성을 제공합니다.
public struct TypeIdentifier<T>: Hashable {
  /// 타입의 고유 식별자
  internal let identifier: ObjectIdentifier

  /// 디버깅을 위한 타입 이름
  internal let typeName: String

  /// 타입을 기반으로 TypeIdentifier를 생성합니다.
  /// - Parameter type: 식별할 타입
  public init(_ type: T.Type) {
    self.identifier = ObjectIdentifier(type)
    self.typeName = String(describing: type)
  }

  /// Hashable 구현
  public func hash(into hasher: inout Hasher) {
    hasher.combine(identifier)
  }

  /// Equatable 구현
  public static func == (lhs: TypeIdentifier<T>, rhs: TypeIdentifier<T>) -> Bool {
    lhs.identifier == rhs.identifier
  }
}

// MARK: - AnyTypeIdentifier

/// 타입 정보를 지운 TypeIdentifier입니다.
/// 내부적으로 Dictionary의 키로 사용됩니다.
public struct AnyTypeIdentifier: Hashable, Sendable {
  private let identifier: ObjectIdentifier
  internal let typeName: String

  /// TypeIdentifier로부터 AnyTypeIdentifier를 생성합니다.
  public init<T>(typeIdentifier typeId: TypeIdentifier<T>) {
    self.identifier = typeId.identifier
    self.typeName = typeId.typeName
  }

  /// 타입을 직접 받아 AnyTypeIdentifier를 생성합니다.
  public init<T>(type: T.Type) {
    self.identifier = ObjectIdentifier(type)
    self.typeName = String(describing: type)
  }

  /// 런타임 메타타입(Any.Type)으로부터 생성합니다.
  ///
  /// UnifiedRegistry의 `resolveAny(_:)` 등에서 사용되는 `Any.Type` 인자를
  /// 제네릭 추론 없이 안전하게 처리하기 위한 전용 이니셜라이저입니다.
  public init(anyType type: Any.Type) {
    self.identifier = ObjectIdentifier(type)
    self.typeName = String(describing: type)
  }

  /// Hashable 구현
  public func hash(into hasher: inout Hasher) {
    hasher.combine(identifier)
  }

  /// Equatable 구현
  public static func == (lhs: AnyTypeIdentifier, rhs: AnyTypeIdentifier) -> Bool {
    lhs.identifier == rhs.identifier
  }
}

// MARK: - TypeSafeRegistry

/// 타입 안전한 의존성 저장소입니다.
///
/// 기존 `[String: Any]` 방식 대신 타입 안전한 키를 사용하여
/// 컴파일 타임 타입 검증과 런타임 안전성을 모두 제공합니다.
///
/// ## 성능 최적화
/// - **Concurrent reads**: 여러 스레드가 동시에 resolve 수행 가능
/// - **Barrier writes**: 등록/삭제는 배리어로 직렬화
/// - **Lock-free factory execution**: 팩토리 실행은 락 외부에서 수행
internal final class TypeSafeRegistry: @unchecked Sendable {
  /// 타입별 팩토리 저장소
  private var factories = [AnyTypeIdentifier: Any]()

  /// 스레드 안전성을 위한 동기화 큐 (concurrent reads, barrier writes)
  private let syncQueue = DispatchQueue(label: "com.diContainer.typeSafeRegistry", attributes: .concurrent)

  /// 타입과 팩토리 클로저를 등록합니다.
  ///
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - factory: 인스턴스를 생성하는 팩토리 클로저 (@Sendable)
  /// - Returns: 해제 핸들러 클로저
  /// - Note: 메모리 안전성을 위해 weak reference 사용
  func register<T>(
    _ type: T.Type,
    factory: @Sendable @escaping () -> T
  ) -> @Sendable () -> Void {
    let key = AnyTypeIdentifier(type: type)

    // 등록은 배리어로 보호
    syncQueue.sync(flags: .barrier) {
      self.factories[key] = factory
    }

    // 🛡️ 메모리 안전성: weak self로 retain cycle 방지
    let releaseHandler: @Sendable () -> Void = { [weak self] in
      // weak self가 이미 deallocated된 경우 gracefully return
      guard let strongSelf = self else {
#if DEBUG
        #logDebug("⚠️ [TypeSafeRegistry] Registry deallocated, skipping release for \(type)")
#endif
        return
      }

      strongSelf.syncQueue.sync(flags: .barrier) {
        strongSelf.factories[key] = nil
#if DEBUG
        #logDebug("🗑️ [TypeSafeRegistry] Released registration for \(type)")
#endif
      }
    }
    return releaseHandler
  }

  /// 타입에 해당하는 인스턴스를 조회합니다.
  ///
  /// - Parameter type: 조회할 타입
  /// - Returns: 해당 타입의 인스턴스 또는 nil
  func resolve<T>(_ type: T.Type) -> T? {
    let key = AnyTypeIdentifier(type: type)

    // 🚀 성능 최적화: 읽기 전용 작업은 concurrent 큐에서 병렬 실행
    let anyFactory: Any? = syncQueue.sync {
      self.factories[key]
    }

    // 락 밖에서 팩토리 실행 (무거운 초기화/재귀 호출 시 교착상태 방지)
    guard let factory = anyFactory as? () -> T else {
      return nil
    }
    return factory()
  }

  /// 특정 타입의 등록을 해제합니다.
  ///
  /// - Parameter type: 해제할 타입
  func release<T>(_ type: T.Type) {
    let key = AnyTypeIdentifier(type: type)
    syncQueue.sync(flags: .barrier) {
      self.factories[key] = nil
    }
  }

  /// 인스턴스를 직접 등록합니다.
  ///
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - instance: 등록할 인스턴스
  /// - Note: 싱글톤 패턴으로 같은 인스턴스를 반환
  func register<T>(_ type: T.Type, instance: T) {
    let key = AnyTypeIdentifier(type: type)

    // 🔒 인스턴스를 클로저로 감싸서 메모리 안전성 확보
    syncQueue.sync(flags: .barrier) {
      // 인스턴스를 약한 참조가 아닌 값 복사로 저장하여 안전성 확보
      self.factories[key] = { instance }
    }
  }
}

// MARK: - Debug helpers
internal extension TypeSafeRegistry {
  /// 등록된 타입 개수 반환
  func registeredCount() -> Int {
    syncQueue.sync { factories.count }
  }

  /// 등록된 타입 이름 리스트 반환(정렬됨)
  func allTypeNames() -> [String] {
    syncQueue.sync { factories.keys.map { $0.typeName }.sorted() }
  }
}
