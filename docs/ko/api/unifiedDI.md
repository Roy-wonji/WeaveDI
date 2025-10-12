# UnifiedDI

## 개요

`UnifiedDI`는 현대적이고 직관적인 의존성 주입 API입니다. 복잡한 기능들을 제거하고 핵심 기능에만 집중하여 이해하기 쉽고 사용하기 간편합니다.

## 설계 철학

- **단순함이 최고**: 복잡한 기능보다 명확한 API
- **타입 안전성**: 컴파일 타임에 모든 오류 검증
- **직관적 사용**: 코드만 봐도 이해할 수 있는 API

## 기본 사용법

```swift
// 1. 등록하고 즉시 사용
let repository = UnifiedDI.register(UserRepository.self) {
    UserRepositoryImpl()
}

// 2. 나중에 조회
let service = UnifiedDI.resolve(UserService.self)

// 3. 필수 의존성 (실패 시 크래시)
let logger = UnifiedDI.requireResolve(Logger.self)
```

## 핵심 API

### 등록 메서드

#### `register(_:factory:)`

의존성을 등록하고 즉시 생성된 인스턴스를 반환합니다 (권장 방식).

```swift
public static func register<T>(
    _ type: T.Type,
    factory: @escaping @Sendable () -> T
) -> T where T: Sendable
```

**사용법:**
```swift
let repository = UnifiedDI.register(UserRepository.self) {
    UserRepositoryImpl()
}
// repository를 바로 사용 가능
```

#### `registerAsync(_:factory:)`

`@DIContainerActor`를 사용한 스레드 안전한 비동기 의존성 등록.

```swift
public static func registerAsync<T>(
    _ type: T.Type,
    factory: @escaping @Sendable () async -> T
) async -> T where T: Sendable
```

**사용법:**
```swift
Task {
    let instance = await UnifiedDI.registerAsync(UserService.self) {
        UserServiceImpl()
    }
    // instance를 바로 사용 가능
}
```

### 해결 메서드

#### `resolve(_:)`

의존성을 안전하게 해결하며, 등록되지 않은 경우 `nil` 반환.

```swift
public static func resolve<T>(_ type: T.Type) -> T? where T: Sendable
```

**사용법:**
```swift
if let service = UnifiedDI.resolve(UserService.self) {
    // 서비스 사용
} else {
    // 대체 로직 수행
}
```

#### `resolveAsync(_:)`

`@DIContainerActor`를 사용한 비동기 의존성 해결.

```swift
public static func resolveAsync<T>(_ type: T.Type) async -> T? where T: Sendable
```

**사용법:**
```swift
Task {
    if let service = await UnifiedDI.resolveAsync(UserService.self) {
        // 서비스 사용
    }
}
```

#### `requireResolve(_:)`

필수 의존성을 해결하며, 등록되지 않은 경우 명확한 에러 메시지와 함께 크래시.

```swift
public static func requireResolve<T>(_ type: T.Type) -> T where T: Sendable
```

**⚠️ 주의사항:** 프로덕션 환경에서는 `resolve(_:)` 사용을 권장합니다.

**사용법:**
```swift
let logger = UnifiedDI.requireResolve(Logger.self)
// logger는 항상 유효한 인스턴스
```

#### `resolve(_:default:)`

기본값과 함께 의존성을 해결 (항상 성공).

```swift
public static func resolve<T>(
    _ type: T.Type,
    default defaultValue: @autoclosure () -> T
) -> T where T: Sendable
```

**사용법:**
```swift
let logger = UnifiedDI.resolve(Logger.self, default: ConsoleLogger())
// logger는 항상 유효한 인스턴스
```

### 관리 메서드

#### `release(_:)`

컨테이너에서 특정 의존성을 제거.

```swift
public static func release<T>(_ type: T.Type) where T: Sendable
```

**사용법:**
```swift
UnifiedDI.release(UserService.self)
// 이후 resolve 호출 시 nil 반환
```

#### `releaseAll()`

등록된 모든 의존성을 제거 (주로 테스트용).

```swift
public static func releaseAll()
```

**⚠️ 주의사항:** 메인 스레드에서만 호출해야 합니다.

**사용법:**
```swift
// 테스트 setUp에서
override func setUp() {
    super.setUp()
    UnifiedDI.releaseAll()
}
```

## 고급 기능

### 성능 최적화

UnifiedDI는 내장 성능 최적화 기능을 포함합니다:

```swift
// 성능 추적 활성화 (디버그 모드만)
#if DEBUG && DI_MONITORING_ENABLED
UnifiedDI.enableOptimization()
let stats = await UnifiedDI.getPerformanceStats()
#endif
```

### 컴포넌트 진단

설정 문제 자동 감지:

```swift
let diagnostics = UnifiedDI.analyzeComponentMetadata()
if !diagnostics.issues.isEmpty {
    print("⚠️ 설정 문제 발견:")
    for issue in diagnostics.issues {
        print("  - \(issue.type): \(issue.detail ?? "")")
    }
}
```

## 통합 예시

### SwiftUI 통합

```swift
import SwiftUI

struct ContentView: View {
    private let userService = UnifiedDI.resolve(
        UserService.self,
        default: MockUserService()
    )

    var body: some View {
        Text("사용자: \(userService.currentUser.name)")
    }
}
```

### TCA 통합

```swift
import ComposableArchitecture

struct AppFeature: Reducer {
    struct State: Equatable {
        // 상태 정의
    }

    enum Action {
        // 액션 정의
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            let userService = UnifiedDI.requireResolve(UserService.self)
            // userService 사용
            return .none
        }
    }
}
```

### 테스트 설정

```swift
import XCTest
import WeaveDI

class UserServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()

        // 이전 등록 해제
        UnifiedDI.releaseAll()

        // 테스트 의존성 등록
        _ = UnifiedDI.register(UserRepository.self) {
            MockUserRepository()
        }

        _ = UnifiedDI.register(UserService.self) {
            UserServiceImpl(
                repository: UnifiedDI.requireResolve(UserRepository.self)
            )
        }
    }

    func testUserCreation() {
        let service = UnifiedDI.requireResolve(UserService.self)
        let user = service.createUser(name: "테스트 사용자")
        XCTAssertEqual(user.name, "테스트 사용자")
    }
}
```

## 오류 처리

### 일반적인 오류 패턴

```swift
// ❌ 피하기: 등록되지 않은 경우 크래시
let service = UnifiedDI.requireResolve(UnregisteredService.self)

// ✅ 개선: 안전한 해결과 대체 처리
let service = UnifiedDI.resolve(UnregisteredService.self) ?? DefaultService()

// ✅ 최선: 기본값과 함께 해결
let service = UnifiedDI.resolve(UnregisteredService.self, default: DefaultService())
```

### 디버그 정보

```swift
#if DEBUG
// 의존성이 등록되었는지 확인
if UnifiedDI.resolve(SomeService.self) == nil {
    print("⚠️ SomeService가 등록되지 않았습니다")
}

// 설정 문제 분석
let diagnostics = UnifiedDI.analyzeComponentMetadata()
for issue in diagnostics.issues {
    print("🔍 문제: \(issue.type) - \(issue.detail ?? "")")
}
#endif
```

## 모범 사례

### 1. 등록 순서

의존성 순서에 따라 등록 (의존성을 먼저):

```swift
// ✅ 좋음: 의존성을 먼저 등록
_ = UnifiedDI.register(APIClient.self) {
    APIClientImpl()
}

_ = UnifiedDI.register(UserRepository.self) {
    UserRepositoryImpl(
        apiClient: UnifiedDI.requireResolve(APIClient.self)
    )
}

_ = UnifiedDI.register(UserService.self) {
    UserServiceImpl(
        repository: UnifiedDI.requireResolve(UserRepository.self)
    )
}
```

### 2. 프로덕션에서 안전한 해결 사용

```swift
// ✅ 프로덕션: 안전한 해결
guard let service = UnifiedDI.resolve(CriticalService.self) else {
    // 우아하게 처리
    return
}

// ✅ 개발: 디버깅을 위한 빠른 실패
#if DEBUG
let service = UnifiedDI.requireResolve(CriticalService.self)
#else
guard let service = UnifiedDI.resolve(CriticalService.self) else {
    // 대체 로직
    return
}
#endif
```

### 3. 중앙집중식 등록

```swift
enum DependencyContainer {
    static func registerAll() {
        registerNetworking()
        registerRepositories()
        registerServices()
    }

    private static func registerNetworking() {
        _ = UnifiedDI.register(HTTPClient.self) {
            URLSessionHTTPClient()
        }

        _ = UnifiedDI.register(APIClient.self) {
            APIClientImpl(
                httpClient: UnifiedDI.requireResolve(HTTPClient.self)
            )
        }
    }

    private static func registerRepositories() {
        _ = UnifiedDI.register(UserRepository.self) {
            UserRepositoryImpl(
                apiClient: UnifiedDI.requireResolve(APIClient.self)
            )
        }
    }

    private static func registerServices() {
        _ = UnifiedDI.register(UserService.self) {
            UserServiceImpl(
                repository: UnifiedDI.requireResolve(UserRepository.self)
            )
        }
    }
}
```

## 관련 API

- [`@Injected`](./injected.md) - 의존성 주입을 위한 프로퍼티 래퍼
- [`DIAdvanced`](./diAdvanced.md) - 고급 의존성 주입 기능
- [`ComponentDiagnostics`](./componentDiagnostics.md) - 자동 이슈 감지
- [`성능 최적화`](./performanceOptimizations.md) - 성능 모니터링 및 최적화

---

*UnifiedDI는 WeaveDI v3.3.0+에서 권장되는 의존성 주입 API입니다*