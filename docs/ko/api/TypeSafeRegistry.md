---
title: TypeSafeRegistry
lang: ko-KR
---

# TypeSafeRegistry

타입 안전한 키를 제공하는 구조체입니다.
기존 String 키 방식의 단점을 보완하여 컴파일 타임 타입 안전성을 제공합니다.

```swift
public struct TypeIdentifier<T>: Hashable {
  /// 타입의 고유 식별자
  internal let identifier: ObjectIdentifier
}
```

  /// 디버깅을 위한 타입 이름
  /// 타입을 기반으로 TypeIdentifier를 생성합니다.
  /// - Parameter type: 식별할 타입
  /// Hashable 구현
  /// Equatable 구현
타입 정보를 지운 TypeIdentifier입니다.
내부적으로 Dictionary의 키로 사용됩니다.

```swift
public struct AnyTypeIdentifier: Hashable, Sendable {
  private let identifier: ObjectIdentifier
  internal let typeName: String
}
```

  /// TypeIdentifier로부터 AnyTypeIdentifier를 생성합니다.
  /// 타입을 직접 받아 AnyTypeIdentifier를 생성합니다.
  /// 런타임 메타타입(Any.Type)으로부터 생성합니다.
  /// UnifiedRegistry의 `resolveAny(_:)` 등에서 사용되는 `Any.Type` 인자를
  /// 제네릭 추론 없이 안전하게 처리하기 위한 전용 이니셜라이저입니다.
  /// Hashable 구현
  /// Equatable 구현
타입 안전한 의존성 저장소입니다.
기존 `[String: Any]` 방식 대신 타입 안전한 키를 사용하여
컴파일 타임 타입 검증과 런타임 안전성을 모두 제공합니다.
## 성능 최적화
- **Concurrent reads**: 여러 스레드가 동시에 resolve 수행 가능
- **Barrier writes**: 등록/삭제는 배리어로 직렬화
- **Lock-free factory execution**: 팩토리 실행은 락 외부에서 수행
  /// 타입별 팩토리 저장소
  /// 스레드 안전성을 위한 동기화 큐 (concurrent reads, barrier writes)
  /// 타입과 팩토리 클로저를 등록합니다.
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - factory: 인스턴스를 생성하는 팩토리 클로저 (@Sendable)
  /// - Returns: 해제 핸들러 클로저
  /// - Note: 메모리 안전성을 위해 weak reference 사용
  /// 타입에 해당하는 인스턴스를 조회합니다.
  /// - Parameter type: 조회할 타입
  /// - Returns: 해당 타입의 인스턴스 또는 nil
  /// 특정 타입의 등록을 해제합니다.
  /// - Parameter type: 해제할 타입
  /// 인스턴스를 직접 등록합니다.
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - instance: 등록할 인스턴스
  /// - Note: 싱글톤 패턴으로 같은 인스턴스를 반환
  /// 등록된 타입 개수 반환
  /// 등록된 타입 이름 리스트 반환(정렬됨)
