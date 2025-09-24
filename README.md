# DiContainer

![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)
![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/Roy-wonji/DiContainer/blob/main/LICENSE)
![Platform](https://img.shields.io/badge/platforms-iOS%2015%2B%20%7C%20macOS%2014%2B%20%7C%20watchOS%208%2B%20%7C%20tvOS%2015%2B-lightgrey)

**현대적인 Swift Concurrency를 위한 간단하고 강력한 의존성 주입 프레임워크**

## 🎯 핵심 특징

- ⚡ **Swift Concurrency 네이티브**: async/await와 Actor 완벽 지원
- 🔒 **타입 안전성**: 컴파일 타임 타입 검증
- 📝 **간단한 API**: 3개의 핵심 Property Wrapper만 기억하면 됨
- 🤖 **자동 최적화**: 의존성 그래프, Actor hop 감지, 타입 안전성 검증 자동화
- 🧪 **테스트 친화적**: 의존성 모킹과 격리 지원

## 🚀 빠른 시작

### 설치

```swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/DiContainer.git", from: "2.0.0")
]
```

### 기본 사용법

```swift
import DiContainer

// 1. 의존성 등록
let userService = UnifiedDI.register(UserServiceProtocol.self) {
    UserService()
}

// 2. Property Wrapper로 주입
class ViewController {
    @Inject var userService: UserServiceProtocol?     // 옵셔널 주입
    @Inject var logger: Logger                        // 필수 주입
    @Factory var generator: PDFGenerator              // 팩토리 (매번 새 인스턴스)
}

// 3. 안전한 주입 (에러 처리)
class SafeController {
    @SafeInject var apiService: APIServiceProtocol?

    func loadData() {
        do {
            let service = try apiService.getValue()
            // 안전하게 사용
        } catch {
            // 에러 처리
        }
    }
}
```

## 📚 핵심 API

### 등록 API

```swift
// 기본 등록 (권장)
let service = UnifiedDI.register(ServiceProtocol.self) {
    ServiceImpl()
}

// KeyPath 등록
let repository = UnifiedDI.register(\.userRepository) {
    UserRepositoryImpl()
}
```

### Property Wrapper

| Property Wrapper | 용도 | 예시 |
|---|---|---|
| `@Inject` | 기본 주입 (옵셔널/필수) | `@Inject var service: Service?` |
| `@Factory` | 팩토리 패턴 (새 인스턴스) | `@Factory var generator: Generator` |
| `@SafeInject` | 안전한 주입 (throws) | `@SafeInject var api: API?` |

### 해결 API

```swift
// 일반 해결
let service = UnifiedDI.resolve(ServiceProtocol.self)

// 필수 해결 (없으면 크래시)
let logger = UnifiedDI.requireResolve(Logger.self)

// 기본값 포함 해결
let cache = UnifiedDI.resolve(Cache.self, default: MemoryCache())
```

## 🔧 고급 기능

### Bootstrap 시스템

```swift
// 앱 시작 시 의존성 초기화
await DIContainer.bootstrap { container in
    container.register(DatabaseProtocol.self) { SQLiteDatabase() }
    container.register(NetworkProtocol.self) { URLSessionNetwork() }
}
```

### 모듈 시스템

```swift
let container = DIContainer()

// 모듈 추가
container.addModule(networkModule)
         .addModule(databaseModule)

// 병렬 빌드
await container.buildModules()
```

## 🧪 테스트

```swift
// 테스트용 초기화
@MainActor
override func setUp() {
    DIContainer.resetForTesting()

    // 테스트용 의존성 등록
    UnifiedDI.register(UserService.self) {
        MockUserService()
    }
}
```

## 🤖 자동 최적화

**별도 설정 없이 자동으로 실행됩니다:**

```swift
// 등록/해결만 하면 자동으로 그래프 생성 및 최적화
let service = UnifiedDI.register(UserService.self) { UserServiceImpl() }
let resolved = UnifiedDI.resolve(UserService.self)

// 자동 수집된 정보는 LogMacro로 자동 출력됩니다 (별도 호출 불필요)
// 📊 Auto tracking registration: UserService
// ⚡ Auto optimized: UserService (10 uses)
// 🎯 Actor optimization suggestion for UserService: MainActor로 이동 권장
// 🔒 Type safety issue: UserService is not Sendable
// 📊 [AutoDI] Current stats: ["UserService": 15]

// 로깅 제어 (기본값: 모든 로그 활성화)
UnifiedDI.setLogLevel(.registration)  // 등록만 로깅
UnifiedDI.setLogLevel(.optimization)  // 최적화만 로깅
UnifiedDI.setLogLevel(.errors)       // 에러/경고만 로깅
UnifiedDI.setLogLevel(.off)          // 로깅 끄기
```

## 📖 문서

- [API 문서](https://roy-wonji.github.io/DiContainer/documentation/dicontainer)
- [자동 최적화 가이드](Sources/DiContainer.docc/ko.lproj/AutoDIOptimizer.md)
- [Migration Guide](Sources/DiContainer.docc/ko.lproj/MIGRATION-2.0.0.md)

## 📄 라이센스

MIT License. 자세한 내용은 [LICENSE](LICENSE) 파일을 참고하세요.

## 👨‍💻 개발자

**Wonji Suh** - [GitHub](https://github.com/Roy-wonji)