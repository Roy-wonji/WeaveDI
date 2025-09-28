# Performance Monitoring API

WeaveDI provides comprehensive performance monitoring tools to help you optimize dependency injection performance and identify bottlenecks in your application.

## Overview

The performance monitoring system tracks dependency resolution times, memory usage, and registration patterns to provide insights into your DI container's performance characteristics.

```swift
import WeaveDI

// Enable performance monitoring
PerformanceMonitor.shared.enable()

// Monitor specific operations
let metrics = await PerformanceMonitor.shared.measureResolution {
    let service = DIContainer.shared.resolve(ExpensiveService.self)
    return service
}

print("Resolution took \(metrics.duration)ms")
print("Memory used: \(metrics.memoryDelta) bytes")
```

## Core Monitoring Features

### Resolution Performance Tracking

```swift
// Automatic resolution timing
class PerformanceAwareService {
    @Inject var userService: UserService?
    @Inject var dataService: DataService?

    func performOperation() async {
        // Monitor will automatically track these resolutions
        userService?.loadUser()
        dataService?.processData()

        // Get performance report
        let report = PerformanceMonitor.shared.getResolutionReport()
        print("Recent resolutions: \(report.recentResolutions)")
        print("Average resolution time: \(report.averageResolutionTime)ms")
    }
}
```

### Memory Usage Monitoring

```swift
// Monitor memory consumption
class MemoryAwareBootstrap {
    static func setupWithMonitoring() async {
        let initialMemory = PerformanceMonitor.shared.getCurrentMemoryUsage()

        await DIContainer.bootstrap { container in
            // Register many services
            for i in 0..<1000 {
                container.register(TestService.self, name: "service_\(i)") {
                    TestServiceImpl(id: i)
                }
            }
        }

        let finalMemory = PerformanceMonitor.shared.getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory

        print("DI setup memory usage: \(memoryIncrease) bytes")
        print("Memory per service: \(memoryIncrease / 1000) bytes")
    }
}
```

## Real-World Monitoring Examples

### CountApp Performance Monitoring

```swift
/// Performance-monitored counter with metrics collection
@MainActor
class MonitoredCounterViewModel: ObservableObject {
    @Published var count = 0
    @Published var performanceMetrics: PerformanceMetrics?

    @Inject var repository: CounterRepository?
    @Inject var logger: LoggerProtocol?

    func increment() async {
        let metrics = await PerformanceMonitor.shared.measureOperation("counter_increment") {
            // Measure the complete increment operation
            let startTime = CFAbsoluteTimeGetCurrent()

            count += 1
            await repository?.saveCount(count)

            let endTime = CFAbsoluteTimeGetCurrent()
            logger?.info("⏱️ Increment operation took \(String(format: "%.2f", (endTime - startTime) * 1000))ms")
        }

        // Update UI with performance data
        performanceMetrics = metrics

        // Log performance data
        logger?.info("📊 Performance: Resolution=\(metrics.resolutionTime)ms, Total=\(metrics.totalTime)ms")
    }

    func getPerformanceReport() -> String {
        let report = PerformanceMonitor.shared.getDetailedReport()
        return """
        📈 Counter Performance Report:
        - Total operations: \(report.operationCount)
        - Average resolution time: \(String(format: "%.2f", report.averageResolutionTime))ms
        - Peak memory usage: \(report.peakMemoryUsage) bytes
        - Cache hit rate: \(String(format: "%.1f", report.cacheHitRate * 100))%
        """
    }
}

/// Enhanced counter repository with performance tracking
class PerformanceTrackedCounterRepository: CounterRepository {
    @Inject var logger: LoggerProtocol?

    func getCurrentCount() async -> Int {
        return await PerformanceMonitor.shared.measureOperation("get_current_count") {
            let count = UserDefaults.standard.integer(forKey: "saved_count")
            logger?.debug("📊 Retrieved count: \(count)")
            return count
        }
    }

    func saveCount(_ count: Int) async {
        await PerformanceMonitor.shared.measureOperation("save_count") {
            UserDefaults.standard.set(count, forKey: "saved_count")
            logger?.debug("💾 Saved count: \(count)")
        }
    }

    func getCountHistory() async -> [CounterHistoryItem] {
        return await PerformanceMonitor.shared.measureOperation("get_count_history") {
            guard let data = UserDefaults.standard.data(forKey: "count_history"),
                  let history = try? JSONDecoder().decode([CounterHistoryItem].self, from: data) else {
                return []
            }
            logger?.debug("📜 Retrieved \(history.count) history items")
            return history
        }
    }

    func resetCount() async {
        await PerformanceMonitor.shared.measureOperation("reset_count") {
            UserDefaults.standard.set(0, forKey: "saved_count")
            logger?.debug("🔄 Count reset")
        }
    }
}
```

### WeatherApp Performance Monitoring

```swift
/// Weather service with comprehensive performance monitoring
class MonitoredWeatherService: WeatherServiceProtocol {
    @Inject var httpClient: HTTPClientProtocol?
    @Inject var cacheService: CacheServiceProtocol?
    @Inject var logger: LoggerProtocol?

    func fetchCurrentWeather(for city: String) async throws -> Weather {
        return try await PerformanceMonitor.shared.measureAsyncOperation("fetch_weather_\(city)") {
            let startTime = CFAbsoluteTimeGetCurrent()

            // Check cache first
            let cacheMetrics = await PerformanceMonitor.shared.measureOperation("cache_lookup") {
                return await cacheService?.retrieve(forKey: "weather_\(city)")
            }

            if let cachedWeather: Weather = cacheMetrics.result {
                let cacheTime = CFAbsoluteTimeGetCurrent() - startTime
                logger?.info("⚡ Cache hit for \(city) in \(String(format: "%.2f", cacheTime * 1000))ms")
                return cachedWeather
            }

            // Network fetch
            let networkMetrics = await PerformanceMonitor.shared.measureAsyncOperation("network_fetch") {
                guard let client = httpClient else {
                    throw WeatherError.httpClientNotAvailable
                }

                let url = buildWeatherURL(for: city)
                let data = try await client.fetchData(from: url)
                return try JSONDecoder().decode(Weather.self, from: data)
            }

            let weather: Weather = networkMetrics.result

            // Cache the result
            await PerformanceMonitor.shared.measureOperation("cache_store") {
                try? await cacheService?.store(weather, forKey: "weather_\(city)")
            }

            let totalTime = CFAbsoluteTimeGetCurrent() - startTime
            logger?.info("🌤️ Weather fetch for \(city) completed in \(String(format: "%.2f", totalTime * 1000))ms")

            return weather
        }
    }

    private func buildWeatherURL(for city: String) -> URL {
        return URL(string: "https://api.openweathermap.org/data/2.5/weather?q=\(city)&appid=test&units=metric")!
    }
}

/// Performance dashboard for weather app
class WeatherPerformanceDashboard {
    @Inject var logger: LoggerProtocol?

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
            recommendations.append("Consider optimizing dependency resolution - average time is high")
        }

        if report.memoryGrowthRate > 1024 * 1024 { // 1MB/hour
            recommendations.append("Memory usage is growing rapidly - check for memory leaks")
        }

        let cacheHitRate = calculateCacheHitRate(report.operations.filter { $0.name.contains("cache") })
        if cacheHitRate < 0.7 {
            recommendations.append("Cache hit rate is low (\(String(format: "%.1f", cacheHitRate * 100))%) - consider cache strategy optimization")
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
        🌤️ Weather App Performance Report
        ================================
        📊 Total weather requests: \(totalWeatherRequests)
        ⏱️ Average fetch time: \(String(format: "%.2f", averageWeatherFetchTime))ms
        📱 Cache hit rate: \(String(format: "%.1f", cacheHitRate * 100))%
        🌐 Network latency: \(String(format: "%.2f", networkLatency))ms
        💾 Memory usage: \(memoryUsage / 1024 / 1024)MB

        💡 Recommendations:
        \(recommendations.map { "• \($0)" }.joined(separator: "\n"))
        """
    }
}
```

## Advanced Monitoring Features

### Custom Metrics Collection

```swift
// Define custom metrics
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

### Performance Alerts System

```swift
protocol PerformanceAlert {
    var threshold: Double { get }
    var message: String { get }
    func shouldTrigger(for metrics: PerformanceReport) -> Bool
}

struct HighResolutionTimeAlert: PerformanceAlert {
    let threshold: Double = 50.0 // ms
    let message = "Dependency resolution time is above 50ms"

    func shouldTrigger(for metrics: PerformanceReport) -> Bool {
        return metrics.averageResolutionTime > threshold
    }
}

struct HighMemoryUsageAlert: PerformanceAlert {
    let threshold: Double = 100 * 1024 * 1024 // 100MB
    let message = "Memory usage is above 100MB"

    func shouldTrigger(for metrics: PerformanceReport) -> Bool {
        return Double(metrics.currentMemoryUsage) > threshold
    }
}

struct LowCacheHitRateAlert: PerformanceAlert {
    let threshold: Double = 0.5 // 50%
    let message = "Cache hit rate is below 50%"

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

    @Inject var logger: LoggerProtocol?

    func checkAlerts() {
        let report = PerformanceMonitor.shared.getDetailedReport()

        for alert in alerts {
            if alert.shouldTrigger(for: report) {
                logger?.warning("⚠️ Performance Alert: \(alert.message)")

                // Could send to analytics, crash reporting, etc.
                sendAlertToMonitoringService(alert)
            }
        }
    }

    private func sendAlertToMonitoringService(_ alert: PerformanceAlert) {
        // Implementation for external monitoring integration
    }
}
```

### Continuous Performance Monitoring

```swift
actor ContinuousMonitor {
    private var isRunning = false
    private let checkInterval: TimeInterval = 30.0 // 30 seconds

    @Inject var logger: LoggerProtocol?

    func start() async {
        guard !isRunning else { return }
        isRunning = true

        logger?.info("🔄 Starting continuous performance monitoring")

        while isRunning {
            await performHealthCheck()
            try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
        }
    }

    func stop() {
        isRunning = false
        logger?.info("⏹️ Stopping continuous performance monitoring")
    }

    private func performHealthCheck() async {
        let report = PerformanceMonitor.shared.getDetailedReport()

        // Log key metrics
        logger?.debug("""
        📊 Performance Health Check:
        - Resolution time: \(String(format: "%.2f", report.averageResolutionTime))ms
        - Memory usage: \(report.currentMemoryUsage / 1024 / 1024)MB
        - Cache hit rate: \(String(format: "%.1f", calculateOverallCacheHitRate(report) * 100))%
        """)

        // Check for performance degradation
        await checkForPerformanceDegradation(report)

        // Run alerts
        let alertManager = PerformanceAlertManager()
        alertManager.checkAlerts()
    }

    private func calculateOverallCacheHitRate(_ report: PerformanceReport) -> Double {
        let cacheOps = report.operations.filter { $0.name.contains("cache") }
        let hits = cacheOps.filter { $0.metadata["hit"] as? Bool == true }.count
        return cacheOps.isEmpty ? 1.0 : Double(hits) / Double(cacheOps.count)
    }

    private func checkForPerformanceDegradation(_ current: PerformanceReport) async {
        // Compare with historical data to detect degradation
        let historical = PerformanceMonitor.shared.getHistoricalBaseline()

        if current.averageResolutionTime > historical.averageResolutionTime * 1.5 {
            logger?.warning("⚠️ Resolution time degradation detected: \(String(format: "%.2f", current.averageResolutionTime))ms vs baseline \(String(format: "%.2f", historical.averageResolutionTime))ms")
        }

        if current.currentMemoryUsage > Int64(Double(historical.averageMemoryUsage) * 1.3) {
            logger?.warning("⚠️ Memory usage increase detected: \(current.currentMemoryUsage / 1024 / 1024)MB vs baseline \(historical.averageMemoryUsage / 1024 / 1024)MB")
        }
    }
}
```

## Performance Optimization Recommendations

### Dependency Resolution Optimization

```swift
class OptimizedDependencyManager {
    // Cache frequently resolved dependencies
    private var resolutionCache: [String: Any] = [:]
    private let cacheQueue = DispatchQueue(label: "resolution-cache", attributes: .concurrent)

    func getOptimizedService<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)

        return cacheQueue.sync {
            if let cached = resolutionCache[key] as? T {
                PerformanceMonitor.shared.recordCacheHit(key)
                return cached
            }

            // Resolve and cache
            guard let service = DIContainer.shared.resolve(type) else { return nil }

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

### Memory Usage Optimization

```swift
class MemoryOptimizedContainer {
    private weak var container: DIContainer?

    init(container: DIContainer) {
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
        // Clear caches, release non-essential services
        PerformanceMonitor.shared.recordMemoryWarning()

        // Clear internal caches
        container?.clearInternalCaches()

        // Log memory state
        let currentMemory = PerformanceMonitor.shared.getCurrentMemoryUsage()
        print("💾 Memory warning - current usage: \(currentMemory / 1024 / 1024)MB")
    }
}
```

## Integration with Development Tools

### Xcode Instruments Integration

```swift
class InstrumentsIntegration {
    static func startProfiling() {
        #if DEBUG
        // Enable detailed logging for Instruments
        PerformanceMonitor.shared.enableInstrumentsMode()

        // Add custom signposts
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

### Performance Testing Integration

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
            _ = DIContainer.shared.resolve(TestService.self)
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let avgTime = (endTime - startTime) / Double(iterations) * 1000

        print("📊 Resolution Performance: \(String(format: "%.4f", avgTime))ms per resolution")
        assert(avgTime < 1.0, "Resolution time too high: \(avgTime)ms")
    }

    private func testMemoryUsage() async {
        let initialMemory = PerformanceMonitor.shared.getCurrentMemoryUsage()

        // Register many services
        for i in 0..<10000 {
            DIContainer.shared.register(TestService.self, name: "test_\(i)") {
                TestServiceImpl()
            }
        }

        let finalMemory = PerformanceMonitor.shared.getCurrentMemoryUsage()
        let memoryPerService = (finalMemory - initialMemory) / 10000

        print("💾 Memory per service: \(memoryPerService) bytes")
        assert(memoryPerService < 1024, "Memory usage per service too high: \(memoryPerService) bytes")
    }
}
```

## Best Practices

### 1. Enable Monitoring Early

```swift
@main
struct App: App {
    init() {
        // Enable monitoring at app start
        PerformanceMonitor.shared.enable()
        PerformanceMonitor.shared.setLogLevel(.info)
    }
}
```

### 2. Monitor Critical Paths

```swift
// Monitor performance-critical operations
func performCriticalOperation() async {
    await PerformanceMonitor.shared.measureOperation("critical_path") {
        // Your critical code here
    }
}
```

### 3. Set Up Automated Alerts

```swift
// Set up regular performance checks
Task {
    let continuousMonitor = ContinuousMonitor()
    await continuousMonitor.start()
}
```

### 4. Profile in Different Scenarios

```swift
// Test performance under different conditions
func profileUnderLoad() async {
    PerformanceMonitor.shared.startProfiling("load_test")

    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<100 {
            group.addTask {
                // Simulate concurrent usage
                _ = DIContainer.shared.resolve(HeavyService.self)
            }
        }
    }

    let report = PerformanceMonitor.shared.stopProfiling("load_test")
    print("Load test results: \(report)")
}
```

## See Also

- [Debugging Tools API](./debuggingTools.md) - Development and debugging utilities
- [Performance Optimization Guide](../tutorial/performanceOptimization.md) - Optimization strategies
- [Testing Guide](../tutorial/testing.md) - Performance testing patterns