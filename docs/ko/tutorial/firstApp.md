# WeaveDI로 첫 번째 앱 만들기

WeaveDI를 사용하여 완전한 iOS 앱을 처음부터 만드는 방법. 이 튜토리얼은 모범 사례를 보여주는 실제 날씨 앱을 구축합니다.

## 🎯 프로젝트 개요

다음과 같은 날씨 앱을 만들 예정입니다:
- **MVVM 아키텍처**: 깔끔한 관심사 분리
- **WeaveDI 통합**: 적절한 의존성 주입
- **Swift 동시성**: 현대적인 async/await 패턴
- **오류 처리**: 견고한 오류 관리
- **테스팅**: 유닛 및 통합 테스트

## 📱 앱 기능

- 현재 날씨 표시
- 5일 예보
- 위치 기반 날씨
- 오프라인 캐싱
- 당겨서 새로고침
- 재시도가 있는 오류 상태

## 🏗️ 프로젝트 설정

```bash
# 새 iOS 프로젝트 생성
# File → New → Project → iOS → App
# Product Name: WeatherApp
# Interface: SwiftUI
# Language: Swift
```

WeaveDI 의존성 추가:
```swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.1.0")
]
```

## 🔧 단계별 구현

### 1단계: 프로젝트 아키텍처 설정

먼저 프로젝트의 폴더 구조를 설정합니다:

```
WeatherApp/
├── App/
│   ├── WeatherApp.swift          // 앱 진입점
│   └── DependencyBootstrap.swift // DI 설정
├── Models/
│   ├── Weather.swift             // 날씨 모델
│   └── Location.swift            // 위치 모델
├── Services/
│   ├── WeatherService.swift      // 날씨 API 서비스
│   ├── LocationService.swift     // 위치 서비스
│   └── CacheService.swift        // 캐시 서비스
├── ViewModels/
│   └── WeatherViewModel.swift    // 날씨 뷰모델
└── Views/
    ├── ContentView.swift         // 메인 뷰
    └── WeatherDetailView.swift   // 상세 날씨 뷰
```

### 2단계: 모델 정의

```swift
// Models/Weather.swift
import Foundation

/// 날씨 데이터를 나타내는 모델
/// API 응답과 UI 표시 모두에 사용됩니다
struct Weather: Codable, Identifiable {
    let id = UUID()
    let temperature: Double      // 온도 (섭씨)
    let humidity: Int           // 습도 (퍼센트)
    let description: String     // 날씨 설명 (예: "맑음", "흐림")
    let iconName: String       // 아이콘 이름
    let city: String           // 도시 이름
    let timestamp: Date        // 데이터 수집 시간

    /// 화면에 표시할 포맷된 온도
    var formattedTemperature: String {
        return String(format: "%.0f°C", temperature)
    }

    /// 화면에 표시할 포맷된 습도
    var formattedHumidity: String {
        return "\(humidity)%"
    }
}

/// 5일 예보를 위한 예보 모델
struct WeatherForecast: Codable, Identifiable {
    let id = UUID()
    let date: Date              // 예보 날짜
    let maxTemperature: Double  // 최고 온도
    let minTemperature: Double  // 최저 온도
    let description: String     // 날씨 설명
    let iconName: String       // 아이콘 이름

    /// 화면에 표시할 포맷된 날짜
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}
```

### 3단계: 서비스 레이어 구현

```swift
// Services/WeatherService.swift
import Foundation

/// 날씨 데이터를 가져오는 서비스 프로토콜
/// 프로토콜을 사용하여 테스트 시 Mock 객체로 교체 가능
protocol WeatherServiceProtocol {
    /// 특정 도시의 현재 날씨를 가져옵니다
    /// - Parameter city: 날씨를 조회할 도시 이름
    /// - Returns: 날씨 데이터
    func fetchCurrentWeather(for city: String) async throws -> Weather

    /// 특정 도시의 5일 예보를 가져옵니다
    /// - Parameter city: 예보를 조회할 도시 이름
    /// - Returns: 예보 데이터 배열
    func fetchForecast(for city: String) async throws -> [WeatherForecast]
}

/// 실제 날씨 API와 통신하는 서비스 구현
class WeatherService: WeatherServiceProtocol {
    private let apiKey = "YOUR_API_KEY"
    private let baseURL = "https://api.openweathermap.org/data/2.5"

    /// URLSession을 주입받아 테스트 시 Mock URLSession 사용 가능
    @Inject var httpClient: HTTPClientProtocol?

    func fetchCurrentWeather(for city: String) async throws -> Weather {
        // API 클라이언트가 주입되었는지 확인
        guard let client = httpClient else {
            throw WeatherError.httpClientNotAvailable
        }

        // API URL 구성
        let urlString = "\(baseURL)/weather?q=\(city)&appid=\(apiKey)&units=metric"
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }

        // HTTP 요청 수행
        let data = try await client.fetchData(from: url)

        // JSON 디코딩
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let apiResponse = try decoder.decode(WeatherAPIResponse.self, from: data)

        // API 응답을 앱 모델로 변환
        return Weather(
            temperature: apiResponse.main.temp,
            humidity: apiResponse.main.humidity,
            description: apiResponse.weather.first?.description ?? "알 수 없음",
            iconName: apiResponse.weather.first?.icon ?? "unknown",
            city: apiResponse.name,
            timestamp: Date()
        )
    }

    func fetchForecast(for city: String) async throws -> [WeatherForecast] {
        guard let client = httpClient else {
            throw WeatherError.httpClientNotAvailable
        }

        let urlString = "\(baseURL)/forecast?q=\(city)&appid=\(apiKey)&units=metric"
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }

        let data = try await client.fetchData(from: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let apiResponse = try decoder.decode(ForecastAPIResponse.self, from: data)

        // API 응답을 앱 모델로 변환
        return apiResponse.list.map { item in
            WeatherForecast(
                date: Date(timeIntervalSince1970: TimeInterval(item.dt)),
                maxTemperature: item.main.tempMax,
                minTemperature: item.main.tempMin,
                description: item.weather.first?.description ?? "알 수 없음",
                iconName: item.weather.first?.icon ?? "unknown"
            )
        }
    }
}

/// 날씨 서비스에서 발생할 수 있는 오류들
enum WeatherError: Error, LocalizedError {
    case httpClientNotAvailable
    case invalidURL
    case networkError
    case decodingError
    case cityNotFound

    var errorDescription: String? {
        switch self {
        case .httpClientNotAvailable:
            return "HTTP 클라이언트를 사용할 수 없습니다"
        case .invalidURL:
            return "잘못된 URL입니다"
        case .networkError:
            return "네트워크 오류가 발생했습니다"
        case .decodingError:
            return "데이터 디코딩 오류가 발생했습니다"
        case .cityNotFound:
            return "해당 도시를 찾을 수 없습니다"
        }
    }
}
```

### 4단계: ViewModel 구현

```swift
// ViewModels/WeatherViewModel.swift
import Foundation
import SwiftUI

/// 날씨 화면의 뷰모델
/// @MainActor를 사용하여 UI 업데이트가 메인 스레드에서 수행되도록 보장
@MainActor
class WeatherViewModel: ObservableObject {
    // MARK: - Published Properties (UI가 자동으로 업데이트됨)

    @Published var currentWeather: Weather?
    @Published var forecast: [WeatherForecast] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedCity = "Seoul"

    // MARK: - Dependencies (WeaveDI를 통해 주입)

    /// 날씨 서비스 - 옵셔널로 주입되어 안전성 보장
    @Inject var weatherService: WeatherServiceProtocol?

    /// 캐시 서비스 - 오프라인 지원을 위해
    @Inject var cacheService: CacheServiceProtocol?

    /// 로거 - 디버깅 및 모니터링을 위해
    @Inject var logger: LoggerProtocol?

    // MARK: - Initialization

    init() {
        // 앱 시작 시 서울 날씨 로드
        Task {
            await loadWeatherData()
        }
    }

    // MARK: - Public Methods

    /// 현재 선택된 도시의 날씨 데이터를 로드합니다
    func loadWeatherData() async {
        logger?.info("날씨 데이터 로드 시작: \(selectedCity)")

        // UI 상태 업데이트 (로딩 시작)
        isLoading = true
        errorMessage = nil

        do {
            // 의존성 확인
            guard let service = weatherService else {
                throw WeatherError.httpClientNotAvailable
            }

            // 현재 날씨와 예보를 동시에 가져오기
            async let currentWeatherTask = service.fetchCurrentWeather(for: selectedCity)
            async let forecastTask = service.fetchForecast(for: selectedCity)

            // 두 작업이 모두 완료될 때까지 대기
            let (weather, forecastData) = try await (currentWeatherTask, forecastTask)

            // UI 업데이트 (성공)
            self.currentWeather = weather
            self.forecast = forecastData

            // 캐시에 저장 (오프라인 지원)
            await cacheWeatherData(weather: weather, forecast: forecastData)

            logger?.info("날씨 데이터 로드 성공")

        } catch {
            // 오류 처리
            logger?.error("날씨 데이터 로드 실패: \(error)")

            // 캐시된 데이터 시도
            await loadCachedWeatherData()

            // 오류 메시지 설정
            self.errorMessage = error.localizedDescription
        }

        // UI 상태 업데이트 (로딩 완료)
        isLoading = false
    }

    /// 도시를 변경하고 새로운 날씨 데이터를 로드합니다
    /// - Parameter city: 새로 선택한 도시
    func changeCity(to city: String) async {
        logger?.info("도시 변경: \(selectedCity) → \(city)")
        selectedCity = city
        await loadWeatherData()
    }

    /// 새로고침 (당겨서 새로고침 기능)
    func refresh() async {
        logger?.info("수동 새로고침 시작")
        await loadWeatherData()
    }

    // MARK: - Private Methods

    /// 날씨 데이터를 캐시에 저장합니다
    private func cacheWeatherData(weather: Weather, forecast: [WeatherForecast]) async {
        guard let cache = cacheService else { return }

        do {
            try await cache.store(weather, forKey: "current_weather_\(selectedCity)")
            try await cache.store(forecast, forKey: "forecast_\(selectedCity)")
            logger?.info("날씨 데이터 캐시 저장 완료")
        } catch {
            logger?.error("캐시 저장 실패: \(error)")
        }
    }

    /// 캐시된 날씨 데이터를 로드합니다 (오프라인 지원)
    private func loadCachedWeatherData() async {
        guard let cache = cacheService else { return }

        do {
            if let cachedWeather: Weather = try await cache.retrieve(forKey: "current_weather_\(selectedCity)") {
                self.currentWeather = cachedWeather
                logger?.info("캐시된 현재 날씨 로드 완료")
            }

            if let cachedForecast: [WeatherForecast] = try await cache.retrieve(forKey: "forecast_\(selectedCity)") {
                self.forecast = cachedForecast
                logger?.info("캐시된 예보 데이터 로드 완료")
            }
        } catch {
            logger?.error("캐시 로드 실패: \(error)")
        }
    }
}
```

### 5단계: SwiftUI 뷰 구현

```swift
// Views/ContentView.swift
import SwiftUI

/// 앱의 메인 날씨 화면
struct ContentView: View {
    /// WeaveID를 통해 ViewModel 주입
    /// StateObject를 사용하여 뷰의 생명주기와 연결
    @StateObject private var viewModel = WeatherViewModel()

    /// 도시 선택을 위한 상태
    @State private var showingCitySelection = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 현재 날씨 섹션
                    currentWeatherSection

                    // 5일 예보 섹션
                    forecastSection
                }
                .padding()
            }
            .navigationTitle("날씨")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                toolbarContent
            }
            .refreshable {
                // 당겨서 새로고침 기능
                await viewModel.refresh()
            }
            .alert("오류", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("재시도") {
                    Task {
                        await viewModel.loadWeatherData()
                    }
                }
                Button("확인") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }

    /// 현재 날씨를 표시하는 뷰
    @ViewBuilder
    private var currentWeatherSection: some View {
        VStack(spacing: 16) {
            Text("현재 날씨")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.isLoading {
                // 로딩 상태
                ProgressView("날씨 데이터를 불러오는 중...")
                    .frame(height: 120)
            } else if let weather = viewModel.currentWeather {
                // 날씨 데이터 표시
                WeatherCardView(weather: weather)
            } else {
                // 데이터 없음 상태
                Text("날씨 데이터를 불러올 수 없습니다")
                    .foregroundColor(.secondary)
                    .frame(height: 120)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    /// 5일 예보를 표시하는 뷰
    @ViewBuilder
    private var forecastSection: some View {
        VStack(spacing: 16) {
            Text("5일 예보")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.forecast.isEmpty {
                Text("예보 데이터가 없습니다")
                    .foregroundColor(.secondary)
                    .frame(height: 100)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.forecast) { forecast in
                        ForecastRowView(forecast: forecast)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    /// 네비게이션 바 툴바 내용
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("도시 선택") {
                showingCitySelection = true
            }
        }
    }
}

/// 현재 날씨를 표시하는 카드 뷰
struct WeatherCardView: View {
    let weather: Weather

    var body: some View {
        VStack(spacing: 12) {
            // 도시 이름
            Text(weather.city)
                .font(.title2)
                .fontWeight(.semibold)

            // 온도
            Text(weather.formattedTemperature)
                .font(.system(size: 48, weight: .thin))

            // 날씨 설명
            Text(weather.description)
                .font(.headline)
                .foregroundColor(.secondary)

            // 습도
            HStack {
                Image(systemName: "humidity")
                Text("습도: \(weather.formattedHumidity)")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

/// 예보 행 뷰
struct ForecastRowView: View {
    let forecast: WeatherForecast

    var body: some View {
        HStack {
            // 날짜
            Text(forecast.formattedDate)
                .font(.headline)
                .frame(width: 60, alignment: .leading)

            // 날씨 설명
            Text(forecast.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 온도 범위
            Text("\(Int(forecast.minTemperature))° / \(Int(forecast.maxTemperature))°")
                .font(.headline)
        }
        .padding(.vertical, 4)
    }
}
```

### 6단계: 의존성 주입 설정

```swift
// App/DependencyBootstrap.swift
import WeaveDI

/// 앱의 모든 의존성을 등록하는 클래스
/// 앱 시작 시 한 번만 호출되어 DI 컨테이너를 설정합니다
class DependencyBootstrap {

    /// 모든 의존성을 등록합니다
    /// 이 메서드는 앱 시작 시 한 번만 호출되어야 합니다
    static func setupDependencies() async {
        await WeaveDI.Container.bootstrap { container in

            // MARK: - 네트워크 서비스 등록

            /// HTTP 클라이언트 등록 - 싱글톤으로 관리
            /// 네트워크 요청을 처리하는 기본 클라이언트
            container.register(HTTPClientProtocol.self) {
                print("🔗 HTTPClient 인스턴스 생성")
                return URLSessionHTTPClient()
            }

            // MARK: - 비즈니스 서비스 등록

            /// 날씨 서비스 등록 - 싱글톤으로 관리
            /// WeatherService는 HTTPClient에 의존하며 자동으로 주입됩니다
            container.register(WeatherServiceProtocol.self) {
                print("🌤️ WeatherService 인스턴스 생성")
                return WeatherService()
            }

            /// 캐시 서비스 등록 - 싱글톤으로 관리
            /// 오프라인 지원을 위한 데이터 캐싱 서비스
            container.register(CacheServiceProtocol.self) {
                print("💾 CacheService 인스턴스 생성")
                return UserDefaultsCacheService()
            }

            /// 위치 서비스 등록 - 싱글톤으로 관리
            /// 사용자의 현재 위치를 가져오는 서비스
            container.register(LocationServiceProtocol.self) {
                print("📍 LocationService 인스턴스 생성")
                return CoreLocationService()
            }

            // MARK: - 유틸리티 서비스 등록

            /// 로거 서비스 등록 - 싱글톤으로 관리
            /// 앱 전체에서 사용되는 로깅 서비스
            container.register(LoggerProtocol.self) {
                print("📝 Logger 인스턴스 생성")
                return ConsoleLogger()
            }

            /// 알림 서비스 등록 - 싱글톤으로 관리
            /// 사용자에게 알림을 표시하는 서비스
            container.register(NotificationServiceProtocol.self) {
                print("🔔 NotificationService 인스턴스 생성")
                return UserNotificationService()
            }

            print("✅ 모든 의존성 등록 완료")
        }
    }

    /// 테스트용 의존성을 등록합니다
    /// 테스트 실행 시 Mock 객체들로 교체됩니다
    static func setupTestDependencies() async {
        await WeaveDI.Container.bootstrap { container in

            // Mock 서비스들 등록
            container.register(WeatherServiceProtocol.self) {
                MockWeatherService()
            }

            container.register(CacheServiceProtocol.self) {
                MockCacheService()
            }

            container.register(HTTPClientProtocol.self) {
                MockHTTPClient()
            }

            container.register(LoggerProtocol.self) {
                MockLogger()
            }

            print("🧪 테스트 의존성 등록 완료")
        }
    }
}
```

### 7단계: 앱 진입점 설정

```swift
// App/WeatherApp.swift
import SwiftUI
import WeaveDI

/// 앱의 메인 진입점
/// 앱이 시작될 때 의존성 주입 시스템을 초기화합니다
@main
struct WeatherApp: App {

    /// 앱이 초기화될 때 의존성 설정
    init() {
        // 비동기 의존성 설정을 백그라운드에서 실행
        Task {
            await DependencyBootstrap.setupDependencies()
            print("🚀 WeatherApp 초기화 완료")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // 앱이 표시되기 전에 의존성 설정 완료 대기
                    // 이렇게 하면 뷰가 로드될 때 모든 서비스가 준비되어 있습니다
                    print("⏳ 의존성 설정 완료 대기 중...")
                }
        }
    }
}
```

## 📋 구현 완료 후 할 일

1. **테스트 작성**
   - 유닛 테스트로 각 서비스 검증
   - ViewModel 테스트로 비즈니스 로직 검증
   - UI 테스트로 사용자 시나리오 검증

2. **에러 핸들링 개선**
   - 네트워크 오류 시 재시도 로직
   - 오프라인 모드 지원 강화
   - 사용자 친화적 에러 메시지

3. **성능 최적화**
   - 이미지 캐싱 추가
   - 데이터 프리페칭
   - 메모리 사용량 최적화

4. **추가 기능**
   - 사용자 설정 (온도 단위 등)
   - 위젯 지원
   - 백그라운드 데이터 갱신

## 🎯 실제 Tutorial 코드로 학습하기

### Tutorial 01: 기본 카운터 앱 (WeaveDI 없이)

먼저 기본적인 카운터 앱을 만들어보겠습니다. 이는 Tutorial-MeetWeaveDI의 01-01 코드입니다:

```swift
// Tutorial-MeetWeaveDI-01-01.swift에서 가져온 실제 코드
import SwiftUI

struct ContentView: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("WeaveDI 카운터")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("\(count)")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(.blue)

            HStack(spacing: 20) {
                Button("-") {
                    count -= 1
                }
                .font(.title)
                .frame(width: 50, height: 50)
                .background(Color.red)
                .foregroundColor(.white)
                .clipShape(Circle())

                Button("+") {
                    count += 1
                }
                .font(.title)
                .frame(width: 50, height: 50)
                .background(Color.green)
                .foregroundColor(.white)
                .clipShape(Circle())
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
```

**🔍 코드 설명:**

1. **기본 SwiftUI 구조**: @State를 사용한 간단한 상태 관리
2. **UI 컴포넌트**: VStack, HStack, Text, Button으로 구성된 카운터 인터페이스
3. **상태 변경**: 버튼 클릭 시 count 값이 직접 변경됩니다
4. **디자인**: 원형 버튼과 색상으로 직관적인 UI 제공

### Tutorial 02: WeaveDI로 고급 카운터 앱 만들기

이제 동일한 카운터 앱을 WeaveDI와 Repository 패턴을 사용하여 고도화해보겠습니다:

```swift
// Tutorial-IntermediateWeaveDI에서 영감받은 고급 CountApp 구현
import SwiftUI
import WeaveDI

// MARK: - Repository 패턴 구현

/// 카운터 데이터를 관리하는 Repository 프로토콜
protocol CounterRepository: Sendable {
    /// 현재 카운트 값을 가져옵니다
    func getCurrentCount() async -> Int
    /// 카운트 값을 저장합니다
    func saveCount(_ count: Int) async
    /// 카운트 히스토리를 가져옵니다
    func getCountHistory() async -> [CounterHistoryItem]
    /// 카운트를 초기화합니다
    func resetCount() async
}

/// 카운터 히스토리 아이템
struct CounterHistoryItem: Codable, Identifiable {
    let id = UUID()
    let count: Int
    let timestamp: Date
    let action: CounterAction

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

/// 카운터 액션 타입
enum CounterAction: String, Codable {
    case increment = "증가"
    case decrement = "감소"
    case reset = "초기화"
    case load = "로드"
}

/// UserDefaults를 사용한 CounterRepository 구현
class UserDefaultsCounterRepository: CounterRepository {
    private let countKey = "saved_count"
    private let historyKey = "count_history"

    /// WeaveDI를 통해 Logger 주입
    @Inject var logger: LoggerProtocol?

    func getCurrentCount() async -> Int {
        let count = UserDefaults.standard.integer(forKey: countKey)
        logger?.info("📊 현재 카운트 로드: \(count)")
        return count
    }

    func saveCount(_ count: Int) async {
        UserDefaults.standard.set(count, forKey: countKey)

        // 히스토리에 액션 추가
        let action: CounterAction = count > await getCurrentCount() ? .increment : .decrement
        await addToHistory(count: count, action: action)

        logger?.info("💾 카운트 저장: \(count)")
    }

    func getCountHistory() async -> [CounterHistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let history = try? JSONDecoder().decode([CounterHistoryItem].self, from: data) else {
            logger?.info("📈 히스토리 없음")
            return []
        }

        logger?.info("📈 히스토리 로드: \(history.count)개 항목")
        return history
    }

    func resetCount() async {
        UserDefaults.standard.set(0, forKey: countKey)
        await addToHistory(count: 0, action: .reset)
        logger?.info("🔄 카운트 초기화")
    }

    private func addToHistory(count: Int, action: CounterAction) async {
        var history = await getCountHistory()
        let newItem = CounterHistoryItem(count: count, timestamp: Date(), action: action)
        history.append(newItem)

        // 최근 20개 항목만 유지
        if history.count > 20 {
            history = Array(history.suffix(20))
        }

        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
}

// MARK: - ViewModel

/// 카운터 화면의 ViewModel (WeaveDI로 의존성 주입)
@MainActor
class CounterViewModel: ObservableObject {
    @Published var count = 0
    @Published var isLoading = false
    @Published var history: [CounterHistoryItem] = []
    @Published var showHistory = false

    /// WeaveDI를 통해 Repository와 Logger 주입
    @Inject var repository: CounterRepository?
    @Inject var logger: LoggerProtocol?

    init() {
        Task {
            await loadInitialData()
        }
    }

    /// 초기 데이터 로드
    func loadInitialData() async {
        guard let repo = repository else {
            logger?.error("❌ CounterRepository를 사용할 수 없습니다")
            return
        }

        isLoading = true
        count = await repo.getCurrentCount()
        history = await repo.getCountHistory()
        isLoading = false

        logger?.info("🚀 초기 데이터 로드 완료")
    }

    /// 카운트 증가
    func increment() async {
        guard let repo = repository else { return }

        isLoading = true
        count += 1
        await repo.saveCount(count)
        history = await repo.getCountHistory()
        isLoading = false

        logger?.info("⬆️ 카운트 증가: \(count)")
    }

    /// 카운트 감소
    func decrement() async {
        guard let repo = repository else { return }

        isLoading = true
        count -= 1
        await repo.saveCount(count)
        history = await repo.getCountHistory()
        isLoading = false

        logger?.info("⬇️ 카운트 감소: \(count)")
    }

    /// 카운트 초기화
    func reset() async {
        guard let repo = repository else { return }

        isLoading = true
        count = 0
        await repo.resetCount()
        history = await repo.getCountHistory()
        isLoading = false

        logger?.info("🔄 카운트 초기화")
    }

    /// 히스토리 토글
    func toggleHistory() {
        showHistory.toggle()
        logger?.info("📈 히스토리 \(showHistory ? "표시" : "숨김")")
    }
}

// MARK: - Views

/// WeaveDI가 적용된 고급 카운터 뷰
struct AdvancedCounterView: View {
    @StateObject private var viewModel = CounterViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // 제목
                Text("WeaveDI 고급 카운터")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                // 로딩 인디케이터 또는 카운트 표시
                if viewModel.isLoading {
                    ProgressView("처리 중...")
                        .scaleEffect(1.2)
                } else {
                    Text("\(viewModel.count)")
                        .font(.system(size: 80, weight: .ultraLight))
                        .foregroundColor(.blue)
                        .animation(.spring(), value: viewModel.count)
                }

                // 버튼들
                HStack(spacing: 30) {
                    AsyncActionButton(
                        title: "−",
                        color: .red,
                        action: viewModel.decrement
                    )

                    AsyncActionButton(
                        title: "+",
                        color: .green,
                        action: viewModel.increment
                    )
                }

                // 초기화 버튼
                AsyncActionButton(
                    title: "초기화",
                    color: .orange,
                    isWide: true,
                    action: viewModel.reset
                )

                // 히스토리 버튼
                Button("히스토리 \(viewModel.showHistory ? "숨기기" : "보기")") {
                    viewModel.toggleHistory()
                }
                .buttonStyle(.bordered)

                // 히스토리 목록
                if viewModel.showHistory {
                    HistoryListView(history: viewModel.history)
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

/// 비동기 액션을 지원하는 버튼
struct AsyncActionButton: View {
    let title: String
    let color: Color
    var isWide: Bool = false
    let action: () async -> Void

    var body: some View {
        Button(title) {
            Task {
                await action()
            }
        }
        .font(isWide ? .title2 : .title)
        .frame(
            width: isWide ? 200 : 60,
            height: isWide ? 44 : 60
        )
        .background(color)
        .foregroundColor(.white)
        .clipShape(isWide ? RoundedRectangle(cornerRadius: 8) : Circle())
        .shadow(radius: 2)
    }
}

/// 히스토리 목록 뷰
struct HistoryListView: View {
    let history: [CounterHistoryItem]

    var body: some View {
        VStack {
            Text("히스토리")
                .font(.headline)
                .padding(.top)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(history.reversed()) { item in
                        HistoryRowView(item: item)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }
}

/// 히스토리 행 뷰
struct HistoryRowView: View {
    let item: CounterHistoryItem

    var body: some View {
        HStack {
            Text(item.action.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(actionColor)
                .foregroundColor(.white)
                .clipShape(Capsule())

            Text("\(item.count)")
                .font(.headline)
                .frame(width: 40)

            Spacer()

            Text(item.formattedTime)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private var actionColor: Color {
        switch item.action {
        case .increment:
            return .green
        case .decrement:
            return .red
        case .reset:
            return .orange
        case .load:
            return .blue
        }
    }
}
```

**🔍 코드 설명:**

1. **Repository 패턴**: 데이터 저장/조회 로직을 분리하여 테스트 가능하고 확장 가능한 구조
2. **WeaveDI 주입**: @Inject를 사용하여 Repository와 Logger를 자동 주입
3. **비동기 처리**: async/await를 사용한 현대적인 비동기 프로그래밍
4. **상태 관리**: @Published와 @StateObject를 통한 반응형 UI
5. **히스토리 기능**: 모든 액션을 추적하고 표시하는 고급 기능
6. **사용자 경험**: 로딩 상태, 애니메이션, 직관적인 UI 제공

### Tutorial 03: UnifiedDI API 활용 (실제 Tutorial 코드)

Tutorial-IntermediateWeaveDI에서 가져온 실제 WeaveDI API 사용 예제:

```swift
// Tutorial-IntermediateWeaveDI-01-01.swift에서 가져온 실제 코드
import WeaveDI
import Foundation

// MARK: 예제 도메인
protocol UserRepository: Sendable {
    func fetchName(id: String) -> String
}

struct UserRepositoryImpl: UserRepository, Sendable {
    func fetchName(id: String) -> String {
        "user-\(id)"
    }
}

protocol UserUseCase: Sendable {
    func greet(id: String) -> String
}

struct UserUseCaseImpl: UserUseCase, Sendable {
    let repo: UserRepository
    func greet(id: String) -> String {
        "Hello, \(repo.fetchName(id: id))"
    }
}

// MARK: Option A) UnifiedDI (간결한 API)
func exampleRegisterAndResolve_UnifiedDI() {
    print("🔄 UnifiedDI API 사용 예제")

    // 1) 등록 (즉시 인스턴스 생성 후 등록)
    _ = UnifiedDI.register(UserRepository.self) {
        print("📦 UserRepository 인스턴스 생성")
        return UserRepositoryImpl()
    }

    _ = UnifiedDI.register(UserUseCase.self) {
        // 의존성은 필요 시 안전하게 조회해서 주입
        let repo = UnifiedDI.resolve(UserRepository.self) ?? UserRepositoryImpl()
        print("📦 UserUseCase 인스턴스 생성 (Repository 주입)")
        return UserUseCaseImpl(repo: repo)
    }

    // 2) 해석 (사용)
    let useCase = UnifiedDI.resolve(UserUseCase.self)
    let greeting = useCase?.greet(id: "42")
    print("👋 인사말: \(greeting ?? "실패")")
}

// MARK: Option B) WeaveDI.Container.live (명시적 컨테이너)
func exampleRegisterAndResolve_WeaveDI.Container() {
    print("🔄 WeaveDI.Container.live API 사용 예제")

    // 1) 등록 (즉시 인스턴스 등록)
    let repo = WeaveDI.Container.live.register(UserRepository.self) {
        print("📦 UserRepository 인스턴스 생성 (WeaveDI.Container)")
        return UserRepositoryImpl()
    }

    WeaveDI.Container.live.register(UserUseCase.self, instance: UserUseCaseImpl(repo: repo))
    print("📦 UserUseCase 인스턴스 등록 (WeaveDI.Container)")

    // 2) 해석
    let useCase = WeaveDI.Container.live.resolve(UserUseCase.self)
    let greeting = useCase?.greet(id: "7")
    print("👋 인사말: \(greeting ?? "실패")")
}

// MARK: 부트스트랩 예시 (앱 시작 시 일괄 등록)
func exampleBootstrap() async {
    print("🚀 부트스트랩 예제 시작")

    await WeaveDI.Container.bootstrap { container in
        print("📋 의존성 일괄 등록 시작")

        _ = container.register(UserRepository.self) {
            print("📦 UserRepository 부트스트랩 등록")
            return UserRepositoryImpl()
        }

        _ = container.register(UserUseCase.self) {
            let repo = container.resolveOrDefault(UserRepository.self, default: UserRepositoryImpl())
            print("📦 UserUseCase 부트스트랩 등록")
            return UserUseCaseImpl(repo: repo)
        }

        print("✅ 모든 의존성 등록 완료")
    }

    // 부트스트랩 후 사용
    let useCase = WeaveDI.Container.shared.resolve(UserUseCase.self)
    let greeting = useCase?.greet(id: "부트스트랩")
    print("👋 부트스트랩 인사말: \(greeting ?? "실패")")
}

/// 실제 Tutorial 코드 실행 함수
func runTutorialExamples() async {
    print("🎯 === WeaveDI Tutorial 예제 실행 ===")

    print("\n1️⃣ UnifiedDI 예제:")
    exampleRegisterAndResolve_UnifiedDI()

    print("\n2️⃣ WeaveDI.Container.live 예제:")
    exampleRegisterAndResolve_WeaveDI.Container()

    print("\n3️⃣ 부트스트랩 예제:")
    await exampleBootstrap()

    print("\n✅ === 모든 Tutorial 예제 완료 ===")
}
```

**🔍 코드 설명:**

1. **UnifiedDI API**: 가장 간결한 API로 빠른 의존성 등록/해결
2. **WeaveDI.Container.live**: 명시적 컨테이너 접근 방식
3. **Bootstrap 패턴**: 앱 시작 시 모든 의존성을 안전하게 초기화
4. **Sendable 프로토콜**: Swift 동시성 안전성 보장
5. **안전한 해결**: resolve 결과가 옵셔널이므로 안전한 처리 가능

### Tutorial 04: 종합 실습 - CountApp + WeatherApp 통합

이제 앞서 배운 모든 내용을 종합하여 CountApp과 WeatherApp을 하나의 탭 기반 앱으로 통합해보겠습니다:

```swift
// 통합 앱 구조
import SwiftUI
import WeaveDI

/// 메인 앱 구조체
@main
struct IntegratedWeaveDIApp: App {
    init() {
        // 앱 시작 시 의존성 설정
        Task {
            await setupAllDependencies()
            print("🚀 IntegratedWeaveDIApp 초기화 완료")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .task {
                    print("⏳ 의존성 설정 완료 대기 중...")
                }
        }
    }
}

/// 메인 탭 뷰
struct MainTabView: View {
    var body: some View {
        TabView {
            // 카운터 탭
            AdvancedCounterView()
                .tabItem {
                    Image(systemName: "plus.circle")
                    Text("카운터")
                }

            // 날씨 탭
            ContentView()
                .tabItem {
                    Image(systemName: "cloud.sun")
                    Text("날씨")
                }

            // 설정 탭
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("설정")
                }
        }
    }
}

/// 설정 화면
struct SettingsView: View {
    @Inject var logger: LoggerProtocol?

    var body: some View {
        NavigationView {
            List {
                Section("앱 정보") {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("의존성 주입")
                        Spacer()
                        Text("WeaveDI 3.1.0")
                            .foregroundColor(.secondary)
                    }
                }

                Section("디버그") {
                    Button("로그 테스트") {
                        logger?.info("🧪 설정에서 로그 테스트")
                    }

                    Button("의존성 상태 확인") {
                        checkDependencyStatus()
                    }
                }
            }
            .navigationTitle("설정")
        }
    }

    private func checkDependencyStatus() {
        logger?.info("🔍 의존성 상태 확인 시작")

        // 등록된 의존성들 확인
        let weatherService = WeaveDI.Container.shared.resolve(WeatherServiceProtocol.self)
        let counterRepo = WeaveDI.Container.shared.resolve(CounterRepository.self)
        let cacheService = WeaveDI.Container.shared.resolve(CacheServiceProtocol.self)

        logger?.info("WeatherService: \(weatherService != nil ? "✅" : "❌")")
        logger?.info("CounterRepository: \(counterRepo != nil ? "✅" : "❌")")
        logger?.info("CacheService: \(cacheService != nil ? "✅" : "❌")")
    }
}

/// 통합 의존성 설정 함수
func setupAllDependencies() async {
    await WeaveDI.Container.bootstrap { container in
        print("🔧 통합 의존성 설정 시작")

        // MARK: - 공통 서비스

        /// 로거 서비스 - 앱 전체에서 사용
        container.register(LoggerProtocol.self) {
            print("📝 Logger 등록")
            return ConsoleLogger()
        }

        /// HTTP 클라이언트 - 네트워크 요청용
        container.register(HTTPClientProtocol.self) {
            print("🌐 HTTPClient 등록")
            return URLSessionHTTPClient()
        }

        /// 캐시 서비스 - 데이터 캐싱용
        container.register(CacheServiceProtocol.self) {
            print("💾 CacheService 등록")
            return UserDefaultsCacheService()
        }

        // MARK: - 날씨 앱 의존성

        /// 날씨 서비스
        container.register(WeatherServiceProtocol.self) {
            print("🌤️ WeatherService 등록")
            return WeatherService()
        }

        /// 위치 서비스
        container.register(LocationServiceProtocol.self) {
            print("📍 LocationService 등록")
            return CoreLocationService()
        }

        // MARK: - 카운터 앱 의존성

        /// 카운터 Repository
        container.register(CounterRepository.self) {
            print("📊 CounterRepository 등록")
            return UserDefaultsCounterRepository()
        }

        print("✅ 모든 통합 의존성 등록 완료")
    }
}
```

**🔍 통합 앱 코드 설명:**

1. **TabView 구조**: 카운터, 날씨, 설정을 탭으로 분리한 완전한 앱 구조
2. **통합 의존성**: 모든 기능이 필요한 의존성을 한 곳에서 등록
3. **공통 서비스**: Logger, HTTPClient, CacheService 등을 모든 탭에서 공유
4. **설정 화면**: 의존성 상태 확인과 디버그 기능 제공
5. **확장 가능성**: 새로운 탭과 기능을 쉽게 추가할 수 있는 구조

---

**축하합니다!** WeaveDI를 사용한 완전한 iOS 앱을 성공적으로 구축했습니다. 이 앱은 실제 Tutorial 코드를 활용하여 모던한 Swift 개발 패턴과 WeaveDI의 강력한 의존성 주입 기능을 완벽하게 활용합니다.
