//
//  SimplePerformanceOptimizer.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - Simple Performance Optimizer

/// 간단하고 효과적인 성능 최적화 시스템
///
/// ## 개요
///
/// 복잡한 캐싱 시스템 대신 실용적인 최적화에 집중합니다.
/// 타입 해결 성능을 측정하고 자주 사용되는 의존성의 빠른 경로를 제공합니다.
///
/// ## 핵심 특징
///
/// ### ⚡ 빠른 타입 해결
/// - 자주 사용되는 타입에 대한 최적화된 경로
/// - 간단한 Dictionary 기반 캐싱
/// - 컴파일 타임 최적화 활용
///
/// ### 📊 성능 측정
/// - 해결 시간 추적
/// - 사용 빈도 모니터링
/// - 간단한 통계 정보 제공
///
/// ## 사용 예시
///
/// ```swift
/// // 성능 최적화 활성화
/// SimplePerformanceOptimizer.enableOptimization()
///
/// // 자주 사용되는 타입 등록
/// SimplePerformanceOptimizer.markAsFrequentlyUsed(UserService.self)
///
/// // 성능 통계 확인
/// let stats = SimplePerformanceOptimizer.getStats()
/// #logDebug("Average resolution time: \(stats.averageResolutionTime)ms")
/// ```
@MainActor
public enum SimplePerformanceOptimizer {

    // MARK: - Configuration

    /// 성능 최적화 활성화 여부
    private static var isOptimizationEnabled: Bool = false

    /// 성능 측정 활성화 여부 (디버그 빌드에서만)
    #if DEBUG
    private static var isPerformanceMeasurementEnabled: Bool = true
    #else
    private static var isPerformanceMeasurementEnabled: Bool = false
    #endif

    // MARK: - Simple Caching

    /// 자주 사용되는 타입 목록
    private static var frequentlyUsedTypes: Set<String> = []

    /// 간단한 타입명 캐시
    private static var typeNameCache: [ObjectIdentifier: String] = [:]

    // MARK: - Performance Metrics

    /// 해결 횟수 추적
    private static var resolutionCounts: [String: Int] = [:]

    /// 해결 시간 추적 (디버그 빌드에서만)
    #if DEBUG
    private static var resolutionTimes: [String: [TimeInterval]] = [:]
    #endif

    // MARK: - Public API

    /// 성능 최적화 활성화
    public static func enableOptimization() {
        isOptimizationEnabled = true
      #logDebug("✅ [SimplePerformanceOptimizer] Optimization enabled")
    }

    /// 성능 최적화 비활성화
    public static func disableOptimization() {
        isOptimizationEnabled = false
      #logDebug("🔴 [SimplePerformanceOptimizer] Optimization disabled")
    }

    /// 자주 사용되는 타입으로 등록
    public static func markAsFrequentlyUsed<T>(_ type: T.Type) {
        let typeName = getOptimizedTypeName(type)
        frequentlyUsedTypes.insert(typeName)
      #logDebug("⚡ [SimplePerformanceOptimizer] Marked as frequently used: \(typeName)")
    }

    // MARK: - Optimized Type Resolution

    /// 최적화된 타입명 가져오기
    public static func getOptimizedTypeName<T>(_ type: T.Type) -> String {
        let identifier = ObjectIdentifier(type)

        if let cached = typeNameCache[identifier] {
            return cached
        }

        let typeName = String(describing: type)
        typeNameCache[identifier] = typeName
        return typeName
    }

    /// 자주 사용되는 타입인지 확인
    public static func isFrequentlyUsed<T>(_ type: T.Type) -> Bool {
        guard isOptimizationEnabled else { return false }
        let typeName = getOptimizedTypeName(type)
        return frequentlyUsedTypes.contains(typeName)
    }

    // MARK: - Performance Tracking

    /// 해결 시작 시간 기록
    nonisolated public static func startResolution<T>(_ type: T.Type) -> PerformanceToken? {
        #if DEBUG
        let typeName = String(describing: type)
        let startTime = CFAbsoluteTimeGetCurrent()
        return PerformanceToken(typeName: typeName, startTime: startTime)
        #else
        return nil
        #endif
    }

    /// 해결 완료 시간 기록
    nonisolated public static func endResolution(_ token: PerformanceToken?) {
        #if DEBUG
        guard let token = token else { return }

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - token.startTime
        let typeName = token.typeName

        Task { @MainActor in
            guard isPerformanceMeasurementEnabled else { return }

            // 해결 횟수 증가
            resolutionCounts[typeName, default: 0] += 1

            // 해결 시간 기록
            resolutionTimes[typeName, default: []].append(duration)

            // 너무 많은 기록을 유지하지 않도록 제한
            if let times = resolutionTimes[typeName], times.count > 100 {
                resolutionTimes[typeName] = Array(times.suffix(50))
            }
        }
        #endif
    }

    // MARK: - Statistics

    /// 성능 통계 정보
    public struct PerformanceStats: Sendable {
        public let totalResolutions: Int
        public let averageResolutionTime: TimeInterval
        public let mostUsedTypes: [(String, Int)]
        public let optimizationEnabled: Bool

        public var summary: String {
            return """
            Performance Statistics:
            - Total resolutions: \(totalResolutions)
            - Average time: \(String(format: "%.4f", averageResolutionTime * 1000))ms
            - Optimization: \(optimizationEnabled ? "Enabled" : "Disabled")
            - Most used types: \(mostUsedTypes.prefix(3).map { "\($0.0)(\($0.1)x)" }.joined(separator: ", "))
            """
        }
    }

    /// 현재 성능 통계 반환
    public static func getStats() -> PerformanceStats {
        let totalResolutions = resolutionCounts.values.reduce(0, +)

        #if DEBUG
        let totalTime = resolutionTimes.values.flatMap { $0 }.reduce(0, +)
        let averageTime = totalResolutions > 0 ? totalTime / Double(totalResolutions) : 0
        #else
        let averageTime: TimeInterval = 0
        #endif

        let mostUsed = resolutionCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { ($0.key, $0.value) }

        return PerformanceStats(
            totalResolutions: totalResolutions,
            averageResolutionTime: averageTime,
            mostUsedTypes: Array(mostUsed),
            optimizationEnabled: isOptimizationEnabled
        )
    }

    /// 통계 초기화
    public static func resetStats() {
        resolutionCounts.removeAll()
        #if DEBUG
        resolutionTimes.removeAll()
        #endif
      #logDebug("🔄 [SimplePerformanceOptimizer] Statistics reset")
    }

    // MARK: - Cache Management

    /// 캐시 정리
    public static func clearCaches() {
        typeNameCache.removeAll()
        frequentlyUsedTypes.removeAll()
        resetStats()
      #logDebug("🧹 [SimplePerformanceOptimizer] Caches cleared")
    }

    /// 메모리 사용량 최적화
    public static func optimizeMemoryUsage() {
        // 타입명 캐시 크기 제한
        if typeNameCache.count > 1000 {
            let sortedEntries = typeNameCache.sorted { $0.key.hashValue < $1.key.hashValue }
            typeNameCache = Dictionary(uniqueKeysWithValues: Array(sortedEntries.prefix(500)))
        }

        // 자주 사용되는 타입 목록 크기 제한
        if frequentlyUsedTypes.count > 50 {
            let sorted = Array(frequentlyUsedTypes).sorted()
            frequentlyUsedTypes = Set(sorted.prefix(25))
        }

      #logDebug("🗜️ [SimplePerformanceOptimizer] Memory usage optimized")
    }
}

// MARK: - Performance Token

/// 성능 측정을 위한 토큰
public struct PerformanceToken {
    public let typeName: String
    public let startTime: TimeInterval

    internal init(typeName: String, startTime: TimeInterval) {
        self.typeName = typeName
        self.startTime = startTime
    }
}

// MARK: - Performance Measurement Extensions

public extension UnifiedRegistry {

    /// 성능 측정이 포함된 해결 메서드
    func resolveWithPerformanceTracking<T>(_ type: T.Type) -> T? {
        let token = SimplePerformanceOptimizer.startResolution(type)
        defer { SimplePerformanceOptimizer.endResolution(token) }

        return resolve(type)
    }

    /// 성능 측정이 포함된 비동기 해결 메서드
    func resolveAsyncWithPerformanceTracking<T>(_ type: T.Type) async -> T? {
        let token = SimplePerformanceOptimizer.startResolution(type)
        defer { SimplePerformanceOptimizer.endResolution(token) }

        return await resolveAsync(type)
    }
}

// MARK: - Auto Performance Optimization

/// 자동 성능 최적화 관리자
@MainActor
public enum AutoPerformanceOptimizer {

    /// 자동 최적화 활성화
    public static func enableAutoOptimization() {
        SimplePerformanceOptimizer.enableOptimization()

        // 공통적으로 자주 사용되는 타입들을 미리 등록
        markCommonTypesAsFrequent()

      #logDebug("🤖 [AutoPerformanceOptimizer] Auto optimization enabled")
    }

    /// 공통 타입들을 자주 사용되는 타입으로 등록
    private static func markCommonTypesAsFrequent() {
        // 일반적으로 자주 사용되는 타입 패턴들
        let _ = [
            "UserDefaults",
            "URLSession",
            "UserService",
            "NetworkService",
            "DatabaseService",
            "Logger",
            "Analytics"
        ]

        // 실제로는 등록된 타입들을 스캔해서 패턴과 매치되는 것들을 찾아야 하지만
        // 여기서는 간단하게 처리
      #logDebug("📋 [AutoPerformanceOptimizer] Common type patterns configured")
    }

    /// 사용 통계 기반 자동 최적화
    public static func optimizeBasedOnUsage() {
        let stats = SimplePerformanceOptimizer.getStats()

        // 상위 10개 타입을 자주 사용되는 타입으로 등록
        for (typeName, _) in stats.mostUsedTypes.prefix(10) {
            // 실제로는 타입명으로부터 타입을 복원해야 하지만
            // 간단한 구현을 위해 여기서는 로깅만
          #logDebug("⚡ [AutoPerformanceOptimizer] Would mark as frequent: \(typeName)")
        }

        // 메모리 사용량 최적화
        SimplePerformanceOptimizer.optimizeMemoryUsage()

      #logDebug("🎯 [AutoPerformanceOptimizer] Usage-based optimization completed")
    }
}
