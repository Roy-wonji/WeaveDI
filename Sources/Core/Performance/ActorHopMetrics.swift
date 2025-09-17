//
//  ActorHopMetrics.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - Actor Hop Metrics System

/// Actor Hop 최적화 효과를 측정하는 메트릭 시스템
///
/// ## 개요
///
/// Swift Concurrency에서 Actor 간 전환(Actor Hop)은 성능에 중요한 영향을 미칩니다.
/// 이 시스템은 의존성 해결 과정에서 발생하는 Actor Hop을 추적하고 최적화 효과를 측정합니다.
///
/// ## 핵심 측정 항목
///
/// ### ⚡ Actor Hop 카운트
/// - 의존성 해결 중 발생한 Actor 전환 횟수
/// - 최적화 전후 비교
/// - 타입별 Actor Hop 패턴 분석
///
/// ### 📊 실행 컨텍스트 추적
/// - MainActor, Global Actor, 일반 Actor 구분
/// - 컨텍스트 전환 시간 측정
/// - 동기/비동기 해결 방식별 성능 차이
///
/// ## 사용 예시
///
/// ```swift
/// // Actor Hop 측정 시작
/// let session = ActorHopMetrics.startMeasurement(for: UserService.self)
///
/// // 의존성 해결 (내부적으로 측정됨)
/// let userService = DI.resolve(UserService.self)
///
/// // 측정 완료
/// ActorHopMetrics.endMeasurement(session)
///
/// // 결과 확인
/// let report = ActorHopMetrics.generateReport()
/// print(report.summary)
/// ```
@MainActor
public enum ActorHopMetrics {

    // MARK: - Configuration

    /// Actor Hop 측정 활성화 여부
    private static var isEnabled: Bool = false

    /// 세부 추적 활성화 여부 (성능 오버헤드 있음)
    private static var isDetailedTrackingEnabled: Bool = false

    // MARK: - Measurement Data

    /// 측정 세션 저장소
    private static var activeSessions: [UUID: MeasurementSession] = [:]

    /// 완료된 측정 결과
    private static var completedMeasurements: [ActorHopMeasurement] = []

    /// 타입별 통계
    private static var typeStats: [String: TypeActorStats] = [:]

    // MARK: - Public API

    /// Actor Hop 측정 활성화
    public static func enable() {
        isEnabled = true
        #logDebug("✅ [ActorHopMetrics] Actor hop measurement enabled")
    }

    /// Actor Hop 측정 비활성화
    public static func disable() {
        isEnabled = false
        #logDebug("🔴 [ActorHopMetrics] Actor hop measurement disabled")
    }

    /// 세부 추적 활성화
    public static func enableDetailedTracking() {
        isDetailedTrackingEnabled = true
        #logDebug("🔍 [ActorHopMetrics] Detailed tracking enabled")
    }

    /// 측정 세션 시작
    public static func startMeasurement<T>(for type: T.Type, context: String = #function) -> UUID? {
        guard isEnabled else { return nil }

        let sessionId = UUID()
        let session = MeasurementSession(
            id: sessionId,
            typeName: String(describing: type),
            context: context,
            startTime: CFAbsoluteTimeGetCurrent(),
            initialActorContext: getCurrentActorContext()
        )

        activeSessions[sessionId] = session
        return sessionId
    }

    /// Actor Hop 기록
    nonisolated public static func recordActorHop(sessionId: UUID?, from: ActorContext, to: ActorContext) {
        guard let sessionId = sessionId else { return }

        Task { @MainActor in
            guard isEnabled else { return }
            guard var session = activeSessions[sessionId] else { return }

            let hop = ActorHop(
                from: from,
                to: to,
                timestamp: CFAbsoluteTimeGetCurrent(),
                duration: 0 // 실제로는 측정 필요
            )

            session.actorHops.append(hop)
            activeSessions[sessionId] = session

            if isDetailedTrackingEnabled {
                #logDebug("🔄 [ActorHopMetrics] Actor hop: \(from.description) → \(to.description)")
            }
        }
    }

    /// 측정 완료
    public static func endMeasurement(_ sessionId: UUID?) {
        guard let sessionId = sessionId, isEnabled else { return }
        guard let session = activeSessions[sessionId] else { return }

        let endTime = CFAbsoluteTimeGetCurrent()
        let totalDuration = endTime - session.startTime

        let measurement = ActorHopMeasurement(
            typeName: session.typeName,
            context: session.context,
            totalDuration: totalDuration,
            actorHops: session.actorHops,
            initialContext: session.initialActorContext,
            finalContext: getCurrentActorContext()
        )

        completedMeasurements.append(measurement)
        activeSessions.removeValue(forKey: sessionId)

        // 타입별 통계 업데이트
        updateTypeStats(for: measurement)

        #logDebug("📊 [ActorHopMetrics] Measurement completed: \(session.typeName) - \(session.actorHops.count) hops in \(String(format: "%.4f", totalDuration * 1000))ms")
    }

    // MARK: - Statistics & Reporting

    /// 현재 Actor 컨텍스트 확인
    private static func getCurrentActorContext() -> ActorContext {
        // Swift 6에서는 더 정확한 Actor 컨텍스트 감지 가능
        // 현재는 기본값으로 처리
        return .mainActor // 기본값으로 MainActor 가정
    }

    /// 타입별 통계 업데이트
    private static func updateTypeStats(for measurement: ActorHopMeasurement) {
        let typeName = measurement.typeName
        var stats = typeStats[typeName] ?? TypeActorStats(typeName: typeName)

        stats.measurementCount += 1
        stats.totalDuration += measurement.totalDuration
        stats.totalHops += measurement.actorHops.count

        if measurement.actorHops.count < stats.minHops {
            stats.minHops = measurement.actorHops.count
        }
        if measurement.actorHops.count > stats.maxHops {
            stats.maxHops = measurement.actorHops.count
        }

        typeStats[typeName] = stats
    }

    /// 포괄적인 리포트 생성
    public static func generateReport() -> ActorHopReport {
        let totalMeasurements = completedMeasurements.count
        let totalHops = completedMeasurements.reduce(0) { $0 + $1.actorHops.count }
        let averageHops = totalMeasurements > 0 ? Double(totalHops) / Double(totalMeasurements) : 0

        let averageDuration = totalMeasurements > 0
            ? completedMeasurements.reduce(0) { $0 + $1.totalDuration } / Double(totalMeasurements)
            : 0

        // 최적화 기회 식별
        let optimizationOpportunities = identifyOptimizationOpportunities()

        return ActorHopReport(
            totalMeasurements: totalMeasurements,
            totalActorHops: totalHops,
            averageHopsPerResolution: averageHops,
            averageResolutionTime: averageDuration,
            typeStatistics: Array(typeStats.values),
            optimizationOpportunities: optimizationOpportunities,
            measurements: completedMeasurements
        )
    }

    /// 최적화 기회 식별
    private static func identifyOptimizationOpportunities() -> [OptimizationOpportunity] {
        var opportunities: [OptimizationOpportunity] = []

        // 높은 Actor Hop 수를 가진 타입들
        let highHopTypes = typeStats.values.filter { $0.averageHops > 3.0 }
        for typeStats in highHopTypes {
            opportunities.append(
                OptimizationOpportunity(
                    type: .reduceActorHops,
                    description: "\(typeStats.typeName)의 Actor Hop 수가 높습니다 (평균 \(String(format: "%.1f", typeStats.averageHops))개)",
                    impact: .high,
                    suggestion: "의존성 구조를 재검토하여 같은 Actor 컨텍스트에서 해결될 수 있도록 최적화하세요."
                )
            )
        }

        // 오래 걸리는 해결 과정
        let slowTypes = typeStats.values.filter { $0.averageDuration > 0.01 } // 10ms 이상
        for typeStats in slowTypes {
            opportunities.append(
                OptimizationOpportunity(
                    type: .improveResolutionSpeed,
                    description: "\(typeStats.typeName)의 해결 시간이 깁니다 (평균 \(String(format: "%.2f", typeStats.averageDuration * 1000))ms)",
                    impact: .medium,
                    suggestion: "캐싱이나 지연 초기화를 고려해보세요."
                )
            )
        }

        return opportunities
    }

    /// 통계 초기화
    public static func reset() {
        activeSessions.removeAll()
        completedMeasurements.removeAll()
        typeStats.removeAll()
        #logDebug("🔄 [ActorHopMetrics] All metrics reset")
    }

    /// 메모리 최적화
    public static func optimizeMemory() {
        // 오래된 측정 결과 제거 (최근 1000개만 유지)
        if completedMeasurements.count > 1000 {
            completedMeasurements = Array(completedMeasurements.suffix(500))
        }

        // 비활성 세션 정리
        let currentTime = CFAbsoluteTimeGetCurrent()
        activeSessions = activeSessions.filter { _, session in
            currentTime - session.startTime < 60.0 // 1분 이상 된 세션 제거
        }

        #logDebug("🗜️ [ActorHopMetrics] Memory optimized")
    }
}

// MARK: - Data Models

/// 측정 세션
private struct MeasurementSession {
    let id: UUID
    let typeName: String
    let context: String
    let startTime: TimeInterval
    let initialActorContext: ActorContext
    var actorHops: [ActorHop] = []
}

/// Actor 컨텍스트 종류
public enum ActorContext: Sendable, CustomStringConvertible {
    case mainActor
    case globalActor(String)
    case customActor(String)
    case task
    case unknown

    public var description: String {
        switch self {
        case .mainActor: return "MainActor"
        case .globalActor(let name): return "GlobalActor(\(name))"
        case .customActor(let name): return "CustomActor(\(name))"
        case .task: return "Task"
        case .unknown: return "Unknown"
        }
    }
}

/// Actor 간 전환 정보
public struct ActorHop: Sendable {
    public let from: ActorContext
    public let to: ActorContext
    public let timestamp: TimeInterval
    public let duration: TimeInterval
}

/// 완료된 측정 결과
public struct ActorHopMeasurement: Sendable {
    public let typeName: String
    public let context: String
    public let totalDuration: TimeInterval
    public let actorHops: [ActorHop]
    public let initialContext: ActorContext
    public let finalContext: ActorContext

    public var hopCount: Int { actorHops.count }
    public var isOptimized: Bool { hopCount <= 1 }
}

/// 타입별 Actor 통계
public struct TypeActorStats: Sendable {
    public let typeName: String
    public var measurementCount: Int = 0
    public var totalDuration: TimeInterval = 0
    public var totalHops: Int = 0
    public var minHops: Int = Int.max
    public var maxHops: Int = 0

    public var averageDuration: TimeInterval {
        measurementCount > 0 ? totalDuration / Double(measurementCount) : 0
    }

    public var averageHops: Double {
        measurementCount > 0 ? Double(totalHops) / Double(measurementCount) : 0
    }

    init(typeName: String) {
        self.typeName = typeName
    }
}

/// 최적화 기회
public struct OptimizationOpportunity: Sendable {
    public enum OpportunityType: Sendable {
        case reduceActorHops
        case improveResolutionSpeed
        case optimizeMemoryUsage
    }

    public enum Impact: Sendable {
        case low, medium, high
    }

    public let type: OpportunityType
    public let description: String
    public let impact: Impact
    public let suggestion: String
}

/// Actor Hop 리포트
public struct ActorHopReport: Sendable {
    public let totalMeasurements: Int
    public let totalActorHops: Int
    public let averageHopsPerResolution: Double
    public let averageResolutionTime: TimeInterval
    public let typeStatistics: [TypeActorStats]
    public let optimizationOpportunities: [OptimizationOpportunity]
    public let measurements: [ActorHopMeasurement]

    public var summary: String {
        let optimizedCount = measurements.filter(\.isOptimized).count
        let optimizationRate = totalMeasurements > 0 ? Double(optimizedCount) / Double(totalMeasurements) * 100 : 0

        return """
        📊 Actor Hop Analysis Report
        ════════════════════════════════

        📈 Overview:
        • Total Measurements: \(totalMeasurements)
        • Total Actor Hops: \(totalActorHops)
        • Average Hops per Resolution: \(String(format: "%.2f", averageHopsPerResolution))
        • Average Resolution Time: \(String(format: "%.2f", averageResolutionTime * 1000))ms
        • Optimization Rate: \(String(format: "%.1f", optimizationRate))%

        🎯 Top Performing Types:
        \(topPerformingTypes)

        ⚠️  Optimization Opportunities: \(optimizationOpportunities.count)
        \(optimizationOpportunities.prefix(3).map { "• \($0.description)" }.joined(separator: "\n"))

        ════════════════════════════════
        """
    }

    private var topPerformingTypes: String {
        let sorted = typeStatistics.sorted { $0.averageHops < $1.averageHops }
        return sorted.prefix(5).map { stats in
            "• \(stats.typeName): \(String(format: "%.1f", stats.averageHops)) hops (\(String(format: "%.2f", stats.averageDuration * 1000))ms)"
        }.joined(separator: "\n")
    }
}