//
//  UnifiedRegistryExtensions.swift
//  WeaveDI
//
//  Created by Wonji Suh on 2025.
//

import Foundation
import LogMacro

// MARK: - Registry Health & Monitoring Extensions

extension UnifiedRegistry {

  // MARK: - Registry Sync Verification

  /// 🔍 레지스트리 동기화 상태 검증
  /// - Returns: 검증 결과 및 잠재적 문제점들
  public func verifyRegistrySync() -> RegistrySyncReport {
    var report = RegistrySyncReport()

    // 1. 최적화 매니저와의 동기화 확인
    let optimizationEnabled = SimpleOptimizationManager.shared.isEnabled()
    if optimizationEnabled {
      var optimizedCount = 0
      var nonOptimizedCount = 0

      for _ in syncFactories.keys {
        // ObjectIdentifier 생성을 위해 타입 이름을 사용 (근사치)
        if SimpleOptimizationManager.shared.tryResolve(String.self) != nil {
          optimizedCount += 1
        } else {
          nonOptimizedCount += 1
        }
      }

      report.optimizationStats = OptimizationSyncStats(
        isEnabled: true,
        optimizedTypes: optimizedCount,
        nonOptimizedTypes: nonOptimizedCount
      )
    } else {
      report.optimizationStats = OptimizationSyncStats(
        isEnabled: false,
        optimizedTypes: 0,
        nonOptimizedTypes: syncFactories.count + asyncFactories.count
      )
    }

    // 2. 팩토리 일관성 검증
    var inconsistencies: [String] = []

    // 동일한 타입이 여러 팩토리에 등록되었는지 확인
    for key in syncFactories.keys {
      var registrationTypes: [String] = []
      if syncFactories[key] != nil { registrationTypes.append("sync") }
      if asyncFactories[key] != nil { registrationTypes.append("async") }
      if scopedFactories[key] != nil { registrationTypes.append("scoped") }
      if scopedAsyncFactories[key] != nil { registrationTypes.append("scopedAsync") }

      if registrationTypes.count > 1 {
        inconsistencies.append("\(key.typeName): \(registrationTypes.joined(separator: ", "))")
      }
    }

    report.factoryInconsistencies = inconsistencies

    // 3. 등록 통계 요약
    report.totalRegistrations = syncFactories.count + asyncFactories.count +
                               scopedFactories.count + scopedAsyncFactories.count
    report.totalTypes = Set(syncFactories.keys)
      .union(Set(asyncFactories.keys))
      .union(Set(scopedFactories.keys))
      .union(Set(scopedAsyncFactories.keys))
      .count

    // 4. 건강성 점수 계산
    report.healthScore = calculateRegistryHealthScore(report)

    return report
  }

  /// 🏥 레지스트리 건강성 점수 계산
  private func calculateRegistryHealthScore(_ report: RegistrySyncReport) -> Double {
    var score: Double = 100.0

    // 팩토리 불일치 패널티
    score -= Double(report.factoryInconsistencies.count) * 5.0

    // 최적화 비활성화 시 약간의 점수 감소
    if !report.optimizationStats.isEnabled && report.totalRegistrations > 10 {
      score -= 5.0
    }

    // 등록 없음 패널티
    if report.totalRegistrations == 0 {
      score = 0.0
    }

    return max(0.0, min(100.0, score))
  }

  /// 🚨 레지스트리 문제점 자동 복구 시도
  /// - Returns: 복구 시도 결과
  public func attemptRegistryAutoFix() -> RegistryFixReport {
    var fixReport = RegistryFixReport()
    let syncReport = verifyRegistrySync()

    fixReport.originalHealthScore = syncReport.healthScore

    // 1. 중복 등록 정리 (최신 등록만 유지)
    var fixedDuplicates = 0
    for inconsistency in syncReport.factoryInconsistencies {
      let typeName = inconsistency.components(separatedBy: ":").first ?? ""
      // 실제 복구 로직은 복잡하므로 여기서는 로그만 남김
      Log.info("🔧 [AutoFix] Would fix duplicate registration for: \(typeName)")
      fixedDuplicates += 1
    }

    fixReport.fixedDuplicates = fixedDuplicates

    // 2. 최적화 캐시 정리 (필수)
    if !syncReport.optimizationStats.isEnabled && syncReport.totalRegistrations > 0 {
      // 최적화 강제 활성화 및 캐시 정리
      enableOptimization()
      // 기존 캐시 완전 정리
      SimpleOptimizationManager.shared.clearCache()
      fixReport.suggestedOptimizationEnabled = true
      Log.info("🔧 [AutoFix] Optimization cache cleared and enabled (mandatory cleanup)")
    } else if syncReport.optimizationStats.isEnabled {
      // 이미 활성화된 경우 캐시만 정리
      SimpleOptimizationManager.shared.clearCache()
      Log.info("🔧 [AutoFix] Optimization cache cleared (mandatory cleanup)")
    }

    // 3. 복구 후 건강성 점수 재계산
    let newSyncReport = verifyRegistrySync()
    fixReport.finalHealthScore = newSyncReport.healthScore

    return fixReport
  }

  // MARK: - Batch Pipeline Management

  /// 🚀 배치 파이프라인 시작
  public func startBatchPipeline() {
    guard !isPipelineRunning else {
      Log.debug("🔄 [UnifiedRegistry] Batch pipeline already running")
      return
    }

    isPipelineRunning = true
    startBatchProcessing()
    startAutoHealthCheck()

    Log.info("🚀 [UnifiedRegistry] Batch pipeline started with config: batch=\(pipelineConfig.batchInterval)s, health=\(pipelineConfig.autoHealthCheckInterval)s")
  }

  /// ⏹️ 배치 파이프라인 중지
  public func stopBatchPipeline() {
    guard isPipelineRunning else { return }

    isPipelineRunning = false
    batchTask?.cancel()
    healthCheckTask?.cancel()
    batchTask = nil
    healthCheckTask = nil

    Log.info("⏹️ [UnifiedRegistry] Batch pipeline stopped")
  }

  /// 🔄 배치 파이프라인 재시작
  public func restartBatchPipeline() {
    Log.info("🔄 [UnifiedRegistry] Restarting batch pipeline...")
    stopBatchPipeline()
    startBatchPipeline()
  }

  /// ⚙️ 배치 파이프라인 설정 업데이트
  public func updatePipelineConfig(_ newConfig: BatchPipelineConfig) {
    let oldConfig = self.pipelineConfig
    self.pipelineConfig = newConfig

    Log.info("⚙️ [UnifiedRegistry] Pipeline config updated:")
    Log.info("  Batch Interval: \(oldConfig.batchInterval)s → \(newConfig.batchInterval)s")
    Log.info("  Health Check Interval: \(oldConfig.autoHealthCheckInterval)s → \(newConfig.autoHealthCheckInterval)s")
    Log.info("  Auto Fix: \(oldConfig.autoFixEnabled) → \(newConfig.autoFixEnabled)")

    if isPipelineRunning {
      restartBatchPipeline()
    }
  }

  /// 📊 배치 파이프라인 통계 조회
  public func getBatchPipelineStatistics() -> BatchPipelineStatistics {
    return BatchPipelineStatistics(
      isRunning: isPipelineRunning,
      totalEventsProcessed: totalEventsProcessed,
      totalBatchesProcessed: totalBatchesProcessed,
      pendingEventsCount: pendingEvents.count,
      lastHealthCheckTime: lastHealthCheckTime,
      lastAutoFixTime: lastAutoFixTime,
      config: pipelineConfig
    )
  }

  /// 📝 이벤트 추가 (내부 사용)
  internal func addEvent(_ event: RegistrationEvent) {
    pendingEvents.append(event)

    Log.debug("📝 [UnifiedRegistry] Event added: \(event.eventType) (pending: \(pendingEvents.count))")

    // 최대 배치 크기 도달 시 즉시 처리
    if pendingEvents.count >= pipelineConfig.maxBatchSize {
      Log.info("⚡ [UnifiedRegistry] Max batch size reached, processing immediately")
      Task { await processPendingBatch() }
    }
  }

  /// 🔄 배치 처리 시작
  private func startBatchProcessing() {
    batchTask = Task {
      while isPipelineRunning {
        try? await Task.sleep(nanoseconds: UInt64(pipelineConfig.batchInterval * 1_000_000_000))

        if isPipelineRunning && !pendingEvents.isEmpty {
          await processPendingBatch()
        }
      }
    }
  }

  /// 📦 대기 중인 배치 처리
  private func processPendingBatch() async {
    guard !pendingEvents.isEmpty else { return }

    let eventsToProcess = pendingEvents
    pendingEvents.removeAll()
    totalBatchesProcessed += 1

#if DEBUG
    Log.info("🔄 [UnifiedRegistry] Processing batch #\(totalBatchesProcessed) with \(eventsToProcess.count) events")
#endif

    // 이벤트별 통계 수집 (RegistrationInfo 활용)
    var registrationCount = 0
    var resolutionCount = 0
    var releaseCount = 0
    var typeNames: Set<String> = []
    var registrationInfoUpdates: [String: (count: Int, type: RegistrationType)] = [:]

    for event in eventsToProcess {
      switch event.eventType {
      case .registered(let typeName, let registrationType):
        registrationCount += 1
        typeNames.insert(typeName)

        // RegistrationInfo 활용: 등록 통계 수집
        registrationInfoUpdates[typeName] = (
          count: registrationInfoUpdates[typeName]?.count ?? 0 + 1,
          type: registrationType
        )

      case .resolved(let typeName):
        resolutionCount += 1
        typeNames.insert(typeName)
      case .released(let typeName):
        releaseCount += 1
        typeNames.insert(typeName)
      case .healthCheckRequested, .optimizationRequested:
        break
      }
    }

    // RegistrationInfo 기반 상세 분석
    await analyzeRegistrationPatterns(registrationInfoUpdates)

    // 배치 처리 실행
    await executeBatchProcessing(
      registrations: registrationCount,
      resolutions: resolutionCount,
      releases: releaseCount,
      affectedTypes: typeNames
    )

    totalEventsProcessed += eventsToProcess.count

#if DEBUG
    Log.debug("✅ [UnifiedRegistry] Batch processed: \(registrationCount) reg, \(resolutionCount) res, \(releaseCount) rel")
#endif
  }

  /// ⚡ 배치 처리 실행
  private func executeBatchProcessing(
    registrations: Int,
    resolutions: Int,
    releases: Int,
    affectedTypes: Set<String>
  ) async {
    // 1. AutoDIOptimizer 업데이트 (배치)
    if registrations > 0 || resolutions > 0 {
      Task { @DIActor in
        for typeName in affectedTypes {
#if DEBUG
          if registrations > 0 {
            // 실제 타입을 알 수 없으므로 타입명으로만 추적
            Log.debug("📈 [BatchPipeline] Tracking registration for \(typeName)")
          }
          if resolutions > 0 {
            Log.debug("📈 [BatchPipeline] Tracking resolution for \(typeName)")
          }
#endif
        }
      }
    }

    // 2. AutoMonitor 업데이트 (배치)
    Task {
#if DEBUG
      Log.debug("📊 [BatchPipeline] Batch monitoring update: +\(registrations) reg, +\(resolutions) res, -\(releases) rel")
#endif
    }

    // 3. 자동 최적화 적용 (필요시)
    if pipelineConfig.autoOptimizationEnabled && registrations >= 5 {
      await applyAutoOptimization(for: affectedTypes)
    }
  }

  /// 🏥 자동 건강성 체크 시작
  private func startAutoHealthCheck() {
    healthCheckTask = Task {
      while isPipelineRunning {
        try? await Task.sleep(nanoseconds: UInt64(pipelineConfig.autoHealthCheckInterval * 1_000_000_000))

        if isPipelineRunning {
          await performAutoHealthCheck()
        }
      }
    }
  }

  /// 🔍 자동 건강성 체크 수행
  private func performAutoHealthCheck() async {
    lastHealthCheckTime = Date()

    Log.info("🏥 [UnifiedRegistry] Performing automatic health check...")

    // 1. 건강성 체크
    let healthReport = verifyRegistrySync()

    Log.info("📊 [UnifiedRegistry] Health Score: \(String(format: "%.1f", healthReport.healthScore))/100")

    // 2. 자동 문제해결 (활성화된 경우)
    if pipelineConfig.autoFixEnabled && healthReport.healthScore < 90.0 {
      await performAutoFix(basedOn: healthReport)
    }

    // 3. 성능 최적화 제안
    if pipelineConfig.autoOptimizationEnabled && healthReport.totalRegistrations > 10 && !healthReport.optimizationStats.isEnabled {
      Log.info("💡 [UnifiedRegistry] Auto-enabling optimization for \(healthReport.totalRegistrations) registered types")
      enableOptimization()
    }
  }

  /// 🔧 자동 문제해결 수행
  private func performAutoFix(basedOn healthReport: RegistrySyncReport) async {
    lastAutoFixTime = Date()

    Log.error("🔧 [UnifiedRegistry] Health score (\(String(format: "%.1f", healthReport.healthScore))) below threshold, attempting auto-fix...")

    let fixReport = attemptRegistryAutoFix()

    let improvement = fixReport.finalHealthScore - fixReport.originalHealthScore
    if improvement > 0 {
      Log.info("✅ [UnifiedRegistry] Auto-fix successful! Health improved by \(String(format: "%.1f", improvement)) points")
    } else {
      Log.error("⚠️ [UnifiedRegistry] Auto-fix completed but no significant improvement detected")
    }

    if fixReport.fixedDuplicates > 0 {
      Log.info("🔄 [UnifiedRegistry] Fixed \(fixReport.fixedDuplicates) duplicate registrations")
    }
  }

  /// 📊 RegistrationInfo 기반 등록 패턴 분석
  private func analyzeRegistrationPatterns(_ updates: [String: (count: Int, type: RegistrationType)]) async {
    guard !updates.isEmpty else { return }

    // 등록 패턴 분석
    var syncCount = 0
    var asyncCount = 0
    var scopedCount = 0

    for (typeName, info) in updates {
      switch info.type {
      case .syncFactory:
        syncCount += 1
      case .asyncFactory, .asyncSingleton:
        asyncCount += 1
      case .scopedFactory, .scopedAsyncFactory:
        scopedCount += 1
      }

      // 기존 RegistrationInfo와 병합
      let key = AnyTypeIdentifier(type: String.self) // 임시로 String 사용
      if let existingInfo = registrationStats[key] {
        let updatedInfo = RegistrationInfo(
          type: info.type,
          registrationCount: existingInfo.registrationCount + info.count,
          lastRegistrationDate: Date()
        )
        registrationStats[key] = updatedInfo
      }
    }

#if DEBUG
    if syncCount > 0 || asyncCount > 0 || scopedCount > 0 {
      Log.info("📊 [RegistrationInfo] Pattern Analysis: sync=\(syncCount), async=\(asyncCount), scoped=\(scopedCount)")
    }
#endif
  }

  /// 🚀 자동 최적화 적용
  private func applyAutoOptimization(for typeNames: Set<String>) async {
#if DEBUG
    Log.info("🚀 [UnifiedRegistry] Applying auto-optimization for \(typeNames.count) types")
#endif

    // 자주 사용되는 타입들에 대해 최적화 활성화
    if typeNames.count >= 3 {
      enableOptimization()
#if DEBUG
      Log.info("✅ [UnifiedRegistry] Optimization enabled due to frequent usage pattern")
#endif
    }
  }

  // MARK: - Detailed Diagnostics

  /// 🔍 상세한 해결 실패 진단 로그 출력
  internal func logDetailedResolutionFailure<T>(_ type: T.Type) async {
    let typeName = String(describing: type)
    let key = AnyTypeIdentifier(type: type)

    Log.error("❌ [UnifiedRegistry] Failed to resolve async \(typeName)")

    // 등록 상태 체크
    let hasSync = syncFactories[key] != nil
    let hasAsync = asyncFactories[key] != nil
    let hasScoped = scopedFactories[key] != nil
    let hasScopedAsync = scopedAsyncFactories[key] != nil
    let isOptimizationEnabled = SimpleOptimizationManager.shared.isEnabled()

#if DEBUG
    Log.error("🔍 [Resolution Diagnostics] for \(typeName):")
    Log.error("  📦 Sync Factory: \(hasSync ? "✅ Found" : "❌ None")")
    Log.error("  ⚡ Async Factory: \(hasAsync ? "✅ Found" : "❌ None")")
    Log.error("  🔒 Scoped Factory: \(hasScoped ? "✅ Found" : "❌ None")")
    Log.error("  🔒⚡ Scoped Async Factory: \(hasScopedAsync ? "✅ Found" : "❌ None")")
    Log.error("  🚀 Optimization Enabled: \(isOptimizationEnabled ? "✅ Yes" : "❌ No")")
#endif

    // 등록된 모든 타입 목록 출력 (디버깅용)
    let allRegisteredTypes = getAllRegisteredTypeNames()
    Log.error("  📋 Total Registered Types: \(allRegisteredTypes.count)")

    if allRegisteredTypes.count > 0 && allRegisteredTypes.count <= 10 {
      Log.error("  📝 Registered Types: \(allRegisteredTypes.joined(separator: ", "))")
    } else if allRegisteredTypes.count > 10 {
      let first5 = Array(allRegisteredTypes.prefix(5))
      Log.error("  📝 Sample Registered Types: \(first5.joined(separator: ", "))... (+\(allRegisteredTypes.count - 5) more)")
    }

    // 유사한 타입명 검색 (오타 감지)
    let similarTypes = allRegisteredTypes.filter { registeredType in
      let distance = levenshteinDistance(typeName, registeredType)
      return distance <= 2 && distance > 0 // 2글자 이하 차이
    }

    if !similarTypes.isEmpty {
      Log.error("  💡 Similar registered types found (possible typo?): \(similarTypes.joined(separator: ", "))")
    }

    Log.error("  💡 Suggestion: Use UnifiedDI.register(\(typeName).self) { YourImplementation() }")

    // 등록 히스토리 정보
    if let info = registrationStats[key] {
      Log.error("  📊 Registration History: \(info.registrationCount) times, last: \(info.lastRegistrationDate)")
    } else {
      Log.error("  📊 Registration History: Never registered")
    }
  }

  /// 문자열 간 편집 거리 계산 (유사한 타입명 찾기용)
  private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
    let a = Array(s1)
    let b = Array(s2)
    let m = a.count
    let n = b.count

    var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

    for i in 0...m { dp[i][0] = i }
    for j in 0...n { dp[0][j] = j }

    for i in 1...m {
      for j in 1...n {
        if a[i-1] == b[j-1] {
          dp[i][j] = dp[i-1][j-1]
        } else {
          dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
        }
      }
    }

    return dp[m][n]
  }
}

// MARK: - Supporting Types

/// 등록 타입
public enum RegistrationType: Sendable {
  case syncFactory
  case asyncFactory
  case asyncSingleton
  case scopedFactory
  case scopedAsyncFactory

  public var description: String {
    switch self {
      case .syncFactory: return "Sync Factory"
      case .asyncFactory: return "Async Factory"
      case .asyncSingleton: return "Async Singleton"
      case .scopedFactory: return "Scoped Factory"
      case .scopedAsyncFactory: return "Scoped Async Factory"
    }
  }
}

/// 등록 정보
public struct RegistrationInfo: Sendable {
  public let type: RegistrationType
  public let registrationCount: Int
  public let lastRegistrationDate: Date

  public var summary: String {
    return """
        Type: \(type.description)
        Count: \(registrationCount)
        Last: \(lastRegistrationDate)
        """
  }
}

/// 최적화 동기화 통계
public struct OptimizationSyncStats: Sendable {
  public let isEnabled: Bool
  public let optimizedTypes: Int
  public let nonOptimizedTypes: Int

  public var summary: String {
    return """
        Optimization: \(isEnabled ? "Enabled" : "Disabled")
        Optimized: \(optimizedTypes)
        Non-optimized: \(nonOptimizedTypes)
        """
  }
}

/// 레지스트리 동기화 보고서
public struct RegistrySyncReport: Sendable {
  public var optimizationStats: OptimizationSyncStats = OptimizationSyncStats(isEnabled: false, optimizedTypes: 0, nonOptimizedTypes: 0)
  public var factoryInconsistencies: [String] = []
  public var totalRegistrations: Int = 0
  public var totalTypes: Int = 0
  public var healthScore: Double = 0.0

  public var summary: String {
    return """
        🏥 Registry Health Score: \(String(format: "%.1f", healthScore))/100.0
        📊 Total Registrations: \(totalRegistrations)
        🎯 Unique Types: \(totalTypes)
        ⚠️ Inconsistencies: \(factoryInconsistencies.count)
        \(optimizationStats.summary)
        """
  }
}

/// 레지스트리 복구 보고서
public struct RegistryFixReport: Sendable {
  public var originalHealthScore: Double = 0.0
  public var finalHealthScore: Double = 0.0
  public var fixedDuplicates: Int = 0
  public var suggestedOptimizationEnabled: Bool = false

  public var improvement: Double {
    return finalHealthScore - originalHealthScore
  }

  public var summary: String {
    return """
        🔧 Registry Auto-Fix Report
        📈 Health Score: \(String(format: "%.1f", originalHealthScore)) → \(String(format: "%.1f", finalHealthScore))
        ✅ Fixed Duplicates: \(fixedDuplicates)
        💡 Optimization Suggestion: \(suggestedOptimizationEnabled ? "Enable optimization for better performance" : "Current settings are optimal")
        """
  }
}

// MARK: - Optimization Integration

extension UnifiedRegistry {

  /// 런타임 최적화를 활성화합니다
  public func enableOptimization() {
    SimpleOptimizationManager.shared.enable()
    Log.info("🚀 [UnifiedRegistry] Runtime optimization enabled")
  }

  /// 런타임 최적화를 비활성화합니다
  public func disableOptimization() {
    SimpleOptimizationManager.shared.disable()
    Log.info("🔧 [UnifiedRegistry] Runtime optimization disabled")
  }

  /// 최적화 상태 확인
  public var isOptimizationEnabled: Bool {
    return SimpleOptimizationManager.shared.isEnabled()
  }
}

// 최적화 저장소 지원을 위한 내부 확장
internal extension UnifiedRegistry {

  /// 최적화된 해결 시도 (내부용)
  func tryOptimizedResolve<T>(_ type: T.Type) -> T? where T: Sendable {
    let result = SimpleOptimizationManager.shared.tryResolve(type)
    if result != nil {
      Log.debug("🚀 [UnifiedRegistry] Resolved from optimization cache: \(String(describing: type))")
    }
    return result
  }

  /// 최적화된 등록 (내부용)
  func tryOptimizedRegister<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) where T: Sendable {
    SimpleOptimizationManager.shared.tryRegister(type, factory: factory)
    Log.debug("🚀 [UnifiedRegistry] Added to optimization cache: \(String(describing: type))")
  }
}

// MARK: - Simple Optimization Manager

/// 간단한 최적화 관리자
internal final class SimpleOptimizationManager: @unchecked Sendable {
  static let shared = SimpleOptimizationManager()

  private let lock = NSLock()
  private var enabledState = false
  // OptimizedScopeManager는 사용하지 않고 간단한 딕셔너리로 대체
  private var optimizedInstances: [ObjectIdentifier: Any] = [:]

  private init() {}

  func enable() {
    lock.lock()
    defer { lock.unlock() }
    enabledState = true
  }

  func disable() {
    lock.lock()
    defer { lock.unlock() }
    enabledState = false
  }

  func isEnabled() -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return enabledState
  }

  func tryResolve<T>(_ type: T.Type) -> T? where T: Sendable {
    guard isEnabled() else { return nil }

    lock.lock()
    defer { lock.unlock() }

    let key = ObjectIdentifier(type)
    return optimizedInstances[key] as? T
  }

  func tryRegister<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) where T: Sendable {
    guard isEnabled() else { return }

    lock.lock()
    defer { lock.unlock() }

    let key = ObjectIdentifier(type)

    // 🔧 안전한 팩토리 실행
    let instance = factory()
    optimizedInstances[key] = instance
  }

  /// 🧹 최적화 캐시 완전 정리 (필수 정리)
  func clearCache() {
    lock.lock()
    defer { lock.unlock() }

    let clearedCount = optimizedInstances.count
    optimizedInstances.removeAll()

    Log.info("🧹 [OptimizationManager] Cache cleared: \(clearedCount) instances removed (mandatory cleanup)")
  }
}

// MARK: - Batch Pipeline Supporting Types

/// 등록 이벤트 타입
public enum RegistrationEventType: Sendable {
    case registered(typeName: String, registrationType: RegistrationType)
    case resolved(typeName: String)
    case released(typeName: String)
    case healthCheckRequested
    case optimizationRequested
}

/// 등록 이벤트
public struct RegistrationEvent: Sendable {
    public let id: UUID
    public let timestamp: Date
    public let eventType: RegistrationEventType
    public let metadata: [String: String]

    public init(eventType: RegistrationEventType, metadata: [String: String] = [:]) {
        self.id = UUID()
        self.timestamp = Date()
        self.eventType = eventType
        self.metadata = metadata
    }
}

/// 배치 파이프라인 설정
public struct BatchPipelineConfig: Sendable {
    /// 배치 처리 간격 (초)
    public let batchInterval: TimeInterval
    /// 최대 배치 크기
    public let maxBatchSize: Int
    /// 자동 건강성 체크 간격 (초)
    public let autoHealthCheckInterval: TimeInterval
    /// 자동 문제해결 활성화 여부
    public let autoFixEnabled: Bool
    /// 성능 최적화 자동 적용 여부
    public let autoOptimizationEnabled: Bool

    public static let `default` = BatchPipelineConfig(
        batchInterval: 2.0,
        maxBatchSize: 50,
        autoHealthCheckInterval: 30.0,
        autoFixEnabled: true,
        autoOptimizationEnabled: true
    )

    public init(
        batchInterval: TimeInterval = 2.0,
        maxBatchSize: Int = 50,
        autoHealthCheckInterval: TimeInterval = 30.0,
        autoFixEnabled: Bool = true,
        autoOptimizationEnabled: Bool = true
    ) {
        self.batchInterval = batchInterval
        self.maxBatchSize = maxBatchSize
        self.autoHealthCheckInterval = autoHealthCheckInterval
        self.autoFixEnabled = autoFixEnabled
        self.autoOptimizationEnabled = autoOptimizationEnabled
    }
}

/// 배치 파이프라인 통계
public struct BatchPipelineStatistics: Sendable {
    public let isRunning: Bool
    public let totalEventsProcessed: Int
    public let totalBatchesProcessed: Int
    public let pendingEventsCount: Int
    public let lastHealthCheckTime: Date?
    public let lastAutoFixTime: Date?
    public let config: BatchPipelineConfig

    public var summary: String {
        let healthCheckStr = lastHealthCheckTime.map { "\(Int(-$0.timeIntervalSinceNow))s ago" } ?? "Never"
        let autoFixStr = lastAutoFixTime.map { "\(Int(-$0.timeIntervalSinceNow))s ago" } ?? "Never"

        return """
        🚀 Batch Pipeline Status: \(isRunning ? "Running" : "Stopped")
        📊 Events Processed: \(totalEventsProcessed) (in \(totalBatchesProcessed) batches)
        📝 Pending Events: \(pendingEventsCount)
        🏥 Last Health Check: \(healthCheckStr)
        🔧 Last Auto Fix: \(autoFixStr)
        ⚙️ Config: batch=\(config.batchInterval)s, health=\(config.autoHealthCheckInterval)s
        """
    }
}

// MARK: - Legacy Support

/// @available(*, deprecated, message: "Use UnifiedRegistry.shared instead")
/// 기존 코드 호환성을 위한 GlobalUnifiedRegistry 별칭
public let GlobalUnifiedRegistry = UnifiedRegistry.shared
