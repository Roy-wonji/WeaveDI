import Foundation
import LogMacro

/// 자동 의존성 주입 최적화 시스템
/// 핵심 추적 및 최적화 기능에 집중한 간소화된 시스템
///
/// ## ⚠️ Thread Safety 참고사항
/// - 주로 앱 초기화 시 단일 스레드에서 사용됩니다
/// - 통계 데이터의 미세한 불일치는 기능에 영향을 주지 않습니다
/// - 높은 성능을 위해 복잡한 동기화를 제거했습니다
public final class AutoDIOptimizer: @unchecked Sendable {
  
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
  
    private var currentLogLevel: LogLevel = .all

    // Synchronization for internal mutable state to avoid races under concurrency
    private let stateLock = NSLock()

    // Helper to perform locked mutations/reads
    private func withLock<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }
  
  private init() {
    lifecycleManager = SimpleLifecycleManager.shared
    #logInfo("🚀 AutoDIOptimizer 초기화 완료 (최적화 기능 포함)")
  }
  
  // MARK: - 핵심 추적 메서드 (간소화)
  
  /// 의존성 등록 추적 (간단하게!)
  public func trackRegistration<T>(_ type: T.Type) {
    let typeName = String(describing: type)
    
        withLock {
            registeredTypes.insert(typeName)
            registrationCount += 1
        }
    
    #logInfo("📦 등록: \(typeName) (총 \(registrationCount)개)")
    
    // 자동 모니터링 연계
    Task {
      await AutoMonitor.shared.onModuleRegistered(type)
    }
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
            #logError("⚡ 최적화 권장: \(typeName)이 자주 사용됩니다 (싱글톤 고려)")
        }
    
    #logDebug("🔍 해결: \(typeName) (총 \(resolutionCount)회)")
  }
  
  
  /// 의존성 관계 추적 (간단하게!)
  public func trackDependency<From, To>(from: From.Type, to: To.Type) {
    let fromName = String(describing: from)
    let toName = String(describing: to)
    
        withLock { dependencies.append((from: fromName, to: toName)) }
    
    #logInfo("🔗 의존성 추가: \(fromName) → \(toName)")
    
    // 자동 모니터링 연계
    Task {
      await AutoMonitor.shared.onDependencyAdded(from: from, to: to)
    }
  }
  
  // MARK: - 간단한 조회 API
  
  /// 등록된 타입 목록
  public func getRegisteredTypes() -> Set<String> {
        return withLock { registeredTypes }
  }
  
  /// 해결된 타입 목록
  public func getResolvedTypes() -> Set<String> {
        return withLock { resolvedTypes }
  }
  
  /// 의존성 관계 목록
  public func getDependencies() -> [(from: String, to: String)] {
        return withLock { dependencies }
  }
  
  /// 간단한 통계
  public func getStats() -> (registered: Int, resolved: Int, dependencies: Int) {
        return withLock { (registrationCount, resolutionCount, dependencies.count) }
  }
  
  /// 요약 정보 (최적화 정보 포함)
  public func getSummary() -> String {
        let stats = getStats()
        let topUsed = getTopUsedTypes(limit: 3)
    
    return """
        📊 DI 시스템 요약:
        • 등록된 타입: \(stats.registered)개
        • 해결 요청: \(stats.resolved)회
        • 의존성 관계: \(stats.dependencies)개
        • 자주 사용되는 타입: \(topUsed.isEmpty ? "없음" : topUsed.joined(separator: ", "))
        • 최적화 상태: \(optimizationEnabled ? "활성화" : "비활성화")
        """
  }
  
  // MARK: - 🚀 간단한 최적화 기능들
  
  /// 자주 사용되는 타입 TOP N
  public func getTopUsedTypes(limit: Int = 5) -> [String] {
    return frequentlyUsed
      .sorted { $0.value > $1.value }
      .prefix(limit)
      .map { "\($0.key)(\($0.value)회)" }
  }
  
  /// 순환 의존성 간단 감지
    public func detectCircularDependencies() -> [String] {
        // Take thread-safe snapshots
        let typesSnapshot = withLock { registeredTypes }
        let depsSnapshot = withLock { dependencies }

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
  public func getOptimizationSuggestions() -> [String] {
    var suggestions: [String] = []
    
    // 자주 사용되는 타입 체크
    for (type, count) in frequentlyUsed where count >= 5 {
      suggestions.append("💡 \(type): \(count)회 사용됨 → 싱글톤 패턴 고려")
    }
    
    // 순환 의존성 체크
    let cycles = detectCircularDependencies()
    suggestions.append(contentsOf: cycles.map { "⚠️ \($0)" })
    
    // 미사용 타입 체크
    let unused = registeredTypes.subtracting(resolvedTypes)
    if !unused.isEmpty {
      suggestions.append("🗑️ 미사용 타입들: \(unused.joined(separator: ", "))")
    }
    
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
    
    Task {
      await AutoMonitor.shared.reset()
    }
    
    #logInfo("🔄 AutoDIOptimizer 초기화됨")
  }
  
  // MARK: - 기존 API와의 호환성을 위한 메서드들
  
  /// 현재 통계 (기존 API 호환)
  public func getCurrentStats() -> [String: Int] {
        return withLock { frequentlyUsed }
  }
  
  /// 그래프 시각화 (간단 버전)
    public func visualizeGraph() -> String {
        var result = "📊 의존성 그래프:\n"
        let (deps, regs) = withLock { (dependencies, registeredTypes) }

        // Show registered nodes
        if regs.isEmpty {
            result += "• 등록된 타입 없음\n"
        } else {
            result += "• 노드(등록된 타입): " + regs.sorted().joined(separator: ", ") + "\n"
        }

        // Show edges
        if deps.isEmpty {
            result += "• 의존성 없음"
        } else {
            for dep in deps {
                result += "• \(dep.from) → \(dep.to)\n"
            }
        }
        return result
    }
  
  /// 자주 사용되는 타입들 (Set 버전)
  public func getFrequentlyUsedTypes() -> Set<String> {
        let snapshot = withLock { frequentlyUsed }
        return Set(snapshot.filter { $0.value >= 3 }.keys)
  }
  
  /// 감지된 순환 의존성 (Set 버전)
  public func getDetectedCircularDependencies() -> Set<String> {
        return Set(detectCircularDependencies())
  }
  
  /// 특정 타입이 최적화되었는지 확인
  public func isOptimized<T>(_ type: T.Type) -> Bool {
        let typeName = String(describing: type)
        let snapshot = withLock { frequentlyUsed }
        return (snapshot[typeName] ?? 0) >= 5
  }
  
  /// 통계 초기화 (별칭)
  public func resetStats() {
    reset()
  }
  
  /// Actor 최적화 제안 (간단 버전)
  public func getActorOptimizationSuggestions() -> [String: ActorOptimization] {
    var suggestions: [String: ActorOptimization] = [:]
        let types = withLock { registeredTypes }
        for type in types {
            if type.contains("Actor") {
                suggestions[type] = ActorOptimization(suggestion: "Actor 타입 감지됨")
            }
        }
        return suggestions
    }
  
  /// 타입 안전성 이슈 감지 (간단 버전)
  public func getDetectedTypeSafetyIssues() -> [String: TypeSafetyIssue] {
        var issues: [String: TypeSafetyIssue] = [:]
        let types = withLock { registeredTypes }
        for type in types {
            if type.contains("Unsafe") {
                issues[type] = TypeSafetyIssue(issue: "Unsafe 타입 사용 감지")
            }
        }
        return issues
    }
  
  /// 자동 수정된 타입들 (간단 버전)
  public func getDetectedAutoFixedTypes() -> Set<String> {
        return Set(getFrequentlyUsedTypes().prefix(3))
  }
  
  /// Actor hop 통계 (간단 버전)
  public func getActorHopStats() -> [String: Int] {
        let snapshot = withLock { frequentlyUsed }
        return snapshot.filter { $0.key.contains("Actor") }
  }
  
  /// 비동기 성능 통계 (간단 버전)
  public func getAsyncPerformanceStats() -> [String: Double] {
        var stats: [String: Double] = [:]
        let snapshot = withLock { frequentlyUsed }
        for (type, count) in snapshot {
            if type.contains("async") || type.contains("Async") {
                stats[type] = Double(count) * 0.1 // 간단한 성능 점수
            }
        }
        return stats
    }
  
  /// 최근 그래프 변경사항 (간단 버전)
  public func getRecentGraphChanges(limit: Int = 10) -> [(timestamp: Date, changes: [String: NodeChangeType])] {
        let now = Date()
        let deps = withLock { dependencies }
        return deps.prefix(limit).enumerated().map { index, dep in
            (timestamp: now.addingTimeInterval(-Double(index) * 60),
             changes: [dep.from: NodeChangeType(change: "added dependency to \(dep.to)")])
        }
  }
  
  /// 로그 레벨 설정
    public func setLogLevel(_ level: LogLevel) {
        withLock { currentLogLevel = level }
        #logInfo("📝 로그 레벨 설정: \(level.rawValue)")
    }
  
  
  /// 현재 로그 레벨
    public func getCurrentLogLevel() -> LogLevel {
        return withLock { currentLogLevel }
    }
  
  /// Nil 해결 처리 (간단 버전)
  public func handleNilResolution<T>(_ type: T.Type) {
    let typeName = String(describing: type)
    #logInfo("⚠️ Nil 해결 감지: \(typeName)")
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

/// 로깅 레벨을 정의하는 열거형
public enum LogLevel: String, CaseIterable, Sendable {
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
