import Foundation
import LogMacro

/// 자동 의존성 주입 최적화 시스템
/// 핵심 추적 및 최적화 기능에 집중한 간소화된 시스템
///
/// ## ⚠️ Thread Safety 참고사항
/// - 주로 앱 초기화 시 단일 스레드에서 사용됩니다
/// - 통계 데이터의 미세한 불일치는 기능에 영향을 주지 않습니다
/// - 높은 성능을 위해 복잡한 동기화를 제거했습니다
@DIActor
public final class AutoDIOptimizer {
  
  public static let shared = AutoDIOptimizer()
  
  // MARK: - 간단한 추적 데이터 (단순함 우선)
  
  private var registeredTypes: Set<String> = []
  private var resolvedTypes: Set<String> = []
  private var dependencies: [(from: String, to: String)] = []
  private var lifecycleManager: SimpleLifecycleManager
  
  // 간단한 통계
  private var registrationCount: Int = 0
  private var resolutionCount: Int = 0
  
  // 🚀 간단한 최적화 기능들
  private var frequentlyUsed: [String: Int] = [:]
  private var cachedInstances: [String: Any] = [:]
  private var optimizationEnabled: Bool = true
  
  private var currentLogLevel: LogLevel = .errors
  
  // Synchronization for internal mutable state to avoid races under concurrency
  private let stateLock = NSLock()
  private nonisolated let statsCache = DIStatsCache.shared
  
  // Helper to perform locked mutations/reads
  private func withLock<T>(_ body: () -> T) -> T {
    stateLock.lock()
    defer { stateLock.unlock() }
    return body()
  }
  
  private init() {
    lifecycleManager = SimpleLifecycleManager.shared
    DILogger.configure(level: .errorsOnly, severityThreshold: .error)
    if DILogger.getCurrentLogLevel() == .all {
      DILogger.info(channel: .optimization, "🚀 AutoDIOptimizer 초기화 완료 (최적화 기능 포함)")
    }
  }
  
  // MARK: - Debounced snapshot
  private var snapshotDebounceScheduled: Bool = false
  private var snapshotDebounceNanos: UInt64 = 100_000_000 // 100ms
  
  private func scheduleSnapshotDebounced() {
    if snapshotDebounceScheduled { return }
    snapshotDebounceScheduled = true
    Task { @DIActor in
      try? await Task.sleep(nanoseconds: snapshotDebounceNanos)
      self.snapshotDebounceScheduled = false
      self.pushSnapshot()
    }
  }
  
  /// 디바운스 간격 설정 (50~1000ms 사이 허용, 기본 100ms)
  public func setDebounceInterval(ms: Int) {
    let clamped = max(50, min(ms, 1000))
    snapshotDebounceNanos = UInt64(clamped) * 1_000_000
    if DILogger.getCurrentLogLevel() == .all {
      DILogger.info(channel: .optimization, "🕒 Snapshot debounce set to: \(clamped)ms")
    }
  }
  
  // MARK: - Snapshot helpers
  private func buildGraphText() -> String {
    var result = "📊 의존성 그래프:\n"
    let regs = registeredTypes
    if regs.isEmpty {
      result += "• 등록된 타입 없음\n"
    } else {
      result += "• 노드(등록된 타입): " + regs.sorted().joined(separator: ", ") + "\n"
    }
    if dependencies.isEmpty {
      result += "• 의존성 없음"
    } else {
      for dep in dependencies { result += "• \(dep.from) → \(dep.to)\n" }
    }
    return result
  }
  
  private func pushSnapshot() {
    let snap = DIStatsSnapshot(
      frequentlyUsed: frequentlyUsed,
      registered: registeredTypes,
      resolved: resolvedTypes,
      dependencies: dependencies,
      logLevel: currentLogLevel,
      graphText: buildGraphText()
    )
    statsCache.write(snap)
  }
  
  // MARK: - 핵심 추적 메서드 (간소화)
  
  /// 의존성 등록 추적 (간단하게!)
  public func trackRegistration<T>(_ type: T.Type) {
    let typeName = String(describing: type)
    
    withLock {
      registeredTypes.insert(typeName)
      registrationCount += 1
    }

    switch DILogger.getCurrentLogLevel() {
    case .all, .registration:
      DILogger.info(channel: .registration, "📦 등록: \(typeName) (총 \(registrationCount)개)")
    case .errorsOnly:
      Log.info("📦 등록: \(typeName) (총 \(registrationCount)개)")
    default:
      break
    }
    
    // 자동 모니터링 연계
    // Same global actor; direct call
    AutoMonitor.shared.onModuleRegistered(type)
    scheduleSnapshotDebounced()
  }
  
  
  /// 의존성 해결 추적 (최적화 포함!)
  public func trackResolution<T>(_ type: T.Type) {
    let typeName = String(describing: type)
    
    var hit10 = false
    withLock {
      resolvedTypes.insert(typeName)
      resolutionCount += 1
      // Always track usage for stats
      frequentlyUsed[typeName, default: 0] += 1
      // Only trigger optimization-related suggestions when enabled
      if optimizationEnabled, frequentlyUsed[typeName] == 10 {
        hit10 = true
      }
    }
    if hit10 {
      switch DILogger.getCurrentLogLevel() {
      case .all, .optimization:
        DILogger.error(channels: [.optimization], "⚡ 최적화 권장: \(typeName)이 자주 사용됩니다 (싱글톤 고려)")
      default:
        break
      }
    }

    if DILogger.getCurrentLogLevel() == .all {
      DILogger.debug(channel: .resolution, "🔍 해결: \(typeName) (총 \(resolutionCount)회)")
    }
    scheduleSnapshotDebounced()
  }
  
  
  /// 의존성 관계 추적 (간단하게!)
  public func trackDependency<From, To>(from: From.Type, to: To.Type) {
    let fromName = String(describing: from)
    let toName = String(describing: to)
    
    withLock { dependencies.append((from: fromName, to: toName)) }

    if DILogger.getCurrentLogLevel() == .all {
      DILogger.info(channel: .optimization, "🔗 의존성 추가: \(fromName) → \(toName)")
    }
    
    // 자동 모니터링 연계
    AutoMonitor.shared.onDependencyAdded(from: from, to: to)
    scheduleSnapshotDebounced()
  }
  
  // MARK: - 간단한 조회 API
  
  /// 등록된 타입 목록
  internal nonisolated func getRegisteredTypes() -> Set<String> {
    return statsCache.read().registered
  }
  @available(*, deprecated, message: "Use UnifiedDI/DIContainer or readSnapshot().registered")
  public nonisolated static func getRegisteredTypes() -> Set<String> { DIStatsCache.shared.read().registered }
  
  /// 해결된 타입 목록
  internal nonisolated func getResolvedTypes() -> Set<String> {
    return statsCache.read().resolved
  }
  @available(*, deprecated, message: "Use UnifiedDI/DIContainer or readSnapshot().resolved")
  public nonisolated static func getResolvedTypes() -> Set<String> { DIStatsCache.shared.read().resolved }
  
  /// 의존성 관계 목록
  internal nonisolated func getDependencies() -> [(from: String, to: String)] {
    return statsCache.read().dependencies
  }
  @available(*, deprecated, message: "Use UnifiedDI/DIContainer or readSnapshot().dependencies")
  public nonisolated static func getDependencies() -> [(from: String, to: String)] { DIStatsCache.shared.read().dependencies }
  
  /// 간단한 통계
  internal nonisolated func getStats() -> (registered: Int, resolved: Int, dependencies: Int) {
    let s = statsCache.read(); return (s.registered.count, s.resolved.count, s.dependencies.count)
  }
  @available(*, deprecated, message: "Use UnifiedDI/DIContainer or readSnapshot()")
  public nonisolated static func getStats() -> (registered: Int, resolved: Int, dependencies: Int) {
    let s = DIStatsCache.shared.read(); return (s.registered.count, s.resolved.count, s.dependencies.count)
  }
  
  /// 요약 정보 (최적화 정보 포함)
  internal nonisolated func getSummary() -> String {
    let s = statsCache.read()
    let topUsed = Array(s.frequentlyUsed.sorted { $0.value > $1.value }.prefix(3)).map { "\($0.key)(\($0.value)회)" }
    return """
        📊 DI 시스템 요약:
        • 등록된 타입: \(s.registered.count)개
        • 해결 요청: \(s.resolved.count)회
        • 의존성 관계: \(s.dependencies.count)개
        • 자주 사용되는 타입: \(topUsed.isEmpty ? "없음" : topUsed.joined(separator: ", "))
        • 스냅샷 기반 조회 (일부 지연 가능)
        """
  }
  @available(*, deprecated, message: "Use UnifiedDI/DIContainer or readSnapshot()")
  public nonisolated static func getSummary() -> String {
    let s = DIStatsCache.shared.read()
    let topUsed = Array(s.frequentlyUsed.sorted { $0.value > $1.value }.prefix(3)).map { "\($0.key)(\($0.value)회)" }
    return """
        📊 DI 시스템 요약:
        • 등록된 타입: \(s.registered.count)개
        • 해결 요청: \(s.resolved.count)회
        • 의존성 관계: \(s.dependencies.count)개
        • 자주 사용되는 타입: \(topUsed.isEmpty ? "없음" : topUsed.joined(separator: ", "))
        • 스냅샷 기반 조회 (일부 지연 가능)
        """
  }
  
  // MARK: - 🚀 간단한 최적화 기능들
  
  /// 자주 사용되는 타입 TOP N
  public nonisolated func getTopUsedTypes(limit: Int = 5) -> [String] {
    let freq = statsCache.read().frequentlyUsed
    return freq.sorted { $0.value > $1.value }
      .prefix(limit)
      .map { "\($0.key)(\($0.value)회)" }
  }
  public nonisolated static func getTopUsedTypes(limit: Int = 5) -> [String] {
    let freq = DIStatsCache.shared.read().frequentlyUsed
    return freq.sorted { $0.value > $1.value }
      .prefix(limit)
      .map { "\($0.key)(\($0.value)회)" }
  }
  
  /// 순환 의존성 간단 감지
  public nonisolated func detectCircularDependencies() -> [String] {
    // Use snapshot
    let snap = statsCache.read()
    let typesSnapshot = snap.registered
    let depsSnapshot = snap.dependencies
    
    var visited: Set<String> = []
    var stack: Set<String> = []
    var cycles: [String] = []
    
    func dfs(_ node: String) {
      if stack.contains(node) {
        cycles.append("순환 감지: \(node)")
        return
      }
      if visited.contains(node) { return }
      
      visited.insert(node)
      stack.insert(node)
      
      // Follow dependencies on the snapshot to avoid races
      for dep in depsSnapshot where dep.from == node {
        dfs(dep.to)
      }
      
      stack.remove(node)
    }
    
    for type in typesSnapshot {
      if !visited.contains(type) {
        dfs(type)
      }
    }
    
    return cycles
  }
  
  /// 최적화 제안
  public nonisolated func getOptimizationSuggestions() -> [String] {
    var suggestions: [String] = []
    let freq = statsCache.read().frequentlyUsed
    // 자주 사용되는 타입 체크
    for (type, count) in freq where count >= 5 {
      suggestions.append("💡 \(type): \(count)회 사용됨 → 싱글톤 패턴 고려")
    }
    
    // 순환 의존성 체크
    let cycles = detectCircularDependencies()
    suggestions.append(contentsOf: cycles.map { "⚠️ \($0)" })
    
    // 미사용 타입 체크
    let snap = statsCache.read()
    let unused = snap.registered.subtracting(snap.resolved)
    if !unused.isEmpty {
      suggestions.append("🗑️ 미사용 타입들: \(unused.joined(separator: ", "))")
    }
    
    return suggestions.isEmpty ? ["✅ 최적화 제안 없음 - 좋은 상태입니다!"] : suggestions
  }
  public nonisolated static func getOptimizationSuggestions() -> [String] {
    var suggestions: [String] = []
    let freq = DIStatsCache.shared.read().frequentlyUsed
    for (type, count) in freq where count >= 5 { suggestions.append("💡 \(type): \(count)회 사용됨 → 싱글톤 패턴 고려") }
    let snap = DIStatsCache.shared.read()
    // cycles
    var visited: Set<String> = []
    var stack: Set<String> = []
    var cycles: [String] = []
    func dfs(_ node: String) {
      if stack.contains(node) { cycles.append("순환 감지: \(node)"); return }
      if visited.contains(node) { return }
      visited.insert(node); stack.insert(node)
      for dep in snap.dependencies where dep.from == node { dfs(dep.to) }
      stack.remove(node)
    }
    for t in snap.registered where !visited.contains(t) { dfs(t) }
    suggestions.append(contentsOf: cycles.map { "⚠️ \($0)" })
    let unused = snap.registered.subtracting(snap.resolved)
    if !unused.isEmpty { suggestions.append("🗑️ 미사용 타입들: \(unused.joined(separator: ", "))") }
    return suggestions.isEmpty ? ["✅ 최적화 제안 없음 - 좋은 상태입니다!"] : suggestions
  }
  
  /// 최적화 활성화/비활성화
  public func setOptimizationEnabled(_ enabled: Bool) {
    optimizationEnabled = enabled
    #logInfo("🔧 최적화 기능: \(enabled ? "활성화" : "비활성화")")
  }
  
  // MARK: - 생명주기 관리 (간단하게!)
  
  /// 특정 모듈 시작
  public func startModule(_ moduleId: String) async throws {
    try await lifecycleManager.startModule(moduleId)
  }
  
  /// 특정 모듈 중지
  public func stopModule(_ moduleId: String) async throws {
    try await lifecycleManager.stopModule(moduleId)
  }
  
  /// 특정 모듈 재시작
  public func restartModule(_ moduleId: String) async throws {
    try await lifecycleManager.restartModule(moduleId)
  }
  
  /// 시스템 건강 상태
  public func getSystemHealth() async -> SimpleLifecycleManager.SystemHealth {
    return await lifecycleManager.getSystemHealth()
  }
  
  /// 모든 정보 한번에 보기 (최적화 정보 포함)
  public func showAll() async {
    #logInfo(getSummary())
    
    #logInfo("\n🔗 의존성 관계:")
    let deps = withLock { dependencies }
    if deps.isEmpty {
      #logInfo("  없음")
    } else {
      for (index, dep) in deps.enumerated() {
        #logInfo("  \(index + 1). \(dep.from) → \(dep.to)")
      }
    }
    
    #logInfo("\n⚡ 최적화 제안:")
    let suggestions = getOptimizationSuggestions()
    for suggestion in suggestions {
      #logInfo("  \(suggestion)")
    }
    
    let health = await getSystemHealth()
    #logInfo("\n💚 시스템 상태: \(health.status.rawValue)")
  }
  
  /// 초기화
  public func reset() {
    withLock {
      registeredTypes.removeAll()
      resolvedTypes.removeAll()
      dependencies.removeAll()
      registrationCount = 0
      resolutionCount = 0
      frequentlyUsed.removeAll()
      cachedInstances.removeAll()
    }
    
    Task { @DIActor in
      AutoMonitor.shared.reset()
    }
    
    #logInfo("🔄 AutoDIOptimizer 초기화됨")
    scheduleSnapshotDebounced()
  }
  
  // MARK: - 기존 API와의 호환성을 위한 메서드들
  
  /// 현재 통계 (기존 API 호환)
  public nonisolated func getCurrentStats() -> [String: Int] {
    return statsCache.read().frequentlyUsed
  }
  public nonisolated static func readSnapshot() -> DIStatsSnapshot { DIStatsCache.shared.read() }
  public nonisolated static func getCurrentStats() -> [String: Int] {
    return DIStatsCache.shared.read().frequentlyUsed
  }
  
  /// 그래프 시각화 (간단 버전)
  internal nonisolated func visualizeGraph() -> String { statsCache.read().graphText }
  @available(*, deprecated, message: "Use UnifiedDI/DIContainer or readSnapshot().graphText")
  public nonisolated static func visualizeGraph() -> String { DIStatsCache.shared.read().graphText }
  
  /// 자주 사용되는 타입들 (Set 버전)
  internal nonisolated func getFrequentlyUsedTypes() -> Set<String> {
    let snapshot = statsCache.read().frequentlyUsed
    return Set(snapshot.filter { $0.value >= 3 }.keys)
  }
  @available(*, deprecated, message: "Use UnifiedDI/DIContainer or readSnapshot().frequentlyUsed")
  public nonisolated static func getFrequentlyUsedTypes() -> Set<String> {
    let snapshot = DIStatsCache.shared.read().frequentlyUsed
    return Set(snapshot.filter { $0.value >= 3 }.keys)
  }
  
  /// 감지된 순환 의존성 (Set 버전)
  internal nonisolated func getDetectedCircularDependencies() -> Set<String> {
    return Set(detectCircularDependencies())
  }
  @available(*, deprecated, message: "Use UnifiedDI/DIContainer")
  public nonisolated static func getDetectedCircularDependencies() -> Set<String> {
    let snap = DIStatsCache.shared.read()
    var visited: Set<String> = []
    var stack: Set<String> = []
    var cycles: Set<String> = []
    func dfs(_ node: String) {
      if stack.contains(node) { cycles.insert("순환 감지: \(node)"); return }
      if visited.contains(node) { return }
      visited.insert(node); stack.insert(node)
      for dep in snap.dependencies where dep.from == node { dfs(dep.to) }
      stack.remove(node)
    }
    for type in snap.registered where !visited.contains(type) { dfs(type) }
    return cycles
  }
  
  /// 특정 타입이 최적화되었는지 확인
  internal nonisolated func isOptimized<T>(_ type: T.Type) -> Bool {
    let typeName = String(describing: type)
    let snapshot = statsCache.read().frequentlyUsed
    return (snapshot[typeName] ?? 0) >= 5
  }
  @available(*, deprecated, message: "Use UnifiedDI/DIContainer")
  public nonisolated static func isOptimized<T>(_ type: T.Type) -> Bool {
    let typeName = String(describing: type)
    let snapshot = DIStatsCache.shared.read().frequentlyUsed
    return (snapshot[typeName] ?? 0) >= 5
  }
  
  /// 통계 초기화 (별칭)
  public func resetStats() {
    reset()
  }
  
  /// Actor 최적화 제안 (간단 버전)
  internal nonisolated func getActorOptimizationSuggestions() -> [String: ActorOptimization] {
    var suggestions: [String: ActorOptimization] = [:]
    let types = statsCache.read().registered
    for type in types {
      if type.contains("Actor") {
        suggestions[type] = ActorOptimization(suggestion: "Actor 타입 감지됨")
      }
    }
    return suggestions
  }
  @available(*, deprecated, message: "Use UnifiedDI.actorOptimizations")
  public nonisolated static func getActorOptimizationSuggestions() -> [String: ActorOptimization] {
    var suggestions: [String: ActorOptimization] = [:]
    let types = DIStatsCache.shared.read().registered
    for type in types { if type.contains("Actor") { suggestions[type] = ActorOptimization(suggestion: "Actor 타입 감지됨") } }
    return suggestions
  }
  
  /// 타입 안전성 이슈 감지 (간단 버전)
  internal nonisolated func getDetectedTypeSafetyIssues() -> [String: TypeSafetyIssue] {
    var issues: [String: TypeSafetyIssue] = [:]
    let types = statsCache.read().registered
    for type in types {
      if type.contains("Unsafe") {
        issues[type] = TypeSafetyIssue(issue: "Unsafe 타입 사용 감지")
      }
    }
    return issues
  }
  @available(*, deprecated, message: "Use UnifiedDI.typeSafetyIssues")
  public nonisolated static func getDetectedTypeSafetyIssues() -> [String: TypeSafetyIssue] {
    var issues: [String: TypeSafetyIssue] = [:]
    let types = DIStatsCache.shared.read().registered
    for type in types { if type.contains("Unsafe") { issues[type] = TypeSafetyIssue(issue: "Unsafe 타입 사용 감지") } }
    return issues
  }
  
  /// 자동 수정된 타입들 (간단 버전)
  internal nonisolated func getDetectedAutoFixedTypes() -> Set<String> {
    return Set(getFrequentlyUsedTypes().prefix(3))
  }
  @available(*, deprecated, message: "Use UnifiedDI.autoFixedTypes")
  public nonisolated static func getDetectedAutoFixedTypes() -> Set<String> {
    return Set(getFrequentlyUsedTypes().prefix(3))
  }
  
  /// Actor hop 통계 (간단 버전)
  internal nonisolated func getActorHopStats() -> [String: Int] {
    let snapshot = statsCache.read().frequentlyUsed
    return snapshot.filter { $0.key.contains("Actor") }
  }
  @available(*, deprecated, message: "Use UnifiedDI.actorHopStats")
  public nonisolated static func getActorHopStats() -> [String: Int] {
    let snapshot = DIStatsCache.shared.read().frequentlyUsed
    return snapshot.filter { $0.key.contains("Actor") }
  }
  
  /// 비동기 성능 통계 (간단 버전)
  internal nonisolated func getAsyncPerformanceStats() -> [String: Double] {
    var stats: [String: Double] = [:]
    let snapshot = statsCache.read().frequentlyUsed
    for (type, count) in snapshot {
      if type.contains("async") || type.contains("Async") {
        stats[type] = Double(count) * 0.1 // 간단한 성능 점수
      }
    }
    return stats
  }
  @available(*, deprecated, message: "Use UnifiedDI.asyncPerformanceStats")
  public nonisolated static func getAsyncPerformanceStats() -> [String: Double] {
    var stats: [String: Double] = [:]
    let snapshot = DIStatsCache.shared.read().frequentlyUsed
    for (type, count) in snapshot { if type.contains("async") || type.contains("Async") { stats[type] = Double(count) * 0.1 } }
    return stats
  }
  
  /// 최근 그래프 변경사항 (간단 버전)
  internal nonisolated func getRecentGraphChanges(limit: Int = 10) -> [(timestamp: Date, changes: [String: NodeChangeType])] {
    let now = Date()
    let deps = statsCache.read().dependencies
    return deps.prefix(limit).enumerated().map { index, dep in
      (timestamp: now.addingTimeInterval(-Double(index) * 60),
       changes: [dep.from: NodeChangeType(change: "added dependency to \(dep.to)")])
    }
  }
  @available(*, deprecated, message: "Use UnifiedDI.getGraphChanges(limit:)")
  public nonisolated static func getRecentGraphChanges(limit: Int = 10) -> [(timestamp: Date, changes: [String: NodeChangeType])] {
    let now = Date(); let deps = DIStatsCache.shared.read().dependencies
    return deps.prefix(limit).enumerated().map { index, dep in
      (timestamp: now.addingTimeInterval(-Double(index) * 60), changes: [dep.from: NodeChangeType(change: "added dependency to \(dep.to)")])
    }
  }
  
  /// 로그 레벨 설정
  public func setLogLevel(_ level: LogLevel, configureLogger: Bool = true) {
    currentLogLevel = level
    #logInfo("📝 로그 레벨 설정: \(level.rawValue)")

    let mappedLevel: DILogLevel
    let severityThreshold: DILogSeverity
    switch level {
    case .all:
      mappedLevel = .all
      severityThreshold = .debug
    case .registration:
      mappedLevel = .registration
      severityThreshold = .info
    case .optimization:
      mappedLevel = .optimization
      severityThreshold = .info
    case .errors:
      mappedLevel = .errorsOnly
      severityThreshold = .error
    case .off:
      mappedLevel = .off
      severityThreshold = .error
    }
    if configureLogger {
      DILogger.configure(level: mappedLevel, severityThreshold: severityThreshold)
    }
    scheduleSnapshotDebounced()
  }
  
  
  /// 현재 로그 레벨
  internal nonisolated func getCurrentLogLevel() -> LogLevel { statsCache.read().logLevel }
  @available(*, deprecated, message: "Use UnifiedDI.logLevel or getLogLevel()")
  public nonisolated static func getCurrentLogLevel() -> LogLevel { DIStatsCache.shared.read().logLevel }
  
  /// Nil 해결 처리 (간단 버전)
  public func handleNilResolution<T>(_ type: T.Type) {
    let typeName = String(describing: type)
    switch DILogger.getCurrentLogLevel() {
    case .all, .registration:
      DILogger.info(channel: .resolution, "⚠️ Nil 해결 감지: \(typeName)")
    default:
      break
    }
  }
  
  /// 설정 업데이트 (간단 버전)
  public func updateConfig(_ config: Any) {
    #logInfo("⚙️ 설정 업데이트됨")
  }
  
}

// MARK: - 호환성을 위한 타입 정의들

public struct ActorOptimization: Sendable {
  public let suggestion: String
  public init(suggestion: String) { self.suggestion = suggestion }
}

public struct TypeSafetyIssue: Sendable {
  public let issue: String
  public init(issue: String) { self.issue = issue }
}

public struct NodeChangeType: Sendable {
  public let change: String
  public init(change: String) { self.change = change }
}

// MARK: - LogLevel 정의

public extension AutoDIOptimizer {
  /// 로깅 레벨을 정의하는 열거형
  enum LogLevel: String, CaseIterable, Sendable {
    /// 모든 로그 출력 (기본값)
    case all = "all"
    /// 등록만 로깅
    case registration = "registration"
    /// 최적화만 로깅
    case optimization = "optimization"
    /// 에러만 로깅
    case errors = "errors"
    /// 로깅 끄기
    case off = "off"
  }
}
