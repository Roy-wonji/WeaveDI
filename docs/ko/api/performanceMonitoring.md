# 성능 모니터링 API

WeaveDI는 의존성 주입 성능을 최적화하고, 병목 현상을 식별하며, 프로덕션 환경에서 최적의 애플리케이션 성능을 유지하도록 설계된 포괄적이고 엔터프라이즈급 성능 모니터링 도구를 제공합니다. 이 정교한 모니터링 시스템은 실시간 메트릭, 이력 분석, 자동 알림 기능을 제공합니다.

## 개요

성능 모니터링 시스템은 의존성 해결 시간, 메모리 사용 패턴, 등록 효율성, 컨테이너 성능 특성을 추적하기 위한 고급 계측을 구현합니다. 이 포괄적인 모니터링은 성능 최적화, 용량 계획, 사전 문제 감지를 위한 실행 가능한 인사이트를 제공합니다.

**주요 모니터링 기능**:
- **실시간 메트릭**: 실시간 성능 데이터 수집 및 분석
- **이력 추적**: 장기 성능 트렌드 분석
- **메모리 프로파일링**: 상세한 메모리 사용 패턴 및 누수 감지
- **병목 현상 식별**: 자동 성능 병목 현상 식별
- **사용자 정의 메트릭**: 애플리케이션별 메트릭을 위한 확장 가능한 프레임워크

**성능 이점**:
- **사전 최적화**: 사용자에게 영향을 주기 전에 문제 식별
- **용량 계획**: 인프라 확장을 위한 데이터 기반 인사이트
- **회귀 감지**: 성능 회귀 자동 감지
- **리소스 최적화**: 메모리 및 CPU 사용 패턴 최적화

```swift
import WeaveDI

// 성능 모니터링 활성화
PerformanceMonitor.shared.enable()

// 특정 작업 모니터링
let metrics = await PerformanceMonitor.shared.measureResolution {
    let service = WeaveDI.Container.shared.resolve(ExpensiveService.self)
    return service
}

print("해결에 걸린 시간: \(metrics.duration)ms")
print("사용된 메모리: \(metrics.memoryDelta) bytes")
```

## 핵심 모니터링 기능

### 해결 성능 추적

**목적**: 느린 의존성을 식별하고 해결 패턴을 최적화하기 위한 의존성 해결 성능의 포괄적 추적.

**추적 기능**:
- **해결 시간 측정**: 개별 의존성 해결의 정밀한 타이밍
- **집계 통계**: 평균, 중앙값, 백분위수 해결 시간
- **성능 트렌드**: 이력 성능 트렌드 및 회귀 감지
- **의존성 핫스팟**: 자주 해결되는 의존성 식별

**수집되는 메트릭**:
- **개별 해결 시간**: 의존성별 해결 타이밍
- **집계 성능**: 전체 컨테이너 성능 통계
- **캐시 히트/미스 비율**: 의존성 캐싱의 효과성
- **메모리 할당 패턴**: 해결 작업 중 메모리 사용량

**성능 최적화 인사이트**:
- **느린 의존성**: 높은 해결 시간을 가진 의존성 식별
- **캐시 효과성**: 캐시 성능 및 최적화 기회 측정
- **해결 패턴**: 최적화를 위한 해결 패턴 분석
- **리소스 사용량**: 해결 중 리소스 소비 모니터링

```swift
// 자동 해결 타이밍
class PerformanceAwareService {
    @Injected var userService: UserService?
    @Injected var dataService: DataService?

    func performOperation() async {
        // 모니터가 이러한 해결을 자동으로 추적함
        userService?.loadUser()
        dataService?.processData()

        // 성능 보고서 가져오기
        let report = PerformanceMonitor.shared.getResolutionReport()
        print("최근 해결: \(report.recentResolutions)")
        print("평균 해결 시간: \(report.averageResolutionTime)ms")
    }
}
```

### 메모리 사용량 모니터링

**목적**: 메모리 누수를 감지하고, 메모리 사용량을 최적화하며, 효율적인 리소스 활용을 보장하기 위한 고급 메모리 프로파일링 및 모니터링.

**메모리 모니터링 기능**:
- **실시간 메모리 추적**: 메모리 사용 패턴의 지속적인 모니터링
- **누수 감지**: 잠재적 메모리 누수 자동 감지
- **할당 프로파일링**: 메모리 할당 패턴의 상세 분석
- **증가율 분석**: 메모리 증가율 및 트렌드 모니터링

**메모리 메트릭**:
- **현재 사용량**: 실시간 메모리 소비
- **최대 사용량**: 작업 중 최대 메모리 사용량
- **증가율**: 시간에 따른 메모리 사용량 증가율
- **할당 패턴**: 메모리 할당의 상세 분석

**최적화 기회**:
- **메모리 핫스팟**: 과도한 메모리를 소비하는 구성 요소 식별
- **최적화 대상**: 메모리 영향을 기반으로 한 최적화 노력 우선순위
- **리소스 계획**: 용량 계획 및 리소스 할당을 위한 데이터
- **성능 상관관계**: 메모리 사용량과 성능 메트릭 간의 상관관계

```swift
// 메모리 소비 모니터링
class MemoryAwareBootstrap {
    static func setupWithMonitoring() async {
        let initialMemory = PerformanceMonitor.shared.getCurrentMemoryUsage()

        await WeaveDI.Container.bootstrap { container in
            // 많은 서비스 등록
            for i in 0..<1000 {
                container.register(TestService.self, name: "service_\(i)") {
                    TestServiceImpl(id: i)
                }
            }
        }

        let finalMemory = PerformanceMonitor.shared.getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory

        print("DI 설정 메모리 사용량: \(memoryIncrease) bytes")
        print("서비스당 메모리: \(memoryIncrease / 1000) bytes")
    }
}
```

## 실제 모니터링 예제

### CountApp 성능 모니터링

```swift
/// 메트릭 수집이 포함된 성능 모니터링 카운터
@MainActor
class MonitoredCounterViewModel: ObservableObject {
    @Published var count = 0
    @Published var performanceMetrics: PerformanceMetrics?

    @Injected var repository: CounterRepository?
    @Injected var logger: LoggerProtocol?

    func increment() async {
        let metrics = await PerformanceMonitor.shared.measureOperation("counter_increment") {
            // 전체 증가 작업 측정
            let startTime = CFAbsoluteTimeGetCurrent()

            count += 1
            await repository?.saveCount(count)

            let endTime = CFAbsoluteTimeGetCurrent()
            logger?.info("⏱️ 증가 작업이 \(String(format: "%.2f", (endTime - startTime) * 1000))ms 걸렸습니다")
        }

        // 성능 데이터로 UI 업데이트
        performanceMetrics = metrics

        // 성능 데이터 로그
        logger?.info("📊 성능: 해결=\(metrics.resolutionTime)ms, 총=\(metrics.totalTime)ms")
    }

    func getPerformanceReport() -> String {
        let report = PerformanceMonitor.shared.getDetailedReport()
        return """
        📈 카운터 성능 보고서:
        - 총 작업 수: \(report.operationCount)
        - 평균 해결 시간: \(String(format: "%.2f", report.averageResolutionTime))ms
        - 최대 메모리 사용량: \(report.peakMemoryUsage) bytes
        - 캐시 히트율: \(String(format: "%.1f", report.cacheHitRate * 100))%
        """
    }
}

/// 성능 추적이 강화된 카운터 리포지토리
class PerformanceTrackedCounterRepository: CounterRepository {
    @Injected var logger: LoggerProtocol?

    func getCurrentCount() async -> Int {
        return await PerformanceMonitor.shared.measureOperation("get_current_count") {
            let count = UserDefaults.standard.integer(forKey: "saved_count")
            logger?.debug("📊 카운트 검색됨: \(count)")
            return count
        }
    }

    func saveCount(_ count: Int) async {
        await PerformanceMonitor.shared.measureOperation("save_count") {
            UserDefaults.standard.set(count, forKey: "saved_count")
            logger?.debug("💾 카운트 저장됨: \(count)")
        }
    }

    func getCountHistory() async -> [CounterHistoryItem] {
        return await PerformanceMonitor.shared.measureOperation("get_count_history") {
            guard let data = UserDefaults.standard.data(forKey: "count_history"),
                  let history = try? JSONDecoder().decode([CounterHistoryItem].self, from: data) else {
                return []
            }
            logger?.debug("📜 \(history.count)개 히스토리 항목 검색됨")
            return history
        }
    }

    func resetCount() async {
        await PerformanceMonitor.shared.measureOperation("reset_count") {
            UserDefaults.standard.set(0, forKey: "saved_count")
            logger?.debug("🔄 카운트 리셋됨")
        }
    }
}
```

### WeatherApp 성능 모니터링

```swift
/// 포괄적인 성능 모니터링이 있는 날씨 서비스
class MonitoredWeatherService: WeatherServiceProtocol {
    @Injected var httpClient: HTTPClientProtocol?
    @Injected var cacheService: CacheServiceProtocol?
    @Injected var logger: LoggerProtocol?

    func fetchCurrentWeather(for city: String) async throws -> Weather {
        return try await PerformanceMonitor.shared.measureAsyncOperation("fetch_weather_\(city)") {
            let startTime = CFAbsoluteTimeGetCurrent()

            // 캐시 먼저 확인
            let cacheMetrics = await PerformanceMonitor.shared.measureOperation("cache_lookup") {
                return await cacheService?.retrieve(forKey: "weather_\(city)")
            }

            if let cachedWeather: Weather = cacheMetrics.result {
                let cacheTime = CFAbsoluteTimeGetCurrent() - startTime
                logger?.info("⚡ \(city) 캐시 히트 \(String(format: "%.2f", cacheTime * 1000))ms")
                return cachedWeather
            }

            // 네트워크 가져오기
            let networkMetrics = await PerformanceMonitor.shared.measureAsyncOperation("network_fetch") {
                guard let client = httpClient else {
                    throw WeatherError.httpClientNotAvailable
                }

                let url = buildWeatherURL(for: city)
                let data = try await client.fetchData(from: url)
                return try JSONDecoder().decode(Weather.self, from: data)
            }

            let weather: Weather = networkMetrics.result

            // 결과 캐시
            await PerformanceMonitor.shared.measureOperation("cache_store") {
                try? await cacheService?.store(weather, forKey: "weather_\(city)")
            }

            let totalTime = CFAbsoluteTimeGetCurrent() - startTime
            logger?.info("🌤️ \(city) 날씨 가져오기가 \(String(format: "%.2f", totalTime * 1000))ms에 완료됨")

            return weather
        }
    }

    private func buildWeatherURL(for city: String) -> URL {
        return URL(string: "https://api.openweathermap.org/data/2.5/weather?q=\(city)&appid=test&units=metric")!
    }
}

/// 날씨 앱을 위한 성능 대시보드
class WeatherPerformanceDashboard {
    @Injected var logger: LoggerProtocol?

    func generateReport() -> WeatherPerformanceReport {
        let monitor = PerformanceMonitor.shared
        let report = monitor.getDetailedReport()

        let weatherOperations = report.operations.filter { $0.name.contains("weather") }
        let cacheOperations = report.operations.filter { $0.name.contains("cache") }
        let networkOperations = report.operations.filter { $0.name.contains("network") }

        return WeatherPerformanceReport(
            totalWeatherRequests: weatherOperations.count,
            averageWeatherFetchTime: weatherOperations.map(\.duration).average(),
            cacheHitRate: calculateCacheHitRate(cacheOperations),
            networkLatency: networkOperations.map(\.duration).average(),
            memoryUsage: report.currentMemoryUsage,
            recommendations: generateRecommendations(report)
        )
    }

    private func calculateCacheHitRate(_ operations: [OperationMetric]) -> Double {
        let cacheHits = operations.filter { $0.metadata["cache_hit"] as? Bool == true }.count
        return operations.isEmpty ? 0.0 : Double(cacheHits) / Double(operations.count)
    }

    private func generateRecommendations(_ report: PerformanceReport) -> [String] {
        var recommendations: [String] = []

        if report.averageResolutionTime > 10.0 {
            recommendations.append("의존성 해결 최적화 고려 - 평균 시간이 높습니다")
        }

        if report.memoryGrowthRate > 1024 * 1024 { // 1MB/시간
            recommendations.append("메모리 사용량이 빠르게 증가하고 있습니다 - 메모리 누수 확인")
        }

        let cacheHitRate = calculateCacheHitRate(report.operations.filter { $0.name.contains("cache") })
        if cacheHitRate < 0.7 {
            recommendations.append("캐시 히트율이 낮습니다 (\(String(format: "%.1f", cacheHitRate * 100))%) - 캐시 전략 최적화 고려")
        }

        return recommendations
    }
}

struct WeatherPerformanceReport {
    let totalWeatherRequests: Int
    let averageWeatherFetchTime: Double
    let cacheHitRate: Double
    let networkLatency: Double
    let memoryUsage: Int64
    let recommendations: [String]

    var formattedReport: String {
        return """
        🌤️ 날씨 앱 성능 보고서
        ================================
        📊 총 날씨 요청: \(totalWeatherRequests)
        ⏱️ 평균 가져오기 시간: \(String(format: "%.2f", averageWeatherFetchTime))ms
        📱 캐시 히트율: \(String(format: "%.1f", cacheHitRate * 100))%
        🌐 네트워크 지연시간: \(String(format: "%.2f", networkLatency))ms
        💾 메모리 사용량: \(memoryUsage / 1024 / 1024)MB

        💡 권장사항:
        \(recommendations.map { "• \($0)" }.joined(separator: "\n"))
        """
    }
}
```

## 고급 모니터링 기능

### 사용자 정의 메트릭 수집

**목적**: 표준 의존성 주입 메트릭을 넘어서 애플리케이션별 성능 메트릭을 수집하기 위한 확장 가능한 프레임워크.

**사용자 정의 메트릭 이점**:
- **애플리케이션별 인사이트**: 애플리케이션 도메인에 특화된 메트릭 모니터링
- **비즈니스 로직 성능**: 중요한 비즈니스 작업의 성능 추적
- **통합 지점**: 외부 서비스 통합의 성능 모니터링
- **사용자 경험 메트릭**: 기술적 메트릭과 사용자 경험 상관관계

**메트릭 프레임워크 기능**:
- **타입 안전 메트릭**: 강타입 메트릭 정의로 오류 방지
- **집계 함수**: 평균, 백분위수, 트렌드를 위한 내장 지원
- **이력 저장**: 트렌드 분석을 위한 사용자 정의 메트릭의 장기 저장
- **실시간 분석**: 사용자 정의 메트릭의 실시간 처리 및 분석

**구현 패턴**:
- **도메인별 메트릭**: 특정 비즈니스 도메인에 맞춤화된 메트릭
- **성능 벤치마크**: 성능 검증을 위한 사용자 정의 벤치마크
- **통합 모니터링**: 외부 통합의 성능 모니터링
- **사용자 여정 추적**: 사용자 상호작용 플로우 전반의 성능 추적

```swift
// 사용자 정의 메트릭 정의
enum CustomMetric: String, CaseIterable {
    case userLoginTime = "user_login"
    case dataProcessingTime = "data_processing"
    case cacheOperationTime = "cache_operation"
    case databaseQueryTime = "database_query"
}

class CustomMetricsCollector {
    private var metrics: [CustomMetric: [Double]] = [:]

    func recordMetric(_ metric: CustomMetric, value: Double) {
        metrics[metric, default: []].append(value)
        PerformanceMonitor.shared.recordCustomMetric(metric.rawValue, value: value)
    }

    func getAverageTime(for metric: CustomMetric) -> Double {
        guard let values = metrics[metric], !values.isEmpty else { return 0.0 }
        return values.reduce(0, +) / Double(values.count)
    }

    func getPercentile(_ percentile: Double, for metric: CustomMetric) -> Double {
        guard let values = metrics[metric]?.sorted(), !values.isEmpty else { return 0.0 }
        let index = Int(Double(values.count - 1) * percentile / 100.0)
        return values[index]
    }
}
```

### 성능 알림 시스템

**목적**: 성능 문제를 자동으로 감지하고 문제가 사용자에게 영향을 주기 전에 이해관계자에게 알리는 사전 알림 시스템.

**알림 시스템 기능**:
- **임계값 기반 알림**: 다양한 성능 메트릭에 대한 구성 가능한 임계값
- **트렌드 기반 감지**: 성능 저하 트렌드 감지
- **다중 채널 알림**: 다양한 알림 채널 지원
- **알림 우선순위**: 심각도와 영향에 따른 알림 우선순위

**알림 유형**:
- **성능 저하**: 성능이 허용 수준 이하로 떨어질 때 감지
- **리소스 고갈**: 메모리 또는 CPU 리소스 고갈 알림
- **이상 감지**: 성능 메트릭의 비정상적인 패턴 식별
- **임계값 위반**: 메트릭이 구성된 임계값을 초과할 때 알림

**통합 기능**:
- **외부 모니터링 시스템**: 외부 모니터링 플랫폼과의 통합
- **인시던트 관리**: 인시던트 관리 시스템과의 통합
- **팀 알림**: 다양한 팀을 위한 구성 가능한 알림
- **에스컬레이션 정책**: 중요한 성능 문제에 대한 자동 에스컬레이션

```swift
protocol PerformanceAlert {
    var threshold: Double { get }
    var message: String { get }
    func shouldTrigger(for metrics: PerformanceReport) -> Bool
}

struct HighResolutionTimeAlert: PerformanceAlert {
    let threshold: Double = 50.0 // ms
    let message = "의존성 해결 시간이 50ms 이상입니다"

    func shouldTrigger(for metrics: PerformanceReport) -> Bool {
        return metrics.averageResolutionTime > threshold
    }
}

struct HighMemoryUsageAlert: PerformanceAlert {
    let threshold: Double = 100 * 1024 * 1024 // 100MB
    let message = "메모리 사용량이 100MB 이상입니다"

    func shouldTrigger(for metrics: PerformanceReport) -> Bool {
        return Double(metrics.currentMemoryUsage) > threshold
    }
}

struct LowCacheHitRateAlert: PerformanceAlert {
    let threshold: Double = 0.5 // 50%
    let message = "캐시 히트율이 50% 미만입니다"

    func shouldTrigger(for metrics: PerformanceReport) -> Bool {
        let cacheOps = metrics.operations.filter { $0.name.contains("cache") }
        let hits = cacheOps.filter { $0.metadata["hit"] as? Bool == true }.count
        let rate = cacheOps.isEmpty ? 1.0 : Double(hits) / Double(cacheOps.count)
        return rate < threshold
    }
}

class PerformanceAlertManager {
    private let alerts: [PerformanceAlert] = [
        HighResolutionTimeAlert(),
        HighMemoryUsageAlert(),
        LowCacheHitRateAlert()
    ]

    @Injected var logger: LoggerProtocol?

    func checkAlerts() {
        let report = PerformanceMonitor.shared.getDetailedReport()

        for alert in alerts {
            if alert.shouldTrigger(for: report) {
                logger?.warning("⚠️ 성능 알림: \(alert.message)")

                // 분석, 크래시 리포팅 등으로 전송 가능
                sendAlertToMonitoringService(alert)
            }
        }
    }

    private func sendAlertToMonitoringService(_ alert: PerformanceAlert) {
        // 외부 모니터링 통합을 위한 구현
    }
}
```

### 지속적인 성능 모니터링

**목적**: 수동 개입 없이 애플리케이션 성능에 대한 지속적인 가시성을 제공하는 자동화된 지속적 모니터링 시스템.

**지속적인 모니터링 이점**:
- **24/7 가시성**: 애플리케이션 성능에 대한 24시간 모니터링
- **자동 감지**: 성능 문제의 자율적 감지
- **트렌드 분석**: 용량 계획을 위한 장기 트렌드 분석
- **사전 최적화**: 문제가 발생하기 전에 최적화 기회 식별

**모니터링 기능**:
- **상태 검사**: 성능 메트릭의 정기적인 상태 평가
- **베이스라인 설정**: 성능 베이스라인의 자동 설정
- **편차 감지**: 설정된 베이스라인으로부터의 편차 감지
- **성능 회귀**: 성능 회귀의 자동 감지

**액터 기반 아키텍처**:
- **스레드 안전성**: Swift 액터를 사용한 안전한 동시 모니터링
- **리소스 효율성**: 최소한의 성능 영향으로 효율적인 모니터링
- **확장 가능한 설계**: 고처리량 애플리케이션을 위한 확장 가능한 아키텍처
- **장애 내성**: 장애 중에도 계속되는 탄력적인 모니터링

```swift
actor ContinuousMonitor {
    private var isRunning = false
    private let checkInterval: TimeInterval = 30.0 // 30초

    @Injected var logger: LoggerProtocol?

    func start() async {
        guard !isRunning else { return }
        isRunning = true

        logger?.info("🔄 지속적인 성능 모니터링 시작")

        while isRunning {
            await performHealthCheck()
            try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
        }
    }

    func stop() {
        isRunning = false
        logger?.info("⏹️ 지속적인 성능 모니터링 중지")
    }

    private func performHealthCheck() async {
        let report = PerformanceMonitor.shared.getDetailedReport()

        // 주요 메트릭 로그
        logger?.debug("""
        📊 성능 상태 검사:
        - 해결 시간: \(String(format: "%.2f", report.averageResolutionTime))ms
        - 메모리 사용량: \(report.currentMemoryUsage / 1024 / 1024)MB
        - 캐시 히트율: \(String(format: "%.1f", calculateOverallCacheHitRate(report) * 100))%
        """)

        // 성능 저하 확인
        await checkForPerformanceDegradation(report)

        // 알림 실행
        let alertManager = PerformanceAlertManager()
        alertManager.checkAlerts()
    }

    private func calculateOverallCacheHitRate(_ report: PerformanceReport) -> Double {
        let cacheOps = report.operations.filter { $0.name.contains("cache") }
        let hits = cacheOps.filter { $0.metadata["hit"] as? Bool == true }.count
        return cacheOps.isEmpty ? 1.0 : Double(hits) / Double(cacheOps.count)
    }

    private func checkForPerformanceDegradation(_ current: PerformanceReport) async {
        // 성능 저하를 감지하기 위해 이력 데이터와 비교
        let historical = PerformanceMonitor.shared.getHistoricalBaseline()

        if current.averageResolutionTime > historical.averageResolutionTime * 1.5 {
            logger?.warning("⚠️ 해결 시간 저하 감지: \(String(format: "%.2f", current.averageResolutionTime))ms vs 베이스라인 \(String(format: "%.2f", historical.averageResolutionTime))ms")
        }

        if current.currentMemoryUsage > Int64(Double(historical.averageMemoryUsage) * 1.3) {
            logger?.warning("⚠️ 메모리 사용량 증가 감지: \(current.currentMemoryUsage / 1024 / 1024)MB vs 베이스라인 \(historical.averageMemoryUsage / 1024 / 1024)MB")
        }
    }
}
```

## 성능 최적화 권장사항

### 의존성 해결 최적화

**목적**: 캐싱, 배칭, 지능적인 해결 패턴을 통해 의존성 해결 성능을 개선하기 위한 고급 최적화 전략.

**최적화 전략**:
- **해결 캐싱**: 빠른 액세스를 위해 자주 해결되는 의존성 캐시
- **배치 해결**: 효율성 향상을 위해 여러 해결을 그룹화
- **지연 로딩**: 의존성이 실제로 필요할 때까지 해결 연기
- **사전 로딩**: 애플리케이션 시작 중 중요한 의존성 사전 로드

**캐싱 구현**:
- **스레드 안전 캐싱**: 다중 스레드 애플리케이션을 위한 동시성 안전 캐싱
- **캐시 무효화**: 지능적인 캐시 무효화 전략
- **메모리 관리**: 캐시된 의존성을 위한 효율적인 메모리 사용
- **성능 모니터링**: 캐시 효과성과 히트율 모니터링

**성능 이점**:
- **해결 시간 단축**: 캐시된 의존성에 대해 현저히 빠른 해결
- **처리량 향상**: 전체 애플리케이션 처리량 향상
- **리소스 효율성**: CPU와 메모리 리소스의 더 효율적인 사용
- **확장성**: 높은 부하 조건에서 더 나은 확장성

```swift
class OptimizedDependencyManager {
    // 자주 해결되는 의존성 캐시
    private var resolutionCache: [String: Any] = [:]
    private let cacheQueue = DispatchQueue(label: "resolution-cache", attributes: .concurrent)

    func getOptimizedService<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)

        return cacheQueue.sync {
            if let cached = resolutionCache[key] as? T {
                PerformanceMonitor.shared.recordCacheHit(key)
                return cached
            }

            // 해결하고 캐시
            guard let service = WeaveDI.Container.shared.resolve(type) else { return nil }

            cacheQueue.async(flags: .barrier) {
                self.resolutionCache[key] = service
            }

            PerformanceMonitor.shared.recordCacheMiss(key)
            return service
        }
    }

    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.resolutionCache.removeAll()
        }
    }
}
```

### 메모리 사용량 최적화

**목적**: 메모리 사용량을 최소화하고, 누수를 방지하며, 전반적인 애플리케이션 메모리 효율성을 개선하기 위한 포괄적인 메모리 최적화 전략.

**메모리 최적화 기법**:
- **약한 참조**: 유지 주기를 방지하기 위해 약한 참조 사용
- **메모리 경고 처리**: 메모리 압박 조건에 대한 반응형 처리
- **캐시 관리**: 지능적인 캐시 크기 조정 및 정리 전략
- **리소스 정리**: 사용하지 않는 리소스의 자동 정리

**메모리 관리 기능**:
- **자동 정리**: 메모리 압박 중 자동 정리
- **누수 방지**: 일반적인 메모리 누수 패턴의 사전 방지
- **메모리 모니터링**: 메모리 사용 패턴의 지속적인 모니터링
- **리소스 재활용**: 비싼 리소스의 효율적인 재활용

**최적화 이점**:
- **메모리 사용량 감소**: 전체 메모리 사용량 감소
- **안정성 향상**: 메모리 압박 하에서 더 나은 애플리케이션 안정성
- **성능 향상**: 효율적인 메모리 사용을 통한 성능 개선
- **리소스 효율성**: 사용 가능한 메모리 리소스의 더 효율적인 사용

```swift
class MemoryOptimizedContainer {
    private weak var container: WeaveDI.Container?

    init(container: WeaveDI.Container) {
        self.container = container
        setupMemoryWarningObserver()
    }

    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    private func handleMemoryWarning() {
        // 캐시 정리, 필수적이지 않은 서비스 해제
        PerformanceMonitor.shared.recordMemoryWarning()

        // 내부 캐시 정리
        container?.clearInternalCaches()

        // 메모리 상태 로그
        let currentMemory = PerformanceMonitor.shared.getCurrentMemoryUsage()
        print("💾 메모리 경고 - 현재 사용량: \(currentMemory / 1024 / 1024)MB")
    }
}
```

## 개발 도구와의 통합

### Xcode Instruments 통합

**목적**: 업계 표준 개발 도구를 사용한 포괄적인 성능 프로파일링 및 분석을 위한 Xcode Instruments와의 원활한 통합.

**Instruments 통합 기능**:
- **사용자 정의 사인포스트**: 의존성 주입 작업을 위한 사용자 정의 사인포스트
- **성능 추적**: Instruments 타임라인에서 상세한 성능 추적
- **메모리 프로파일링**: Instruments 메모리 프로파일링 도구와의 통합
- **스레드 분석**: 동시 작업을 위한 스레드 사용 분석

**프로파일링 기능**:
- **시간 프로파일링**: 의존성 작업의 상세한 타이밍 분석
- **메모리 분석**: 포괄적인 메모리 사용량 분석
- **CPU 사용량**: 의존성 해결 중 CPU 사용 패턴
- **스레드 안전성**: 스레드 안전성과 동시성 패턴 분석

**개발 워크플로 통합**:
- **디버그 빌드**: 디버그 빌드를 위한 향상된 프로파일링
- **성능 테스팅**: 성능 테스트 스위트와의 통합
- **지속적 통합**: CI/CD 파이프라인에서 자동화된 성능 테스팅
- **성능 회귀 감지**: 성능 회귀의 자동 감지

```swift
class InstrumentsIntegration {
    static func startProfiling() {
        #if DEBUG
        // Instruments를 위한 상세 로깅 활성화
        PerformanceMonitor.shared.enableInstrumentsMode()

        // 사용자 정의 사인포스트 추가
        os_signpost(.begin, log: OSLog(subsystem: "com.app.weavedinew", category: "DI"), name: "DI Container Operation")
        #endif
    }

    static func recordResolution<T>(_ type: T.Type, duration: TimeInterval) {
        #if DEBUG
        os_signpost(.event, log: OSLog(subsystem: "com.app.weavedi", category: "DI"), name: "Dependency Resolution", "Type: %{public}s, Duration: %.2fms", String(describing: type), duration * 1000)
        #endif
    }
}
```

### 성능 테스팅 통합

**목적**: 성능 특성을 검증하고 성능 요구사항이 충족되는지 확인하는 포괄적인 성능 테스팅 프레임워크.

**테스팅 프레임워크 기능**:
- **자동화된 성능 테스트**: 성능 검증을 위한 자동화된 테스트 스위트
- **벤치마크 테스팅**: 일관된 성능 측정을 위한 표준화된 벤치마크
- **부하 테스팅**: 다양한 부하 조건에서의 성능 테스팅
- **회귀 테스팅**: 성능 회귀의 자동 감지

**테스트 카테고리**:
- **해결 성능**: 의존성 해결 성능 측정
- **메모리 사용량**: 메모리 사용 패턴 및 한계 검증
- **동시 접근**: 동시 접근 하에서의 성능 테스트
- **부트스트랩 성능**: 컨테이너 초기화 성능 측정

**성능 검증**:
- **성능 어설션**: 성능 요구사항에 대한 자동화된 어설션
- **임계값 검증**: 정의된 임계값에 대한 성능 검증
- **트렌드 분석**: 장기 성능 트렌드 분석
- **성능 보고**: 포괄적인 성능 테스트 보고

```swift
class PerformanceTestSuite {
    func runPerformanceTests() async {
        await testResolutionPerformance()
        await testMemoryUsage()
        await testConcurrentAccess()
        await testBootstrapPerformance()
    }

    private func testResolutionPerformance() async {
        let iterations = 10000
        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<iterations {
            _ = WeaveDI.Container.shared.resolve(TestService.self)
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let avgTime = (endTime - startTime) / Double(iterations) * 1000

        print("📊 해결 성능: \(String(format: "%.4f", avgTime))ms per resolution")
        assert(avgTime < 1.0, "해결 시간이 너무 높습니다: \(avgTime)ms")
    }

    private func testMemoryUsage() async {
        let initialMemory = PerformanceMonitor.shared.getCurrentMemoryUsage()

        // 많은 서비스 등록
        for i in 0..<10000 {
            WeaveDI.Container.shared.register(TestService.self, name: "test_\(i)") {
                TestServiceImpl()
            }
        }

        let finalMemory = PerformanceMonitor.shared.getCurrentMemoryUsage()
        let memoryPerService = (finalMemory - initialMemory) / 10000

        print("💾 서비스당 메모리: \(memoryPerService) bytes")
        assert(memoryPerService < 1024, "서비스당 메모리 사용량이 너무 높습니다: \(memoryPerService) bytes")
    }
}
```

## 모범 사례

### 1. 조기 모니터링 활성화

**전략**: 개발 초기 단계부터 성능 모니터링을 구현하여 베이스라인을 설정하고 성능 문제를 조기에 포착합니다.

**조기 모니터링 이점**:
- **베이스라인 설정**: 개발 중 성능 베이스라인 설정
- **조기 문제 감지**: 성능 문제가 문제가 되기 전에 포착
- **개발 피드백**: 변경 사항의 성능 영향에 대한 즉각적인 피드백
- **최적화 기회**: 개발 초기에 최적화 기회 식별

**구현 가이드라인**:
- **애플리케이션 시작**: 애플리케이션 초기화 중 모니터링 활성화
- **개발 환경**: 모든 개발 환경에서 모니터링 사용
- **지속적 통합**: CI/CD 파이프라인에 모니터링 포함
- **팀 채택**: 모니터링 관행의 팀 전체 채택 장려

```swift
@main
struct App: App {
    init() {
        // 앱 시작 시 모니터링 활성화
        PerformanceMonitor.shared.enable()
        PerformanceMonitor.shared.setLogLevel(.info)
    }
}
```

### 2. 중요한 경로 모니터링

**전략**: 최적화 노력의 영향을 극대화하기 위해 성능이 중요한 코드 경로에 모니터링 노력을 집중합니다.

**중요한 경로 식별**:
- **사용자 대면 작업**: 사용자 경험에 직접 영향을 주는 작업 모니터링
- **고빈도 작업**: 자주 실행되는 작업에 집중
- **리소스 집약적 작업**: 상당한 리소스를 소비하는 작업 모니터링
- **비즈니스 중요 기능**: 비즈니스 중요 기능의 모니터링 우선순위

**모니터링 구현**:
- **선택적 계측**: 시스템을 압도하지 않고 중요한 경로 계측
- **성능 임계값**: 중요한 작업에 대한 적절한 성능 임계값 설정
- **알림 구성**: 중요한 경로 성능 문제에 대한 알림 구성
- **최적화 우선순위**: 모니터링 데이터를 기반으로 한 최적화 노력 우선순위

```swift
// 성능이 중요한 작업 모니터링
func performCriticalOperation() async {
    await PerformanceMonitor.shared.measureOperation("critical_path") {
        // 중요한 코드 여기
    }
}
```

### 3. 자동화된 알림 설정

**전략**: 성능 문제에 대한 시기적절한 알림을 보장하고 사전 대응을 가능하게 하는 자동화된 알림 구현.

**알림 구성 모범 사례**:
- **임계값 튜닝**: 거짓 양성을 최소화하기 위해 알림 임계값을 신중하게 조정
- **알림 우선순위**: 비즈니스 영향과 긴급성에 따른 알림 우선순위
- **에스컬레이션 정책**: 다양한 알림 유형에 대한 적절한 에스컬레이션 정책 구현
- **팀 배포**: 전문성에 따라 적절한 팀 구성원에게 알림 배포

**자동화 이점**:
- **사전 대응**: 성능 문제에 대한 사전 대응 가능
- **다운타임 감소**: 조기 문제 감지를 통한 다운타임 최소화
- **팀 효율성**: 자동화된 모니터링을 통한 팀 효율성 향상
- **지속적인 개선**: 자동화된 피드백을 통한 지속적인 개선 가능

```swift
// 정기적인 성능 검사 설정
Task {
    let continuousMonitor = ContinuousMonitor()
    await continuousMonitor.start()
}
```

### 4. 다양한 시나리오에서 프로파일링

**전략**: 모든 조건에서 견고한 성능을 보장하기 위해 다양한 사용 시나리오에서 포괄적인 성능 프로파일링.

**프로파일링 시나리오**:
- **부하 테스팅**: 예상 프로덕션 부하 하에서 성능 프로파일링
- **스트레스 테스팅**: 극한 조건에서 성능 테스트
- **동시 사용**: 동시 사용 패턴 프로파일링
- **엣지 케이스**: 엣지 케이스 조건에서 성능 테스트

**시나리오 기반 테스팅 이점**:
- **포괄적인 범위**: 모든 사용 시나리오에서 성능 보장
- **병목 현상 식별**: 다양한 조건에서 병목 현상 식별
- **용량 계획**: 현실적인 성능 데이터로 용량 계획 정보 제공
- **성능 검증**: 시나리오 전반에서 성능 요구사항 검증

**구현 전략**:
- **자동화된 테스팅**: 시나리오 기반 성능 테스팅 자동화
- **환경 일관성**: 일관된 테스팅 환경 보장
- **데이터 수집**: 모든 시나리오에서 포괄적인 데이터 수집
- **분석 및 보고**: 시나리오 결과의 상세한 분석 및 보고 제공

```swift
// 다양한 조건에서 성능 테스트
func profileUnderLoad() async {
    PerformanceMonitor.shared.startProfiling("load_test")

    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<100 {
            group.addTask {
                // 동시 사용 시뮬레이션
                _ = WeaveDI.Container.shared.resolve(HeavyService.self)
            }
        }
    }

    let report = PerformanceMonitor.shared.stopProfiling("load_test")
    print("부하 테스트 결과: \(report)")
}
```

## 참고 자료

- [디버깅 도구 API](./debuggingTools.md) - 개발 및 디버깅 유틸리티
- [성능 최적화 가이드](../tutorial/performanceOptimization.md) - 최적화 전략
- [테스팅 가이드](../tutorial/testing.md) - 성능 테스팅 패턴