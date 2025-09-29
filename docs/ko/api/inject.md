# @Inject 프로퍼티 래퍼

`@Inject` 프로퍼티 래퍼는 클래스와 구조체의 프로퍼티에 자동 의존성 주입을 제공하는 WeaveDI의 핵심 기능입니다. 이는 깔끔하고 선언적인 의존성 관리를 통해 코드의 가독성을 높이고 테스트 가능성을 향상시키는 가장 널리 사용되는 기능입니다.

## 개요

`@Inject`는 프로퍼티에 처음 접근할 때 DI 컨테이너에서 의존성을 자동으로 해결하는 지연 평가(lazy evaluation) 방식을 사용합니다. 옵셔널 해결을 제공하여 누락된 의존성에 대해 코드가 회복력을 갖도록 하며, 이는 런타임 크래시를 방지하고 우아한 성능 저하(graceful degradation)를 가능하게 합니다.

**핵심 특징**:
- **지연 해결(Lazy Resolution)**: 프로퍼티 첫 접근 시에만 의존성을 해결하여 성능 최적화
- **옵셔널 안전성(Optional Safety)**: 의존성이 등록되지 않은 경우 nil 반환으로 크래시 방지
- **자동 캐싱(Automatic Caching)**: 한 번 해결된 의존성은 재사용되어 성능 향상
- **스레드 안전성(Thread Safety)**: 모든 큐에서 안전하게 접근 가능한 스레드 안전 구현

**성능 특성**:
- **첫 접근**: 의존성 해결을 위한 작은 오버헤드 (~0.1-1ms)
- **후속 접근**: 거의 제로 오버헤드 (직접 프로퍼티 접근)
- **메모리 사용량**: 해결된 의존성 추적을 위한 최소 메모리 오버헤드

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

**목적**: 기본적인 의존성 주입으로 자동 의존성 해결을 위한 `@Inject` 프로퍼티 래퍼 사용법입니다.

**동작 방식**:
- **지연 해결**: 프로퍼티 첫 접근 시에만 의존성 해결
- **옵셔널 안전성**: 서비스가 등록되지 않은 경우 nil 반환으로 크래시 방지
- **자동 캐싱**: 첫 해결 후 동일한 인스턴스 재사용
- **스레드 안전성**: 모든 큐에서 스레드 안전하게 해결

**성능 특성**:
- **첫 접근**: 의존성 해결을 위한 작은 오버헤드 (~0.1-1ms)
- **후속 접근**: 거의 제로 오버헤드 (직접 프로퍼티 접근)
- **메모리 사용량**: 해결된 의존성 추적을 위한 최소 메모리 오버헤드
- **스레드 안전성**: 모든 큐에서 안전하게 접근 가능

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

**모범 사례**: 구체적인 타입보다는 항상 프로토콜을 주입하여 테스트 가능성, 유연성, 의존성 역전 원칙을 준수하세요.

**프로토콜 주입의 이점**:
- **테스트 가능성**: 테스트 중 Mock 구현체를 쉽게 대체 가능
- **유연성**: 클라이언트 코드 변경 없이 구현체 교체 가능
- **느슨한 결합**: 모듈 간 의존성 감소
- **인터페이스 분리**: 클라이언트가 사용하는 인터페이스에만 의존

**구현 가이드라인**:
- 서비스를 위한 명확하고 집중된 프로토콜 정의
- 복잡한 동작을 위한 프로토콜 컴포지션 사용
- 프로토콜을 통한 구현 세부사항 노출 방지

더 나은 테스트 가능성을 위해 구체적인 타입보다는 항상 프로토콜을 주입하세요:

```swift
// ✅ 좋음 - 프로토콜 주입
@Inject var networkClient: NetworkClientProtocol?

// ❌ 피하세요 - 구체적인 타입 주입
@Inject var networkClient: URLSessionNetworkClient?
```

## 실제 예제

### CountApp에서 @Inject 사용 (튜토리얼에서)

**목적**: 실제 CountApp 튜토리얼 코드를 기반으로 한 `@Inject` 사용법과 의존성 주입 패턴의 실제 적용 사례입니다.

**아키텍처 패턴**:
- **Repository 패턴**: 데이터 접근 계층의 추상화
- **MVVM 패턴**: Model-View-ViewModel 아키텍처 구현
- **의존성 주입**: 느슨한 결합을 위한 의존성 관리
- **로깅 통합**: 모든 계층에 걸친 통합 로깅

**성능 최적화**:
- **지연 초기화**: 서비스는 실제 사용 시점에 초기화
- **싱글톤 패턴**: Repository와 Logger는 싱글톤으로 관리
- **메모리 효율성**: 불필요한 인스턴스 생성 방지

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

**목적**: WeatherApp에서의 복잡한 의존성 주입 패턴과 에러 처리, 캐싱 전략의 실제 구현 사례입니다.

**아키텍처 특징**:
- **계층화된 아키텍처**: Service → Repository → Network 계층 구조
- **에러 처리**: 포괄적인 에러 처리 및 복구 전략
- **캐싱 전략**: 성능 향상을 위한 다층 캐싱
- **비동기 처리**: async/await를 활용한 현대적 비동기 패턴

**성능 고려사항**:
- **네트워크 최적화**: 불필요한 네트워크 호출 최소화
- **캐시 활용**: 캐시된 데이터 우선 사용으로 응답성 향상
- **에러 복구**: 네트워크 실패 시 캐시 데이터로 우아한 복구

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

**목적**: SwiftUI의 StateObject와 `@Inject`의 통합으로 선언적 UI와 의존성 주입을 결합한 현대적 iOS 앱 개발 패턴입니다.

**통합 이점**:
- **선언적 코드**: SwiftUI의 선언적 패러다임과 DI의 자연스러운 결합
- **생명주기 관리**: StateObject가 ViewModel 생명주기를 자동 관리
- **데이터 바인딩**: @Published 프로퍼티를 통한 자동 UI 업데이트
- **테스트 용이성**: ViewModel 단위 테스트의 용이성

**성능 특성**:
- **지연 로딩**: ViewModel의 의존성들이 필요 시점에 로드
- **메모리 효율성**: SwiftUI가 ViewModel 생명주기를 효율적으로 관리
- **UI 반응성**: 의존성 해결이 UI 스레드를 블록하지 않음

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

**목적**: SwiftUI View에서 직접 의존성을 주입하여 간단한 서비스 액세스와 빠른 프로토타이핑을 가능하게 하는 패턴입니다.

**직접 주입의 이점**:
- **단순성**: ViewModel 없이도 서비스에 직접 접근
- **빠른 개발**: 간단한 기능을 위한 빠른 구현
- **유연성**: View별로 다른 서비스 조합 사용 가능
- **테스트**: 개별 View 동작의 독립적 테스트 가능

**사용 시나리오**:
- 설정 화면과 같은 간단한 View
- 상태 관리가 필요하지 않은 단순 기능
- 프로토타이핑 및 빠른 개발
- 일회성 작업을 수행하는 View

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

**스레드 안전성 보장**: `@Inject`는 포괄적인 스레드 안전성을 제공하여 멀티스레드 환경에서 안전한 의존성 접근을 보장합니다.

**안전성 메커니즘**:
- **독립적인 인스턴스**: 각 프로퍼티 접근이 격리된 인스턴스를 생성하지 않고 안전하게 공유
- **스레드 안전 해결**: 컨테이너 해결이 내부적으로 동기화됨
- **동시 접근**: 여러 스레드가 안전하게 팩토리 프로퍼티에 접근 가능
- **메모리 장벽**: 일관된 가시성을 위한 자동 메모리 장벽 처리

**동시성 이점**:
- **병렬 처리**: 각 스레드가 독립적인 인스턴스를 얻음
- **수동 동기화 불필요**: 수동 스레드 동기화 필요 없음
- **경쟁 조건 방지**: 인스턴스 격리로 경쟁 조건 방지
- **확장 가능한 동시성**: 스레드 수에 따른 성능 확장

**성능 특성**:
- **해결 오버헤드**: 해결 중 최소 동기화 접근 오버헤드
- **인스턴스 생성**: 인스턴스 생성 후 동기화 없음
- **메모리 장벽**: 자동 메모리 장벽 처리

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

**테스트 전략**: `@Inject`는 새로운 Mock 인스턴스와 상태 격리를 통해 강력한 테스트 패턴을 제공합니다.

**테스트 이점**:
- **신뢰할 수 있는 테스트 의존성**: 누락된 의존성으로 인한 테스트 실패 없음
- **유연한 Mock 전략**: 실제 의존성과 Mock 의존성 간 쉬운 전환
- **격리된 테스트**: 각 테스트가 독립적인 컨테이너 상태를 가짐
- **통합 테스트**: 부분적인 Mock으로 전체 시스템 테스트

**테스트 구성 패턴**:
- **전체 Mock 환경**: 모든 의존성을 Mock으로 등록
- **부분 Mock 환경**: 일부 Mock, 일부 실제 구현체 사용
- **통합 테스트**: 실제 의존성과 Mock 의존성의 혼합 사용

```swift
class UserServiceTests: XCTestCase {
    override func setUp() async throws {
        await WeaveDI.Container.resetForTesting()

        await WeaveDI.Container.bootstrap { container in
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

**목적**: 의존성이 사용할 수 없는 경우에도 애플리케이션이 계속 작동할 수 있도록 하는 회복력 있는 에러 처리 패턴입니다.

**우아한 성능 저하의 이점**:
- **애플리케이션 안정성**: 누락된 의존성으로 인한 크래시 방지
- **사용자 경험**: 일부 기능이 없어도 애플리케이션 사용 가능
- **개발 유연성**: 모든 서비스가 구현되지 않아도 개발 진행 가능
- **점진적 배포**: 기능별로 점진적인 배포 및 롤백 가능

**패턴 구현**:
- **옵셔널 체이닝**: 안전한 메서드 호출을 위한 옵셔널 체이닝 사용
- **기본값 제공**: 서비스가 없는 경우 기본 동작 제공
- **로깅**: 누락된 서비스에 대한 적절한 로깅
- **사용자 피드백**: 기능 제한에 대한 사용자 알림

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

**목적**: 중요한 의존성의 가용성을 런타임에 검증하여 애플리케이션의 핵심 기능이 올바르게 작동하도록 보장합니다.

**검증 전략**:
- **조기 검증**: 애플리케이션 시작 시 중요한 의존성 검증
- **실패 빠른 처리**: 중요한 의존성이 없는 경우 즉시 실패
- **명확한 에러 메시지**: 누락된 의존성에 대한 명확한 설명
- **개발자 가이드**: 누락된 의존성 해결 방법 안내

**검증 레벨**:
- **중요(Critical)**: 애플리케이션 핵심 기능에 필수적인 의존성
- **선택적(Optional)**: 향상된 기능을 위한 선택적 의존성
- **개발(Development)**: 개발 및 디버깅을 위한 의존성

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

**성능 최적화 전략**: 의존성이 첫 번째 접근 시에만 지연으로 해결되어 애플리케이션 시작 시간을 최적화하고 메모리 사용량을 줄입니다.

**지연 해결의 이점**:
- **빠른 앱 시작**: 사용하지 않는 의존성은 초기화되지 않음
- **메모리 효율성**: 필요한 경우에만 메모리 할당
- **조건부 사용**: 특정 조건에서만 사용되는 서비스의 효율적 관리
- **점진적 로딩**: 사용자 상호작용에 따른 점진적 기능 로딩

**성능 특성**:
- **초기화 비용**: 무거운 의존성의 초기화 비용을 실제 사용 시점으로 연기
- **메모리 사용량**: 사용하지 않는 서비스로 인한 메모리 낭비 방지
- **CPU 효율성**: 불필요한 초기화 작업 방지로 CPU 효율성 향상

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

**캐싱 전략**: 한 번 해결된 의존성 참조가 자동으로 캐시되어 후속 접근에서 뛰어난 성능을 제공합니다.

**캐싱 이점**:
- **성능 향상**: 첫 해결 후 거의 제로 오버헤드로 접근
- **일관성**: 동일한 인스턴스 참조로 일관된 상태 유지
- **메모리 효율성**: 중복 인스턴스 생성 방지
- **예측 가능성**: 예측 가능한 성능 특성

**캐싱 메커니즘**:
- **자동 캐싱**: 첫 해결 시 자동으로 참조 저장
- **스레드 안전**: 멀티스레드 환경에서 안전한 캐시 접근
- **메모리 관리**: 적절한 메모리 관리로 메모리 누수 방지
- **생명주기**: 프로퍼티 래퍼 생명주기와 연동된 캐시 관리

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

**목적**: 데이터 접근 계층을 추상화하여 비즈니스 로직과 데이터 소스를 분리하는 Repository 패턴의 `@Inject` 적용 사례입니다.

**Repository 패턴의 이점**:
- **계층 분리**: 데이터 접근 로직과 비즈니스 로직의 명확한 분리
- **테스트 용이성**: Mock Repository를 통한 쉬운 단위 테스트
- **유연성**: 다양한 데이터 소스 간 쉬운 전환
- **캐싱 전략**: 통합된 캐싱 및 성능 최적화

**구현 특징**:
- **다중 데이터 소스**: 네트워크, 캐시, 로컬 데이터베이스의 조합
- **에러 처리**: 포괄적인 에러 처리 및 복구 전략
- **성능 최적화**: 캐시 우선 접근으로 성능 최적화
- **로깅 통합**: 모든 데이터 접근에 대한 통합 로깅

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

**목적**: 비즈니스 로직을 캡슐화하고 여러 Repository와 서비스 간의 조정을 담당하는 서비스 레이어 패턴입니다.

**서비스 레이어의 특징**:
- **비즈니스 로직 캡슐화**: 복잡한 비즈니스 규칙의 중앙 집중식 관리
- **트랜잭션 관리**: 여러 Repository에 걸친 트랜잭션 조정
- **의존성 조정**: 여러 하위 서비스 간의 의존성 관리
- **에러 처리**: 비즈니스 레벨의 에러 처리 및 복구

**아키텍처 이점**:
- **관심사 분리**: 각 서비스가 특정 비즈니스 도메인에 집중
- **재사용성**: 여러 UI 계층에서 동일한 서비스 로직 재사용
- **테스트 용이성**: 비즈니스 로직의 독립적 테스트
- **확장성**: 비즈니스 요구사항 변화에 대한 유연한 대응

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

**가이드라인**: `@Inject`는 의존성이 누락된 경우를 우아하게 처리하기 위해 옵셔널 해결을 제공하므로, 항상 옵셔널 타입을 사용해야 합니다.

**옵셔널 사용의 이점**:
- **크래시 방지**: 누락된 의존성으로 인한 런타임 크래시 방지
- **개발 유연성**: 모든 의존성이 구현되지 않아도 개발 진행 가능
- **테스트 용이성**: 부분적 Mock을 통한 유연한 테스트 환경 구성
- **점진적 개발**: 기능별 점진적 개발 및 배포 가능

**컴파일 시간 안전성**:
- **타입 안전성**: Swift의 옵셔널 타입 시스템을 활용한 안전성
- **명시적 처리**: 옵셔널 바인딩을 통한 명시적 nil 처리
- **코드 가독성**: 의존성의 선택적 특성을 코드에서 명확히 표현

`@Inject`는 누락된 의존성을 우아하게 처리하기 위해 옵셔널 해결을 제공합니다:

```swift
// ✅ 좋음
@Inject var service: MyService?

// ❌ 피하세요
@Inject var service: MyService // 컴파일러 오류
```

### 2. Nil 케이스 처리

**전략**: 의존성 주입이 실패할 수 있는 모든 경우를 적절히 처리하여 애플리케이션의 안정성과 사용자 경험을 보장하세요.

**Nil 처리 패턴**:
- **Guard 문**: 조기 반환을 통한 명확한 에러 처리
- **옵셔널 바인딩**: if-let을 통한 안전한 값 추출
- **Nil 병합 연산자**: 기본값 제공을 통한 우아한 성능 저하
- **옵셔널 체이닝**: 안전한 메서드 호출 체인

**에러 처리 전략**:
- **로깅**: 누락된 의존성에 대한 적절한 로깅
- **사용자 피드백**: 기능 제한에 대한 사용자 알림
- **대체 동작**: 의존성이 없는 경우의 대체 로직
- **개발자 도구**: 개발 환경에서의 디버깅 정보 제공

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

**설계 원칙**: 구체적인 구현체가 아닌 프로토콜을 주입하여 의존성 역전 원칙(Dependency Inversion Principle)을 준수하고 코드의 유연성을 높이세요.

**프로토콜 주입의 이점**:
- **테스트 용이성**: Mock 구현체를 통한 쉽고 안정적인 단위 테스트
- **유연성**: 런타임에 다른 구현체로 교체 가능
- **확장성**: 새로운 구현체 추가 시 기존 코드 변경 최소화
- **모듈화**: 인터페이스를 통한 모듈 간 결합도 감소

**설계 가이드라인**:
- **단일 책임**: 각 프로토콜이 하나의 명확한 책임을 가짐
- **인터페이스 분리**: 클라이언트가 사용하지 않는 메서드에 의존하지 않음
- **최소 인터페이스**: 필요한 최소한의 메서드만 프로토콜에 정의
- **의미 있는 이름**: 프로토콜의 역할을 명확히 표현하는 이름 사용

```swift
// ✅ 좋음 - 테스트 가능하고 유연함
@Inject var logger: LoggerProtocol?

// ❌ 피하세요 - 테스트하고 Mock하기 어려움
@Inject var logger: ConsoleLogger?
```

### 4. 의존성 문서화

**문서화 전략**: 각 의존성의 목적과 역할을 명확히 문서화하여 코드의 가독성과 유지보수성을 향상시키세요.

**문서화 요소**:
- **의존성 목적**: 해당 의존성이 왜 필요한지 설명
- **사용 패턴**: 의존성이 어떻게 사용되는지 기술
- **생명주기**: 의존성의 생명주기와 관리 방식
- **대체 가능성**: 의존성이 선택적인지 필수적인지 명시

**문서화 이점**:
- **팀 협업**: 팀원들이 코드를 쉽게 이해하고 수정 가능
- **유지보수**: 의존성 변경 시 영향도 파악 용이
- **온보딩**: 새로운 팀원의 빠른 코드베이스 이해
- **아키텍처 이해**: 시스템의 전체적인 의존성 구조 파악

**문서화 도구**:
- **인라인 주석**: 코드 내 직접적인 설명
- **DocC**: Swift의 공식 문서화 도구 활용
- **README**: 프로젝트 레벨의 의존성 설명
- **아키텍처 다이어그램**: 의존성 관계의 시각적 표현

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