# 빠른 시작 가이드

5분 안에 WeaveDI를 시작해보세요.

## 설치

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.2.0")
]
```

### Xcode

1. File → Add Package Dependencies
2. 입력: `https://github.com/Roy-wonji/WeaveDI.git`
3. Add Package

## 기본 사용법

### 1. Import

```swift
import WeaveDI
```

### 2. 서비스 정의

```swift
protocol UserService {
    func fetchUser(id: String) async -> User?
}

class UserServiceImpl: UserService {
    func fetchUser(id: String) async -> User? {
        // 구현
        return User(id: id, name: "John")
    }
}
```

### 3. 의존성 등록

```swift
// 앱 시작 시 등록
let userService = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}
```

### 4. Property Wrapper 사용

```swift
class UserViewController {
    @Inject var userService: UserService?

    func loadUser() async {
        guard let service = userService else { return }
        let user = await service.fetchUser(id: "123")
        // UI 업데이트
    }
}
```

## Property Wrapper

### @Inject - 선택적 의존성

```swift
class ViewController {
    @Inject var userService: UserService?

    func viewDidLoad() {
        userService?.fetchUser(id: "current")
    }
}
```

### @Factory - 매번 새 인스턴스

```swift
class DocumentProcessor {
    @Factory var pdfGenerator: PDFGenerator

    func createDocument() {
        let generator = pdfGenerator // 새 인스턴스
        generator.generate()
    }
}
```

### @SafeInject - 에러 처리

```swift
class DataManager {
    @SafeInject var database: Database?

    func save(_ data: Data) throws {
        guard let db = database else {
            throw DIError.dependencyNotFound
        }
        try db.save(data)
    }
}
```

## 고급 기능

### 런타임 최적화

```swift
// 성능 향상을 위한 최적화 활성화
UnifiedRegistry.shared.enableOptimization()
```

### Bootstrap 패턴

```swift
await DIContainer.bootstrap { container in
    container.register(UserService.self) { UserServiceImpl() }
    container.register(DatabaseService.self) { DatabaseServiceImpl() }
}
```

## 다음 단계

- [Property Wrapper](/ko/guide/property-wrappers) - 상세한 주입 패턴
- [Core API](/ko/api/core-apis) - 완전한 API 레퍼런스
- [런타임 최적화](/ko/guide/runtime-optimization) - 성능 튜닝