# Quick Start Guide

Comprehensive guide to get up and running with WeaveDI - from basic setup to production-ready implementation in real projects.

## Overview

WeaveDI 3.2 is a modern dependency injection framework that perfectly supports Swift Concurrency and automatic optimization. **It absorbs all the core advantages of Uber Needle while providing a better developer experience.**

### 🏆 WeaveDI Advantages over Needle

| Feature | Needle | WeaveDI |
|---------|--------|---------|
| **Compile-time Safety** | ✅ | ✅ (Simpler) |
| **Runtime Performance** | ✅ Zero-cost | ✅ Zero-cost + Actor optimization |
| **Swift 6 Support** | ⚠️ Limited | ✅ Perfect native |
| **Code Generation Required** | ❌ Mandatory | ✅ Optional |
| **Migration** | ❌ All-or-nothing | ✅ Gradual |

> 💡 **Needle users?** Check out the complete migration guide in [Needle Style Usage](/guide/needle-style-di)!

## Step 1: Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.2.0")
]
```

### Install in Xcode

1. Open your project in Xcode
2. File → Add Package Dependencies
3. Enter URL: `https://github.com/Roy-wonji/WeaveDI.git`
4. Add Package

## Step 2: Import

```swift
import WeaveDI
```

## Step 3: First Dependency Registration

### Define Services

의존성 주입을 시작하기 전에 먼저 서비스 프로토콜과 구현체를 정의해야 합니다.

```swift
// 프로토콜 기반 설계로 유연한 구현체 교체 가능
protocol UserService {
    func getUser(id: String) async throws -> User?
    func saveUser(_ user: User) async throws
    func deleteUser(id: String) async throws
    func getAllUsers() async throws -> [User]
}

// 실제 구현체 - 프로덕션 환경에서 사용
class UserServiceImpl: UserService {
    private let networkClient: NetworkClient
    private let cacheManager: CacheManager

    init(networkClient: NetworkClient = .shared,
         cacheManager: CacheManager = .shared) {
        self.networkClient = networkClient
        self.cacheManager = cacheManager
    }

    func getUser(id: String) async throws -> User? {
        // 1. 캐시에서 먼저 확인
        if let cachedUser = await cacheManager.getUser(id: id) {
            return cachedUser
        }

        // 2. 네트워크에서 가져오기
        let user = try await networkClient.fetchUser(id: id)

        // 3. 캐시에 저장 후 반환
        await cacheManager.cacheUser(user)
        return user
    }

    func saveUser(_ user: User) async throws {
        // 네트워크를 통해 서버에 저장
        try await networkClient.saveUser(user)

        // 로컬 캐시도 업데이트
        await cacheManager.cacheUser(user)

        print("✅ 사용자 저장 완료: \(user.name)")
    }

    func deleteUser(id: String) async throws {
        try await networkClient.deleteUser(id: id)
        await cacheManager.removeUser(id: id)
        print("🗑️ 사용자 삭제 완료: \(id)")
    }

    func getAllUsers() async throws -> [User] {
        return try await networkClient.fetchAllUsers()
    }
}

// 테스트용 Mock 구현체
class MockUserService: UserService {
    var users: [String: User] = [:]
    var shouldThrowError = false

    func getUser(id: String) async throws -> User? {
        if shouldThrowError {
            throw UserError.networkError
        }
        return users[id]
    }

    func saveUser(_ user: User) async throws {
        if shouldThrowError {
            throw UserError.saveError
        }
        users[user.id] = user
    }

    func deleteUser(id: String) async throws {
        if shouldThrowError {
            throw UserError.deleteError
        }
        users.removeValue(forKey: id)
    }

    func getAllUsers() async throws -> [User] {
        if shouldThrowError {
            throw UserError.fetchError
        }
        return Array(users.values)
    }
}
```

**코드 설명:**
- **프로토콜 기반 설계**: `UserService` 프로토콜로 구현체를 추상화
- **비동기 지원**: `async throws` 패턴으로 모던 Swift Concurrency 활용
- **실제 구현체**: `UserServiceImpl`은 네트워크와 캐시를 활용한 실제 로직
- **테스트 지원**: `MockUserService`로 유닛 테스트에서 사용할 수 있는 가짜 구현체
- **에러 처리**: 각 메서드에서 적절한 에러 타입 정의 및 처리
- **의존성 분리**: 네트워크 클라이언트와 캐시 매니저를 별도 의존성으로 관리

### Dependency Registration (Using UnifiedDI)

```swift
// Register at app startup
let userService = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}

// Immediately available
let user = userService.getUser(id: "123")
```

## Step 4: Property Wrapper Injection

### @Inject - Basic Injection

```swift
class UserViewController {
    @Inject var userService: UserService?

    func loadUser() {
        if let service = userService {
            let user = service.getUser(id: "current")
            // Update UI
        }
    }
}
```

### @Factory - New Instance Every Time

```swift
class ReportGenerator {
    @Factory var pdfGenerator: PDFGenerator

    func generateReport() {
        // Use a new PDFGenerator instance every time
        let pdf = pdfGenerator.create()
        return pdf
    }
}

// Register PDFGenerator
_ = UnifiedDI.register(PDFGenerator.self) {
    PDFGenerator()
}
```

### @SafeInject - Safe Injection (Error Handling)

```swift
class APIController {
    @SafeInject var apiService: APIService?

    func fetchData() async {
        do {
            let service = try apiService.getValue()
            let data = await service.fetchUserData()
            // Process data
        } catch {
            Log.error("API service not available: \(error)")
            // Fallback logic
        }
    }
}
```

## Advanced Features

### Enable Runtime Optimization

For high-performance applications:

```swift
// Enable hot-path optimization
UnifiedRegistry.shared.enableOptimization()

// Your existing code automatically gets 50-80% performance improvement
let service = await UnifiedDI.resolve(UserService.self)
```

### Bootstrap Pattern

For complex apps:

```swift
await DIContainer.bootstrap { container in
    container.register(UserService.self) { UserServiceImpl() }
    container.register(APIService.self) { APIServiceImpl() }
}
```

## Next Steps

- Learn about [Property Wrappers](/guide/property-wrappers)
- Explore [Runtime Optimization](/guide/runtime-optimization)
- Check out [Core APIs](/api/core-apis)