# 성능 모니터링 API 참조

WeaveDI는 의존성 주입 시스템의 성능을 모니터링하고 최적화하기 위한 포괄적인 도구를 제공합니다. 이러한 도구들은 병목 현상을 식별하고, 해결 시간을 추적하며, 전반적인 애플리케이션 성능을 개선하는 데 도움이 됩니다.

## 개요

성능 모니터링 시스템은 의존성 해결 시간, 메모리 사용량, 그리고 컨테이너 효율성에 대한 실시간 메트릭을 제공합니다. 이는 프로덕션과 개발 환경 모두에서 성능 병목 현상을 식별하는 데 중요합니다.

```swift
import WeaveDI

// 성능 모니터링 활성화
WeaveDI.Container.enablePerformanceMonitoring()

// 메트릭 수집
class MyService {
    @Inject var logger: LoggerProtocol?

    func performOperation() {
        // 이 해결이 자동으로 추적됨
        logger?.info("작업 수행됨")
    }
}

// 성능 보고서 가져오기
let report = WeaveDI.Container.getPerformanceReport()
print("평균 해결 시간: \\(report.averageResolutionTime)ms")
```

## 핵심 성능 메트릭

### 해결 시간 추적

#### 기본 해결 성능

```swift
// 성능 추적 활성화
WeaveDI.Container.enablePerformanceMonitoring()

class PerformanceTracker {
    static func measureResolutionTime<T>(_ type: T.Type) -> TimeInterval {
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = WeaveDI.Container.resolve(type)
        let endTime = CFAbsoluteTimeGetCurrent()

        return endTime - startTime
    }

    static func benchmarkDependencies() {
        let dependencies: [Any.Type] = [
            LoggerProtocol.self,
            UserService.self,
            DatabaseService.self,
            NetworkService.self
        ]

        print("📊 의존성 해결 벤치마크:")
        for dependency in dependencies {
            let time = measureResolutionTime(dependency)
            print("  \\(dependency): \\(String(format: "%.3f", time * 1000))ms")
        }
    }
}
```

### 메모리 사용량 모니터링

#### 컨테이너 메모리 추적

```swift
extension WeaveDI.Container {
    static func getMemoryMetrics() -> MemoryMetrics {
        return MemoryMetrics(
            containerSize: getContainerMemoryUsage(),
            instanceCount: getActiveInstanceCount(),
            cachedDependencies: getCachedDependencyCount(),
            estimatedMemoryUsage: getEstimatedMemoryUsage()
        )
    }

    static func printMemoryReport() {
        let metrics = getMemoryMetrics()
        print("🧠 메모리 사용량 보고서:")
        print("  컨테이너 크기: \\(metrics.containerSize) bytes")
        print("  활성 인스턴스: \\(metrics.instanceCount)")
        print("  캐시된 의존성: \\(metrics.cachedDependencies)")
        print("  예상 메모리 사용량: \\(metrics.estimatedMemoryUsage) bytes")
    }
}

struct MemoryMetrics {
    let containerSize: Int
    let instanceCount: Int
    let cachedDependencies: Int
    let estimatedMemoryUsage: Int
}
```

## 튜토리얼의 실제 예제

### CountApp 성능 모니터링

우리 튜토리얼의 CountApp에 대한 포괄적인 성능 모니터링입니다:

```swift
/// CountApp을 위한 성능 모니터링 시스템
class CounterPerformanceMonitor {
    private static var metrics: [String: PerformanceMetric] = [:]
    private static let queue = DispatchQueue(label: "performance.monitor")

    static func initialize() {
        WeaveDI.Container.enablePerformanceMonitoring()
        setupCustomMetrics()
        schedulePeriodicReports()
    }

    private static func setupCustomMetrics() {
        // 카운터 특정 메트릭 설정
        registerMetric("counter.increment.time", description: "카운터 증가 시간")
        registerMetric("counter.repository.read", description: "레포지토리 읽기 시간")
        registerMetric("counter.repository.write", description: "레포지토리 쓰기 시간")
        registerMetric("counter.history.fetch", description: "히스토리 가져오기 시간")
    }

    static func trackOperation<T>(_ name: String, operation: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            recordMetric(name, duration: duration)
        }

        return try await operation()
    }

    static func recordMetric(_ name: String, duration: TimeInterval) {
        queue.async {
            if var metric = metrics[name] {
                metric.recordDuration(duration)
                metrics[name] = metric
            } else {
                var newMetric = PerformanceMetric(name: name)
                newMetric.recordDuration(duration)
                metrics[name] = newMetric
            }
        }
    }

    static func generateReport() -> PerformanceReport {
        return queue.sync {
            let containerReport = WeaveDI.Container.getPerformanceReport()
            let customMetrics = Array(metrics.values)

            return PerformanceReport(
                containerMetrics: containerReport,
                customMetrics: customMetrics,
                memoryMetrics: WeaveDI.Container.getMemoryMetrics(),
                timestamp: Date()
            )
        }
    }

    private static func schedulePeriodicReports() {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            printPerformanceReport()
        }
    }

    static func printPerformanceReport() {
        let report = generateReport()

        print("\\n📊 CountApp 성능 보고서 - \\(report.timestamp)")
        print("🏃‍♂️ 컨테이너 성능:")
        print("  총 해결 수: \\(report.containerMetrics.totalResolutions)")
        print("  평균 해결 시간: \\(String(format: "%.2f", report.containerMetrics.averageResolutionTime))ms")

        if let slowest = report.containerMetrics.slowestDependency {
            print("  가장 느린 의존성: \\(slowest.name) (\\(String(format: "%.2f", slowest.time))ms)")
        }

        print("\\n🎯 사용자 정의 메트릭:")
        for metric in report.customMetrics {
            print("  \\(metric.name):")
            print("    평균: \\(String(format: "%.2f", metric.averageDuration * 1000))ms")
            print("    최대: \\(String(format: "%.2f", metric.maxDuration * 1000))ms")
            print("    호출 수: \\(metric.callCount)")
        }

        print("\\n🧠 메모리 메트릭:")
        let memory = report.memoryMetrics
        print("  활성 인스턴스: \\(memory.instanceCount)")
        print("  메모리 사용량: \\(memory.estimatedMemoryUsage) bytes")
    }
}

/// 성능 추적이 향상된 CounterService
class CounterService {
    private let logger: LoggerProtocol
    private let repository: CounterRepository

    init(logger: LoggerProtocol, repository: CounterRepository) {
        self.logger = logger
        self.repository = repository
        logger.info("📊 CounterService 초기화됨 (성능 추적 활성)")
    }

    func increment() async -> Int {
        return await CounterPerformanceMonitor.trackOperation("counter.increment.time") {
            logger.debug("⬆️ 증가 작업 시작")

            let currentCount = await CounterPerformanceMonitor.trackOperation("counter.repository.read") {
                await repository.getCurrentCount()
            }

            let newCount = currentCount + 1

            await CounterPerformanceMonitor.trackOperation("counter.repository.write") {
                await repository.saveCount(newCount)
            }

            logger.info("📈 카운트가 \\(newCount)로 증가됨")
            return newCount
        }
    }

    func getCurrentCount() async -> Int {
        return await CounterPerformanceMonitor.trackOperation("counter.repository.read") {
            await repository.getCurrentCount()
        }
    }
}

/// 성능 모니터링이 있는 CounterHistoryService
class CounterHistoryService {
    private let repository: CounterRepository
    private let logger: LoggerProtocol

    init(repository: CounterRepository, logger: LoggerProtocol) {
        self.repository = repository
        self.logger = logger
    }

    func getRecentHistory(limit: Int = 10) async -> [CounterHistoryItem] {
        return await CounterPerformanceMonitor.trackOperation("counter.history.fetch") {
            logger.debug("📊 최근 히스토리 가져오는 중 (제한: \\(limit))")

            let allHistory = await repository.getCountHistory()
            let recentHistory = Array(allHistory.suffix(limit))

            logger.debug("📋 \\(recentHistory.count)개 히스토리 항목 반환됨")
            return recentHistory
        }
    }
}

/// 성능 메트릭이 있는 ViewModel
@MainActor
class CounterViewModel: ObservableObject {
    @Published var count = 0
    @Published var isLoading = false
    @Published var performanceMetrics: String = ""

    @Inject var counterService: CounterService?
    @Inject var historyService: CounterHistoryService?
    @Inject var logger: LoggerProtocol?

    init() {
        CounterPerformanceMonitor.initialize()

        Task {
            await loadInitialData()
            startPerformanceTracking()
        }
    }

    func increment() async {
        isLoading = true

        guard let service = counterService else {
            logger?.error("❌ CounterService 사용 불가")
            isLoading = false
            return
        }

        count = await service.increment()
        await updatePerformanceDisplay()

        isLoading = false
    }

    private func loadInitialData() async {
        guard let service = counterService else { return }
        count = await service.getCurrentCount()
    }

    private func startPerformanceTracking() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                await self.updatePerformanceDisplay()
            }
        }
    }

    private func updatePerformanceDisplay() async {
        let report = CounterPerformanceMonitor.generateReport()

        var displayText = "성능 메트릭:\\n"
        displayText += "해결 수: \\(report.containerMetrics.totalResolutions)\\n"
        displayText += "평균 시간: \\(String(format: "%.1f", report.containerMetrics.averageResolutionTime))ms\\n"
        displayText += "메모리: \\(report.memoryMetrics.estimatedMemoryUsage) bytes"

        performanceMetrics = displayText
    }
}
```

### WeatherApp 성능 최적화

```swift
/// WeatherApp을 위한 고급 성능 모니터링
class WeatherPerformanceOptimizer {
    private static var networkMetrics: [String: NetworkMetric] = [:]
    private static var cacheHitRates: [String: CacheMetric] = [:]

    static func initialize() {
        setupNetworkMonitoring()
        setupCacheMonitoring()
        enablePredictiveOptimization()
    }

    private static func setupNetworkMonitoring() {
        // 네트워크 요청 성능 추적
        NotificationCenter.default.addObserver(
            forName: .networkRequestStarted,
            object: nil,
            queue: nil
        ) { notification in
            if let url = notification.userInfo?["url"] as? String {
                startNetworkTracking(for: url)
            }
        }

        NotificationCenter.default.addObserver(
            forName: .networkRequestCompleted,
            object: nil,
            queue: nil
        ) { notification in
            if let url = notification.userInfo?["url"] as? String,
               let duration = notification.userInfo?["duration"] as? TimeInterval {
                recordNetworkMetric(url: url, duration: duration)
            }
        }
    }

    static func trackWeatherRequest<T>(
        city: String,
        operation: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()

        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            recordWeatherMetric(city: city, duration: duration)
        }

        return try await operation()
    }

    private static func recordWeatherMetric(city: String, duration: TimeInterval) {
        let key = "weather_\\(city)"

        if var metric = networkMetrics[key] {
            metric.addSample(duration)
            networkMetrics[key] = metric
        } else {
            networkMetrics[key] = NetworkMetric(name: key, duration: duration)
        }

        // 성능 임계값 확인
        if duration > 2.0 { // 2초 이상
            print("⚠️ 느린 날씨 요청 탐지: \\(city) (\\(String(format: "%.2f", duration))s)")
        }
    }

    static func getCacheEfficiencyReport() -> CacheEfficiencyReport {
        let totalRequests = cacheHitRates.values.reduce(0) { $0 + $1.totalRequests }
        let cacheHits = cacheHitRates.values.reduce(0) { $0 + $1.hits }
        let hitRate = totalRequests > 0 ? Double(cacheHits) / Double(totalRequests) : 0.0

        return CacheEfficiencyReport(
            totalRequests: totalRequests,
            cacheHits: cacheHits,
            hitRate: hitRate,
            recommendations: generateCacheRecommendations(hitRate: hitRate)
        )
    }

    private static func generateCacheRecommendations(hitRate: Double) -> [String] {
        var recommendations: [String] = []

        if hitRate < 0.5 {
            recommendations.append("캐시 만료 시간을 늘리는 것을 고려하세요")
            recommendations.append("더 나은 캐시 키 전략을 구현하세요")
        }

        if hitRate < 0.3 {
            recommendations.append("캐시 크기를 늘리세요")
            recommendations.append("프리페칭 전략을 구현하세요")
        }

        return recommendations
    }
}

/// 성능 최적화된 WeatherService
class OptimizedWeatherService: WeatherServiceProtocol {
    @Inject var httpClient: HTTPClientProtocol?
    @Inject var cache: CacheServiceProtocol?
    @Inject var logger: LoggerProtocol?

    private let backgroundQueue = DispatchQueue(label: "weather.background", qos: .utility)
    private var pendingRequests: [String: Task<Weather, Error>] = [:]

    func fetchCurrentWeather(for city: String) async throws -> Weather {
        return try await WeatherPerformanceOptimizer.trackWeatherRequest(city: city) {
            // 중복 요청 제거
            if let pendingTask = pendingRequests[city] {
                logger?.debug("🔄 \\(city)에 대한 진행 중인 요청에 연결")
                return try await pendingTask.value
            }

            // 새 요청 작업 생성
            let task = Task<Weather, Error> {
                defer { pendingRequests.removeValue(forKey: city) }
                return try await performWeatherFetch(for: city)
            }

            pendingRequests[city] = task
            return try await task.value
        }
    }

    private func performWeatherFetch(for city: String) async throws -> Weather {
        let cacheKey = "weather_\\(city)"

        // 캐시 확인 (성능 추적 포함)
        let cacheCheckStart = CFAbsoluteTimeGetCurrent()
        if let cachedWeather: Weather = try? await cache?.retrieve(forKey: cacheKey) {
            let cacheTime = CFAbsoluteTimeGetCurrent() - cacheCheckStart
            logger?.debug("💾 \\(city) 캐시 히트 (\\(String(format: "%.2f", cacheTime * 1000))ms)")
            WeatherPerformanceOptimizer.recordCacheHit(for: city)
            return cachedWeather
        }

        WeatherPerformanceOptimizer.recordCacheMiss(for: city)

        // 네트워크 요청
        guard let client = httpClient else {
            throw WeatherError.httpClientUnavailable
        }

        logger?.info("🌐 \\(city)의 새로운 날씨 데이터 가져오는 중")
        let weather = try await client.fetchWeather(for: city)

        // 백그라운드에서 캐시
        Task.detached(priority: .utility) {
            try? await self.cache?.store(weather, forKey: cacheKey)
        }

        return weather
    }

    func preloadWeatherData(for cities: [String]) async {
        logger?.info("🔄 \\(cities.count)개 도시의 날씨 데이터 미리 로드 중")

        await withTaskGroup(of: Void.self) { group in
            for city in cities {
                group.addTask {
                    try? await self.fetchCurrentWeather(for: city)
                }
            }
        }
    }
}
```

## 성능 알림 시스템

### 실시간 성능 경고

```swift
class PerformanceAlertSystem {
    private static var thresholds: [String: PerformanceThreshold] = [:]
    private static var alertHandlers: [(PerformanceAlert) -> Void] = []

    static func setThreshold(
        for metric: String,
        warningLevel: TimeInterval,
        criticalLevel: TimeInterval
    ) {
        thresholds[metric] = PerformanceThreshold(
            warningLevel: warningLevel,
            criticalLevel: criticalLevel
        )
    }

    static func addAlertHandler(_ handler: @escaping (PerformanceAlert) -> Void) {
        alertHandlers.append(handler)
    }

    static func checkPerformance(metric: String, value: TimeInterval) {
        guard let threshold = thresholds[metric] else { return }

        let alertLevel: AlertLevel
        if value >= threshold.criticalLevel {
            alertLevel = .critical
        } else if value >= threshold.warningLevel {
            alertLevel = .warning
        } else {
            return // 임계값 내
        }

        let alert = PerformanceAlert(
            metric: metric,
            value: value,
            level: alertLevel,
            timestamp: Date()
        )

        // 모든 핸들러에 알림
        alertHandlers.forEach { $0(alert) }
    }

    static func setupDefaultThresholds() {
        setThreshold(for: "dependency.resolution", warningLevel: 0.005, criticalLevel: 0.010) // 5ms/10ms
        setThreshold(for: "weather.api.request", warningLevel: 1.0, criticalLevel: 3.0) // 1s/3s
        setThreshold(for: "database.query", warningLevel: 0.100, criticalLevel: 0.500) // 100ms/500ms
    }
}

struct PerformanceThreshold {
    let warningLevel: TimeInterval
    let criticalLevel: TimeInterval
}

struct PerformanceAlert {
    let metric: String
    let value: TimeInterval
    let level: AlertLevel
    let timestamp: Date
}

enum AlertLevel {
    case warning
    case critical
}
```

### 자동 성능 최적화

```swift
class AutoPerformanceOptimizer {
    private static var optimizationRules: [OptimizationRule] = []

    static func initialize() {
        setupOptimizationRules()
        startMonitoring()
    }

    private static func setupOptimizationRules() {
        // 규칙 1: 느린 의존성 해결을 위한 캐싱
        addRule { metrics in
            if metrics.averageResolutionTime > 0.010 { // 10ms
                return .enableCaching("느린 해결을 위해 캐싱 활성화")
            }
            return nil
        }

        // 규칙 2: 높은 메모리 사용량에 대한 정리
        addRule { metrics in
            if metrics.memoryUsage > 50_000_000 { // 50MB
                return .performCleanup("높은 메모리 사용량으로 인한 정리")
            }
            return nil
        }

        // 규칙 3: 캐시 미스율이 높은 경우 프리로딩
        addRule { metrics in
            if metrics.cacheHitRate < 0.5 {
                return .enablePreloading("낮은 캐시 히트율로 인한 프리로딩")
            }
            return nil
        }
    }

    static func addRule(_ rule: @escaping (PerformanceMetrics) -> OptimizationAction?) {
        optimizationRules.append(rule)
    }

    private static func startMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            evaluateOptimizations()
        }
    }

    private static func evaluateOptimizations() {
        let currentMetrics = getCurrentMetrics()

        for rule in optimizationRules {
            if let action = rule(currentMetrics) {
                executeOptimization(action)
            }
        }
    }

    private static func executeOptimization(_ action: OptimizationAction) {
        switch action {
        case .enableCaching(let reason):
            print("🚀 최적화 실행: 캐싱 활성화 - \\(reason)")
            WeaveDI.Container.enableResolutionCaching()

        case .performCleanup(let reason):
            print("🧹 최적화 실행: 메모리 정리 - \\(reason)")
            WeaveDI.Container.performMemoryCleanup()

        case .enablePreloading(let reason):
            print("⚡ 최적화 실행: 프리로딩 활성화 - \\(reason)")
            enableSmartPreloading()
        }
    }
}

enum OptimizationAction {
    case enableCaching(String)
    case performCleanup(String)
    case enablePreloading(String)
}

typealias OptimizationRule = (PerformanceMetrics) -> OptimizationAction?
```

## 지속적인 성능 모니터링

### 성능 메트릭 내보내기

```swift
class PerformanceExporter {
    static func exportToCSV() -> String {
        let report = WeaveDI.Container.getPerformanceReport()
        var csv = "Timestamp,Metric,Value,Unit\\n"

        let timestamp = ISO8601DateFormatter().string(from: Date())

        csv += "\\(timestamp),TotalResolutions,\\(report.totalResolutions),count\\n"
        csv += "\\(timestamp),AverageResolutionTime,\\(report.averageResolutionTime),ms\\n"

        if let slowest = report.slowestDependency {
            csv += "\\(timestamp),SlowestDependency,\\(slowest.time),ms\\n"
        }

        return csv
    }

    static func exportToJSON() -> Data? {
        let report = WeaveDI.Container.getPerformanceReport()
        return try? JSONEncoder().encode(report)
    }

    static func schedulePeriodicExport(interval: TimeInterval = 300) { // 5분
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            let csv = exportToCSV()
            saveToFile(csv, filename: "performance_\\(Date().timeIntervalSince1970).csv")
        }
    }

    private static func saveToFile(_ content: String, filename: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                   in: .userDomainMask)[0]
        let filePath = documentsPath.appendingPathComponent(filename)

        try? content.write(to: filePath, atomically: true, encoding: .utf8)
    }
}
```

### 성능 대시보드

```swift
#if DEBUG
struct PerformanceDashboard: View {
    @State private var performanceData: PerformanceReport?
    @State private var isMonitoring = false
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let data = performanceData {
                        performanceSection(data)
                        memorySection(data.memoryMetrics)
                        alertsSection()
                    } else {
                        Text("성능 데이터 로드 중...")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("성능 대시보드")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isMonitoring ? "중지" : "시작") {
                        isMonitoring.toggle()
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            if isMonitoring {
                loadPerformanceData()
            }
        }
        .onAppear {
            loadPerformanceData()
        }
    }

    private func performanceSection(_ data: PerformanceReport) -> some View {
        GroupBox("해결 성능") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("총 해결 수")
                    Spacer()
                    Text("\\(data.containerMetrics.totalResolutions)")
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("평균 시간")
                    Spacer()
                    Text("\\(String(format: "%.2f", data.containerMetrics.averageResolutionTime))ms")
                        .fontWeight(.semibold)
                        .foregroundColor(data.containerMetrics.averageResolutionTime > 5.0 ? .red : .green)
                }

                if let slowest = data.containerMetrics.slowestDependency {
                    HStack {
                        Text("가장 느린 의존성")
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(slowest.name)
                                .font(.caption)
                            Text("\\(String(format: "%.2f", slowest.time))ms")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
    }

    private func memorySection(_ memory: MemoryMetrics) -> some View {
        GroupBox("메모리 사용량") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("활성 인스턴스")
                    Spacer()
                    Text("\\(memory.instanceCount)")
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("메모리 사용량")
                    Spacer()
                    Text("\\(ByteCountFormatter().string(fromByteCount: Int64(memory.estimatedMemoryUsage)))")
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func alertsSection() -> some View {
        GroupBox("최근 알림") {
            // 최근 성능 알림 표시
            Text("알림 없음")
                .foregroundColor(.secondary)
        }
    }

    private func loadPerformanceData() {
        performanceData = WeaveDI.Container.getPerformanceReport()
    }
}
#endif
```

## 모범 사례

### 1. 적절한 메트릭 수집

```swift
// ✅ 좋음 - 중요한 메트릭만 추적
WeaveDI.Container.trackMetric("critical.dependency.resolution")

// ❌ 피하기 - 과도한 메트릭 수집
WeaveDI.Container.trackAllResolutions() // 성능 오버헤드
```

### 2. 성능 임계값 설정

```swift
class PerformanceConfiguration {
    static func setupThresholds() {
        PerformanceAlertSystem.setThreshold(
            for: "dependency.resolution",
            warningLevel: 0.005, // 5ms
            criticalLevel: 0.010  // 10ms
        )
    }
}
```

### 3. 프로덕션 모니터링

```swift
#if !DEBUG
// 프로덕션에서는 경량 모니터링만
WeaveDI.Container.enableLightweightMonitoring()
#else
// 개발에서는 상세 모니터링
WeaveDI.Container.enableVerboseMonitoring()
#endif
```

### 4. 정기적인 보고서

```swift
class PerformanceReporting {
    static func scheduleReports() {
        // 일일 보고서
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
            generateDailyReport()
        }
    }

    private static func generateDailyReport() {
        let report = WeaveDI.Container.getPerformanceReport()
        // 보고서 생성 및 전송
    }
}
```

## 참고 자료

- [디버깅 도구 API](./debuggingTools.md) - 디버깅 도구
- [UnifiedDI API](./unifiedDI.md) - 간소화된 DI 인터페이스
- [Bootstrap API](./bootstrap.md) - 컨테이너 초기화
- [테스팅 가이드](../tutorial/testing.md) - 성능 테스팅 전략