---
title: QuickStart
lang: ko-KR
---

# 빠른 시작 가이드


WeaveDI를 5분만에 시작해보세요!

## 개요

WeaveDI 2.0은 Swift Concurrency와 자동 최적화를 완벽 지원하는 현대적인 의존성 주입 프레임워크입니다. **Uber Needle의 모든 핵심 장점을 흡수하면서도 더 나은 개발자 경험을 제공합니다.**

### 🏆 Needle 대비 WeaveDI의 장점

| 특징 | Needle | WeaveDI |
|------|--------|---------|
| **컴파일타임 안전성** | ✅ | ✅ (더 간편) |
| **런타임 성능** | ✅ 제로 코스트 | ✅ 제로 코스트 + Actor 최적화 |
| **Swift 6 지원** | ⚠️ 제한적 | ✅ 완벽 네이티브 |
| **코드 생성 필요** | ❌ 필수 | ✅ 선택적 |
| **마이그레이션** | ❌ All-or-nothing | ✅ 점진적 |

> 💡 **Needle 사용자라면?** [Needle 스타일 사용법](NeedleStyleDI.md)에서 완벽한 마이그레이션 가이드를 확인하세요!

## 1단계: 설치

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "2.0.0")
]
```

### Xcode에서 설치

1. Xcode에서 프로젝트 열기
2. File → Add Package Dependencies
3. URL 입력: `https://github.com/Roy-wonji/WeaveDI.git`
4. Add Package

## 2단계: 임포트

```swift
import WeaveDI
```

## 3단계: 첫 번째 의존성 등록

### 서비스 정의

```swift
// 프로토콜 정의
protocol UserService {
    func getUser(id: String) -> User?
    func saveUser(_ user: User) throws
}

// 구현체 정의
class UserServiceImpl: UserService {
    func getUser(id: String) -> User? {
        // 사용자 조회 로직
        return User(id: id, name: "Sample User")
    }

    func saveUser(_ user: User) throws {
        // 사용자 저장 로직
        Log.debug("Saving user: \(user.name)")
    }
}
```

### 의존성 등록 (UnifiedDI 사용)

```swift
// 앱 시작 시점에 등록
let userService = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}

// 즉시 사용 가능
let user = userService.getUser(id: "123")
```

## 4단계: Property Wrapper로 주입

### @Inject - 기본 주입

```swift
class UserViewController {
    @Inject var userService: UserService?

    func loadUser() {
        if let service = userService {
            let user = service.getUser(id: "current")
            // UI 업데이트
        }
    }
}
```

### @Factory - 매번 새로운 인스턴스

```swift
class ReportGenerator {
    @Factory var pdfGenerator: PDFGenerator

    func generateReport() {
        // 매번 새로운 PDFGenerator 인스턴스 사용
        let pdf = pdfGenerator.create()
        return pdf
    }
}

// PDFGenerator 등록
_ = UnifiedDI.register(PDFGenerator.self) {
    PDFGenerator()
}
```

### @SafeInject - 안전한 주입 (에러 처리)

```swift
class APIController {
    @SafeInject var apiService: APIService?

    func fetchData() async {
        do {
            let service = try apiService.getValue()
            let data = await service.fetchUserData()
            // 데이터 처리
        } catch {
            Log.error("API service not available: \(error)")
            // 대체 로직
        }
    }
}
```

## 5단계: 다양한 등록 방법

### KeyPath 등록

```swift
// Extension으로 KeyPath 정의
extension WeaveDI.Container {
    var userService: UserService? {
        resolve(UserService.self)
    }
}

// KeyPath로 등록
let userService = UnifiedDI.register(\.userService) {
    UserServiceImpl()
}
```

### 조건부 등록

```swift
// 환경에 따른 조건부 등록
let analyticsService = UnifiedDI.Conditional.registerIf(
    AnalyticsService.self,
    condition: isProduction,
    factory: { FirebaseAnalyticsService() },  // 프로덕션용
    fallback: { MockAnalyticsService() }      // 개발/테스트용
)
```

## 6단계: 해결 방법들

### 기본 해결

```swift
// 옵셔널 해결 (안전)
let service = UnifiedDI.resolve(UserService.self)
if let service = service {
    // 사용
}

// 필수 해결 (없으면 크래시)
let requiredService = UnifiedDI.requireResolve(UserService.self)
// 항상 유효한 인스턴스

// 기본값과 함께 해결
let cacheService = UnifiedDI.resolve(
    CacheService.self,
    default: MemoryCacheService()
)
// 항상 유효한 인스턴스 (등록되지 않으면 기본값 사용)
```

## 7단계: 자동 최적화 활용

### 자동화 기능 켜기

```swift
// 앱 시작 시점에 설정
UnifiedDI.setAutoOptimization(true)  // 기본값: true
UnifiedDI.setLogLevel(.all)          // 기본값: .all
```

### 자동 수집 정보 확인

```swift
// 사용 통계 확인
let stats = UnifiedDI.stats
Log.debug("사용 통계: \(stats)")

// Actor hop 통계 확인
let actorHopStats = UnifiedDI.actorHopStats
Log.debug("Actor hop 통계: \(actorHopStats)")

// 최적화 제안 확인
let optimizations = UnifiedDI.actorOptimizations
for (type, optimization) in optimizations {
    Log.debug("최적화 제안 - \(type): \(optimization.suggestion)")
}

// 타입 안전성 이슈 확인
let safetyIssues = UnifiedDI.typeSafetyIssues
for (type, issue) in safetyIssues {
    Log.warning("타입 안전성 이슈 - \(type): \(issue.suggestion)")
}
```

## 8단계: 실제 앱 구조 예시

### App.swift

```swift
import SwiftUI
import WeaveDI

@main
struct MyApp: App {
    init() {
        setupDependencies()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func setupDependencies() {
        // 자동 최적화 활성화
        UnifiedDI.setAutoOptimization(true)
        UnifiedDI.setLogLevel(.all)

        // Core Services
        _ = UnifiedDI.register(NetworkService.self) {
            URLSessionNetworkService()
        }

        _ = UnifiedDI.register(DatabaseService.self) {
            CoreDataService()
        }

        // Business Services
        _ = UnifiedDI.register(UserService.self) {
            UserServiceImpl()
        }

        _ = UnifiedDI.register(AuthService.self) {
            AuthServiceImpl()
        }

        // Analytics (조건부)
        _ = UnifiedDI.Conditional.registerIf(
            AnalyticsService.self,
            condition: !ProcessInfo.processInfo.arguments.contains("--uitests"),
            factory: { FirebaseAnalyticsService() },
            fallback: { MockAnalyticsService() }
        )

        Log.debug("Dependencies registered successfully")
    }
}
```

### ContentView.swift

```swift
import SwiftUI
import WeaveDI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else {
                    Text("Hello, \(viewModel.currentUser?.name ?? "Guest")!")
                }

                Button("Load User") {
                    Task {
                        await viewModel.loadCurrentUser()
                    }
                }
            }
            .navigationTitle("WeaveDI Demo")
        }
    }
}

class ContentViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = false

    @Inject var userService: UserService?
    @Inject var analyticsService: AnalyticsService?

    @MainActor
    func loadCurrentUser() async {
        isLoading = true
        defer { isLoading = false }

        analyticsService?.track(event: "user_load_started")

        // 사용자 로드
        currentUser = userService?.getUser(id: "current")

        analyticsService?.track(event: "user_load_completed")
    }
}
```

## 9단계: 테스트 설정

### 테스트용 의존성 설정

```swift
import XCTest
@testable import WeaveDI

class MyAppTests: XCTestCase {

    @MainActor
    override func setUp() {
        super.setUp()

        // 테스트 환경 초기화
        UnifiedDI.releaseAll()
        UnifiedDI.setLogLevel(.off)  // 테스트 중 로그 끄기

        // Mock 서비스들 등록
        _ = UnifiedDI.register(UserService.self) {
            MockUserService()
        }

        _ = UnifiedDI.register(NetworkService.self) {
            MockNetworkService()
        }
    }

    @MainActor
    override func tearDown() {
        UnifiedDI.releaseAll()
        super.tearDown()
    }

    func testUserServiceRegistration() {
        // Given
        let userService = UnifiedDI.resolve(UserService.self)

        // Then
        XCTAssertNotNil(userService)
        XCTAssertTrue(userService is MockUserService)
    }
}

// Mock 구현
class MockUserService: UserService {
    func getUser(id: String) -> User? {
        return User(id: id, name: "Mock User")
    }

    func saveUser(_ user: User) throws {
        // Mock implementation
    }
}
```

## 10단계: 고급 사용법 미리보기

### 비동기 의존성

```swift
// 비동기로 초기화되는 서비스
class DatabaseService {
    static func initialize() async -> DatabaseService {
        let service = DatabaseService()
        await service.connect()
        return service
    }

    private func connect() async {
        // DB 연결 로직
    }
}

// 등록 시
let dbService = await DatabaseService.initialize()
_ = UnifiedDI.register(DatabaseService.self) { dbService }
```

### Actor 기반 서비스

```swift
@MainActor
class UIService {
    func updateUI() {
        // UI 업데이트 로직 - 자동으로 MainActor에서 실행
    }
}

// 등록
_ = UnifiedDI.register(UIService.self) {
    UIService()
}

// 사용 - Actor hop 자동 감지
Task {
    let uiService = UnifiedDI.resolve(UIService.self)
    await uiService?.updateUI()  // MainActor로 자동 hop
}
```

## 다음 단계

이제 WeaveDI의 기본 사용법을 익혔습니다! 더 자세한 내용은 다음 가이드들을 참고하세요:

- [Property Wrapper 상세 가이드](PropertyWrappers.md) - 모든 Property Wrapper 패턴
- [자동 최적화 가이드](AutoDIOptimizer.md) - 성능 최적화 기능
- [Core API 참조](CoreAPIs.md) - 모든 API 레퍼런스

## 문제 해결

### 자주 발생하는 문제들

1. **의존성이 nil로 해결되는 경우**
   ```swift
   // 등록이 해결보다 먼저 되었는지 확인
   _ = UnifiedDI.register(Service.self) { ServiceImpl() }
   let service = UnifiedDI.resolve(Service.self) // 이제 정상 동작
   ```

2. **테스트에서 의존성이 격리되지 않는 경우**
   ```swift
   @MainActor
   override func setUp() {
       UnifiedDI.releaseAll()  // 이전 테스트의 의존성 정리
       // 새 의존성 등록
   }
   ```

3. **타입 안전성 경고가 나타나는 경우**
   ```swift
   // Sendable 프로토콜 추가
   protocol UserService: Sendable {
       // ...
   }
   ```

## 🚀 Needle 수준 성능 활성화 (선택사항)

Uber Needle과 동일한 제로 코스트 성능을 원한다면:

### 1. 빌드 플래그 설정

**Xcode:**
```
Build Settings → Other Swift Flags → -DUSE_STATIC_FACTORY 추가
```

**SPM:**
```bash
swift build -c release -Xswiftc -DUSE_STATIC_FACTORY
```

### 2. 앱 초기화 시 활성화

```swift
@main
struct MyApp: App {
    init() {
        // Needle 수준 성능 활성화
        UnifiedDI.enableStaticOptimization()
        // 출력: 🚀 WeaveDI: Static factory optimization ENABLED
    }
}
```

### 3. 컴파일타임 의존성 검증

```swift
// Needle의 핵심 장점: 컴파일타임 안전성
@DependencyGraph([
    UserService.self: [NetworkService.self, Logger.self],
    NetworkService.self: [Logger.self]
])
extension WeaveDI {}
```

### 4. 고성능 해결

```swift
// 성능이 중요한 곳에서 사용
let fastService = UnifiedDI.staticResolve(UserService.self)

// 성능 비교 확인
print(UnifiedDI.performanceComparison())
// 출력: 🏆 WeaveDI vs Needle Performance: EQUAL
```

### 5. Needle 마이그레이션

```swift
// Needle에서 마이그레이션하는 경우
print(UnifiedDI.migrateFromNeedle())  // 단계별 가이드
print(UnifiedDI.needleMigrationBenefits())  // 마이그레이션 이점
```

> 📖 **더 자세한 Needle 스타일 사용법:** [Needle 방식 DI 사용법](NeedleStyleDI.md)

---

이제 WeaveDI를 프로젝트에 통합하고 현대적인 의존성 주입의 혜택을 누려보세요! **Needle 사용자라면 더욱 강력하고 편리한 DI 경험을 얻을 수 있습니다.** 🏆
