# 스코프 가이드 (Screen / Session / Request)

WeaveDI의 스코프 시스템은 의존성을 컨텍스트별 컨테이너로 구성하여 강력한 의존성 격리 및 캐싱 기능을 제공합니다. 이를 통해 화면 수준, 세션 수준, 요청 수준의 다양한 애플리케이션 상태에 대한 효율적인 메모리 관리와 적절한 생명주기 제어가 가능합니다.

## 개요

스코프는 복잡한 애플리케이션에서 의존성 생명주기 관리의 근본적인 문제를 해결합니다. 스코프가 없다면 모든 의존성이 글로벌 싱글톤(부적절한 상태 공유) 또는 매번 재생성(비효율적)이어야 합니다. 스코프는 의존성이 적절한 경계 내에서 캐시되고 재사용되며, 그 경계를 벗어날 때 자동으로 정리되는 중간 지점을 제공합니다.

**주요 장점**:
- **메모리 효율성**: 의존성이 스코프 경계 내에서 캐시되고 자동으로 정리됩니다
- **상태 격리**: 화면별 또는 세션별 상태가 컨텍스트 간에 누출되지 않습니다
- **성능 최적화**: 동일한 스코프 내에서 불필요한 객체 재생성을 방지합니다
- **생명주기 관리**: 스코프가 정리될 때 자동 정리됩니다

## 왜 스코프가 필요한가?

스코프는 현대 애플리케이션의 특정 아키텍처 패턴과 성능 요구사항을 해결합니다:

### 1. 화면 수준 상태 관리
**문제**: UI 구성 요소가 화면 내에서 상태를 공유해야 하지만 다른 화면과는 격리되어야 합니다.

**해결**: 화면 스코프는 ViewModel, 캐시, 화면별 서비스가 하나의 화면 내에서 공유되지만 다른 화면으로 이동할 때 정리되도록 보장합니다.

```swift
// 예제: 이미지 캐시는 사진 갤러리 화면 내에서 공유되어야 하지만
// 사용자가 다른 화면으로 이동할 때 정리되어야 함
```

### 2. 사용자 세션 관리
**문제**: 사용자별 서비스는 사용자 세션 전체에서 사용 가능해야 하지만 로그아웃 시 완전히 정리되어야 합니다.

**해결**: 세션 스코프는 사용자별 의존성을 자동으로 관리하고 세션 종료 시 적절한 정리를 수행합니다.

```swift
// 예제: 사용자 환경설정, 알림 설정, 개인화 데이터는
// 세션 중에는 유지되지만 로그아웃 시 정리되어야 함
```

### 3. 요청 컨텍스트 관리
**문제**: 서버 사이드나 많은 요청을 처리하는 애플리케이션에서 요청별 데이터는 격리되고 요청 완료 후 정리되어야 합니다.

**해결**: 요청 스코프는 요청별 데이터의 스레드 안전 격리와 자동 정리를 보장합니다.

```swift
// 예제: HTTP 요청 컨텍스트, 추적 정보, 임시 처리 데이터는
// 요청별로 격리되고 응답 전송 후 정리되어야 함
```

## 핵심 타입과 API

### ScopeKind
서로 다른 사용 사례에 최적화된 세 가지 내장 스코프 유형을 정의합니다:

```swift
enum ScopeKind {
    case screen    // UI 네비게이션 경계
    case session   // 사용자 세션 경계
    case request   // 요청/작업 경계
}
```

**스코프 특성**:
- **Screen**: 일반적으로 짧은 생명주기 (초~분), UI 중심
- **Session**: 중간~긴 생명주기 (분~시간), 사용자 중심
- **Request**: 매우 짧은 생명주기 (밀리초~초), 작업 중심

### ScopeContext
스코프 생명주기와 식별을 위한 중앙 관리 시스템:

```swift
class ScopeContext {
    // 고유 식별자와 함께 현재 스코프 설정
    func setCurrent(_ kind: ScopeKind, id: String)

    // 특정 스코프 정리 및 관련된 모든 의존성 정리
    func clear(_ kind: ScopeKind)

    // 현재 스코프 ID 확인 (디버깅에 유용)
    func currentID(for kind: ScopeKind) -> String?
}
```

**컨텍스트 관리 패턴**:
- **계층적 ID**: "ProfileScreen", "UserSession_123", "Request_UUID"와 같은 의미 있는 ID 사용
- **자동 정리**: 적절한 메모리 관리를 위해 항상 `setCurrent`와 `clear`를 함께 사용
- **스레드 안전성**: 모든 ScopeContext 작업은 스레드 안전하고 actor 호환됩니다

### 등록 API
스코프 등록 메서드는 동기식 및 비동기식 의존성 생성을 모두 제공합니다:

```swift
// 동기식 스코프 등록
func registerScoped<T>(
    _ type: T.Type,
    scope: ScopeKind,
    factory: @escaping () -> T
)

// 비동기식 스코프 등록
func registerAsyncScoped<T>(
    _ type: T.Type,
    scope: ScopeKind,
    factory: @escaping () async -> T
)
```

## 상세 사용 예제

### 화면 스코프 - 완전한 네비게이션 예제

화면 스코프는 서로 다른 화면이나 뷰 컨트롤러 간에 격리되어야 하는 UI별 의존성을 관리하는 데 완벽합니다.

**목적**: 화면 생명주기 동안 지속되어야 하지만 네비게이션 시 정리되어야 하는 의존성을 관리합니다.

**생명주기**: 화면 표시 시 생성, 화면 생명주기 동안 캐시, 화면 사라질 때 소멸.

```swift
class HomeViewController: UIViewController {
    @Injected var viewModel: HomeViewModel?
    @Injected var imageCache: ImageCache?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // 고유 식별자로 화면 스코프 설정
        ScopeContext.shared.setCurrent(.screen, id: "HomeScreen")

        // 화면별 의존성 등록
        Task {
            await GlobalUnifiedRegistry.registerScoped(HomeViewModel.self, scope: .screen) {
                HomeViewModel(
                    userService: UnifiedDI.resolve(UserService.self)!,
                    analytics: UnifiedDI.resolve(AnalyticsService.self)
                )
            }

            await GlobalUnifiedRegistry.registerScoped(ImageCache.self, scope: .screen) {
                ImageCache(maxSize: 50_000_000) // 이 화면을 위한 50MB 캐시
            }

            // 의존성이 이제 사용 가능하고 이 화면 내에서 캐시됩니다
            setupUI()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // 화면 스코프 정리 - HomeViewModel과 ImageCache 자동 정리
        ScopeContext.shared.clear(.screen)

        print("✅ 화면 의존성이 정리되었습니다")
    }

    private func setupUI() {
        // 이들은 동일한 캐시된 인스턴스로 해결됩니다
        let vm1 = UnifiedDI.resolve(HomeViewModel.self)
        let vm2 = UnifiedDI.resolve(HomeViewModel.self)
        // vm1 === vm2 (같은 인스턴스)

        let cache1 = UnifiedDI.resolve(ImageCache.self)
        let cache2 = UnifiedDI.resolve(ImageCache.self)
        // cache1 === cache2 (같은 인스턴스)
    }
}
```

**고급 화면 스코프 패턴**:

```swift
// 복잡한 UI를 위한 자식 스코프가 있는 화면 스코프
class DetailViewController: UIViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // 메인 화면 스코프
        ScopeContext.shared.setCurrent(.screen, id: "DetailScreen_\(itemID)")

        Task {
            // 메인 화면 의존성 등록
            await GlobalUnifiedRegistry.registerScoped(DetailViewModel.self, scope: .screen) {
                DetailViewModel(itemID: self.itemID)
            }

            // 계층적 ID를 가진 자식 구성 요소 의존성 등록
            await GlobalUnifiedRegistry.registerScoped(CommentListViewModel.self, scope: .screen) {
                CommentListViewModel(itemID: self.itemID)
            }

            await GlobalUnifiedRegistry.registerScoped(RelatedItemsViewModel.self, scope: .screen) {
                RelatedItemsViewModel(itemID: self.itemID)
            }
        }
    }
}
```

### 세션 스코프 - 사용자 인증 예제

세션 스코프는 사용자 세션 내의 여러 화면에서 지속되어야 하는 사용자별 의존성을 관리합니다.

**목적**: 사용자의 인증된 세션 전체에 걸쳐 사용자별 서비스와 데이터를 캐시합니다.

**생명주기**: 성공적인 인증 시 생성, 앱 사용 전반에 걸쳐 지속, 로그아웃이나 세션 만료 시 소멸.

```swift
class AuthenticationManager {
    func handleSuccessfulLogin(user: User) async {
        // 사용자 식별자로 세션 스코프 설정
        ScopeContext.shared.setCurrent(.session, id: "UserSession_\(user.id)")

        // 세션별 의존성 등록
        await GlobalUnifiedRegistry.registerScoped(UserSession.self, scope: .session) {
            UserSession(
                user: user,
                preferences: user.preferences,
                permissions: user.permissions
            )
        }

        await GlobalUnifiedRegistry.registerScoped(NotificationManager.self, scope: .session) {
            NotificationManager(
                userID: user.id,
                settings: user.notificationSettings
            )
        }

        await GlobalUnifiedRegistry.registerScoped(PersonalizationService.self, scope: .session) {
            PersonalizationService(
                userID: user.id,
                preferences: user.preferences
            )
        }

        // 세션 의존성이 이제 앱 전체에서 사용 가능합니다
        print("✅ 스코프 의존성과 함께 사용자 세션이 설정되었습니다")
    }

    func handleLogout() {
        // 세션 스코프 정리 - 모든 사용자별 의존성 자동 정리
        ScopeContext.shared.clear(.session)

        print("✅ 사용자 세션이 정리되었고, 모든 사용자별 의존성이 정리되었습니다")

        // 로그인 화면으로 이동
        navigateToLogin()
    }
}

// 앱 전체에서 사용 - 세션 의존성이 어디서나 사용 가능
class ProfileViewController: UIViewController {
    @Injected var userSession: UserSession?
    @Injected var personalization: PersonalizationService?

    override func viewDidLoad() {
        super.viewDidLoad()

        // 이들은 로그인 시 설정된 동일한 캐시된 인스턴스로 해결됩니다
        guard let session = userSession else { return }
        guard let personalizer = personalization else { return }

        // 세션 데이터 사용
        displayUserProfile(session.user)
        applyPersonalization(personalizer.getTheme())
    }
}
```

**새로고침이 있는 고급 세션 스코프**:

```swift
class SessionManager {
    func refreshSession() async {
        guard let currentUserID = ScopeContext.shared.currentID(for: .session) else { return }

        // 현재 세션 정리
        ScopeContext.shared.clear(.session)

        // 새로고침된 데이터로 재설정
        let refreshedUser = try await fetchUpdatedUserData()
        await handleSuccessfulLogin(user: refreshedUser)
    }
}
```

### 요청 스코프 - 서버 사이드 패턴

요청 스코프는 서버 사이드 애플리케이션이나 많은 독립적인 작업을 처리하는 클라이언트 애플리케이션에 이상적입니다.

**목적**: 데이터 혼합을 방지하고 적절한 정리를 가능하게 하기 위해 요청/작업별로 의존성을 격리합니다.

**생명주기**: 요청 시작 시 생성, 요청 처리 전반에 걸쳐 사용, 요청 완료 시 소멸.

```swift
class APIRequestHandler {
    func handleIncomingRequest(_ httpRequest: HTTPRequest) async -> HTTPResponse {
        // 고유한 요청 스코프 생성
        let requestID = UUID().uuidString
        ScopeContext.shared.setCurrent(.request, id: "Request_\(requestID)")

        defer {
            // 요청이 실패해도 정리 보장
            ScopeContext.shared.clear(.request)
        }

        do {
            // 요청별 의존성 등록
            await GlobalUnifiedRegistry.registerAsyncScoped(RequestContext.self, scope: .request) {
                await RequestContext.create(
                    requestID: requestID,
                    userAgent: httpRequest.headers["User-Agent"],
                    traceID: httpRequest.headers["X-Trace-ID"] ?? requestID
                )
            }

            await GlobalUnifiedRegistry.registerAsyncScoped(RequestLogger.self, scope: .request) {
                RequestLogger(requestID: requestID)
            }

            await GlobalUnifiedRegistry.registerAsyncScoped(DatabaseTransaction.self, scope: .request) {
                await DatabaseTransaction.begin()
            }

            // 스코프 의존성과 함께 요청 처리
            let response = await processRequest(httpRequest)

            // 성공 시 트랜잭션 커밋
            if let transaction = await UnifiedDI.resolveAsync(DatabaseTransaction.self) {
                await transaction.commit()
            }

            return response

        } catch {
            // 오류 시 트랜잭션 롤백
            if let transaction = await UnifiedDI.resolveAsync(DatabaseTransaction.self) {
                await transaction.rollback()
            }

            throw error
        }
    }

    private func processRequest(_ request: HTTPRequest) async -> HTTPResponse {
        // 이들은 요청별 캐시된 인스턴스로 해결됩니다
        let context = await UnifiedDI.resolveAsync(RequestContext.self)!
        let logger = await UnifiedDI.resolveAsync(RequestLogger.self)!

        logger.info("요청 처리 중: \(context.requestID)")

        // 여기에 비즈니스 로직...
        // 모든 의존성이 이 특정 요청에 격리됩니다

        return HTTPResponse.ok()
    }
}
```

**동시 요청 처리**:

```swift
class ConcurrentAPIServer {
    func handleMultipleRequests(_ requests: [HTTPRequest]) async {
        // 각각 격리된 스코프로 여러 요청을 동시에 처리
        await withTaskGroup(of: HTTPResponse.self) { group in
            for request in requests {
                group.addTask {
                    await self.handleIncomingRequest(request)
                }
            }
        }
        // 각 요청이 자체적인 격리된 의존성을 가졌습니다
    }
}
```

## 생명주기 관리 패턴

### iOS 앱 생명주기 통합

```swift
class AppDelegate: UIResponder, UIApplicationDelegate {
    func applicationDidBecomeActive(_ application: UIApplication) {
        // 필요한 경우 앱 레벨 스코프 설정
        ScopeContext.shared.setCurrent(.session, id: "AppSession_\(Date().timeIntervalSince1970)")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // 메모리 해제를 위한 임시 스코프 정리
        ScopeContext.shared.clear(.screen)

        // 앱이 포그라운드로 돌아올 때를 위해 세션 스코프 유지
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // 모든 스코프 정리
        ScopeContext.shared.clear(.session)
        ScopeContext.shared.clear(.screen)
        ScopeContext.shared.clear(.request)
    }
}
```

### SwiftUI 통합

```swift
struct ContentView: View {
    var body: some View {
        NavigationView {
            HomeView()
        }
        .onAppear {
            ScopeContext.shared.setCurrent(.screen, id: "MainNavigation")
        }
        .onDisappear {
            ScopeContext.shared.clear(.screen)
        }
    }
}

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        VStack {
            // UI 콘텐츠
        }
        .task {
            // 화면 스코프 설정
            ScopeContext.shared.setCurrent(.screen, id: "HomeView")

            // 스코프 의존성 등록
            await GlobalUnifiedRegistry.registerScoped(HomeScreenCache.self, scope: .screen) {
                HomeScreenCache()
            }
        }
    }
}
```

## 고급 패턴

### 계층적 스코프

```swift
// 주요 섹션을 위한 부모 스코프
ScopeContext.shared.setCurrent(.session, id: "ShoppingSession")

// 특정 플로우를 위한 자식 스코프
ScopeContext.shared.setCurrent(.screen, id: "CheckoutFlow")

// 정리할 때는 자식 스코프부터 정리
ScopeContext.shared.clear(.screen)  // 체크아웃 플로우 정리
// 사용자가 로그아웃할 때까지 세션 계속
```

### 조건부 스코프 등록

```swift
func registerDependencies() async {
    let scopeID = ScopeContext.shared.currentID(for: .screen)

    if scopeID?.contains("Admin") == true {
        // 관리자별 의존성
        await GlobalUnifiedRegistry.registerScoped(AdminService.self, scope: .screen) {
            AdminService()
        }
    } else {
        // 일반 사용자 의존성
        await GlobalUnifiedRegistry.registerScoped(UserService.self, scope: .screen) {
            UserService()
        }
    }
}
```

### 스코프 전환 처리

```swift
class NavigationManager {
    func navigateToScreen(_ screenID: String) async {
        // 현재 화면 스코프 정리
        ScopeContext.shared.clear(.screen)

        // 새 화면 스코프 설정
        ScopeContext.shared.setCurrent(.screen, id: screenID)

        // 새 화면 의존성 등록
        await registerDependenciesForScreen(screenID)
    }
}
```

## 성능 고려사항

### 메모리 관리
- **스코프 크기**: 과도한 메모리 사용을 피하기 위해 적절한 스코프 경계 유지
- **정리 타이밍**: 컨텍스트가 끝날 때 즉시 스코프 정리
- **캐시 제한**: 스코프에서 큰 객체를 캐시할 때 메모리 제한 고려

### 동시성 성능
- **스레드 안전성**: 모든 스코프 작업은 스레드 안전함
- **Actor 통합**: Swift의 actor 모델과 원활하게 작동
- **병렬 접근**: 여러 스레드가 스코프 의존성에 안전하게 접근 가능

### 디버깅 및 모니터링

```swift
// 현재 스코프 상태 확인
func debugScopes() {
    let screenID = ScopeContext.shared.currentID(for: .screen)
    let sessionID = ScopeContext.shared.currentID(for: .session)
    let requestID = ScopeContext.shared.currentID(for: .request)

    print("현재 스코프:")
    print("  화면: \(screenID ?? "없음")")
    print("  세션: \(sessionID ?? "없음")")
    print("  요청: \(requestID ?? "없음")")
}

// 스코프 생명주기 모니터링
class ScopeMonitor {
    static func logScopeChange(_ kind: ScopeKind, _ action: String, id: String?) {
        print("🔍 스코프 \(action): \(kind) - \(id ?? "nil")")
    }
}
```

## 문제 해결 가이드

### 일반적인 문제와 해결책

#### "스코프가 적용되지 않음"
**증상**: 의존성이 캐시되지 않고, 매번 새 인스턴스가 생성됨
**원인**: 등록 전에 스코프 ID가 설정되지 않음
**해결책**:
```swift
// ❌ 잘못된 순서
await GlobalUnifiedRegistry.registerScoped(MyService.self, scope: .screen) { MyService() }
ScopeContext.shared.setCurrent(.screen, id: "MyScreen") // 너무 늦음!

// ✅ 올바른 순서
ScopeContext.shared.setCurrent(.screen, id: "MyScreen")
await GlobalUnifiedRegistry.registerScoped(MyService.self, scope: .screen) { MyService() }
```

#### "메모리 누수 감지"
**증상**: 시간이 지나면서 메모리 사용량이 증가하고, 객체가 해제되지 않음
**원인**: 스코프가 끝날 때 `clear()`를 호출하는 것을 잊음
**해결책**:
```swift
// ✅ 항상 setCurrent와 clear를 쌍으로 사용
override func viewWillAppear(_ animated: Bool) {
    ScopeContext.shared.setCurrent(.screen, id: "MyScreen")
    // 의존성 등록...
}

override func viewDidDisappear(_ animated: Bool) {
    ScopeContext.shared.clear(.screen) // 필수적인 정리!
}
```

#### "동시성 문제"
**증상**: 경쟁 조건, 멀티스레드 코드에서 예상치 못한 동작
**해결책**: WeaveDI 스코프는 본질적으로 스레드 안전하지만, 적절한 async/await 사용을 보장하세요:
```swift
// ✅ 적절한 비동기 등록
await GlobalUnifiedRegistry.registerAsyncScoped(AsyncService.self, scope: .request) {
    await AsyncService.create()
}

// ✅ 적절한 비동기 해결
let service = await UnifiedDI.resolveAsync(AsyncService.self)
```

#### "의존성을 찾을 수 없음"
**증상**: 등록 후에도 해결이 nil을 반환함
**원인**: 등록과 해결 사이에 스코프가 정리됨
**해결책**: 스코프 생명주기가 의존성 사용과 일치하는지 확인:
```swift
func checkScopeStatus() {
    if ScopeContext.shared.currentID(for: .screen) == nil {
        print("⚠️ 화면 스코프가 설정되지 않음 - 의존성이 캐시되지 않습니다")
    }
}
```

## 모범 사례 요약

### 1. 스코프 생명주기 관리
- 항상 `setCurrent`와 `clear`를 쌍으로 사용
- 의미 있고 고유한 스코프 ID 사용
- 컨텍스트가 끝날 때 즉시 스코프 정리

### 2. 의존성 설계
- 관련된 의존성을 동일한 스코프에 그룹화
- 가능하면 크로스 스코프 의존성 피하기
- 의존성이 스코프를 인식하도록 설계

### 3. 성능 최적화
- 오래 지속되는 스코프에서 메모리 사용량 모니터링
- 짧은 생명주기 작업에 요청 스코프 사용
- 사용하지 않는 스코프 사전 정리

### 4. 오류 처리
- 정리를 보장하기 위한 defer 블록 사용
- 스코프 전환을 우아하게 처리
- 스코프를 사용할 수 없을 때 대체 동작 제공

> **중요**: 스코프 ID가 설정되지 않으면, 스코프 등록은 일회성 생성으로 동작합니다 (캐싱 없음). 이는 캐싱을 기대하지만 매번 새 인스턴스를 얻는 예상치 못한 동작으로 이어질 수 있습니다.

## 참고

- [코어 API](../api/coreApis.md) - 상세한 등록 및 해결 방법
- [프로퍼티 래퍼](./propertyWrappers.md) - @Injected로 스코프 의존성 사용하기
- [부트스트랩 가이드](./bootstrap.md) - 앱 시작 시 스코프 의존성 설정하기