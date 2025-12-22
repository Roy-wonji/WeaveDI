import Foundation
import WeaveDICore
import WeaveDINeedleCompat

/// DI 모니터링 설정
public struct DIMonitorConfiguration: Sendable {
    public let logLevel: DILogLevel
    public let logSeverityThreshold: DILogSeverity
    public let healthCheckInterval: TimeInterval
    public let enablePerformanceTracking: Bool
    public let enableAutoReporting: Bool
    public let reportingInterval: TimeInterval

    public init(
        logLevel: DILogLevel = .errorsOnly,
        logSeverityThreshold: DILogSeverity = .info,
        healthCheckInterval: TimeInterval = 300,  // 5분
        enablePerformanceTracking: Bool = false,
        enableAutoReporting: Bool = false,
        reportingInterval: TimeInterval = 1800    // 30분
    ) {
        self.logLevel = logLevel
        self.logSeverityThreshold = logSeverityThreshold
        self.healthCheckInterval = healthCheckInterval
        self.enablePerformanceTracking = enablePerformanceTracking
        self.enableAutoReporting = enableAutoReporting
        self.reportingInterval = reportingInterval
    }
}

/// DI 모니터링 이벤트
public enum DIMonitorEvent: Sendable {
    case healthCheckCompleted(DIHealthStatus)
    case performanceThresholdExceeded(operation: String, duration: TimeInterval)
    case criticalError(message: String)
    case warningDetected(message: String)
    case systemStarted
    case systemStopped
}

/// DI 모니터링 리포트
public struct DIMonitorReport: Sendable {
    public let timestamp: Date
    public let period: TimeInterval
    public let healthStatus: DIHealthStatus
    public let logSummary: DILogSummary
    public let recommendations: [String]
}

/// 로그 요약 정보
public struct DILogSummary: Sendable {
    public let totalLogs: Int
    public let errorCount: Int
    public let warningCount: Int
    public let infoCount: Int
    public let debugCount: Int
    public let channelBreakdown: [DILogChannel: Int]
}

/// DI 통합 모니터링 시스템 - 로깅과 헬스체크를 통합 관리
@MainActor
public class DIMonitor: ObservableObject {

    public static let shared = DIMonitor()

    // MARK: - Published Properties

    @Published public private(set) var isMonitoring = false
    @Published public private(set) var configuration: DIMonitorConfiguration
    @Published public private(set) var lastHealthStatus: DIHealthStatus?
    @Published public private(set) var lastReport: DIMonitorReport?

    // MARK: - Private Properties

    private var monitoringTask: Task<Void, Never>?
    private var reportingTask: Task<Void, Never>?
    private var eventHandlers: [(DIMonitorEvent) -> Void] = []

    // 로그 통계 추적
    private var logCounts: [DILogSeverity: Int] = [:]
    private var channelCounts: [DILogChannel: Int] = [:]
    private var startTime: Date?

    private init() {
        #if DEBUG
        self.configuration = DIMonitorConfiguration(
            logLevel: .all,
            logSeverityThreshold: .debug,
            healthCheckInterval: 60,        // 1분
            enablePerformanceTracking: true,
            enableAutoReporting: true,
            reportingInterval: 300          // 5분
        )
        #elseif DEBUG
        self.configuration = DIMonitorConfiguration(
            logLevel: .errorsOnly,
            logSeverityThreshold: .warning,
            healthCheckInterval: 300,       // 5분
            enablePerformanceTracking: false,
            enableAutoReporting: false
        )
        #else
        self.configuration = DIMonitorConfiguration(
            logLevel: .off,
            logSeverityThreshold: .error,
            healthCheckInterval: 600,       // 10분
            enablePerformanceTracking: false,
            enableAutoReporting: false
        )
        #endif

        setupInitialConfiguration()
    }

    // MARK: - Public API

    /// 모니터링 시작
    public func startMonitoring(with config: DIMonitorConfiguration? = nil) {
        guard !isMonitoring else { return }

        if let config = config {
            self.configuration = config
            setupInitialConfiguration()
        }

        isMonitoring = true
        startTime = Date()
        resetCounters()

        // 헬스체크 모니터링 시작
        monitoringTask = Task {
            await DIHealthCheck.shared.startMonitoring(interval: configuration.healthCheckInterval)

            while !Task.isCancelled && isMonitoring {
                // 정기적인 헬스체크
                let healthStatus = await DIHealthCheck.shared.performHealthCheck()
                DispatchQueue.main.async {
                    self.lastHealthStatus = healthStatus
                    self.notifyEventHandlers(.healthCheckCompleted(healthStatus))
                }

                // 임계값 체크
                await checkThresholds(healthStatus)

                try? await Task.sleep(nanoseconds: UInt64(configuration.healthCheckInterval * 1_000_000_000))
            }
        }

        // 자동 리포팅 시작
        if configuration.enableAutoReporting {
            startAutoReporting()
        }

        notifyEventHandlers(.systemStarted)
        DILogger.info(channel: .general, "DI Monitor started with configuration: \(configuration)")
    }

    /// 모니터링 중지
public func stopMonitoring() {
    guard isMonitoring else { return }

        isMonitoring = false

        monitoringTask?.cancel()
        reportingTask?.cancel()
        monitoringTask = nil
        reportingTask = nil

        Task {
            await DIHealthCheck.shared.stopMonitoring()
        }

        notifyEventHandlers(.systemStopped)
        DILogger.info(channel: .general, "DI Monitor stopped")
    }

    /// 즉시 리포트 생성
    public func generateReport() async -> DIMonitorReport {
        let healthStatus: DIHealthStatus
        if let existingStatus = lastHealthStatus {
            healthStatus = existingStatus
        } else {
            healthStatus = await DIHealthCheck.shared.performHealthCheck()
        }
        let logSummary = generateLogSummary()
        let recommendations = generateRecommendations(healthStatus: healthStatus, logSummary: logSummary)

        let report = DIMonitorReport(
            timestamp: Date(),
            period: startTime?.timeIntervalSinceNow.magnitude ?? 0,
            healthStatus: healthStatus,
            logSummary: logSummary,
            recommendations: recommendations
        )

        DispatchQueue.main.async {
            self.lastReport = report
        }

        return report
    }

    /// 설정 업데이트
    public func updateConfiguration(_ config: DIMonitorConfiguration) {
        self.configuration = config
        setupInitialConfiguration()

        if isMonitoring {
            // 실행 중인 모니터링 재시작
            stopMonitoring()
            startMonitoring(with: config)
        }

        DILogger.info(channel: .general, "DI Monitor configuration updated")
    }

    /// 이벤트 핸들러 등록
    public func addEventHandler(_ handler: @escaping (DIMonitorEvent) -> Void) {
        eventHandlers.append(handler)
    }

    /// 로그 이벤트 추적 (DILogger에서 호출)
    public func trackLogEvent(severity: DILogSeverity, channel: DILogChannel) {
        logCounts[severity, default: 0] += 1
        channelCounts[channel, default: 0] += 1

        // 임계값 체크
        if severity == .error {
            notifyEventHandlers(.criticalError(message: "Error logged in \(channel.rawValue) channel"))
        } else if severity == .warning {
            notifyEventHandlers(.warningDetected(message: "Warning logged in \(channel.rawValue) channel"))
        }
    }

    // MARK: - Private Methods

    /// 초기 설정 적용
    private func setupInitialConfiguration() {
        DILogger.configure(
            level: configuration.logLevel,
            severityThreshold: configuration.logSeverityThreshold
        )
    }

    /// 자동 리포팅 시작
    private func startAutoReporting() {
        reportingTask = Task {
            while !Task.isCancelled && isMonitoring && configuration.enableAutoReporting {
                let report = await generateReport()

                DILogger.info(channel: .general, """
                    📊 DI Monitor Report Generated:
                    - Health: \(report.healthStatus.overallHealth ? "✅" : "❌")
                    - Total Logs: \(report.logSummary.totalLogs)
                    - Errors: \(report.logSummary.errorCount)
                    - Recommendations: \(report.recommendations.count)
                    """)

                try? await Task.sleep(nanoseconds: UInt64(configuration.reportingInterval * 1_000_000_000))
            }
        }
    }

    /// 임계값 체크
    private func checkThresholds(_ healthStatus: DIHealthStatus) async {
        // 성능 임계값 체크
        if configuration.enablePerformanceTracking {
            let avgTime = healthStatus.summary.averageResolutionTime
            if avgTime > 100 { // 100ms
                DispatchQueue.main.async {
                    self.notifyEventHandlers(.performanceThresholdExceeded(
                        operation: "dependency_resolution",
                        duration: avgTime / 1000
                    ))
                }
            }
        }

        // 메모리 임계값 체크
        if healthStatus.summary.memoryUsage > 100 { // 100MB
            DispatchQueue.main.async {
                self.notifyEventHandlers(.criticalError(message: "Memory usage exceeded 100MB"))
            }
        }

        // 순환 의존성 체크
        if healthStatus.summary.circularDependencies > 0 {
            DispatchQueue.main.async {
                self.notifyEventHandlers(.criticalError(message: "Circular dependencies detected"))
            }
        }
    }

    /// 로그 요약 생성
    private func generateLogSummary() -> DILogSummary {
        let totalLogs = logCounts.values.reduce(0, +)

        return DILogSummary(
            totalLogs: totalLogs,
            errorCount: logCounts[.error] ?? 0,
            warningCount: logCounts[.warning] ?? 0,
            infoCount: logCounts[.info] ?? 0,
            debugCount: logCounts[.debug] ?? 0,
            channelBreakdown: channelCounts
        )
    }

    /// 권장사항 생성
    private func generateRecommendations(
        healthStatus: DIHealthStatus,
        logSummary: DILogSummary
    ) -> [String] {
        var recommendations: [String] = []

        // 헬스체크 기반 권장사항
        if !healthStatus.overallHealth {
            recommendations.append("🔴 시스템 상태가 불안정합니다. 즉시 확인이 필요합니다.")
        }

        if healthStatus.summary.memoryUsage > 50 {
            recommendations.append("⚠️ 메모리 사용량이 높습니다 (\(String(format: "%.1f", healthStatus.summary.memoryUsage))MB). 등록된 의존성을 검토하세요.")
        }

        if healthStatus.summary.averageResolutionTime > 50 {
            recommendations.append("⚠️ 의존성 해결 시간이 느립니다 (\(String(format: "%.1f", healthStatus.summary.averageResolutionTime))ms). 성능 최적화를 고려하세요.")
        }

        if healthStatus.summary.circularDependencies > 0 {
            recommendations.append("🔴 순환 의존성이 발견되었습니다. 의존성 구조를 재설계하세요.")
        }

        // 로그 기반 권장사항
        if logSummary.errorCount > 10 {
            recommendations.append("🔴 에러 로그가 많습니다 (\(logSummary.errorCount)개). 근본 원인을 분석하세요.")
        }

        if logSummary.warningCount > 20 {
            recommendations.append("⚠️ 경고 로그가 많습니다 (\(logSummary.warningCount)개). 잠재적 문제를 확인하세요.")
        }

        if logSummary.totalLogs == 0 && isMonitoring {
            recommendations.append("ℹ️ 로그가 기록되지 않고 있습니다. 로그 레벨 설정을 확인하세요.")
        }

        // 성능 최적화 권장사항
        if healthStatus.summary.registeredDependencies > 100 {
            recommendations.append("💡 등록된 의존성이 많습니다 (\(healthStatus.summary.registeredDependencies)개). 모듈화를 고려하세요.")
        }

        if recommendations.isEmpty {
            recommendations.append("✅ 시스템이 정상적으로 작동하고 있습니다.")
        }

        return recommendations
    }

    /// 이벤트 핸들러 알림
    private func notifyEventHandlers(_ event: DIMonitorEvent) {
        for handler in eventHandlers {
            handler(event)
        }
    }

    /// 카운터 리셋
    private func resetCounters() {
        logCounts.removeAll()
        channelCounts.removeAll()
    }
}

// Wire monitoring toggles from core configuration when this module is present.
private let _monitorToggleHook: Void = {
    WeaveDIConfiguration.setMonitorToggleHandler { flag in
        Task { @MainActor in
            if flag {
                DIMonitor.shared.startMonitoring()
            } else {
                DIMonitor.shared.stopMonitoring()
            }
        }
    }
}()

// MARK: - DILogger Integration

extension DILogger {
    /// DIMonitor와 연동된 로깅 (내부적으로 추적)
    public static func logWithTracking(
        _ severity: DILogSeverity,
        channel: DILogChannel,
        _ message: Any,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // 기존 로깅 수행 - 일반 public 메서드 사용
        switch severity {
        case .debug:
            debug(channel: channel, message, file: file, function: function, line: line)
        case .info:
            info(channel: channel, message, file: file, function: function, line: line)
        case .warning:
            warning(channel: channel, message, file: file, function: function, line: line)
        case .error:
            error(channels: [channel], message, file: file, function: function, line: line)
        }

        // 모니터에 추적 정보 전달
        Task { @MainActor in
            DIMonitor.shared.trackLogEvent(severity: severity, channel: channel)
        }
    }
}

// MARK: - Public Convenience API

extension DIMonitor {
    /// 개발 환경에서 빠른 시작
    public static func startDevelopmentMonitoring() {
        #if DEBUG
        let config = DIMonitorConfiguration(
            logLevel: .all,
            logSeverityThreshold: .debug,
            healthCheckInterval: 60,
            enablePerformanceTracking: true,
            enableAutoReporting: true,
            reportingInterval: 300
        )
        shared.startMonitoring(with: config)
        #endif
    }

    /// 프로덕션 환경에서 최소한의 모니터링
    public static func startProductionMonitoring() {
        let config = DIMonitorConfiguration(
            logLevel: .errorsOnly,
            logSeverityThreshold: .error,
            healthCheckInterval: 600,
            enablePerformanceTracking: false,
            enableAutoReporting: false
        )
        shared.startMonitoring(with: config)
    }

    /// 사용자 정의 모니터링 시작
    public static func startCustomMonitoring(_ config: DIMonitorConfiguration) {
        shared.startMonitoring(with: config)
    }

    /// 모니터링 중지
    public static func stop() {
        shared.stopMonitoring()
    }
}
