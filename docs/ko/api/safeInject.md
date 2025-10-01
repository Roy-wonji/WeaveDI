# @SafeInject 프로퍼티 래퍼 (v3.2.0부터 Deprecated)

::: danger Deprecated
`@SafeInject`는 **v3.2.0부터 Deprecated**입니다. 더 나은 타입 안전성과 TCA 스타일 KeyPath 접근을 위해 `@Injected`로 마이그레이션하세요.

**마이그레이션 가이드:**
```swift
// 기존 (Deprecated)
@SafeInject(fallback: ConsoleLogger()) var logger: LoggerProtocol

// 새로운 방식 (권장)
@Injected(\.logger) var logger
// InjectedKey에서 기본값 정의:
struct LoggerKey: InjectedKey {
    static var currentValue: LoggerProtocol = ConsoleLogger()
}
```

완전한 마이그레이션 가이드는 [@Injected 문서](./injected.md)를 참조하세요.
:::

`@SafeInject` 프로퍼티 래퍼는 컴파일 타임 안전성과 런타임 회복력을 갖춘 보장된 의존성 주입을 제공했습니다. **이제 @Injected로 대체되었습니다.**

## 개요

`@SafeInject`는 의존성 주입을 옵셔널 기반 패턴에서 보장된 해결 패턴으로 근본적으로 변환합니다. 의존성이 항상 해결될 것을 보장함으로써 옵셔널 처리와 관련된 인지 부하와 보일러플레이트 코드를 제거합니다. 래퍼는 의존성이 컨테이너에 등록되지 않았을 때 여러 대체 전략을 구현하여 코드를 훨씬 더 견고하고 유지보수 가능하며 작업하기 쉽게 만듭니다.

**주요 이점**:
- **보장된 해결**: 의존성이 결코 nil이 아니므로 옵셔널 언래핑 제거
- **대체 전략**: 누락된 의존성 처리를 위한 다양한 접근 방식
- **코드 단순성**: 옵셔널 처리 없이 더 깔끔하고 읽기 쉬운 코드
- **런타임 안전성**: 누락된 의존성으로 인한 크래시 방지
- **테스팅 지원**: 내장된 대체 기능으로 테스팅이 더 쉽고 신뢰할 수 있음

**성능 특성**:
- **해결 속도**: 등록된 의존성의 경우 `@Inject`와 동일
- **대체 오버헤드**: 대체가 사용될 때 최소한의 오버헤드
- **메모리 사용량**: 대체 인스턴스 저장을 위한 작은 추가 메모리
- **스레드 안전성**: 스레드 안전한 해결 및 대체 메커니즘

```swift
import WeaveDI

class UserService {
    @SafeInject(fallback: ConsoleLogger())
    var logger: LoggerProtocol

    @SafeInject(fallback: MockUserRepository())
    var repository: UserRepository

    func createUser(name: String) async {
        // 옵셔널 언래핑이 필요 없음!
        logger.info("사용자 생성: \(name)")
        await repository.save(User(name: name))
        logger.info("사용자 생성 성공")
    }
}
```

## 기본 사용법

### 대체 옵션이 있는 간단한 SafeInject

**목적**: 견고한 오류 처리를 위한 명시적 대체 인스턴스와 함께 기본적인 보장된 의존성 주입.

**패턴 이점**:
- **명시적 대체**: 대체 동작의 명확하고 컴파일 타임 정의
- **타입 안전성**: 대체 인스턴스는 동일한 프로토콜을 준수해야 함
- **즉시 가용성**: 옵셔널 확인 없이 의존성을 즉시 사용 가능
- **오류 방지**: 누락된 의존성으로 인한 런타임 오류 제거

**사용 사례**:
- 적절한 등록 없이도 항상 작동해야 하는 서비스
- 모든 서비스가 구성되지 않을 수 있는 개발 환경
- 우아한 성능 저하 시나리오
- 부분적인 의존성 모킹이 있는 테스팅 환경

```swift
class WeatherService {
    @SafeInject(fallback: ConsoleLogger())
    var logger: LoggerProtocol

    @SafeInject(fallback: MockNetworkClient())
    var networkClient: NetworkClient

    func fetchWeather() async {
        logger.info("날씨 데이터 가져오는 중...")
        // guard let이나 옵셔널 체이닝 필요 없음
        let data = await networkClient.fetchData(from: weatherURL)
        logger.info("날씨 데이터 수신됨")
    }
}
```

### 기본 팩토리와 함께

**목적**: 메모리 효율적인 대체 관리를 위한 클로저 기반 팩토리 패턴을 사용한 지연 대체 생성.

**팩토리 이점**:
- **지연 생성**: 필요할 때만 대체 인스턴스 생성
- **메모리 효율성**: 사용되지 않는 대체 인스턴스 생성 방지
- **동적 생성**: 런타임 매개변수로 대체 생성 가능
- **유연한 구성**: 조건에 따른 다양한 생성 패턴

**성능 최적화**:
- **지연된 인스턴스화**: 컨테이너 해결이 실패할 때만 대체 생성
- **리소스 관리**: 대체 객체를 위한 효율적인 메모리 사용
- **초기화 제어**: 대체가 언제 어떻게 생성되는지 제어

```swift
class DocumentService {
    @SafeInject { PDFGenerator() }
    var pdfGenerator: PDFGenerator

    @SafeInject { InMemoryCache() }
    var cache: CacheService

    func generateDocument() -> Document {
        // 의존성이 보장됨
        let pdf = pdfGenerator.generate()
        cache.store(pdf)
        return pdf
    }
}
```

## 튜토리얼의 실제 예제

### SafeInject가 있는 CountApp

우리 튜토리얼 CountApp을 기반으로, @SafeInject가 어떻게 신뢰성을 보장하는지 보여줍니다:

```swift
/// 보장된 의존성을 가진 카운터 ViewModel
@MainActor
class SafeCounterViewModel: ObservableObject {
    @Published var count = 0
    @Published var isLoading = false
    @Published var history: [CounterHistoryItem] = []

    // 대체 옵션을 가진 보장된 의존성
    @SafeInject(fallback: MockCounterRepository())
    var repository: CounterRepository

    @SafeInject(fallback: ConsoleLogger())
    var logger: LoggerProtocol

    init() {
        Task {
            await loadInitialData()
        }
    }

    func loadInitialData() async {
        isLoading = true

        // 옵셔널 언래핑이 필요 없음!
        count = await repository.getCurrentCount()
        history = await repository.getCountHistory()
        logger.info("📊 초기 데이터 로드 완료: count=\(count), history=\(history.count)개")

        isLoading = false
    }

    func increment() async {
        isLoading = true
        count += 1

        // 작동이 보장됨
        await repository.saveCount(count)
        history = await repository.getCountHistory()
        logger.info("⬆️ 카운트 증가: \(count)")

        isLoading = false
    }

    func decrement() async {
        isLoading = true
        count -= 1

        await repository.saveCount(count)
        history = await repository.getCountHistory()
        logger.info("⬇️ 카운트 감소: \(count)")

        isLoading = false
    }

    func reset() async {
        isLoading = true
        count = 0

        await repository.resetCount()
        history = await repository.getCountHistory()
        logger.info("🔄 카운트 리셋")

        isLoading = false
    }
}

/// 대체용 모의 구현
class MockCounterRepository: CounterRepository {
    private var currentCount = 0
    private var historyItems: [CounterHistoryItem] = []

    func getCurrentCount() async -> Int {
        return currentCount
    }

    func saveCount(_ count: Int) async {
        currentCount = count
        let item = CounterHistoryItem(
            count: count,
            timestamp: Date(),
            action: .increment
        )
        historyItems.append(item)
    }

    func getCountHistory() async -> [CounterHistoryItem] {
        return historyItems
    }

    func resetCount() async {
        currentCount = 0
        let resetItem = CounterHistoryItem(
            count: 0,
            timestamp: Date(),
            action: .reset
        )
        historyItems.append(resetItem)
    }
}
```

### SafeInject가 있는 WeatherApp

```swift
/// 보장된 의존성을 가진 날씨 서비스
class SafeWeatherService: WeatherServiceProtocol {
    @SafeInject(fallback: MockHTTPClient())
    var httpClient: HTTPClientProtocol

    @SafeInject(fallback: ConsoleLogger())
    var logger: LoggerProtocol

    @SafeInject(fallback: InMemoryCacheService())
    var cacheService: CacheServiceProtocol

    func fetchCurrentWeather(for city: String) async throws -> Weather {
        logger.info("🌤️ \(city)의 날씨 요청 시작")

        do {
            // 옵셔널 언래핑 필요 없음
            let url = buildWeatherURL(for: city)
            let data = try await httpClient.fetchData(from: url)
            let weather = try JSONDecoder().decode(Weather.self, from: data)

            // 결과 캐시
            try await cacheService.store(weather, forKey: "weather_\(city)")
            logger.info("✅ \(city) 날씨 데이터 수신 및 캐시 완료")

            return weather
        } catch {
            logger.error("❌ \(city) 날씨 요청 실패: \(error)")

            // 캐시된 데이터 시도
            if let cachedWeather: Weather = try? await cacheService.retrieve(forKey: "weather_\(city)") {
                logger.info("📱 캐시된 \(city) 날씨 데이터 사용")
                return cachedWeather
            }

            throw error
        }
    }

    func fetchForecast(for city: String) async throws -> [WeatherForecast] {
        logger.info("📅 \(city)의 예보 요청 시작")

        let url = buildForecastURL(for: city)
        let data = try await httpClient.fetchData(from: url)
        let forecastResponse = try JSONDecoder().decode(ForecastResponse.self, from: data)

        let forecasts = forecastResponse.list.map { item in
            WeatherForecast(
                date: Date(timeIntervalSince1970: TimeInterval(item.dt)),
                maxTemperature: item.main.tempMax,
                minTemperature: item.main.tempMin,
                description: item.weather.first?.description ?? "Unknown",
                iconName: item.weather.first?.icon ?? "unknown"
            )
        }

        // 예보 캐시
        try await cacheService.store(forecasts, forKey: "forecast_\(city)")
        logger.info("✅ \(city) 예보 데이터 수신 및 캐시 완료: \(forecasts.count)개")

        return forecasts
    }

    private func buildWeatherURL(for city: String) -> URL {
        // URL 빌드 로직
        return URL(string: "https://api.openweathermap.org/data/2.5/weather?q=\(city)&appid=test&units=metric")!
    }

    private func buildForecastURL(for city: String) -> URL {
        return URL(string: "https://api.openweathermap.org/data/2.5/forecast?q=\(city)&appid=test&units=metric")!
    }
}

/// 대체용 모의 HTTP 클라이언트
class MockHTTPClient: HTTPClientProtocol {
    func fetchData(from url: URL) async throws -> Data {
        // 모의 날씨 데이터 반환
        let mockResponse = """
        {
            "name": "Mock City",
            "main": {
                "temp": 20.0,
                "humidity": 50
            },
            "weather": [
                {
                    "description": "Mock Weather",
                    "icon": "01d"
                }
            ]
        }
        """
        return mockResponse.data(using: .utf8)!
    }
}
```

## SafeInject 전략

### 1. 대체 인스턴스

**목적**: 즉시 가용성과 예측 가능한 동작을 위한 구체적이고 미리 인스턴스화된 대체 인스턴스 제공.

**전략 이점**:
- **즉시 가용성**: 대체 인스턴스가 즉시 사용 준비됨
- **예측 가능한 동작**: 예상되는 동작을 가진 알려진 대체 구현
- **간단한 구성**: 최소한의 복잡성으로 직관적인 설정
- **테스팅 신뢰성**: 테스트 실행 전반에 걸친 일관된 대체 동작

**모범 사례**:
- **가벼운 인스턴스**: 최소한이고 효율적인 대체 구현 사용
- **안전한 작업**: 대체 인스턴스가 해로운 부작용이 없도록 보장
- **명확한 의미**: 목적을 명확히 나타내는 대체 선택 (예: NoOpAnalytics)
- **리소스 관리**: 대체 인스턴스의 메모리 및 리소스 사용량 고려

구체적인 대체 인스턴스 제공:

```swift
class AnalyticsService {
    @SafeInject(fallback: NoOpAnalytics())
    var analytics: AnalyticsProtocol

    func trackEvent(_ event: String) {
        // 분석 서비스가 등록되지 않았어도 항상 작동
        analytics.track(event)
    }
}

class NoOpAnalytics: AnalyticsProtocol {
    func track(_ event: String) {
        // 아무것도 하지 않음 - 안전한 대체
    }
}
```

### 2. 팩토리 클로저

**목적**: 유연성과 메모리 효율성을 제공하는 동적 대체 인스턴스 생성을 위한 클로저 기반 팩토리 패턴 사용.

**팩토리 패턴 이점**:
- **동적 생성**: 런타임 특정 매개변수로 대체 생성
- **메모리 효율성**: 컨테이너 해결이 실패할 때만 인스턴스 생성
- **유연한 구성**: 런타임 조건에 따른 다양한 생성 로직
- **리소스 최적화**: 사용되지 않는 대체를 위한 리소스 할당 방지

**구현 전략**:
- **매개변수 주입**: 팩토리 클로저에 런타임 매개변수 전달
- **환경 감지**: 환경에 따른 다양한 대체 생성
- **구성 접근**: 대체 생성 중 구성 값 사용
- **의존성 체이닝**: 다른 의존성을 사용하는 대체 생성

클로저를 사용하여 대체 인스턴스 생성:

```swift
class ImageService {
    @SafeInject { DefaultImageProcessor() }
    var imageProcessor: ImageProcessor

    @SafeInject { FileSystemImageCache() }
    var imageCache: ImageCache

    func processImage(_ image: UIImage) -> UIImage {
        let processed = imageProcessor.process(image)
        imageCache.store(processed)
        return processed
    }
}
```

### 3. 기본 구현이 있는 프로토콜

**목적**: 포괄적인 대체 전략 역할을 하는 기본 구현을 제공하기 위해 Swift 프로토콜 확장 활용.

**프로토콜 확장 이점**:
- **기본 동작**: 프로토콜이 합리적인 기본 구현 제공
- **코드 재사용**: 여러 구현에서 공유되는 기본 동작
- **확장성**: 기본값을 유지하면서 특정 메서드를 쉽게 재정의
- **타입 안전성**: 모든 준수 타입이 자동으로 기본 동작을 얻음

**설계 패턴**:
- **안전한 기본값**: 프로덕션 사용에 안전한 기본 구현
- **우아한 성능 저하**: 실패 대신 축소된 기능을 제공하는 기본값
- **구성 대체**: 구성 서비스를 위한 기본값
- **모의 유사 동작**: 테스팅을 위해 실제 동작을 시뮬레이션하는 기본값

```swift
protocol ConfigurationService {
    func getValue(for key: String) -> String
}

extension ConfigurationService {
    func getValue(for key: String) -> String {
        return "default_value"
    }
}

class DefaultConfiguration: ConfigurationService {
    // 기본 구현 사용
}

class AppService {
    @SafeInject(fallback: DefaultConfiguration())
    var config: ConfigurationService

    func setupApp() {
        let apiKey = config.getValue(for: "api_key")
        // 항상 값을 가짐
    }
}
```

## @Inject와 비교

### 코드 비교

**비교 분석**: `@SafeInject` vs `@Inject`는 의존성 주입 패턴에서 안전성과 유연성 간의 트레이드오프를 보여줍니다.

**@Inject 특성**:
- **옵셔널 의존성**: 언래핑이 필요한 옵셔널 값 반환
- **명시적 Nil 처리**: guard 문과 옵셔널 체이닝 필요
- **런타임 유연성**: 진정한 옵셔널 의존성 처리 가능
- **메모리 효율성**: 메모리에 저장된 대체 인스턴스 없음

**@SafeInject 특성**:
- **보장된 의존성**: 결코 nil을 반환하지 않으며 항상 작동하는 인스턴스 제공
- **단순화된 코드**: 옵셔널 언래핑이나 guard 문 불필요
- **내장된 회복력**: 의존성이 누락되었을 때 자동 대체
- **예측 가능한 동작**: 대체일지라도 항상 작동하는 의존성 보유

**성능 영향**:
- **@Inject**: 등록된 의존성의 경우 약간 빠름 (대체 오버헤드 없음)
- **@SafeInject**: 대체 저장을 위한 최소한의 오버헤드, 등록된 의존성의 경우 동일한 속도
- **메모리**: @SafeInject는 대체 인스턴스를 위한 추가 메모리 사용
- **코드 크기**: @SafeInject는 옵셔널 처리를 제거하여 코드 크기 감소

```swift
// @Inject 사용 (옵셔널 처리 필요)
class UserServiceWithInject {
    @Inject var logger: LoggerProtocol?
    @Inject var repository: UserRepository?

    func createUser(name: String) async {
        // 옵셔널 처리 필요
        logger?.info("사용자 생성: \(name)")

        guard let repo = repository else {
            logger?.error("Repository 사용 불가")
            return
        }

        await repo.save(User(name: name))
        logger?.info("사용자 생성됨")
    }
}

// @SafeInject 사용 (옵셔널 처리 없음)
class UserServiceWithSafeInject {
    @SafeInject(fallback: ConsoleLogger())
    var logger: LoggerProtocol

    @SafeInject(fallback: MockUserRepository())
    var repository: UserRepository

    func createUser(name: String) async {
        // 깔끔하고 직관적인 코드
        logger.info("사용자 생성: \(name)")
        await repository.save(User(name: name))
        logger.info("사용자 생성됨")
    }
}
```

## 등록 및 해결

### 일반 등록

**목적**: `@SafeInject`는 WeaveDI의 표준 의존성 등록 시스템과 원활하게 통합되어 필요할 때만 대체 동작을 제공합니다.

**해결 우선순위**:
1. **컨테이너 해결**: 먼저 WeaveDI 컨테이너에서 해결 시도
2. **대체 해결**: 컨테이너 해결이 실패하면 제공된 대체 사용
3. **타입 안전성**: 컨테이너와 대체 인스턴스 모두 동일한 프로토콜을 준수해야 함

**통합 이점**:
- **투명한 작업**: 의존성이 등록되었을 때 `@Inject`와 동일하게 작동
- **대체 안전성**: 의존성이 누락되었을 때 자동 대체
- **개발 유연성**: 등록된 의존성과 대체 의존성 간 쉬운 전환
- **테스팅 지원**: 신뢰할 수 있는 대체 동작으로 단순화된 테스팅

SafeInject는 일반 의존성 등록과 함께 작동합니다:

```swift
await WeaveDI.Container.bootstrap { container in
    container.register(LoggerProtocol.self) { FileLogger() }
    container.register(UserRepository.self) { DatabaseUserRepository() }
}

// SafeInject는 사용 가능할 때 등록된 의존성을 사용
let service = UserServiceWithSafeInject() // FileLogger와 DatabaseUserRepository 사용
```

### 등록되지 않았을 때 대체

**목적**: 의존성이 컨테이너에 등록되지 않았을 때의 우아한 성능 저하 시연.

**대체 활성화 시나리오**:
- **누락된 등록**: 의존성이 컨테이너에 등록되지 않음
- **컨테이너 리셋**: 테스팅이나 개발 중 컨테이너 정리
- **부분적 구성**: 일부 의존성은 등록되고 다른 것들은 누락
- **환경 차이**: 환경 전반에 걸친 다양한 등록

**대체 동작**:
- **자동 전환**: 대체 구현으로의 원활한 전환
- **오류 발생 없음**: 누락된 의존성으로 인한 예외나 크래시 없음
- **일관된 인터페이스**: 대체가 등록된 의존성과 동일한 인터페이스 제공
- **투명한 작업**: 호출 코드가 대체 vs 등록된 의존성을 인식하지 못함

```swift
// 의존성이 등록되지 않은 경우
let service = UserServiceWithSafeInject() // ConsoleLogger와 MockUserRepository 대체 사용
```

## 스레드 안전성

**스레드 안전성 보장**: `@SafeInject`는 다중 보호 계층과 동시 접근 처리를 통해 포괄적인 스레드 안전성을 제공합니다.

**안전 메커니즘**:
- **컨테이너 스레드 안전성**: 기본 WeaveDI 컨테이너는 스레드 안전
- **대체 스레드 안전성**: 대체 해결이 경쟁 조건으로부터 보호됨
- **인스턴스 스레드 안전성**: 대체 인스턴스는 스레드 안전해야 함 (구현 책임)
- **프로퍼티 접근 안전성**: 프로퍼티 래퍼가 해결된 의존성에 대한 스레드 안전 접근 보장

**동시성 고려사항**:
- **병렬 접근**: 여러 스레드가 `@SafeInject` 프로퍼티에 안전하게 접근 가능
- **해결 캐싱**: 해결된 의존성이 스레드 간에 안전하게 캐시됨
- **대체 생성**: 대체 팩토리 클로저가 동시 환경에서 안전하게 실행됨
- **메모리 장벽**: 일관된 가시성을 위한 자동 메모리 장벽 처리

**동시 환경에서의 성능**:
- **확장 가능한 접근**: 동시 스레드 접근으로 성능이 잘 확장됨
- **최소한의 경합**: 의존성 해결을 위한 낮은 잠금 경합
- **캐시 효율성**: 빠른 후속 접근을 위해 해결된 의존성 캐시됨

@SafeInject는 스레드 안전하며 다른 큐에서 작동합니다:

```swift
class ConcurrentService {
    @SafeInject(fallback: ThreadSafeLogger())
    var logger: LoggerProtocol

    func processConcurrently() async {
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    // 모든 스레드에서 안전하게 사용
                    self.logger.info("항목 \(i) 처리 중")
                }
            }
        }
    }
}
```

## @SafeInject로 테스팅

### 테스트 설정

**테스팅 전략**: `@SafeInject`는 보장된 의존성 가용성과 유연한 대체 구성을 통해 우수한 테스팅 기능을 제공합니다.

**테스팅 이점**:
- **신뢰할 수 있는 테스트 의존성**: 누락된 의존성으로 인해 테스트가 실패하지 않음
- **유연한 모의 전략**: 실제와 모의 의존성 간 쉬운 전환
- **대체 테스팅**: 서비스를 사용할 수 없을 때 애플리케이션 동작 확인
- **통합 테스팅**: 부분적 모킹으로 완전한 시스템 테스트

**테스트 구성 패턴**:
- **완전한 모의 환경**: 모든 의존성을 모의로 등록
- **부분적 모의 환경**: 일부 모의를 등록하고 다른 것들은 대체에 의존
- **대체 테스팅**: 대체 동작을 확인하기 위해 등록 없이 테스트
- **혼합 환경**: 통합 테스팅을 위해 실제와 모의 의존성 결합

```swift
class SafeInjectServiceTests: XCTestCase {

    func testWithRegisteredDependencies() async throws {
        // 테스트 의존성 등록
        await WeaveDI.Container.bootstrap { container in
            container.register(LoggerProtocol.self) { TestLogger() }
            container.register(UserRepository.self) { TestUserRepository() }
        }

        let service = UserServiceWithSafeInject()

        // 등록된 테스트 의존성 사용
        await service.createUser(name: "Test User")

        // 실제 의존성으로 동작 확인
    }

    func testWithoutRegisteredDependencies() async throws {
        // 컨테이너 리셋 (의존성 등록 없음)
        await WeaveDI.Container.resetForTesting()

        let service = UserServiceWithSafeInject()

        // 대체 의존성 사용
        await service.createUser(name: "Test User")

        // 대체 동작이 올바르게 작동하는지 확인
    }
}
```

### 대체 모킹

**목적**: 특정 테스트 시나리오를 위한 맞춤형 대체 구성을 허용하는 고급 테스팅 패턴.

**맞춤형 대체 이점**:
- **테스트별 모의**: 특정 테스트 시나리오를 위한 전문화된 모의 제공
- **동작 확인**: 맞춤형 테스트 더블과의 상호작용 확인
- **상태 제어**: 대체 의존성의 초기 상태와 동작 제어
- **격리 테스팅**: 제어된 대체로 구성 요소를 완전히 격리하여 테스트

**고급 테스팅 패턴**:
- **생성자 주입**: 생성자 매개변수를 통해 대체 재정의
- **프로퍼티 주입**: 인스턴스 생성 후 대체 수정
- **프로토콜 모킹**: 최대 유연성을 위한 프로토콜 기반 모의 사용
- **상태 확인**: 맞춤형 대체 인스턴스에서 상태 변경 확인

```swift
class TestableService {
    @SafeInject(fallback: MockService())
    var service: ServiceProtocol

    // 테스트를 위해 대체를 재정의할 수 있음
    init(fallbackService: ServiceProtocol? = nil) {
        if let fallback = fallbackService {
            self._service = SafeInject(fallback: fallback)
        }
    }
}

class ServiceTests: XCTestCase {
    func testWithCustomFallback() {
        let mockService = SpecialMockService()
        let testableService = TestableService(fallbackService: mockService)

        // 사용자 정의 모의로 테스트
    }
}
```

## 성능 고려사항

### 메모리 사용량

**메모리 관리 전략**: `@SafeInject`는 보장된 의존성 가용성을 유지하면서 효율적인 메모리 관리를 구현합니다.

**메모리 특성**:
- **대체 저장**: 즉시 가용성을 위해 대체 인스턴스에 대한 참조 유지
- **해결 캐싱**: 반복된 컨테이너 조회를 피하기 위해 해결된 의존성 캐시
- **생명주기 관리**: 대체 인스턴스는 일반적인 Swift 메모리 관리 규칙을 따름
- **리소스 최적화**: 지연 팩토리 클로저는 불필요한 인스턴스 생성 방지

**메모리 최적화 가이드라인**:
- **가벼운 대체**: 대체 인스턴스를 위한 최소한의 구현 선택
- **리소스 공유**: 적절할 때 대체 인스턴스 간 리소스 공유
- **지연 생성**: 비용이 많이 드는 대체 인스턴스를 위한 팩토리 클로저 사용
- **메모리 모니터링**: 프로덕션 환경에서 메모리 사용 패턴 모니터링

SafeInject는 대체 인스턴스에 대한 참조를 유지합니다:

```swift
class EfficientService {
    // ✅ 좋음 - 가벼운 대체
    @SafeInject(fallback: NoOpLogger())
    var logger: LoggerProtocol

    // ⚠️ 고려 - 무거운 대체 인스턴스
    @SafeInject(fallback: FullDatabaseService())
    var database: DatabaseService
}
```

### 지연 대체 생성

**목적**: 지연된 대체 생성을 통한 메모리 사용량 및 초기화 성능 최적화.

**지연 생성 이점**:
- **메모리 효율성**: 컨테이너 해결이 실패할 때만 대체 인스턴스 생성
- **초기화 성능**: 프로퍼티 래퍼 초기화 중 비용이 많이 드는 대체 생성 방지
- **리소스 보존**: 사용되지 않는 대체를 위한 리소스 할당 안 함
- **동적 구성**: 런타임 특정 매개변수로 대체 생성

**구현 전략**:
- **클로저 기반 팩토리**: 인스턴스 생성을 지연하기 위해 클로저 사용
- **조건부 생성**: 런타임 조건에 따른 다양한 대체 생성
- **리소스 관리**: 대체 인스턴스에서 비용이 많이 드는 리소스를 효율적으로 관리
- **성능 모니터링**: 대체 생성 패턴과 성능 영향 추적

```swift
class LazyFallbackService {
    @SafeInject {
        // 필요할 때만 대체 생성
        ExpensiveFallbackService()
    }
    var expensiveService: ExpensiveService
}
```

## 모범 사례

### 1. 적절한 대체 선택

**전략**: 해로운 부작용 없이 안전하고 예측 가능한 동작을 제공하는 대체 구현 선택.

**대체 선택 기준**:
- **안전성 우선**: 대체는 결코 데이터 손실이나 보안 문제를 일으키지 않아야 함
- **최소한의 부작용**: 파괴적인 작업을 수행하는 대체 방지
- **명확한 의도**: 목적을 명확히 나타내는 대체 사용 (예: NoOp, Mock, Console)
- **리소스 효율성**: 과도한 리소스를 소비하지 않는 가벼운 구현 선택

**대체 범주**:
- **No-Op 구현**: 아무 작업도 수행하지 않는 안전한 대체
- **콘솔/디버그 구현**: 디버깅을 위해 콘솔에 로그하는 대체
- **인메모리 구현**: 외부 의존성 없이 작동하는 임시 대체
- **모의 구현**: 실제 동작을 시뮬레이션하는 테스트 친화적 대체

**위험 평가**:
- **프로덕션 안전성**: 대체가 프로덕션 환경에서 안전한지 확인
- **데이터 무결성**: 대체가 데이터 일관성을 손상시키지 않는지 확인
- **보안 영향**: 대체 구현의 보안 영향 평가
- **성능 영향**: 대체 구현의 성능 특성 모니터링

```swift
// ✅ 좋음 - 안전한 무작동 대체
@SafeInject(fallback: NoOpAnalytics())
var analytics: AnalyticsProtocol

// ✅ 좋음 - 최소한의 대체
@SafeInject(fallback: ConsoleLogger())
var logger: LoggerProtocol

// ⚠️ 신중히 고려 - 부작용이 있는 대체
@SafeInject(fallback: ProductionEmailService())
var emailService: EmailService // 실제 이메일을 보낼 수 있음!
```

### 2. 대체 동작 문서화

**문서화 전략**: 팀 구성원이 누락된 의존성의 영향을 이해할 수 있도록 대체 동작을 명확히 문서화.

**문서화 요소**:
- **대체 목적**: 특정 대체가 선택된 이유 설명
- **동작 설명**: 대체 구현이 무엇을 하는지 문서화
- **안전성 보장**: 대체의 안전성 특성 설명
- **성능 영향**: 대체 사용의 성능 영향 언급

**문서화 모범 사례**:
- **인라인 주석**: 대체 선택을 설명하는 명확한 주석 추가
- **README 문서화**: 프로젝트 문서에 대체 전략 문서화
- **코드 예제**: 예상되는 대체 동작의 예제 제공
- **마이그레이션 노트**: 시간에 따른 대체 동작 변경 사항 문서화

```swift
class PaymentService {
    /// 무작동 대체가 있는 분석 서비스 (프로덕션에서 안전)
    @SafeInject(fallback: NoOpAnalytics())
    var analytics: AnalyticsProtocol

    /// 콘솔 대체가 있는 로거 (파일 로거가 없으면 콘솔에 로그)
    @SafeInject(fallback: ConsoleLogger())
    var logger: LoggerProtocol
}
```

### 3. 두 경로 모두 테스트

**테스팅 전략**: 포괄적인 테스팅은 일반적인 의존성 해결과 대체 동작을 모두 확인해야 합니다.

**이중 경로 테스팅 이점**:
- **완전한 커버리지**: 성공과 대체 시나리오가 모두 올바르게 작동하는지 확인
- **동작 확인**: 대체가 예상된 기능을 제공하는지 확인
- **회귀 방지**: 어느 해결 경로에서든 문제 포착
- **통합 신뢰도**: 시스템 신뢰성에 대한 신뢰 구축

**테스팅 접근법**:
- **등록된 의존성 테스트**: 모든 의존성이 올바르게 등록된 상태로 테스트
- **대체 의존성 테스트**: 누락되거나 등록되지 않은 의존성으로 테스트
- **혼합 시나리오 테스트**: 일부는 등록되고 다른 것들은 누락된 상태로 테스트
- **성능 테스트**: 두 경로의 성능 특성 확인

**테스트 조직**:
- **별도 테스트 케이스**: 각 시나리오를 위한 구별되는 테스트 생성
- **매개변수화 테스트**: 여러 시나리오를 커버하기 위해 테스트 매개변수 사용
- **통합 스위트**: 통합 테스트 스위트에 두 경로 모두 포함
- **지속적 테스팅**: CI/CD 파이프라인에서 두 경로 모두 테스트되도록 보장

```swift
func testServiceWithRegisteredDependencies() {
    // 실제 의존성으로 테스트
}

func testServiceWithFallbackDependencies() {
    // 대체 의존성으로 테스트
}
```

### 4. 중요한 의존성에 사용

**사용 전략**: 애플리케이션 기능에 중요한 의존성에 `@SafeInject`를 전략적으로 적용.

**중요한 의존성 식별**:
- **핵심 기능**: 기본적인 애플리케이션 작동에 필요한 의존성
- **오류 처리**: 적절한 오류 처리와 복구에 필요한 서비스
- **보안 서비스**: 애플리케이션 보안에 중요한 의존성
- **데이터 무결성**: 데이터 일관성 유지에 필요한 서비스

**결정 프레임워크**:
- **항상 작동해야 함**: 옵셔널이 될 수 없는 의존성에 `@SafeInject` 사용
- **옵셔널 가능**: 우아하게 비활성화될 수 있는 기능에 `@Inject` 사용
- **향상된 기능**: 향상되지만 필수적이지 않은 기능을 제공하는 의존성에 `@Inject` 사용
- **개발 도구**: 개발 vs 프로덕션 요구에 따라 적절한 래퍼 사용

**아키텍처 고려사항**:
- **서비스 계층**: 다양한 아키텍처 계층을 위한 다양한 주입 전략
- **기능 플래그**: 주입 전략을 선택할 때 기능 가용성 고려
- **환경 차이**: 다양한 배포 환경을 위한 다양한 전략
- **마이그레이션 경로**: 요구사항이 발전함에 따라 주입 전략 간 전환 계획

```swift
class CriticalService {
    // ✅ 항상 작동해야 하는 의존성에 SafeInject 사용
    @SafeInject(fallback: EmergencyHandler())
    var emergencyHandler: EmergencyHandler

    // ✅ 옵셔널 의존성에 @Inject 사용
    @Inject var optionalFeature: OptionalFeature?
}
```

## 일반적인 패턴

### SafeInject가 있는 서비스 계층

```swift
class UserManagementService {
    @SafeInject(fallback: ConsoleLogger())
    var logger: LoggerProtocol

    @SafeInject(fallback: InMemoryUserRepository())
    var userRepository: UserRepository

    @SafeInject(fallback: NoOpEmailService())
    var emailService: EmailService

    func registerUser(_ userData: UserData) async throws {
        logger.info("새 사용자 등록: \(userData.email)")

        let user = User(from: userData)
        try await userRepository.save(user)

        await emailService.sendWelcomeEmail(to: user)

        logger.info("사용자 등록 완료: \(user.id)")
    }
}
```

### 구성 서비스 패턴

```swift
protocol AppConfiguration {
    func apiBaseURL() -> URL
    func apiKey() -> String
    func isDebugMode() -> Bool
}

class DefaultAppConfiguration: AppConfiguration {
    func apiBaseURL() -> URL {
        URL(string: "https://api.example.com")!
    }

    func apiKey() -> String {
        "default_api_key"
    }

    func isDebugMode() -> Bool {
        true
    }
}

class NetworkService {
    @SafeInject(fallback: DefaultAppConfiguration())
    var config: AppConfiguration

    func makeAPICall() async {
        let baseURL = config.apiBaseURL()
        let apiKey = config.apiKey()

        // 항상 구성 값을 가짐
    }
}
```

## 참고 자료

- [@Inject 프로퍼티 래퍼](./inject.md) - 옵셔널 의존성 주입용
- [@Factory 프로퍼티 래퍼](./factory.md) - 팩토리 기반 주입용
- [프로퍼티 래퍼 가이드](../guide/propertyWrappers.md) - 모든 프로퍼티 래퍼의 종합 가이드