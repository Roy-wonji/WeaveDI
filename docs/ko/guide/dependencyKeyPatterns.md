# 의존성 키 패턴

안전한 의존성 해결을 위한 DependencyKey 패턴들을 정리합니다.

## 개요

WeaveDI의 DependencyKey는 의존성을 타입 안전하게 관리할 수 있는 핵심 메커니즘입니다. 이 가이드에서는 실제 프로덕션 환경에서 사용할 수 있는 안전하고 효과적인 패턴들을 소개합니다.

## 기본 패턴

### 1. 직접 등록 패턴

가장 기본적인 형태로, 앱 시작 시점에 직접 의존성을 등록하는 패턴입니다.

```swift
// Pre-registration at app startup + safe resolution
extension BookListUseCaseImpl: DependencyKey {
  public static var liveValue: BookListInterface = {
    guard let repo = WeaveDI.Container.live.resolve(BookListInterface.self) else {
      return DefaultBookListRepositoryImpl()
    }
    return BookListUseCaseImpl(repository: repo)
  }()
}
```

### 2. Factory 지연 초기화 패턴

Factory를 통해 의존성을 지연 생성하는 패턴으로, 복잡한 초기화 로직을 분리할 수 있습니다.

```swift
extension BookListUseCaseImpl: DependencyKey {
  public static var liveValue: BookListInterface = BookListUseCaseFactory.create()
}

enum BookListUseCaseFactory {
  static func create() -> BookListInterface {
    @Inject(\.bookListInterface) var repo: BookListInterface?
    return repo ?? DefaultBookListRepositoryImpl()
  }
}
```

## 고급 패턴

### 3. 조건부 등록 패턴

환경이나 조건에 따라 다른 구현체를 제공하는 패턴입니다.

```swift
extension APIClientKey: DependencyKey {
  public static var liveValue: APIClient {
    #if DEBUG
    return MockAPIClient()
    #else
    return ProductionAPIClient()
    #endif
  }
}
```

### 4. 비동기 등록 패턴

네트워크나 디스크 I/O가 필요한 의존성을 비동기로 등록하는 패턴입니다.

```swift
Task {
  await WeaveDI.Container.bootstrapAsync { c in
    c.register(BookListInterface.self) { BookListRepositoryImpl() }

    // 비동기 초기화가 필요한 경우
    let configService = await ConfigurationService.initialize()
    c.register(ConfigurationService.self) { configService }
  }
}
```

### 5. 스코프 기반 패턴

의존성의 생명주기를 명확히 관리하는 패턴입니다.

```swift
// Singleton 스코프
extension DatabaseManager: DependencyKey {
  public static var liveValue: DatabaseManager = DatabaseManager.shared
}

// Instance 스코프 (매번 새로운 인스턴스)
extension TemporaryCache: DependencyKey {
  public static var liveValue: TemporaryCache {
    TemporaryCache()
  }
}
```

## 베스트 프랙티스

### 안전한 해결 패턴

```swift
// ✅ 좋은 예: 안전한 fallback 제공
extension UserService: DependencyKey {
  public static var liveValue: UserServiceProtocol {
              WeaveDI.Container.live.resolve(UserServiceProtocol.self) ??
    DefaultUserService()
  }
}

// ❌ 피해야 할 예: force unwrap 사용
extension UserService: DependencyKey {
  public static var liveValue: UserServiceProtocol {
              WeaveDI.Container.live.resolve(UserServiceProtocol.self)! // 위험!
  }
}
```

### 타입 안전성 보장

```swift
// KeyPath를 활용한 타입 안전한 등록
await WeaveDI.Container.bootstrap { container in
  container.register(\.userService) { UserServiceImpl() }
  container.register(\.apiClient) { APIClientImpl() }
}

// DependencyKey 확장
extension WeaveDI.Container {
  var userService: UserServiceProtocol {
    get { self[UserServiceKey.self] }
    set { self[UserServiceKey.self] = newValue }
  }
}
```

### 테스트 지원 패턴

```swift
extension UserService: DependencyKey {
  public static var liveValue: UserServiceProtocol = UserServiceImpl()

  #if DEBUG
  public static var testValue: UserServiceProtocol = MockUserService()
  #endif
}

// 테스트에서 사용
func testUserLogin() {
  WeaveDI.Container.test.userService = MockUserService()
  // 테스트 로직...
}
```

## 성능 고려사항

### 1. 지연 초기화 활용

```swift
extension ExpensiveService: DependencyKey {
  public static var liveValue: ExpensiveServiceProtocol = {
    // 실제 사용 시점에 초기화
    ExpensiveServiceImpl()
  }()
}
```

### 2. 캐싱 패턴

```swift
extension CachedService: DependencyKey {
  private static let _cachedInstance = CachedServiceImpl()

  public static var liveValue: CachedServiceProtocol {
    _cachedInstance
  }
}
```

## 마이그레이션 가이드

기존 DI 프레임워크에서 WeaveDI로 마이그레이션할 때 유용한 패턴들:

```swift
// 기존 Swinject 패턴을 WeaveDI로 변환
// Before (Swinject)
container.register(UserServiceProtocol.self) { _ in UserServiceImpl() }

// After (WeaveDI)
extension UserServiceKey: DependencyKey {
  public static var liveValue: UserServiceProtocol = UserServiceImpl()
}
```

이러한 패턴들을 활용하여 안전하고 유지보수 가능한 의존성 주입 코드를 작성할 수 있습니다.
