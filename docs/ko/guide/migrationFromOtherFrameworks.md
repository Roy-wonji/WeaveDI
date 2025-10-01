# 다른 DI 프레임워크에서 마이그레이션

인기 있는 Swift 의존성 주입 프레임워크에서 WeaveDI로 마이그레이션하는 완전한 가이드입니다.

## 개요

이 가이드는 다음 프레임워크들로부터의 마이그레이션을 다룹니다:
- **Swinject** - 가장 인기 있는 DI 프레임워크
- **Factory** - 모던 프로퍼티 래퍼 기반 DI
- **Resolver** - 경량 DI 컨테이너

## Swinject에서 마이그레이션

### 주요 차이점

| 기능 | Swinject | WeaveDI |
|------|----------|---------|
| 등록 | Container API | Container + InjectedKey |
| 해결 | `resolve()` | `@Injected` + `resolve()` |
| 스코프 | Graph, Container, Transient | Singleton, Session, Transient |
| 스레드 안전성 | 락 기반 | 락-프리 + TypeID |
| 동시성 | 제한적 | Swift Concurrency 네이티브 |
| 프로퍼티 래퍼 | 사용 불가 | `@Injected`, `@Factory` |

### 등록 마이그레이션

**이전 (Swinject):**
```swift
import Swinject

let container = Container()

// 간단한 등록
container.register(UserService.self) { _ in
    UserServiceImpl()
}

// 의존성 포함
container.register(OrderService.self) { resolver in
    let userService = resolver.resolve(UserService.self)!
    return OrderServiceImpl(userService: userService)
}

// 스코프 포함
container.register(APIClient.self) { _ in
    URLSessionAPIClient()
}.inObjectScope(.container)
```

**이후 (WeaveDI):**
```swift
import WeaveDI

// 앱 시작 시 부트스트랩
await WeaveDI.Container.bootstrap { container in
    // 간단한 등록
    container.register(UserService.self) {
        UserServiceImpl()
    }

    // 의존성 포함 (자동 해결)
    container.register(OrderService.self) {
        OrderServiceImpl()
    }

    // 스코프 포함
    container.register(APIClient.self, scope: .singleton) {
        URLSessionAPIClient()
    }
}

// 또는 프로퍼티 래퍼 지원을 위해 InjectedKey 사용
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    static var testValue: UserService = MockUserService()
}

extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}
```

### 해결 마이그레이션

**이전 (Swinject):**
```swift
class ViewController {
    let userService: UserService
    let orderService: OrderService

    init(resolver: Resolver) {
        self.userService = resolver.resolve(UserService.self)!
        self.orderService = resolver.resolve(OrderService.self)!
    }

    // 또는 프로퍼티 주입으로
    var userService: UserService!
}
```

**이후 (WeaveDI):**
```swift
class ViewController {
    @Injected(\.userService) var userService
    @Injected(\.orderService) var orderService

    init() {
        // 의존성이 자동으로 주입됨
    }
}

// 또는 수동 해결
class ViewController {
    let userService: UserService
    let orderService: OrderService

    init() async {
        self.userService = await UnifiedDI.resolve(UserService.self)!
        self.orderService = await UnifiedDI.resolve(OrderService.self)!
    }
}
```

## 다음 단계

- [빠른 시작](./quickStart) - WeaveDI 시작하기
- [모범 사례](./bestPractices) - WeaveDI 모범 사례 학습
- [테스트 가이드](../tutorial/testing) - 테스트 전략 업데이트
- [TCA 통합](./tcaIntegration) - 모던 아키텍처 패턴