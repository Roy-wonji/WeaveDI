import Foundation
import DiContainer
import LogMacro

// MARK: - 운영 모니터링 및 개선 전략

/// 프로덕션 환경에서 DI 컨테이너의 성능과 안정성을 모니터링하고
/// 지속적으로 개선하기 위한 고급 모니터링 시스템을 구현합니다.

// MARK: - 메트릭 수집 시스템

/// 의존성 주입 관련 메트릭들을 수집하고 분석하는 시스템
final class DIMetricsCollector: @unchecked Sendable {
    private let queue = DispatchQueue(label: "DIMetricsCollector", attributes: .concurrent)

    // 메트릭 데이터
    private var _resolutionMetrics: [String: ResolutionMetrics] = [:]
    private var _systemMetrics: SystemMetrics = SystemMetrics()
    private var _alertThresholds: AlertThresholds = AlertThresholds()

    /// 의존성 해결 메트릭을 기록합니다
    func recordResolution<T>(
        type: T.Type,
        executionTime: TimeInterval,
        success: Bool,
        cacheHit: Bool = false,
        memoryUsage: Int64? = nil
    ) {
        let typeName = String(describing: type)

        queue.async(flags: .barrier) {
            if self._resolutionMetrics[typeName] == nil {
                self._resolutionMetrics[typeName] = ResolutionMetrics(typeName: typeName)
            }

            self._resolutionMetrics[typeName]?.addResolution(
                executionTime: executionTime,
                success: success,
                cacheHit: cacheHit,
                memoryUsage: memoryUsage
            )

            self._systemMetrics.totalResolutions += 1
            if success {
                self._systemMetrics.successfulResolutions += 1
            }
            if cacheHit {
                self._systemMetrics.cacheHits += 1
            }

            // 알림 임계값 확인
            self.checkAlerts(for: typeName, metrics: self._resolutionMetrics[typeName]!)
        }

        #logInfo("📊 메트릭 기록: \(typeName) - \(String(format: "%.3f", executionTime * 1000))ms (성공: \(success))")
    }

    /// 시스템 메트릭을 업데이트합니다
    func updateSystemMetrics(
        memoryUsage: Int64? = nil,
        cpuUsage: Double? = nil,
        activeThreads: Int? = nil
    ) {
        queue.async(flags: .barrier) {
            if let memory = memoryUsage {
                self._systemMetrics.currentMemoryUsage = memory
                self._systemMetrics.peakMemoryUsage = max(self._systemMetrics.peakMemoryUsage, memory)
            }

            if let cpu = cpuUsage {
                self._systemMetrics.currentCpuUsage = cpu
                self._systemMetrics.peakCpuUsage = max(self._systemMetrics.peakCpuUsage, cpu)
            }

            if let threads = activeThreads {
                self._systemMetrics.activeThreads = threads
            }

            self._systemMetrics.lastUpdateTime = Date()
        }
    }

    /// 성능 리포트를 생성합니다
    func generatePerformanceReport() -> PerformanceReport {
        return queue.sync {
            let topSlowest = Array(_resolutionMetrics.values
                .sorted { $0.averageExecutionTime > $1.averageExecutionTime }
                .prefix(5))

            let topMostUsed = Array(_resolutionMetrics.values
                .sorted { $0.totalCount > $1.totalCount }
                .prefix(5))

            let topErrorProne = Array(_resolutionMetrics.values
                .filter { $0.errorRate > 0.01 } // 1% 이상
                .sorted { $0.errorRate > $1.errorRate }
                .prefix(5))

            return PerformanceReport(
                systemMetrics: _systemMetrics,
                topSlowest: topSlowest,
                topMostUsed: topMostUsed,
                topErrorProne: topErrorProne,
                overallSuccessRate: _systemMetrics.successRate,
                overallCacheHitRate: _systemMetrics.cacheHitRate,
                reportGeneratedAt: Date()
            )
        }
    }

    private func checkAlerts(for typeName: String, metrics: ResolutionMetrics) {
        // 성능 임계값 확인
        if metrics.averageExecutionTime > _alertThresholds.slowResolutionThreshold {
            triggerAlert(.slowResolution(typeName: typeName, avgTime: metrics.averageExecutionTime))
        }

        // 에러율 임계값 확인
        if metrics.errorRate > _alertThresholds.highErrorRateThreshold {
            triggerAlert(.highErrorRate(typeName: typeName, errorRate: metrics.errorRate))
        }

        // 메모리 사용량 임계값 확인
        if let avgMemory = metrics.averageMemoryUsage,
           avgMemory > _alertThresholds.highMemoryUsageThreshold {
            triggerAlert(.highMemoryUsage(typeName: typeName, avgMemory: avgMemory))
        }
    }

    private func triggerAlert(_ alert: DIAlert) {
        #logWarning("🚨 DI 알림: \(alert.description)")
        // 실제 구현에서는 외부 모니터링 시스템으로 알림 전송
    }
}

// MARK: - 메트릭 데이터 구조

struct ResolutionMetrics {
    let typeName: String
    private(set) var totalCount: Int = 0
    private(set) var successCount: Int = 0
    private(set) var cacheHitCount: Int = 0
    private(set) var totalExecutionTime: TimeInterval = 0.0
    private(set) var executionTimes: [TimeInterval] = []
    private(set) var memoryUsages: [Int64] = []

    var errorRate: Double {
        totalCount > 0 ? Double(totalCount - successCount) / Double(totalCount) : 0.0
    }

    var averageExecutionTime: TimeInterval {
        totalCount > 0 ? totalExecutionTime / Double(totalCount) : 0.0
    }

    var cacheHitRate: Double {
        totalCount > 0 ? Double(cacheHitCount) / Double(totalCount) : 0.0
    }

    var averageMemoryUsage: Int64? {
        memoryUsages.isEmpty ? nil : memoryUsages.reduce(0, +) / Int64(memoryUsages.count)
    }

    mutating func addResolution(
        executionTime: TimeInterval,
        success: Bool,
        cacheHit: Bool,
        memoryUsage: Int64?
    ) {
        totalCount += 1
        totalExecutionTime += executionTime
        executionTimes.append(executionTime)

        if success {
            successCount += 1
        }

        if cacheHit {
            cacheHitCount += 1
        }

        if let memory = memoryUsage {
            memoryUsages.append(memory)
        }

        // 최근 1000개 항목만 유지
        if executionTimes.count > 1000 {
            let removedTime = executionTimes.removeFirst()
            totalExecutionTime -= removedTime
        }

        if memoryUsages.count > 1000 {
            memoryUsages.removeFirst()
        }
    }
}

struct SystemMetrics {
    var totalResolutions: Int = 0
    var successfulResolutions: Int = 0
    var cacheHits: Int = 0
    var currentMemoryUsage: Int64 = 0
    var peakMemoryUsage: Int64 = 0
    var currentCpuUsage: Double = 0.0
    var peakCpuUsage: Double = 0.0
    var activeThreads: Int = 0
    var lastUpdateTime: Date = Date()

    var successRate: Double {
        totalResolutions > 0 ? Double(successfulResolutions) / Double(totalResolutions) : 0.0
    }

    var cacheHitRate: Double {
        totalResolutions > 0 ? Double(cacheHits) / Double(totalResolutions) : 0.0
    }
}

struct AlertThresholds {
    let slowResolutionThreshold: TimeInterval = 0.1 // 100ms
    let highErrorRateThreshold: Double = 0.05 // 5%
    let highMemoryUsageThreshold: Int64 = 100 * 1024 * 1024 // 100MB
}

enum DIAlert {
    case slowResolution(typeName: String, avgTime: TimeInterval)
    case highErrorRate(typeName: String, errorRate: Double)
    case highMemoryUsage(typeName: String, avgMemory: Int64)

    var description: String {
        switch self {
        case .slowResolution(let type, let time):
            return "느린 해결: \(type) - 평균 \(String(format: "%.0f", time * 1000))ms"
        case .highErrorRate(let type, let rate):
            return "높은 에러율: \(type) - \(String(format: "%.1f", rate * 100))%"
        case .highMemoryUsage(let type, let memory):
            return "높은 메모리 사용: \(type) - 평균 \(memory / 1024 / 1024)MB"
        }
    }
}

struct PerformanceReport {
    let systemMetrics: SystemMetrics
    let topSlowest: [ResolutionMetrics]
    let topMostUsed: [ResolutionMetrics]
    let topErrorProne: [ResolutionMetrics]
    let overallSuccessRate: Double
    let overallCacheHitRate: Double
    let reportGeneratedAt: Date
}

// MARK: - 자동 최적화 시스템

/// 메트릭을 기반으로 자동으로 최적화 제안을 생성하는 시스템
final class DIAutoOptimizer {
    private let metricsCollector: DIMetricsCollector

    init(metricsCollector: DIMetricsCollector) {
        self.metricsCollector = metricsCollector
    }

    /// 최적화 제안을 생성합니다
    func generateOptimizationSuggestions() -> [OptimizationSuggestion] {
        let report = metricsCollector.generatePerformanceReport()
        var suggestions: [OptimizationSuggestion] = []

        // 1. 느린 해결 타입들에 대한 싱글톤 제안
        for metrics in report.topSlowest {
            if metrics.averageExecutionTime > 0.05 && metrics.cacheHitRate < 0.5 {
                suggestions.append(.applySingleton(
                    typeName: metrics.typeName,
                    currentAvgTime: metrics.averageExecutionTime,
                    expectedImprovement: "해결 시간 \(String(format: "%.0f", metrics.averageExecutionTime * 1000))ms → 1ms"
                ))
            }
        }

        // 2. 자주 사용되는 타입들에 대한 캐싱 제안
        for metrics in report.topMostUsed {
            if metrics.totalCount > 100 && metrics.cacheHitRate < 0.8 {
                suggestions.append(.enableCaching(
                    typeName: metrics.typeName,
                    currentHitRate: metrics.cacheHitRate,
                    usage: metrics.totalCount
                ))
            }
        }

        // 3. 에러가 많은 타입들에 대한 Fallback 제안
        for metrics in report.topErrorProne {
            suggestions.append(.addFallbackStrategy(
                typeName: metrics.typeName,
                errorRate: metrics.errorRate,
                suggestion: "기본값 또는 Mock 구현 등록 고려"
            ))
        }

        // 4. 시스템 전체 최적화 제안
        if report.overallCacheHitRate < 0.6 {
            suggestions.append(.improveOverallCaching(
                currentHitRate: report.overallCacheHitRate,
                suggestion: "전역 캐시 정책 검토 필요"
            ))
        }

        if report.systemMetrics.peakMemoryUsage > 500 * 1024 * 1024 { // 500MB
            suggestions.append(.optimizeMemoryUsage(
                peakUsage: report.systemMetrics.peakMemoryUsage,
                suggestion: "스코프 기반 생명주기 관리 강화"
            ))
        }

        return suggestions
    }
}

enum OptimizationSuggestion {
    case applySingleton(typeName: String, currentAvgTime: TimeInterval, expectedImprovement: String)
    case enableCaching(typeName: String, currentHitRate: Double, usage: Int)
    case addFallbackStrategy(typeName: String, errorRate: Double, suggestion: String)
    case improveOverallCaching(currentHitRate: Double, suggestion: String)
    case optimizeMemoryUsage(peakUsage: Int64, suggestion: String)

    var description: String {
        switch self {
        case .applySingleton(let type, _, let improvement):
            return "💡 싱글톤 적용: \(type) - \(improvement)"
        case .enableCaching(let type, let rate, let usage):
            return "💾 캐싱 활성화: \(type) - 현재 \(String(format: "%.1f", rate * 100))% 히트율, \(usage)회 사용"
        case .addFallbackStrategy(let type, let error, let suggestion):
            return "🛡️ Fallback 전략: \(type) - 에러율 \(String(format: "%.1f", error * 100))%, \(suggestion)"
        case .improveOverallCaching(let rate, let suggestion):
            return "🚀 전체 캐싱 개선: 현재 \(String(format: "%.1f", rate * 100))% - \(suggestion)"
        case .optimizeMemoryUsage(let peak, let suggestion):
            return "🧠 메모리 최적화: 최대 사용량 \(peak / 1024 / 1024)MB - \(suggestion)"
        }
    }

    var priority: OptimizationPriority {
        switch self {
        case .applySingleton:
            return .medium
        case .enableCaching:
            return .low
        case .addFallbackStrategy:
            return .high
        case .improveOverallCaching:
            return .medium
        case .optimizeMemoryUsage:
            return .high
        }
    }
}

enum OptimizationPriority: Int, Comparable {
    case low = 1
    case medium = 2
    case high = 3

    static func < (lhs: OptimizationPriority, rhs: OptimizationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - 로깅 및 추적 시스템

/// DI 관련 상세 로그를 관리하는 시스템
final class DILogger {
    enum LogLevel: Int, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3

        static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    private var currentLevel: LogLevel = .info
    private var logHandlers: [(LogLevel, String, String) -> Void] = []

    func setLogLevel(_ level: LogLevel) {
        currentLevel = level
        #logInfo("📝 DI 로그 레벨 설정: \(level)")
    }

    func addLogHandler(_ handler: @escaping (LogLevel, String, String) -> Void) {
        logHandlers.append(handler)
    }

    func log(_ level: LogLevel, category: String, message: String) {
        guard level >= currentLevel else { return }

        let logMessage = "[\(category)] \(message)"

        for handler in logHandlers {
            handler(level, category, logMessage)
        }

        // 기본 콘솔 출력
        let emoji = level.emoji
        print("\(emoji) \(logMessage)")
    }

    func logResolution<T>(_ type: T.Type, duration: TimeInterval, context: String = "") {
        log(.debug, category: "RESOLUTION",
            message: "\(type) resolved in \(String(format: "%.3f", duration * 1000))ms \(context)")
    }

    func logRegistration<T>(_ type: T.Type, scope: String? = nil) {
        let scopeInfo = scope.map { " (scope: \($0))" } ?? ""
        log(.info, category: "REGISTRATION", message: "\(type) registered\(scopeInfo)")
    }

    func logError<T>(_ type: T.Type, error: Error) {
        log(.error, category: "ERROR", message: "Failed to resolve \(type): \(error.localizedDescription)")
    }
}

private extension DILogger.LogLevel {
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}

// MARK: - DI 컨테이너 모니터링 확장

extension DIContainer {
    /// 운영 모니터링 시스템을 설정합니다
    func setupOperationalMonitoring() {
        let metricsCollector = DIMetricsCollector()
        let optimizer = DIAutoOptimizer(metricsCollector: metricsCollector)
        let logger = DILogger()

        // 외부 모니터링 시스템으로 로그 전송
        logger.addLogHandler { level, category, message in
            if level >= .warning {
                // 실제 구현에서는 Sentry, DataDog 등으로 전송
                #logWarning("📡 외부 모니터링으로 전송: \(message)")
            }
        }

        registerSingleton(DIMetricsCollector.self) { metricsCollector }
        registerSingleton(DIAutoOptimizer.self) { optimizer }
        registerSingleton(DILogger.self) { logger }

        #logInfo("📊 운영 모니터링 시스템 설정 완료")
    }

    /// 메트릭과 함께 의존성을 해결합니다
    func resolveWithMetrics<T>(_ type: T.Type, context: String = "") -> T? {
        let startTime = Date()
        let logger: DILogger = resolve()

        do {
            let instance: T = resolve()
            let duration = Date().timeIntervalSince(startTime)

            logger.logResolution(type, duration: duration, context: context)

            let metricsCollector: DIMetricsCollector = resolve()
            metricsCollector.recordResolution(
                type: type,
                executionTime: duration,
                success: true,
                memoryUsage: getCurrentMemoryUsage()
            )

            return instance
        } catch {
            let duration = Date().timeIntervalSince(startTime)

            logger.logError(type, error: error)

            let metricsCollector: DIMetricsCollector = resolve()
            metricsCollector.recordResolution(
                type: type,
                executionTime: duration,
                success: false
            )

            return nil
        }
    }

    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
}

// MARK: - 모니터링 데모

final class OperationalMonitoringDemo {
    private let container = DIContainer()

    init() {
        container.setupOperationalMonitoring()
        setupDemoServices()
    }

    private func setupDemoServices() {
        // 다양한 성능 특성을 가진 서비스들
        container.register(String.self, name: "fast") {
            Thread.sleep(forTimeInterval: 0.001) // 1ms
            return "Fast Service"
        }

        container.register(String.self, name: "slow") {
            Thread.sleep(forTimeInterval: 0.1) // 100ms
            return "Slow Service"
        }

        container.register(String.self, name: "unreliable") {
            if Int.random(in: 1...10) <= 3 { // 30% 실패율
                throw NSError(domain: "Demo", code: 500, userInfo: [NSLocalizedDescriptionKey: "Random failure"])
            }
            return "Unreliable Service"
        }
    }

    func demonstrateOperationalMonitoring() async {
        #logInfo("🎬 운영 모니터링 데모 시작")

        await simulateTrafficPatterns()
        generatePerformanceReport()
        showOptimizationSuggestions()
        demonstrateLogging()

        #logInfo("🎉 운영 모니터링 데모 완료")
    }

    private func simulateTrafficPatterns() async {
        #logInfo("\n1️⃣ 트래픽 패턴 시뮬레이션")

        // 다양한 사용 패턴으로 메트릭 수집
        for _ in 1...50 {
            _ = container.resolveWithMetrics(String.self, name: "fast", context: "normal_traffic")
        }

        for _ in 1...10 {
            _ = container.resolveWithMetrics(String.self, name: "slow", context: "heavy_computation")
        }

        for _ in 1...20 {
            _ = container.resolveWithMetrics(String.self, name: "unreliable", context: "external_api")
        }

        // 시스템 메트릭 업데이트
        let metricsCollector: DIMetricsCollector = container.resolve()
        metricsCollector.updateSystemMetrics(
            memoryUsage: getCurrentMemoryUsage(),
            cpuUsage: Double.random(in: 10...80),
            activeThreads: Int.random(in: 5...20)
        )
    }

    private func generatePerformanceReport() {
        #logInfo("\n2️⃣ 성능 리포트 생성")

        let metricsCollector: DIMetricsCollector = container.resolve()
        let report = metricsCollector.generatePerformanceReport()

        #logInfo("📊 성능 리포트:")
        #logInfo("- 전체 해결 횟수: \(report.systemMetrics.totalResolutions)")
        #logInfo("- 성공률: \(String(format: "%.1f", report.overallSuccessRate * 100))%")
        #logInfo("- 캐시 히트율: \(String(format: "%.1f", report.overallCacheHitRate * 100))%")
        #logInfo("- 현재 메모리 사용량: \(report.systemMetrics.currentMemoryUsage / 1024 / 1024)MB")

        if !report.topSlowest.isEmpty {
            #logInfo("🐌 가장 느린 타입들:")
            for metrics in report.topSlowest {
                #logInfo("  - \(metrics.typeName): \(String(format: "%.0f", metrics.averageExecutionTime * 1000))ms")
            }
        }

        if !report.topErrorProne.isEmpty {
            #logInfo("⚠️ 에러가 많은 타입들:")
            for metrics in report.topErrorProne {
                #logInfo("  - \(metrics.typeName): \(String(format: "%.1f", metrics.errorRate * 100))% 에러율")
            }
        }
    }

    private func showOptimizationSuggestions() {
        #logInfo("\n3️⃣ 최적화 제안")

        let optimizer: DIAutoOptimizer = container.resolve()
        let suggestions = optimizer.generateOptimizationSuggestions()

        if suggestions.isEmpty {
            #logInfo("현재 최적화 제안이 없습니다. 성능이 양호합니다! ✅")
        } else {
            #logInfo("💡 최적화 제안들:")
            let sortedSuggestions = suggestions.sorted { $0.priority > $1.priority }
            for suggestion in sortedSuggestions {
                #logInfo("  - \(suggestion.description)")
            }
        }
    }

    private func demonstrateLogging() {
        #logInfo("\n4️⃣ 상세 로깅 데모")

        let logger: DILogger = container.resolve()
        logger.setLogLevel(.debug)

        // 다양한 로그 레벨 테스트
        logger.log(.debug, category: "DEMO", message: "디버그 메시지")
        logger.log(.info, category: "DEMO", message: "정보 메시지")
        logger.log(.warning, category: "DEMO", message: "경고 메시지")
        logger.log(.error, category: "DEMO", message: "에러 메시지")
    }

    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - 운영 모니터링 데모

enum OperationalMonitoringExample {
    static func demonstrateOperationalMonitoring() async {
        #logInfo("🎬 운영 모니터링 및 개선 전략 데모 시작")

        let demo = OperationalMonitoringDemo()
        await demo.demonstrateOperationalMonitoring()

        #logInfo("🎉 운영 모니터링 및 개선 전략 데모 완료")
    }
}