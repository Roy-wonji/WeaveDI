# @Inject 프로퍼티 래퍼

`@Inject` 프로퍼티 래퍼는 클래스와 구조체의 프로퍼티에 자동 의존성 주입을 제공합니다. 깔끔한 의존성 관리를 위한 WeaveDI의 가장 널리 사용되는 기능입니다.

## 개요

`@Inject`는 프로퍼티에 처음 접근할 때 DI 컨테이너에서 의존성을 자동으로 해결합니다. 옵셔널 해결을 제공하여 누락된 의존성에 대해 코드가 회복력을 갖도록 합니다.

```swift
import WeaveDI

class WeatherViewModel: ObservableObject {
    @Inject var weatherService: WeatherService?
    @Inject var logger: LoggerProtocol?

    func loadWeather() {
        logger?.info("날씨 데이터 로딩 중...")
        weatherService?.fetchCurrentWeather()
    }
}
```

## 기본 사용법

### 간단한 주입

```swift
class UserViewController: UIViewController {
    @Inject var userService: UserService?

    override func viewDidLoad() {
        super.viewDidLoad()
        userService?.loadUserData()
    }
}
```

### 프로토콜 타입과 함께

더 나은 테스트 가능성을 위해 구체적인 타입보다는 항상 프로토콜을 주입하세요:

```swift
// ✅ 좋음 - 프로토콜 주입
@Inject var networkClient: NetworkClientProtocol?

// ❌ 피하세요 - 구체적인 타입 주입
@Inject var networkClient: URLSessionNetworkClient?
```

## 실제 예제

### CountApp에서 @Inject 사용 (튜토리얼에서)

실제 튜토리얼 코드를 기반으로:

```swift
/// @Inject를 사용한 의존성이 있는 카운터 Repository
class UserDefaultsCounterRepository: CounterRepository {
    /// WeaveDI를 통해 Logger 주입
    @Inject var logger: LoggerProtocol?

    func getCurrentCount() async -> Int {
        let count = UserDefaults.standard.integer(forKey: "saved_count")
        logger?.info("📊 현재 카운트 로드: \(count)")
        return count
    }

    func saveCount(_ count: Int) async {
        UserDefaults.standard.set(count, forKey: "saved_count")
        logger?.info("💾 카운트 저장: \(count)")
    }
}

/// 주입된 의존성이 있는 ViewModel
@MainActor
class CounterViewModel: ObservableObject {
    @Published var count = 0
    @Published var isLoading = false

    /// @Inject를 통해 Repository와 Logger 주입
    @Inject var repository: CounterRepository?
    @Inject var logger: LoggerProtocol?

    func increment() async {
        guard let repo = repository else { return }

        isLoading = true
        count += 1
        await repo.saveCount(count)
        isLoading = false

        logger?.info("⬆️ 카운트 증가: \(count)")
    }
}
```

### WeatherApp에서 @Inject 사용

```swift
/// HTTP 클라이언트가 주입된 날씨 서비스
class WeatherService: WeatherServiceProtocol {
    @Inject var httpClient: HTTPClientProtocol?
    @Inject var logger: LoggerProtocol?

    func fetchCurrentWeather(for city: String) async throws -> Weather {
        guard let client = httpClient else {
            throw WeatherError.httpClientNotAvailable
        }

        logger?.info("🌤️ \(city)의 날씨 가져오는 중")
        let data = try await client.fetchData(from: weatherURL(for: city))
        return try JSONDecoder().decode(Weather.self, from: data)
    }
}

/// 여러 서비스가 주입된 ViewModel
@MainActor
class WeatherViewModel: ObservableObject {
    @Published var currentWeather: Weather?
    @Published var isLoading = false

    @Inject var weatherService: WeatherServiceProtocol?
    @Inject var cacheService: CacheServiceProtocol?
    @Inject var logger: LoggerProtocol?

    func loadWeather(for city: String) async {
        logger?.info("📍 \(city)의 날씨 로딩 중")

        isLoading = true
        defer { isLoading = false }

        do {
            currentWeather = try await weatherService?.fetchCurrentWeather(for: city)
            await cacheWeather()
        } catch {
            logger?.error("❌ 날씨 로딩 실패: \(error)")
            await loadCachedWeather()
        }
    }
}
```

## SwiftUI 통합

### StateObject와 함께

```swift
struct CounterView: View {
    @StateObject private var viewModel = CounterViewModel()

    var body: some View {
        VStack {
            Text("\(viewModel.count)")
                .font(.largeTitle)

            Button("증가") {
                Task { await viewModel.increment() }
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
    }
}
```

### 뷰에서 직접 주입

```swift
struct SettingsView: View {
    @Inject var settingsService: SettingsService?
    @Inject var logger: LoggerProtocol?

    var body: some View {
        List {
            Toggle("알림", isOn: .constant(true))
                .onChange(of: true) { enabled in
                    settingsService?.setNotifications(enabled)
                    logger?.info("🔔 알림: \(enabled)")
                }
        }
    }
}
```

## 스레드 안전성

`@Inject`는 스레드 안전하며 다른 큐에서 사용할 수 있습니다:

```swift
class BackgroundService {
    @Inject var dataProcessor: DataProcessor?

    func processInBackground() {
        DispatchQueue.global(qos: .background).async {
            // 백그라운드 큐에서 주입된 의존성에 안전하게 접근
            self.dataProcessor?.processLargeDataset()
        }
    }
}
```

## @Inject로 테스팅

### 테스트를 위한 Mock 주입

```swift
class UserServiceTests: XCTestCase {
    override func setUp() async throws {
        await DIContainer.resetForTesting()

        await DIContainer.bootstrap { container in
            // 테스트를 위한 Mock 등록
            container.register(UserRepository.self) { MockUserRepository() }
            container.register(Logger.self) { MockLogger() }
        }
    }

    func testUserService() {
        let service = UserService()
        // @Inject 프로퍼티는 Mock 인스턴스로 해결됩니다
        XCTAssertTrue(service.repository is MockUserRepository)
    }
}
```

## 오류 처리

### 우아한 성능 저하

```swift
class AnalyticsManager {
    @Inject var analyticsService: AnalyticsService?

    func trackEvent(_ event: String) {
        // 누락된 의존성을 우아하게 처리
        if let service = analyticsService {
            service.track(event)
        } else {
            print("⚠️ 분석 서비스를 사용할 수 없습니다. 이벤트가 추적되지 않음: \(event)")
        }
    }
}
```

### 런타임 검증

```swift
class CriticalService {
    @Inject var essentialDependency: EssentialService?

    func performCriticalOperation() {
        guard let dependency = essentialDependency else {
            fatalError("CriticalService를 사용하기 전에 EssentialService가 등록되어야 합니다")
        }

        dependency.performOperation()
    }
}
```

## 성능 고려사항

### 지연 해결

의존성은 첫 번째 접근 시 지연으로 해결됩니다:

```swift
class ExpensiveService {
    @Inject var heavyDependency: HeavyService? // 접근할 때까지 해결되지 않음

    func lightweightOperation() {
        // heavyDependency는 여기서 해결되지 않음
        print("가벼운 작업 수행 중")
    }

    func heavyOperation() {
        // heavyDependency는 첫 번째 접근 시 해결됨
        heavyDependency?.performHeavyWork()
    }
}
```

### 캐싱

한 번 해결되면 의존성 참조가 캐시됩니다:

```swift
class CachedService {
    @Inject var service: SomeService?

    func multipleAccesses() {
        service?.method1() // 컨테이너에서 해결
        service?.method2() // 캐시된 참조 사용
        service?.method3() // 캐시된 참조 사용
    }
}
```

## 일반적인 패턴

### Repository 패턴

```swift
class DataRepository {
    @Inject var networkClient: NetworkClient?
    @Inject var cacheManager: CacheManager?
    @Inject var logger: Logger?

    func fetchData() async -> Data? {
        // 먼저 캐시 시도
        if let cachedData = await cacheManager?.getCachedData() {
            logger?.info("📱 캐시된 데이터 사용")
            return cachedData
        }

        // 네트워크에서 가져오기
        do {
            let data = try await networkClient?.fetchData()
            await cacheManager?.cache(data)
            logger?.info("🌐 새로운 데이터 가져옴")
            return data
        } catch {
            logger?.error("❌ 네트워크 가져오기 실패: \(error)")
            return nil
        }
    }
}
```

### 서비스 레이어

```swift
class UserService {
    @Inject var userRepository: UserRepository?
    @Inject var authService: AuthService?
    @Inject var logger: Logger?

    func getCurrentUser() async -> User? {
        guard let auth = authService,
              let repo = userRepository else {
            logger?.error("필요한 의존성을 사용할 수 없습니다")
            return nil
        }

        guard let userId = auth.currentUserId else {
            logger?.info("인증된 사용자가 없습니다")
            return nil
        }

        return await repo.getUser(id: userId)
    }
}
```

## 모범 사례

### 1. 항상 옵셔널 사용

`@Inject`는 누락된 의존성을 우아하게 처리하기 위해 옵셔널 해결을 제공합니다:

```swift
// ✅ 좋음
@Inject var service: MyService?

// ❌ 피하세요
@Inject var service: MyService // 컴파일러 오류
```

### 2. Nil 케이스 처리

주입이 실패할 수 있는 경우를 항상 처리하세요:

```swift
func performAction() {
    guard let service = injectedService else {
        print("서비스를 사용할 수 없습니다")
        return
    }
    service.performAction()
}
```

### 3. 구현이 아닌 프로토콜 주입

```swift
// ✅ 좋음 - 테스트 가능하고 유연함
@Inject var logger: LoggerProtocol?

// ❌ 피하세요 - 테스트하고 Mock하기 어려움
@Inject var logger: ConsoleLogger?
```

### 4. 의존성 문서화

```swift
class WeatherService {
    /// 네트워크 요청을 위한 HTTP 클라이언트
    @Inject var httpClient: HTTPClientProtocol?

    /// 디버깅 및 모니터링을 위한 로거
    @Inject var logger: LoggerProtocol?

    /// 오프라인 날씨 데이터를 위한 캐시
    @Inject var cache: CacheServiceProtocol?
}
```

## 참고

- [@Factory 프로퍼티 래퍼](./factory.md) - 팩토리 기반 주입용
- [@SafeInject 프로퍼티 래퍼](./safeInject.md) - 보장된 주입용
- [프로퍼티 래퍼 가이드](../guide/propertyWrappers.md) - 모든 프로퍼티 래퍼의 포괄적인 가이드