---
title: DIActor
lang: ko-KR
---

# DIActor

Thread-safe DI operations을 위한 Actor 기반 구현

## 특징
- **Actor 격리**: Swift Concurrency 완전 준수
- **Type Safety**: 컴파일 타임 타입 안전성
- **Memory Safety**: 자동 메모리 관리
- **Performance**: 최적화된 동시 접근

## 기본 사용법

```swift
import WeaveDI

// Async/await 패턴으로 사용
let diActor = DIActor.shared
await diActor.register(ServiceProtocol.self) { ServiceImpl() }
let service = await diActor.resolve(ServiceProtocol.self)
```

## 핵심 API

```swift
@globalActor
public actor DIActor {
    public static let shared = DIActor()

    // MARK: - 등록

    /// 팩토리 클로저로 타입 등록
    public func register<T>(
        _ type: T.Type,
        factory: @escaping @Sendable () -> T
    ) -> @Sendable () async -> Void

    /// Sendable 인스턴스를 직접 등록
    public func register<T>(_ type: T.Type, instance: T) where T: Sendable

    /// 공유 actor 인스턴스로 등록 (권장)
    public func registerSharedActor<T>(
        _ type: T.Type,
        factory: @escaping @Sendable () -> T
    ) -> @Sendable () async -> Void where T: Sendable

    // MARK: - 해결

    /// 타입 해결 (옵셔널 반환)
    public func resolve<T>(_ type: T.Type) -> T?

    /// Result 패턴으로 해결
    public func resolveResult<T>(_ type: T.Type) -> Result<T, DIError>

    /// throwing 방식으로 해결
    public func resolveThrows<T>(_ type: T.Type) throws -> T

    // MARK: - 해제

    /// 특정 타입 해제
    public func release<T>(_ type: T.Type)

    /// 모든 등록 해제
    public func releaseAll()

    // MARK: - 검사

    /// 등록된 타입 개수 반환
    public func registeredCount() -> Int

    /// 등록된 모든 타입 이름 반환
    public func allRegisteredTypes() -> [String]

    /// 등록 상태를 자세히 출력
    public func printStatus()
}
```

## 등록 패턴

### 기본 팩토리 등록

```swift
// 팩토리 클로저로 등록
await DIActor.shared.register(UserService.self) {
    UserServiceImpl()
}

// 필요할 때 해결
if let service = await DIActor.shared.resolve(UserService.self) {
    await service.fetchUsers()
}
```

### 인스턴스 등록

```swift
// Sendable 인스턴스를 직접 등록
let config = AppConfig(apiKey: "key123", timeout: 30)
await DIActor.shared.register(AppConfig.self, instance: config)

// 동일한 인스턴스 해결
let resolvedConfig = await DIActor.shared.resolve(AppConfig.self)
print(resolvedConfig?.apiKey) // "key123"
```

### 공유 Actor 등록 (권장)

```swift
// 공유 actor로 등록 (싱글톤과 유사하지만 스레드 안전)
let releaseHandler = await DIActor.shared.registerSharedActor(DatabaseService.self) {
    DatabaseService()
}

// 모든 해결은 동일한 인스턴스를 반환 (한 번만 생성됨)
let db1 = await DIActor.shared.resolve(DatabaseService.self)
let db2 = await DIActor.shared.resolve(DatabaseService.self)
// db1과 db2는 동일한 인스턴스

// 완료 시 해제
await releaseHandler()
```

## 해결 패턴

### 옵셔널 해결

```swift
// 옵셔널 반환
if let service = await DIActor.shared.resolve(UserService.self) {
    await service.performAction()
} else {
    print("서비스가 등록되지 않았습니다")
}
```

### Result 패턴

```swift
// Result<T, DIError> 반환
let result = await DIActor.shared.resolveResult(UserService.self)
switch result {
case .success(let service):
    await service.performAction()
case .failure(let error):
    print("해결 실패: \(error)")
}
```

### Throwing 패턴

```swift
// DIError를 throw
do {
    let service = try await DIActor.shared.resolveThrows(UserService.self)
    await service.performAction()
} catch {
    print("해결 실패: \(error)")
}
```

## 성능 기능

### Hot Path 캐시

DIActor는 자주 사용되는 타입(10회 이상 해결)을 자동으로 캐시하여 더 빠른 접근을 제공합니다:

```swift
// 첫 번째 해결: 일반 속도
let service1 = await DIActor.shared.resolve(UserService.self)

// 10회 이상 해결 후: 캐시됨, 훨씬 빠름
for _ in 1...20 {
    let service = await DIActor.shared.resolve(UserService.self)
    // 10번째 해결 후 캐시된 접근
}
```

### 사용량 추적

```swift
// DIActor는 모든 타입의 사용 횟수를 추적합니다
await DIActor.shared.printStatus()
// 출력에 사용 횟수 포함:
// UserService: 23회 해결
// DatabaseService: 15회 해결
```

## Global API

편의를 위해 WeaveDI는 내부적으로 DIActor를 사용하는 global API를 제공합니다:

```swift
public enum DIActorGlobalAPI {
    /// DIActor를 사용하여 의존성 등록
    public static func register<T>(
        _ type: T.Type,
        factory: @escaping @Sendable () -> T
    ) async -> @Sendable () async -> Void

    /// DIActor를 사용하여 의존성 해결
    public static func resolve<T>(_ type: T.Type) async -> T?

    /// Result 패턴으로 해결
    public static func resolveResult<T>(_ type: T.Type) async -> Result<T, DIError>

    /// throwing 방식으로 해결
    public static func resolveThrows<T>(_ type: T.Type) async throws -> T

    /// 특정 타입 해제
    public static func release<T>(_ type: T.Type) async

    /// 모든 등록 해제
    public static func releaseAll() async
}
```

### Global API 사용

```swift
import WeaveDI

// Global API를 통한 등록
await DIActorGlobalAPI.register(UserService.self) {
    UserServiceImpl()
}

// Global API를 통한 해결
let service = await DIActorGlobalAPI.resolve(UserService.self)
```

## 마이그레이션 브리지

기존 DispatchQueue 기반 코드를 Actor 기반으로 마이그레이션하기 위한 브리지:

```swift
public enum DIActorBridge {
    /// 기존 DI API를 Actor 기반으로 브리지
    public static func register<T>(
        _ type: T.Type,
        factory: @escaping @Sendable () -> T
    ) async

    /// 호환성을 위한 동기 래퍼 (과도기용)
    /// - Warning: 메인 스레드에서만 사용하세요
    public static func registerSync<T>(
        _ type: T.Type,
        factory: @escaping () -> T
    )

    /// 호환성을 위한 동기 래퍼 (과도기용)
    /// - Warning: 메인 스레드에서만 사용하세요
    public static func resolveSync<T>(_ type: T.Type) -> T?
}
```

### 마이그레이션 예시

```swift
// OLD (DispatchQueue 기반):
DI.register(Service.self) { ServiceImpl() }
let service = DI.resolve(Service.self)

// NEW (Actor 기반):
await DIActorBridge.register(Service.self) { ServiceImpl() }
let service = await DIActorBridge.resolve(Service.self)
```

## 메모리 관리

### 자동 정리

DIActor는 주기적으로 hot cache를 자동으로 정리합니다:

```swift
// 정리는 메모리 압력에 따라 자동으로 발생합니다
// 수동 개입이 필요하지 않습니다
```

### 수동 해제

```swift
// 특정 타입 해제
await DIActor.shared.release(UserService.self)

// 모든 타입 해제
await DIActor.shared.releaseAll()

// 해제 핸들러 사용
let releaseHandler = await DIActor.shared.register(Service.self) {
    ServiceImpl()
}

// 나중에 해제하고 싶을 때
await releaseHandler()
```

## 스코프 인스턴스

DIActor는 생명주기 관리를 위한 스코프 인스턴스를 지원합니다:

```swift
// 스코프 인스턴스는 스코프 식별자별로 저장됩니다
// 기능 수준 또는 화면 수준 생명주기에 유용합니다

// DIActor에서 내부적으로 구현 처리
// scope 매개변수와 함께 WeaveDI.Container.resolve()를 통해 접근
```

## 검사 및 디버깅

### 등록 상태 출력

```swift
await DIActor.shared.printStatus()
// 출력:
// 📊 [DIActor] Registration Status:
// • UserService (2025-10-01 10:30:00에 등록, 15회 해결)
// • DatabaseService (2025-10-01 10:30:01에 등록, 8회 해결, 공유됨)
// • NetworkService (2025-10-01 10:30:02에 등록, 3회 해결)
```

### 등록된 타입 개수

```swift
let count = await DIActor.shared.registeredCount()
print("총 등록된 타입: \(count)")
```

### 모든 타입 목록

```swift
let types = await DIActor.shared.allRegisteredTypes()
print("등록된 타입:")
for typeName in types {
    print("  - \(typeName)")
}
```

## 모범 사례

1. **싱글톤에 공유 Actor 선호**: 수동으로 싱글톤을 관리하는 대신 `registerSharedActor()`를 사용하세요
2. **Async/Await 사용**: DIActor 작업에는 항상 `await`를 사용하세요
3. **해제 핸들러 저장**: 나중에 등록 해제가 필요한 경우 해제 핸들러를 보관하세요
4. **올바른 해결 패턴 선택**: 선택적 의존성에는 optional을, 필수 의존성에는 throwing을 사용하세요
5. **프로덕션에서 Sync 래퍼 피하기**: 마이그레이션 중에만 `DIActorBridge.Sync` 메서드를 사용하세요
6. **사용량 모니터링**: 개발 중에 `printStatus()`를 사용하여 사용 패턴을 이해하세요

## WeaveDI.Container와의 통합

DIActor는 스레드 안전 작업을 위해 WeaveDI.Container에서 내부적으로 사용됩니다:

```swift
// WeaveDI.Container는 내부적으로 DIActor를 사용합니다
await WeaveDI.Container.bootstrap { container in
    // 이것은 내부적으로 DIActor를 사용합니다
    container.register(UserService.self) {
        UserServiceImpl()
    }
}

// 고급 사용 사례를 위한 직접 DIActor 접근
let service = await DIActor.shared.resolve(UserService.self)
```

## 참고 자료

- [WeaveDI.Container](./coreApis.md) - 고수준 컨테이너 API
- [AutoDIOptimizer](./autoDiOptimizer.md) - 자동 최적화 시스템
- [Performance Monitoring](./performanceMonitoring.md) - 성능 추적 도구
