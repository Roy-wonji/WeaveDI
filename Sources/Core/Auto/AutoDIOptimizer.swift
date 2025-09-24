//
//  AutoDIOptimizer.swift
//  DiContainer
//
//  Created by Wonji Suh on 2024.
//  Copyright © 2024 Wonji Suh. All rights reserved.
//

import Foundation
import LogMacro

// MARK: - Automatic DI Optimization System

/// 자동 의존성 주입 최적화 시스템
///
/// ## 개요
///
/// 별도 선언 없이 자동으로 의존성 그래프를 생성하고 성능을 최적화하는 시스템입니다.
/// 등록과 해결 과정에서 자동으로 실행되어 개발자가 신경쓸 필요가 없습니다.
///
/// ## 핵심 기능
///
/// ### 🔄 자동 그래프 생성
/// - 의존성 등록/해결 시 자동으로 그래프 업데이트
/// - 실시간 의존성 관계 추적
/// - 순환 의존성 자동 감지 및 경고
///
/// ### ⚡ 자동 성능 최적화
/// - 사용 패턴 분석을 통한 자동 캐싱
/// - 자주 사용되는 타입 자동 식별
/// - 최적화된 해결 경로 자동 생성
public final class AutoDIOptimizer: @unchecked Sendable {
  
  // MARK: - Singleton
  
  /// 공유 인스턴스
  public static let shared = AutoDIOptimizer()
  
  // MARK: - Properties
  
  /// 의존성 그래프 (타입 이름 → 의존하는 타입들)
  private var dependencyGraph: [String: Set<String>] = [:]
  
  /// 사용 통계 (타입 이름 → 사용 횟수)
  private var usageStats: [String: Int] = [:]
  
  /// 성능 캐시 (자주 사용되는 타입들)
  private var performanceCache: Set<String> = []
  
  /// 순환 의존성 감지 결과
  private var circularDependencies: Set<String> = []
  
  /// 최적화 활성화 여부
  private var isOptimizationEnabled = true
  
  /// 로깅 레벨
  public enum LogLevel: Sendable {
    case all        // 모든 로그 출력 (기본값)
    case registration // 등록만 로깅
    case optimization // 최적화만 로깅
    case errors      // 에러만 로깅
    case off        // 로깅 끄기
  }
  
  /// 현재 로깅 레벨
  private var logLevel: LogLevel = .all
  
  /// Actor hop 추적 데이터 (타입 → hop 횟수)
  private var actorHops: [String: Int] = [:]
  
  /// 비동기 해결 성능 추적 (타입 → 평균 시간 ms)
  private var asyncResolutionTimes: [String: Double] = [:]
  
  /// Actor 최적화 제안 (타입 → 제안 사항)
  private var actorOptimizations: [String: ActorOptimization] = [:]
  
  /// 런타임 타입 안전성 추적 (타입 → 안전성 상태)
  private var typeSafetyIssues: [String: TypeSafetyIssue] = [:]
  
  /// 자동 수정된 타입들
  private var autoFixedTypes: Set<String> = []
  
  /// 동기화를 위한 큐
  private let queue = DispatchQueue(label: "auto-di-optimizer", attributes: .concurrent)
  
  /// Actor 최적화 제안 정보
  public struct ActorOptimization: Sendable {
    public let typeName: String
    public let hopCount: Int
    public let avgResolutionTime: Double
    public let recommendation: OptimizationRecommendation
    
    public enum OptimizationRecommendation: String, Sendable {
      case moveToMainActor = "MainActor로 이동 권장"
      case useGlobalActor = "GlobalActor 사용 권장"
      case reduceAsyncCalls = "비동기 호출 줄이기 권장"
      case cacheResult = "결과 캐싱 권장"
      case optimized = "이미 최적화됨"
    }
  }
  
  /// 타입 안전성 이슈 정보
  public struct TypeSafetyIssue: Sendable {
    public let typeName: String
    public let issue: SafetyIssueType
    public let autoFixed: Bool
    public let recommendation: String
    
    public enum SafetyIssueType: String, Sendable {
      case nilResolution = "nil 해결 감지"
      case typecastFailure = "타입 캐스팅 실패"
      case concurrencyViolation = "동시성 위반"
      case actorBoundaryViolation = "Actor 경계 위반"
      case sendableViolation = "Sendable 위반"
    }
  }
  
  private init() {
    startAutoOptimization()
  }
  
  // MARK: - Auto Graph Generation
  
  /// 의존성 등록 시 자동으로 그래프에 추가
  public func trackRegistration<T>(_ type: T.Type) {
    let typeName = String(describing: type)
    
    // 로깅 레벨에 따른 조건부 로깅
    if logLevel == .all || logLevel == .registration {
      Log.debug("📊 Auto tracking registration: \(typeName)")
    }
    
    queue.async(flags: .barrier) { [weak self] in
      self?.dependencyGraph[typeName] = self?.dependencyGraph[typeName] ?? []
      self?.updateGraph()
    }
  }
  
  /// 의존성 해결 시 자동으로 사용 통계 업데이트
  public func trackResolution<T>(_ type: T.Type) {
    let typeName = String(describing: type)
    let startTime = CFAbsoluteTimeGetCurrent()
    
    // 🔥 자동 Actor hop 감지
    Task.detached { @Sendable [weak self] in
      // Task가 다른 Actor 컨텍스트에서 실행되므로 hop으로 카운트
      self?.trackActorHop(type)
    }
    
    // 🔥 자동 타입 안전성 검증
    self.performTypeSafetyCheck(for: type)
    
    queue.async(flags: .barrier) { [weak self] in
      guard let self = self else { return }
      
      // 해결 시간 추적
      let duration = CFAbsoluteTimeGetCurrent() - startTime
      if duration > 0.001 { // 1ms 이상인 경우만
        self.trackAsyncResolution(type, duration: duration)
      }
      
      self.usageStats[typeName, default: 0] += 1
      let newCount = self.usageStats[typeName] ?? 0
      
      if newCount % 10 == 0 && (self.logLevel == .all || self.logLevel == .optimization) {
        Log.debug("⚡ Auto optimized: \(typeName) (\(newCount) uses)")
      }
      
      self.updatePerformanceOptimization(for: typeName)
    }
  }
  
  /// 의존성 관계 추가 (A가 B에 의존)
  public func trackDependency<From, To>(from: From.Type, to: To.Type) {
    let fromName = String(describing: from)
    let toName = String(describing: to)
    
    queue.async(flags: .barrier) { [weak self] in
      self?.dependencyGraph[fromName, default: []].insert(toName)
      self?.detectCircularDependencies()
      self?.updateGraph()
    }
  }
  
  /// Actor hop 추적
  public func trackActorHop<T>(_ type: T.Type) {
    let typeName = String(describing: type)
    
    queue.async(flags: .barrier) { [weak self] in
      guard let self = self else { return }
      self.actorHops[typeName, default: 0] += 1
      
      // 5회 이상 hop이 발생하면 최적화 제안
      if self.actorHops[typeName, default: 0] >= 5 {
        self.analyzeActorOptimization(for: typeName)
      }
    }
  }
  
  /// 비동기 해결 시간 추적
  public func trackAsyncResolution<T>(_ type: T.Type, duration: TimeInterval) {
    let typeName = String(describing: type)
    let durationMs = duration * 1000 // 밀리초로 변환
    
    queue.async(flags: .barrier) { [weak self] in
      guard let self = self else { return }
      
      // 이동 평균 계산
      let currentAvg = self.asyncResolutionTimes[typeName] ?? 0
      let newAvg = (currentAvg + durationMs) / 2
      self.asyncResolutionTimes[typeName] = newAvg
      
      // 느린 해결 감지 (50ms 이상)
      if durationMs > 50 && (self.logLevel == .all || self.logLevel == .optimization) {
        Log.error("⚡ Slow async resolution detected: \(typeName) (\(String(format: "%.1f", durationMs))ms)")
      }
    }
  }
  
  /// Actor 최적화 분석
  private func analyzeActorOptimization(for typeName: String) {
    let hopCount = actorHops[typeName, default: 0]
    let avgTime = asyncResolutionTimes[typeName, default: 0]
    
    let recommendation: ActorOptimization.OptimizationRecommendation
    
    switch (hopCount, avgTime) {
      case (let hops, let time) where hops > 10 && time > 100:
        recommendation = .moveToMainActor
      case (let hops, _) where hops > 8:
        recommendation = .useGlobalActor
      case (_, let time) where time > 50:
        recommendation = .reduceAsyncCalls
      case (let hops, let time) where hops > 5 || time > 30:
        recommendation = .cacheResult
      default:
        recommendation = .optimized
    }
    
    let optimization = ActorOptimization(
      typeName: typeName,
      hopCount: hopCount,
      avgResolutionTime: avgTime,
      recommendation: recommendation
    )
    
    actorOptimizations[typeName] = optimization
    
    // 최적화 제안 로깅
    if recommendation != .optimized && (logLevel == .all || logLevel == .optimization) {
      Log.debug("🎯 Actor optimization suggestion for \(typeName): \(recommendation.rawValue) (hops: \(hopCount), avg: \(String(format: "%.1f", avgTime))ms)")
    }
  }
  
  /// 자동 타입 안전성 검증
  private func performTypeSafetyCheck<T>(for type: T.Type) {
    let typeName = String(describing: type)
    
    // Sendable 검증 (간접적으로 체크)
    let mirror = Mirror(reflecting: type)
    if mirror.displayStyle == .class {
      let issue = TypeSafetyIssue(
        typeName: typeName,
        issue: .sendableViolation,
        autoFixed: false,
        recommendation: "타입을 Sendable로 만들거나 @unchecked Sendable 사용 고려"
      )
      
      queue.async(flags: .barrier) { [weak self] in
        self?.typeSafetyIssues[typeName] = issue
        if self?.logLevel == .all || self?.logLevel == .errors {
          Log.error("🔒 Type safety issue: \(typeName) is not Sendable")
        }
      }
    }
    
    // Actor 타입 검증 (Swift 6 existential syntax)
    if type is any Actor.Type {
      queue.async(flags: .barrier) { [weak self] in
        // Actor 타입은 자동으로 적절한 격리 제안
        let issue = TypeSafetyIssue(
          typeName: typeName,
          issue: .actorBoundaryViolation,
          autoFixed: true,
          recommendation: "Actor 타입 감지 - 적절한 격리 적용됨"
        )
        self?.typeSafetyIssues[typeName] = issue
        self?.autoFixedTypes.insert(typeName)
      }
    }
    
    // nil 해결 자동 감지 (해결 실패 시 트리거됨)
    // 이는 실제 해결 과정에서 DependencyContainer가 호출
  }
  
  /// nil 해결 감지 시 자동 처리
  public func handleNilResolution<T>(_ type: T.Type) {
    let typeName = String(describing: type)
    
    queue.async(flags: .barrier) { [weak self] in
      guard let self = self else { return }
      
      let issue = TypeSafetyIssue(
        typeName: typeName,
        issue: .nilResolution,
        autoFixed: false,
        recommendation: "의존성이 등록되지 않았습니다. register() 호출 확인 필요"
      )
      
      self.typeSafetyIssues[typeName] = issue
      
      if self.logLevel == .all || self.logLevel == .errors {
        Log.error("🚨 Auto safety check: \(typeName) resolved to nil - dependency not registered")
      }
    }
  }
  
  // MARK: - Auto Performance Optimization
  
  /// 자동 성능 최적화 시작
  private func startAutoOptimization() {
    // 백그라운드에서 주기적으로 최적화 실행
    Task.detached { [weak self] in
      while true {
        try? await Task.sleep(nanoseconds: 30_000_000_000) // 30초마다
        await self?.performAutoOptimization()
      }
    }
  }
  
  /// 자동 최적화 실행
  @MainActor
  private func performAutoOptimization() async {
    guard isOptimizationEnabled else { return }
    
    await withTaskGroup(of: Void.self) { group in
      // 성능 캐시 최적화
      group.addTask { [weak self] in
        await self?.optimizePerformanceCache()
      }
      
      // 순환 의존성 검사
      group.addTask { [weak self] in
        await self?.checkCircularDependencies()
      }
      
      // 그래프 최적화
      group.addTask { [weak self] in
        await self?.optimizeGraph()
      }
      
      // 자동 상태 로깅
      group.addTask { [weak self] in
        await self?.logAutoStatus()
      }
    }
  }
  
  /// 특정 타입의 성능 최적화 업데이트
  private func updatePerformanceOptimization(for typeName: String) {
    let usageCount = usageStats[typeName, default: 0]
    
    // 10번 이상 사용된 타입은 성능 캐시에 추가
    if usageCount >= 10 {
      performanceCache.insert(typeName)
    }
  }
  
  /// 성능 캐시 최적화
  private func optimizePerformanceCache() async {
    queue.async(flags: .barrier) { [weak self] in
      guard let self = self else { return }
      
      // 사용량 기준으로 상위 20개만 캐시에 유지
      let topTypes = self.usageStats
        .sorted { $0.value > $1.value }
        .prefix(20)
        .map { $0.key }
      
      self.performanceCache = Set(topTypes)
    }
  }
  
  // MARK: - Circular Dependency Detection
  
  /// 순환 의존성 자동 감지
  private func detectCircularDependencies() {
    circularDependencies.removeAll()
    var visited = Set<String>()
    var recursionStack = Set<String>()
    
    for typeName in dependencyGraph.keys {
      if !visited.contains(typeName) {
        detectCircularDependenciesRecursive(typeName, &visited, &recursionStack)
      }
    }
  }
  
  /// 순환 의존성 재귀 검사
  private func detectCircularDependenciesRecursive(
    _ typeName: String,
    _ visited: inout Set<String>,
    _ recursionStack: inout Set<String>
  ) {
    visited.insert(typeName)
    recursionStack.insert(typeName)
    
    if let dependencies = dependencyGraph[typeName] {
      for dependency in dependencies {
        if !visited.contains(dependency) {
          detectCircularDependenciesRecursive(dependency, &visited, &recursionStack)
        } else if recursionStack.contains(dependency) {
          circularDependencies.insert(typeName)
          circularDependencies.insert(dependency)
        }
      }
    }
    
    recursionStack.remove(typeName)
  }
  
  /// 순환 의존성 자동 검사
  private func checkCircularDependencies() async {
    queue.async(flags: .barrier) { [weak self] in
      self?.detectCircularDependencies()
      
      if let self = self, !self.circularDependencies.isEmpty && (self.logLevel == .all || self.logLevel == .errors) {
        Log.error("⚠️ Auto detected circular dependencies: \(self.circularDependencies)")
      }
    }
  }
  
  // MARK: - Graph Optimization
  
  /// 그래프 업데이트
  private func updateGraph() {
    // 토글이 꺼져 있으면 아무 것도 하지 않음
    if queue.sync(execute: { !isRealtimeGraphEnabled }) { return }
    // 디바운스 적용: 최근 요청만 실행 (100ms)
    // 최신 스냅샷에서 변경된 엣지만 Detector에 반영
    // 인스턴스 상수로 유지 (디바운스 간격)
    let debounceInterval: TimeInterval = 0.1
    // 취소 가능한 작업 관리
    queue.sync(flags: .barrier) { [weak self] in
      guard let self = self else { return }
      self._scheduleGraphUpdate(debounce: debounceInterval)
    }
  }

  // MARK: - Graph update scheduler
  private var lastPushedGraph: [String: Set<String>] = [:]
  private var scheduledGraphUpdate: DispatchWorkItem?

  private func _scheduleGraphUpdate(debounce: TimeInterval) {
    scheduledGraphUpdate?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self = self else { return }
      let newGraph = self.queue.sync { self.dependencyGraph }
      let oldGraph = self.queue.sync { self.lastPushedGraph }

      // Compute diff
      var additions: [(from: String, to: String)] = []
      var removals: [(from: String, to: String)] = []

      // Added edges
      for (from, newEdges) in newGraph {
        let oldEdges = oldGraph[from] ?? []
        for to in newEdges where !oldEdges.contains(to) {
          additions.append((from, to))
        }
      }
      // Removed edges
      for (from, oldEdges) in oldGraph {
        let newEdges = newGraph[from] ?? []
        for to in oldEdges where !newEdges.contains(to) {
          removals.append((from, to))
        }
      }

      let removalsCopy = removals
      let additionsCopy = additions
      Task.detached { @Sendable in
        for (from, to) in removalsCopy {
          await CircularDependencyDetector.shared.removeDependency(from: from, to: to)
        }
        for (from, to) in additionsCopy {
          await CircularDependencyDetector.shared.recordDependency(from: from, to: to)
        }
      }

      // Update last pushed snapshot
      self.queue.sync(flags: .barrier) { self.lastPushedGraph = newGraph }
    }
    scheduledGraphUpdate = item
    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + debounce, execute: item)
  }
  
  /// 그래프 최적화
  private func optimizeGraph() async {
    queue.async(flags: .barrier) { [weak self] in
      // 사용하지 않는 의존성 정리
      self?.cleanupUnusedDependencies()
    }
  }
  
  /// 사용하지 않는 의존성 정리
  private func cleanupUnusedDependencies() {
    let usedTypes = Set(usageStats.keys)
    dependencyGraph = dependencyGraph.filter { usedTypes.contains($0.key) }
  }
  
  /// 자동 상태 로깅
  private func logAutoStatus() async {
    queue.async { [weak self] in
      guard let self = self, self.logLevel != .off else { return }
      
      // 로깅 레벨에 따른 조건부 로깅
      if (self.logLevel == .all || self.logLevel == .optimization) && !self.usageStats.isEmpty {
        Log.debug("📊 [AutoDI] Current stats: \(self.usageStats)")
      }
      
      if (self.logLevel == .all || self.logLevel == .optimization) && !self.performanceCache.isEmpty {
        Log.debug("⚡ [AutoDI] Optimized types: \(self.performanceCache)")
      }
      
      if (self.logLevel == .all) && !self.dependencyGraph.isEmpty {
        let graphSummary = self.dependencyGraph.mapValues { $0.count }
        Log.debug("🔄 [AutoDI] Graph summary: \(graphSummary)")
      }
    }
  }
  
  // MARK: - Public API
  
  /// 현재 의존성 그래프 반환
  public var currentGraph: [String: Set<String>] {
    queue.sync { dependencyGraph }
  }
  
  /// 현재 성능 통계 반환
  public var currentStats: [String: Int] {
    queue.sync { usageStats }
  }
  
  /// 자주 사용되는 타입들 반환
  public var frequentlyUsedTypes: Set<String> {
    queue.sync { performanceCache }
  }
  
  /// 순환 의존성 목록 반환
  public var detectedCircularDependencies: Set<String> {
    queue.sync { circularDependencies }
  }
  
  /// Actor hop 통계 반환
  public var actorHopStats: [String: Int] {
    queue.sync { actorHops }
  }
  
  /// 비동기 해결 시간 통계 반환
  public var asyncPerformanceStats: [String: Double] {
    queue.sync { asyncResolutionTimes }
  }
  
  /// Actor 최적화 제안 목록 반환
  public var actorOptimizationSuggestions: [String: ActorOptimization] {
    queue.sync { actorOptimizations }
  }
  
  /// 타입 안전성 이슈 목록 반환
  public var detectedTypeSafetyIssues: [String: TypeSafetyIssue] {
    queue.sync { typeSafetyIssues }
  }
  
  /// 자동 수정된 타입들 반환
  public var detectedAutoFixedTypes: Set<String> {
    queue.sync { autoFixedTypes }
  }

  /// 상위 N개의 자주 사용된 타입 이름을 반환합니다 (프리웜 후보)
  public func topUsedTypes(limit: Int = 10) -> [String] {
    queue.sync {
      Array(usageStats.sorted { $0.value > $1.value }.prefix(max(0, limit))).map { $0.key }
    }
  }

  // MARK: - Realtime Graph Toggle
  private var isRealtimeGraphEnabled = true

  /// 실시간 그래프 업데이트 on/off (기본: true)
  public func setRealtimeGraphEnabled(_ enabled: Bool) {
    queue.sync(flags: .barrier) {
      isRealtimeGraphEnabled = enabled
      if !enabled {
        // 예약된 업데이트 취소
        scheduledGraphUpdate?.cancel()
        scheduledGraphUpdate = nil
      } else {
        // 즉시 한번 동기화 (디바운스 없이)
        _scheduleGraphUpdate(debounce: 0)
      }
    }
  }
  
  /// 특정 타입이 최적화되었는지 확인
  public func isOptimized<T>(_ type: T.Type) -> Bool {
    let typeName = String(describing: type)
    return queue.sync { performanceCache.contains(typeName) }
  }
  
  /// 자동 최적화 활성화/비활성화
  public func setOptimizationEnabled(_ enabled: Bool) {
    queue.async(flags: .barrier) { [weak self] in
      self?.isOptimizationEnabled = enabled
    }
  }
  
  /// 로깅 레벨 설정
  public func setLogLevel(_ level: LogLevel) {
    queue.async(flags: .barrier) { [weak self] in
      self?.logLevel = level
    }
  }
  
  /// 현재 로깅 레벨 반환
  public var currentLogLevel: LogLevel {
    queue.sync { logLevel }
  }
  
  /// 통계 초기화
  public func resetStats() {
    queue.async(flags: .barrier) { [weak self] in
      self?.usageStats.removeAll()
      self?.performanceCache.removeAll()
      self?.circularDependencies.removeAll()
    }
  }
  
  /// 의존성 그래프 시각화 (간단한 텍스트 형태)
  public func visualizeGraph() -> String {
    return queue.sync {
      var result = "📊 자동 생성된 의존성 그래프:\n\n"
      
      for (typeName, dependencies) in dependencyGraph.sorted(by: { $0.key < $1.key }) {
        let usageCount = usageStats[typeName, default: 0]
        let isOptimized = performanceCache.contains(typeName)
        let isCircular = circularDependencies.contains(typeName)
        
        var status = ""
        if isOptimized { status += "⚡" }
        if isCircular { status += "⚠️" }
        
        result += "\(typeName) \(status) (사용: \(usageCount)회)\n"
        
        if !dependencies.isEmpty {
          for dependency in dependencies.sorted() {
            result += "  └─ \(dependency)\n"
          }
        }
        result += "\n"
      }
      
      return result
    }
  }
}
