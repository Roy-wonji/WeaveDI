# DependencyValues 통합 예제

실제 시나리오에서 WeaveDI를 swift-dependencies와 통합하여 사용하는 방법을 보여주는 완전한 예제입니다.

## 개요

이 가이드는 WeaveDI의 `@Injected` 프로퍼티 래퍼를 `InjectedValues`와 함께 사용하고 Point-Free의 `swift-dependencies`와 연동하여 최대한의 호환성을 얻는 실용적인 예제를 제공합니다.

## 기본 설정

### 1. 서비스 프로토콜 정의

```swift
import WeaveDI
import Dependencies

protocol UserService: Sendable {
    func fetchUser(id: String) async throws -> User
    func saveUser(_ user: User) async throws
}

protocol LoggingService: Sendable {
    func log(_ message: String, level: LogLevel)
}

protocol CacheService: Sendable {
    func get<T: Codable>(_ key: String, type: T.Type) async -> T?
    func set<T: Codable>(_ key: String, value: T) async
}
```

### 2. InjectedKey 정의

```swift
struct UserServiceKey: InjectedKey {
    static let liveValue: UserService = LiveUserService()
    static let testValue: UserService = MockUserService()
}

struct LoggingServiceKey: InjectedKey {
    static let liveValue: LoggingService = ConsoleLoggingService()
    static let testValue: LoggingService = NoOpLoggingService()
}

struct CacheServiceKey: InjectedKey {
    static let liveValue: CacheService = InMemoryCacheService()
    static let testValue: CacheService = NoOpCacheService()
}
```

### 3. InjectedValues 확장 (KeyPath 지원)

```swift
extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }

    var loggingService: LoggingService {
        get { self[LoggingServiceKey.self] }
        set { self[LoggingServiceKey.self] = newValue }
    }

    var cacheService: CacheService {
        get { self[CacheServiceKey.self] }
        set { self[CacheServiceKey.self] = newValue }
    }
}
```

### 4. Swift-Dependencies 브리지 (선택사항)

```swift
extension DependencyValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }

    var loggingService: LoggingService {
        get { self[LoggingServiceKey.self] }
        set { self[LoggingServiceKey.self] = newValue }
    }

    var cacheService: CacheService {
        get { self[CacheServiceKey.self] }
        set { self[CacheServiceKey.self] = newValue }
    }
}
```

## 실제 사용 예제

### 여러 주입 패턴을 사용하는 UserManager 클래스

```swift
class UserManager {
    // 방법 1: 직접 타입 주입 (가장 안전함)
    @Injected(UserServiceKey.self) private var userService

    // 방법 2: KeyPath 기반 주입 (권장)
    @Injected(\.loggingService) private var logger

    // 방법 3: swift-dependencies 스타일 (TCA 호환)
    @Dependency(\.cacheService) private var cache

    func loadUser(id: String) async throws -> User {
        logger.log("사용자 ID로 로딩: \(id)", level: .info)

        // 캐시 먼저 확인
        if let cachedUser = await cache.get("user_\(id)", type: User.self) {
            logger.log("캐시에서 사용자 발견", level: .debug)
            return cachedUser
        }

        // 서비스에서 가져오기
        guard let service = userService else {
            throw UserManagerError.serviceUnavailable
        }

        let user = try await service.fetchUser(id: id)

        // 결과 캐싱
        await cache.set("user_\(user.id)", value: user)
        logger.log("사용자 로딩 및 캐싱 완료", level: .info)

        return user
    }

    func saveUser(_ user: User) async throws {
        logger.log("사용자 저장: \(user.name)", level: .info)

        guard let service = userService else {
            throw UserManagerError.serviceUnavailable
        }

        try await service.saveUser(user)

        // 캐시 업데이트
        await cache.set("user_\(user.id)", value: user)
        logger.log("사용자 저장 완료", level: .info)
    }
}
```

## 실제 구현

### UserService 구현

```swift
class LiveUserService: UserService {
    func fetchUser(id: String) async throws -> User {
        // API 호출 시뮬레이션
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        return User(id: id, name: "실제 사용자 \(id)", email: "user\(id)@example.com")
    }

    func saveUser(_ user: User) async throws {
        // 저장 작업 시뮬레이션
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        print("💾 데이터베이스에 사용자 저장: \(user.name)")
    }
}
```

### 로깅 서비스 구현

```swift
class ConsoleLoggingService: LoggingService {
    func log(_ message: String, level: LogLevel) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [\(level.rawValue.uppercased())] \(message)")
    }
}
```

### 캐시 서비스 구현

```swift
class InMemoryCacheService: CacheService {
    private var storage: [String: Data] = [:]
    private let queue = DispatchQueue(label: "cache", attributes: .concurrent)

    func get<T: Codable>(_ key: String, type: T.Type) async -> T? {
        return await withCheckedContinuation { continuation in
            queue.async {
                guard let data = self.storage[key],
                      let value = try? JSONDecoder().decode(type, from: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: value)
            }
        }
    }

    func set<T: Codable>(_ key: String, value: T) async {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                if let data = try? JSONEncoder().encode(value) {
                    self.storage[key] = data
                }
                continuation.resume()
            }
        }
    }
}
```

## 테스트 예제

### 기본 사용 예제

```swift
func basicUsageExample() async {
    let userManager = UserManager()

    do {
        // 사용자 로딩
        let user = try await userManager.loadUser(id: "123")
        print("✅ 사용자 로딩: \(user.name) (\(user.email))")

        // 사용자 업데이트 및 저장
        let updatedUser = User(id: user.id, name: "업데이트된 \(user.name)", email: user.email)
        try await userManager.saveUser(updatedUser)

        // 다시 로딩 (캐시에서 가져와야 함)
        let cachedUser = try await userManager.loadUser(id: "123")
        print("✅ 캐시된 사용자: \(cachedUser.name)")

    } catch {
        print("❌ 오류: \(error)")
    }
}
```

### 테스트 환경 시뮬레이션

```swift
func testEnvironmentExample() async {
    await withInjectedValues {
        // 모킹 서비스로 교체
        let mockUserService = MockUserService()
        mockUserService.mockUsers = [
            "test": User(id: "test", name: "테스트 사용자", email: "test@mock.com")
        ]

        $0.userService = mockUserService
        $0.loggingService = NoOpLoggingService()
        $0.cacheService = NoOpCacheService()
    } operation: {
        let userManager = UserManager()

        do {
            let user = try await userManager.loadUser(id: "test")
            print("✅ 모킹 사용자: \(user.name) (\(user.email))")

            // 새 사용자 저장
            let newUser = User(id: "new", name: "새 모킹 사용자", email: "new@mock.com")
            try await userManager.saveUser(newUser)
            print("✅ 모킹 사용자 저장 완료")

        } catch {
            print("❌ 모킹 테스트 오류: \(error)")
        }
    }
}
```

## 모킹 구현

### Mock UserService

```swift
class MockUserService: UserService {
    var mockUsers: [String: User] = [:]

    func fetchUser(id: String) async throws -> User {
        if let user = mockUsers[id] {
            return user
        }
        return User(id: id, name: "모킹 사용자 \(id)", email: "mock\(id)@test.com")
    }

    func saveUser(_ user: User) async throws {
        mockUsers[user.id] = user
    }
}
```

### 테스트용 No-Op 서비스

```swift
class NoOpLoggingService: LoggingService {
    func log(_ message: String, level: LogLevel) {
        // 테스트용 no-op
    }
}

class NoOpCacheService: CacheService {
    func get<T: Codable>(_ key: String, type: T.Type) async -> T? {
        return nil
    }

    func set<T: Codable>(_ key: String, value: T) async {
        // 테스트용 no-op
    }
}
```

## 성능 비교

### 다양한 접근 방식 벤치마킹

```swift
func performanceExample() async {
    let iterations = 1000

    // WeaveDI @Injected 성능
    let weaveDIStart = Date()
    for _ in 0..<iterations {
        let userManager = UserManager()
        // 실제 네트워크 호출 없이 서비스 접근만 측정
        let _ = userManager
    }
    let weaveDITime = Date().timeIntervalSince(weaveDIStart)

    print("📊 성능 결과 (\(iterations) 반복):")
    print("   WeaveDI @Injected: \(String(format: "%.4f", weaveDITime))초")

    // swift-dependencies와 비교
    await withDependencies {
        $0.userService = MockUserService()
    } operation: {
        let dependenciesStart = Date()
        for _ in 0..<iterations {
            @Dependency(\.userService) var userService
            let _ = userService
        }
        let dependenciesTime = Date().timeIntervalSince(dependenciesStart)
        print("   swift-dependencies: \(String(format: "%.4f", dependenciesTime))초")

        let improvement = (dependenciesTime - weaveDITime) / dependenciesTime * 100
        if improvement > 0 {
            print("   🚀 WeaveDI가 \(String(format: "%.1f", improvement))% 더 빠릅니다!")
        }
    }
}
```

## 사용 패턴

### 패턴 1: 현재 구체 타입 주입 (사용자 패턴)

```swift
class ExchangeFeature {
    // 현재 패턴 - 직접 구체 타입 주입
    @Injected(ExchangeUseCaseImpl.self) private var exchangeUseCase
    @Injected(FavoriteCurrencyUseCaseImpl.self) private var favoriteUseCase
    @Injected(ExchangeRateCacheUseCaseImpl.self) private var cacheUseCase

    func loadExchangeRates() async {
        guard let useCase = exchangeUseCase else { return }
        // 서비스 사용...
    }
}
```

### 패턴 2: 프로토콜 기반 주입 (권장)

```swift
class ImprovedExchangeFeature {
    // 더 나은 테스트 가능성을 위한 프로토콜 기반 접근
    @Injected(\.exchangeUseCase) var exchangeUseCase
    @Injected(\.favoriteUseCase) var favoriteUseCase
    @Injected(\.cacheUseCase) var cacheUseCase

    func loadExchangeRates() async {
        // 더 나은 추상화로 서비스 사용...
    }
}
```

### 패턴 3: 하이브리드 접근

```swift
class HybridExchangeFeature {
    // 기존 안정적인 코드는 변경하지 않음
    @Injected(ExchangeUseCaseImpl.self) private var exchangeUseCase
    @Injected(FavoriteCurrencyUseCaseImpl.self) private var favoriteUseCase

    // 새 서비스에는 프로토콜 기반 사용
    @Injected(\.analyticsService) var analytics
    @Injected(\.networkMonitor) var networkMonitor
}
```

## 예제 실행

완전한 예제를 실행하려면:

1. 예제 디렉토리로 이동:
   ```bash
   cd Example/DependencyValuesExample
   ```

2. 예제 실행:
   ```bash
   swift run
   ```

예제는 다음을 시연합니다:
- 기본 의존성 주입 사용법
- 모킹을 사용한 테스트 환경 시뮬레이션
- WeaveDI와 swift-dependencies 간의 성능 비교
- 다양한 주입 패턴과 그 트레이드오프

## 핵심 포인트

1. **다중 주입 패턴**: WeaveDI는 직접 타입 주입, KeyPath 기반 주입, swift-dependencies 호환성을 지원합니다
2. **쉬운 테스트**: `withInjectedValues`를 사용하여 테스트용 의존성을 재정의할 수 있습니다
3. **성능 이점**: WeaveDI는 다른 DI 솔루션에 비해 더 나은 성능을 제공합니다
4. **점진적 마이그레이션**: 기존 코드를 깨뜨리지 않고 점진적으로 WeaveDI를 도입할 수 있습니다
5. **타입 안전성**: 모든 접근 방식이 컴파일 타임 타입 안전성을 유지합니다

## 다음 단계

- [프로퍼티 래퍼 가이드](./propertyWrappers.md) - WeaveDI의 주입 패턴 심화
- [TCA 통합](./tcaIntegration.md) - The Composable Architecture와 WeaveDI 사용
- [테스트 가이드](../tutorial/testing.md) - WeaveDI를 사용한 고급 테스트 전략