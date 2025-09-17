//
//  UnifiedDIIntegration.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - UnifiedDI Integration with Advanced Monitoring

/// UnifiedDI와 고급 모니터링 시스템 통합
public extension UnifiedDI {

    // MARK: - Performance-Tracked Resolution

    /// 고급 성능 추적이 포함된 해결
    static func resolveWithAdvancedTracking<T>(_ type: T.Type) -> T? {
        let performanceToken = SimplePerformanceOptimizer.startResolution(type)

        defer {
            SimplePerformanceOptimizer.endResolution(performanceToken)
        }

        // 순환 의존성 체크도 포함
        do {
            try CircularDependencyDetector.shared.beginResolution(type)
            defer { CircularDependencyDetector.shared.endResolution(type) }

            let result = resolve(type)

            // 자동 의존성 기록 (고급 탐지용)
            if let _ = result {
                CircularDependencyDetector.shared.recordAutoEdgeIfEnabled(for: type)
            }

            return result
        } catch {
            #logDebug("⚠️ [UnifiedDI] Circular dependency detected for \(type): \(error)")
            return nil
        }
    }

    /// 필수 해결 + 추적
    static func requireResolveWithAdvancedTracking<T>(_ type: T.Type) -> T {
        guard let result = resolveWithAdvancedTracking(type) else {
            fatalError("Failed to resolve required dependency: \(type)")
        }
        return result
    }

    /// 안전한 해결 + 추적
    static func resolveThrowsWithAdvancedTracking<T>(_ type: T.Type) throws -> T {
        let performanceToken = SimplePerformanceOptimizer.startResolution(type)

        defer {
            SimplePerformanceOptimizer.endResolution(performanceToken)
        }

        // 순환 의존성 체크
        try CircularDependencyDetector.shared.beginResolution(type)
        defer { CircularDependencyDetector.shared.endResolution(type) }

        guard let result = resolve(type) else {
            throw SafeDIError.dependencyNotFound(type: String(describing: type), keyPath: nil)
        }

        // 자동 의존성 기록
        CircularDependencyDetector.shared.recordAutoEdgeIfEnabled(for: type)

        return result
    }

    // MARK: - Registration with Validation

    /// 검증이 포함된 등록 (간소화 버전)
    static func registerWithValidation<T>(
        _ type: T.Type,
        dependencies: [Any.Type] = [],
        factory: @escaping @Sendable () -> T
    ) {
        // 기본 등록 (검증 기능은 추후 구현)
        register(type, factory: factory)

        // 의존성 그래프에 기록
        for dep in dependencies {
            CircularDependencyDetector.shared.recordDependency(from: type, to: dep)
        }

        #logDebug("✅ [UnifiedDI] Registered \(type) with basic validation")
    }

    // MARK: - Batch Operations with Monitoring

    /// 일괄 등록 + 모니터링
    static func performBatchRegistrationWithMonitoring() {
        #logDebug("📦 [UnifiedDI] Starting batch registration monitoring")

        let startTime = Date()

        // 일괄 등록 후 전체 그래프 분석
        performPostRegistrationAnalysis()

        let duration = Date().timeIntervalSince(startTime)
        #logDebug("📦 [UnifiedDI] Batch registration monitoring completed in \(String(format: "%.2f", duration * 1000))ms")
    }

    // MARK: - Diagnostic Methods

    /// 현재 상태 진단
    @MainActor
    static func diagnose() -> UnifiedDIDiagnostics {
        let performanceStats = SimplePerformanceOptimizer.getStats()
        let actorHopReport = ActorHopMetrics.generateReport()
        let circularAnalysis = AdvancedCircularDependencyDetector.performComprehensiveAnalysis()

        return UnifiedDIDiagnostics(
            performanceStats: performanceStats,
            actorHopReport: actorHopReport,
            circularAnalysis: circularAnalysis,
            timestamp: Date()
        )
    }

    /// 건강도 체크
    @MainActor
    static func healthCheck() -> HealthCheckResult {
        let stats = SimplePerformanceOptimizer.getStats()
        let cycles = CircularDependencyDetector.shared.detectAllCircularDependencies()
        // let detectionStats = AdvancedCircularDependencyDetector.getDetectionStatistics()

        var issues: [String] = []
        var score: Double = 100.0

        // 순환 의존성 체크
        if !cycles.isEmpty {
            issues.append("\(cycles.count)개의 순환 의존성 발견")
            score -= Double(cycles.count) * 20.0
        }

        // 성능 체크
        if stats.averageResolutionTime > 0.01 { // 10ms 이상
            issues.append("평균 해결 시간이 높습니다: \(String(format: "%.2f", stats.averageResolutionTime * 1000))ms")
            score -= 15.0
        }

        // Actor Hop 체크 (추후 구현 예정)
        // if actorHopReport.averageHopsPerResolution > 3.0 {
        //     issues.append("평균 Actor Hop 수가 높습니다: \(String(format: "%.1f", actorHopReport.averageHopsPerResolution))")
        //     score -= 10.0
        // }

        score = max(0, score)

        let status: HealthStatus
        switch score {
        case 80...100: status = .healthy
        case 60...79: status = .warning
        case 40...59: status = .degraded
        default: status = .critical
        }

        return HealthCheckResult(
            status: status,
            score: score,
            issues: issues,
            recommendations: generateHealthRecommendations(status: status, issues: issues)
        )
    }

    /// 성능 리포트 생성 (비동기로 호출 필요)
    @MainActor
    static func generatePerformanceReport() -> String {
        let diagnosis = diagnose()

        return """
        🚀 UnifiedDI Performance Report
        ════════════════════════════════════

        📊 Resolution Performance:
        • Total Resolutions: \(diagnosis.performanceStats.totalResolutions)
        • Average Time: \(String(format: "%.2f", diagnosis.performanceStats.averageResolutionTime * 1000))ms
        • Optimization: \(diagnosis.performanceStats.optimizationEnabled ? "Enabled" : "Disabled")

        🔄 Actor Hop Analysis:
        • Total Measurements: \(diagnosis.actorHopReport.totalMeasurements)
        • Average Hops: \(String(format: "%.2f", diagnosis.actorHopReport.averageHopsPerResolution))
        • Optimization Rate: \(String(format: "%.1f", Double(diagnosis.actorHopReport.measurements.filter(\.isOptimized).count) / max(1, Double(diagnosis.actorHopReport.totalMeasurements)) * 100))%

        🔍 Circular Dependencies:
        • Detected Cycles: \(diagnosis.circularAnalysis.basicCycles.count)
        • Potential Risks: \(diagnosis.circularAnalysis.potentialCycles.count)
        • Risk Level: \(diagnosis.circularAnalysis.riskAssessment.riskLevel.description)

        💡 Top Recommendations:
        \(diagnosis.circularAnalysis.recommendations.prefix(3).map { "• \($0.description)" }.joined(separator: "\n"))

        ════════════════════════════════════
        Generated: \(DateFormatter.localizedString(from: diagnosis.timestamp, dateStyle: .short, timeStyle: .medium))
        """
    }

    // MARK: - Monitoring Control

    /// 전체 모니터링 활성화
    @MainActor
    static func enableAllMonitoring() {
        SimplePerformanceOptimizer.enableOptimization()
        ActorHopMetrics.enable()
        AdvancedCircularDependencyDetector.enableAdvancedDetection()
        AdvancedCircularDependencyDetector.startRealtimeMonitoring()

        #logDebug("🎯 [UnifiedDI] All monitoring systems enabled")
    }

    /// 전체 모니터링 비활성화
    @MainActor
    static func disableAllMonitoring() {
        SimplePerformanceOptimizer.disableOptimization()
        ActorHopMetrics.disable()
        AdvancedCircularDependencyDetector.disableAdvancedDetection()

        #logDebug("🔴 [UnifiedDI] All monitoring systems disabled")
    }

    /// 자동 최적화 활성화
    @MainActor
    static func enableAutoOptimization() {
        AutoPerformanceOptimizer.enableAutoOptimization()
        AdvancedCircularDependencyDetector.enableAutoFix()

        #logDebug("🤖 [UnifiedDI] Auto-optimization enabled")
    }

    // MARK: - Private Helpers

    private static func performPostRegistrationAnalysis() {
        Task { @MainActor in
            // 새로운 순환 의존성 체크
            let cycles = CircularDependencyDetector.shared.detectAllCircularDependencies()
            if !cycles.isEmpty {
                #logDebug("⚠️ [UnifiedDI] \(cycles.count) circular dependencies detected after batch registration")
            }

            // 성능 최적화 제안
            AutoPerformanceOptimizer.optimizeBasedOnUsage()
        }
    }

    private static func generateHealthRecommendations(status: HealthStatus, issues: [String]) -> [String] {
        var recommendations: [String] = []

        switch status {
        case .healthy:
            recommendations.append("시스템이 정상 작동 중입니다.")
        case .warning:
            recommendations.append("정기적인 모니터링을 권장합니다.")
            recommendations.append("성능 최적화를 고려해보세요.")
        case .degraded:
            recommendations.append("즉시 성능 튜닝이 필요합니다.")
            recommendations.append("의존성 구조를 검토해보세요.")
        case .critical:
            recommendations.append("시스템 재설계가 필요합니다.")
            recommendations.append("순환 의존성을 즉시 해결하세요.")
        }

        return recommendations
    }
}

// MARK: - Property Wrapper Integration

/// 성능 추적이 포함된 Inject
@propertyWrapper
public struct InjectWithTracking<T> {
    private let type: T.Type

    public init(_ type: T.Type) {
        self.type = type
    }

    public var wrappedValue: T? {
        return UnifiedDI.resolveWithAdvancedTracking(type)
    }
}

/// 필수 의존성 + 성능 추적
@propertyWrapper
public struct RequiredInjectWithTracking<T> {
    private let type: T.Type

    public init(_ type: T.Type) {
        self.type = type
    }

    public var wrappedValue: T {
        return UnifiedDI.requireResolveWithAdvancedTracking(type)
    }
}

// MARK: - Data Models

/// UnifiedDI 진단 정보
public struct UnifiedDIDiagnostics: Sendable {
    public let performanceStats: SimplePerformanceOptimizer.PerformanceStats
    public let actorHopReport: ActorHopReport
    public let circularAnalysis: ComprehensiveAnalysisResult
    public let timestamp: Date
}

/// 건강도 체크 결과
public struct HealthCheckResult: Sendable {
    public let status: HealthStatus
    public let score: Double
    public let issues: [String]
    public let recommendations: [String]

    public var summary: String {
        return """
        🏥 UnifiedDI Health Check
        Status: \(status.emoji) \(status.description)
        Score: \(String(format: "%.1f", score))/100

        Issues (\(issues.count)):
        \(issues.map { "• \($0)" }.joined(separator: "\n"))

        Recommendations:
        \(recommendations.map { "• \($0)" }.joined(separator: "\n"))
        """
    }
}

/// 건강 상태
public enum HealthStatus: Sendable, CustomStringConvertible {
    case healthy, warning, degraded, critical

    public var description: String {
        switch self {
        case .healthy: return "Healthy"
        case .warning: return "Warning"
        case .degraded: return "Degraded"
        case .critical: return "Critical"
        }
    }

    public var emoji: String {
        switch self {
        case .healthy: return "✅"
        case .warning: return "⚠️"
        case .degraded: return "🔶"
        case .critical: return "🚨"
        }
    }
}

// MARK: - Convenience Extensions

public extension DependencyContainer {

    /// UnifiedDI 스타일로 건강도 체크
    @MainActor
    func checkHealth() -> HealthCheckResult {
        return UnifiedDI.healthCheck()
    }

    /// 성능 리포트 출력
    @MainActor
    func printPerformanceReport() {
        print(UnifiedDI.generatePerformanceReport())
    }

    /// 전체 모니터링 활성화
    @MainActor
    func enableMonitoring() {
        UnifiedDI.enableAllMonitoring()
    }
}