---
title: DIActor
lang: en-US
---

# DIActor

Thread-safe DI operations을 위한 Actor 기반 구현
## 특징:
- **Actor 격리**: Swift Concurrency 완전 준수
- **Type Safety**: 컴파일 타임 타입 안전성
- **Memory Safety**: 자동 메모리 관리
- **Performance**: 최적화된 동시 접근
## 사용법:
```swift
// Async/await 패턴으로 사용
let diActor = DIActor.shared
await diActor.register(ServiceProtocol.self) { ServiceImpl() }
let service = await diActor.resolve(ServiceProtocol.self)
```

```swift
public actor DIActor {
}
```

  /// 타입 안전한 팩토리 저장소
  /// 등록된 타입들의 생성 시간 추적 (디버깅용)
  /// 해제 핸들러들을 저장 (메모리 관리)
  /// 싱글톤 인스턴스 저장소
  /// 공유(싱글톤) 타입 집합
  /// 스코프별 인스턴스 저장소
  /// 자주 사용되는 타입의 사용 횟수 추적
  /// Hot path 캐시 - 자주 사용되는 타입들 (10회 이상 사용된 타입)
  /// 마지막 정리 시간 (메모리 관리용)
  /// 타입과 팩토리 클로저를 등록합니다.
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - factory: 인스턴스를 생성하는 팩토리 클로저
  /// - Returns: 등록 해제 핸들러
  /// 인스턴스를 직접 등록합니다.
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - instance: 등록할 인스턴스
  /// Shared Actor 인스턴스로 타입을 등록합니다. (권장)
  /// 전통적인 싱글톤 대신 Actor 기반 공유 인스턴스를 제공합니다.
  /// Actor의 격리성을 통해 자동으로 thread-safety를 보장합니다.
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - factory: 인스턴스를 생성하는 팩토리 클로저 (한 번만 실행됨)
  /// - Returns: 등록 해제 핸들러
  /// Shared Actor 인스턴스를 해제합니다.
  /// 등록된 타입의 인스턴스를 해결합니다. (최적화된 버전)
  /// - Parameter type: 해결할 타입
  /// - Returns: 해결된 인스턴스 또는 nil
  /// 캐시 정리를 수행합니다
  /// Result 패턴으로 타입을 해결합니다.
  /// - Parameter type: 해결할 타입
  /// - Returns: 성공 시 인스턴스, 실패 시 DIError
  /// throwing 방식으로 타입을 해결합니다.
  /// - Parameter type: 해결할 타입
  /// - Returns: 해결된 인스턴스
  /// - Throws: DIError.dependencyNotFound
  /// 특정 타입의 등록을 해제합니다.
  /// - Parameter type: 해제할 타입
  /// 모든 등록을 해제합니다.
  /// 등록된 타입 개수를 반환합니다.
  /// 등록된 모든 타입 이름을 반환합니다.
  /// 등록 상태를 자세히 출력합니다.
Global API for DIActor to provide seamless async/await interface

```swift
public enum DIActorGlobalAPI {
}
```

  /// Register a dependency using DIActor
  /// Resolve a dependency using DIActor
  /// Resolve with Result pattern using DIActor
  /// Resolve with throwing using DIActor
  /// Release a specific type using DIActor
  /// Release all registrations using DIActor
기존 코드를 Actor 기반으로 마이그레이션하기 위한 브리지
## 마이그레이션 예시:
```swift
// OLD (DispatchQueue 기반):
DI.register(Service.self) { ServiceImpl() }
let service = DI.resolve(Service.self)
// NEW (Actor 기반):
await DIActorBridge.register(Service.self) { ServiceImpl() }
let service = await DIActorBridge.resolve(Service.self)
```

```swift
public enum DIActorBridge {
}
```

  /// 기존 DI API를 Actor 기반으로 브리지
  /// 기존 코드와 호환성을 위한 동기 래퍼 (과도기용)
  /// - Warning: 메인 스레드에서만 사용하세요
  /// 기존 코드와 호환성을 위한 동기 래퍼 (과도기용)
  /// - Warning: 메인 스레드에서만 사용하세요
