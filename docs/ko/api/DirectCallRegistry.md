---
title: DirectCallRegistry
lang: ko-KR
---

# DirectCallRegistry

팩토리 체이닝 없는 직접 호출 레지스트리
기존: Factory → Factory → Factory (체이닝)
개선: Type → 직접 인스턴스 생성 (No 체이닝)

```swift
public final class DirectCallRegistry: @unchecked Sendable {
}
```

  /// 타입별 직접 생성자
  /// 직접 인스턴스 저장 (싱글톤)
  /// 직접 팩토리 저장 (트랜지언트) - 체이닝 없음
  /// 직접 해결 (체이닝 없는 호출)
  /// 제거
의존성 체인을 플래튼화하는 최적화

```swift
public final class FlattenedDependencyRegistry: @unchecked Sendable {
}
```

  /// 의존성 체인을 플래튼화하여 등록
  /// 플래튼화된 해결 (한 번의 호출)
모든 최적화를 통합한 DI 컨테이너

```swift
public final class UltimateDI: @unchecked Sendable {
}
```

  /// 최적화된 등록 - 자동으로 최적 경로 선택
  /// 최적화된 등록 - 단순 팩토리
  /// 최적화된 등록 - 복잡한 의존성 체인
  /// 최적화된 해결 - 자동으로 최적 경로 시도
  /// 강제 직접 호출 해결
  /// 제거
  /// 모든 저장소 클리어
직접 등록

```swift
public func setDirect<T>(_ type: T.Type, to instance: T) {
  UltimateDI.shared.register(type, instance: instance)
}
```

직접 팩토리 등록

```swift
public func setDirect<T>(_ type: T.Type, factory: @escaping () -> T) {
  UltimateDI.shared.register(type, factory: factory)
}
```

직접 해결

```swift
public func getDirect<T>(_ type: T.Type) -> T? {
  return UltimateDI.shared.resolve(type)
}
```

복잡한 의존성 등록 (플래튼화)

```swift
public func setComplex<T>(_ type: T.Type, dependencies: [Any.Type], build: @escaping () -> T) {
  UltimateDI.shared.registerComplex(type, dependencies: dependencies, buildChain: build)
}
```

  /// 최적화 모드 활성화
  /// 최적화된 해결 (fallback 체인)
