import Foundation

/// DI 컨테이너 헬스체크 결과
public struct DIHealthStatus: Sendable {
  public let timestamp: Date
  public let overallHealth: Bool
  public let checks: [DIHealthCheckResult]
  public let summary: DIHealthSummary
}

/// 개별 헬스체크 결과
public struct DIHealthCheckResult: Sendable {
  public let name: String
  public let status: Bool
  public let message: String
  public let severity: DIHealthSeverity
  public let metrics: [String: String]? // Any 대신 String으로 변경
}

/// 헬스체크 심각도
public enum DIHealthSeverity: String, CaseIterable, Sendable {
  case info = "INFO"
  case warning = "WARNING"
  case critical = "CRITICAL"
}

/// DI 시스템 요약 정보
public struct DIHealthSummary: Sendable {
  public let registeredDependencies: Int
  public let resolvedDependencies: Int
  public let memoryUsage: Double // MB
  public let averageResolutionTime: Double // ms
  public let circularDependencies: Int
  public let failedResolutions: Int
}

/// DI 헬스체크 시스템 - 의존성 주입 시스템의 상태를 모니터링
public actor DIHealthCheck {

  public static let shared = DIHealthCheck()

  private var lastHealthCheck: DIHealthStatus?
  private var healthCheckInterval: TimeInterval = 60.0 // 60초
  private var isMonitoring = false
  private var monitoringTask: Task<Void, Never>?

  private init() {}

  // MARK: - Public API

  /// 즉시 헬스체크 수행
  public func performHealthCheck() async -> DIHealthStatus {
    DILogger.info(channel: .health, "Starting DI health check")

    let startTime = Date()
    var checks: [DIHealthCheckResult] = []

    // 1. 컨테이너 상태 체크
    checks.append(await checkContainerStatus())

    // 2. 메모리 사용량 체크
    checks.append(await checkMemoryUsage())

    // 3. 성능 지표 체크
    checks.append(await checkPerformanceMetrics())

    // 4. 의존성 그래프 체크
    checks.append(await checkDependencyGraph())

    // 5. 순환 의존성 체크
    checks.append(await checkCircularDependencies())

    // 6. 등록 무결성 체크
    checks.append(await checkRegistrationIntegrity())

    // 전체 상태 계산
    let overallHealth = checks.allSatisfy { $0.severity != .critical }
    let summary = await generateSummary()

    let status = DIHealthStatus(
      timestamp: startTime,
      overallHealth: overallHealth,
      checks: checks,
      summary: summary
    )

    lastHealthCheck = status

    // 결과 로깅
    DILogger.logHealth(
      component: "DI Container",
      status: overallHealth,
      details: "Health check completed with \(checks.count) checks"
    )

    return status
  }

  /// 연속 모니터링 시작
  public func startMonitoring(interval: TimeInterval = 60.0) {
    guard !isMonitoring else { return }

    healthCheckInterval = interval
    isMonitoring = true

    monitoringTask = Task {
      while !Task.isCancelled && isMonitoring {
        _ = await performHealthCheck()
        try? await Task.sleep(nanoseconds: UInt64(healthCheckInterval * 1_000_000_000))
      }
    }

    DILogger.info(channel: .health, "Started DI health monitoring (interval: \(interval)s)")
  }

  /// 연속 모니터링 중지
  public func stopMonitoring() {
    isMonitoring = false
    monitoringTask?.cancel()
    monitoringTask = nil

    DILogger.info(channel: .health, "Stopped DI health monitoring")
  }

  /// 최근 헬스체크 결과 반환
  public func getLastHealthStatus() -> DIHealthStatus? {
    return lastHealthCheck
  }

  // MARK: - Individual Health Checks

  /// 컨테이너 상태 체크
  private func checkContainerStatus() async -> DIHealthCheckResult {
    var metrics: [String: String] = [:]

    // 기본 컨테이너 상태 및 레지스트리 헬스 정보 수집
    let childContainerCount = DIContainer.shared.getChildren().count
    let registryReport = await UnifiedRegistry.shared.verifyRegistrySync()
    let healthScore = registryReport.healthScore

    metrics["child_containers"] = String(childContainerCount)
    metrics["total_registrations"] = String(registryReport.totalRegistrations)
    metrics["registry_health_score"] = String(format: "%.1f", healthScore)

    var severity: DIHealthSeverity = .info
    var status = true
    var message = "DI Container is operational"

    if healthScore < 30 {
      severity = .critical
      status = false
      message = "DI Container registry health is critical (score: \(String(format: "%.1f", healthScore)))"
    } else if healthScore < 70 {
      severity = .warning
      message = "DI Container registry health is degraded (score: \(String(format: "%.1f", healthScore)))"
    } else if registryReport.totalRegistrations == 0 {
      severity = .warning
      message = "DI Container is initialized but has no registrations"
    } else if childContainerCount > 0 {
      message += " (child containers: \(childContainerCount))"
    }

    return DIHealthCheckResult(
      name: "Container Status",
      status: status,
      message: message,
      severity: severity,
      metrics: metrics
    )
  }

  /// 메모리 사용량 체크
  private func checkMemoryUsage() async -> DIHealthCheckResult {
    let memoryInfo = getMemoryUsage()
    let memoryUsageMB = memoryInfo.usedMemory / 1024 / 1024

    var severity: DIHealthSeverity = .info
    var message = "Memory usage: \(String(format: "%.2f", memoryUsageMB))MB"
    var status = true

    // 메모리 사용량 임계값 체크
    if memoryUsageMB > 100 {
      severity = .critical
      message += " (HIGH - Above 100MB)"
      status = false
    } else if memoryUsageMB > 50 {
      severity = .warning
      message += " (MEDIUM - Above 50MB)"
    }

    return DIHealthCheckResult(
      name: "Memory Usage",
      status: status,
      message: message,
      severity: severity,
      metrics: [
        "used_memory_mb": String(format: "%.2f", memoryUsageMB),
        "total_memory_mb": String(format: "%.2f", memoryInfo.totalMemory / 1024 / 1024)
      ]
    )
  }

  /// 성능 지표 체크
  private func checkPerformanceMetrics() async -> DIHealthCheckResult {
    guard WeaveDIConfiguration.enableOptimizerTracking else {
      return DIHealthCheckResult(
        name: "Performance Metrics",
        status: true,
        message: "Performance monitoring disabled",
        severity: .info,
        metrics: nil
      )
    }

    let usageStats = DIContainer.shared.getUsageStatistics()
    let totalResolutions = usageStats.values.reduce(0, +)
    let topTypes = usageStats.sorted { $0.value > $1.value }.prefix(3)

    var severity: DIHealthSeverity = .info
    var message = "Total resolutions: \(totalResolutions)"
    let status = totalResolutions > 0

    if totalResolutions == 0 {
      severity = .warning
      message = "No resolution activity detected"
    } else if topTypes.first?.value ?? 0 >= 50 {
      severity = .warning
      message += " (heavy usage detected)"
    }

    return DIHealthCheckResult(
      name: "Performance Metrics",
      status: status,
      message: message,
      severity: severity,
      metrics: [
        "total_resolutions": String(totalResolutions),
        "top_types": topTypes.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
      ]
    )
  }

  /// 의존성 그래프 체크
  private func checkDependencyGraph() async -> DIHealthCheckResult {
    // 기본적인 그래프 상태 체크
    let registeredCount = await UnifiedRegistry.shared.getRegisteredCount()

    let status = true
    var severity: DIHealthSeverity = .info
    var message = "Dependency graph: \(registeredCount) dependencies registered"

    if registeredCount == 0 {
      severity = .warning
      message += " (No dependencies registered)"
    }

    return DIHealthCheckResult(
      name: "Dependency Graph",
      status: status,
      message: message,
      severity: severity,
      metrics: [
        "registered_dependencies": String(registeredCount)
      ]
    )
  }

  /// 순환 의존성 체크
  private func checkCircularDependencies() async -> DIHealthCheckResult {
    // CircularDependencyDetector를 사용하여 순환 의존성 검사
    let circularDeps = await CircularDependencyDetector.shared.detectAllCircularDependencies()

    let status = circularDeps.isEmpty
    let severity: DIHealthSeverity = status ? .info : .critical
    let message = status ?
    "No circular dependencies detected" :
    "Found \(circularDeps.count) circular dependencies"

    return DIHealthCheckResult(
      name: "Circular Dependencies",
      status: status,
      message: message,
      severity: severity,
      metrics: [
        "circular_dependencies_count": String(circularDeps.count),
        "circular_dependencies": circularDeps.map { $0.description }.joined(separator: ", ")
      ]
    )
  }

  /// 등록 무결성 체크
  private func checkRegistrationIntegrity() async -> DIHealthCheckResult {
    // ComponentMetadataRegistry를 사용하여 기본 무결성 검사
    let allMetadata = ComponentMetadataRegistry.allMetadata()

    // 기본적인 메타데이터 검증
    let emptyComponents = allMetadata.filter { $0.providedTypes.isEmpty }
    let duplicateTypes = findDuplicateTypes(in: allMetadata)

    let totalIssues = emptyComponents.count + duplicateTypes.count
    let status = totalIssues == 0
    let severity: DIHealthSeverity = status ? .info : .warning
    let message = status ?
    "All registrations are valid (\(allMetadata.count) components)" :
    "Found \(totalIssues) potential registration issues"

    return DIHealthCheckResult(
      name: "Registration Integrity",
      status: status,
      message: message,
      severity: severity,
      metrics: [
        "total_components": String(allMetadata.count),
        "empty_components": String(emptyComponents.count),
        "duplicate_types": String(duplicateTypes.count),
        "total_issues": String(totalIssues)
      ]
    )
  }

  /// 중복 타입 찾기
  private func findDuplicateTypes(in metadata: [ComponentMetadata]) -> [String] {
    var typeCount: [String: Int] = [:]
    for component in metadata {
      for type in component.providedTypes {
        typeCount[type, default: 0] += 1
      }
    }
    return typeCount.compactMap { $0.value > 1 ? $0.key : nil }
  }

  // MARK: - Summary Generation

  /// 헬스체크 요약 정보 생성
  private func generateSummary() async -> DIHealthSummary {
    let registeredCount = await UnifiedRegistry.shared.getRegisteredCount()
    let memoryUsage = getMemoryUsage().usedMemory / 1024 / 1024

    let usageStats = WeaveDIConfiguration.enableOptimizerTracking
      ? DIContainer.shared.getUsageStatistics()
      : [:]

    let resolvedCount = usageStats.values.reduce(0, +)
    let avgTime = 0.0
    let failedCount = 0

    let circularDeps = await CircularDependencyDetector.shared.detectAllCircularDependencies().count

    return DIHealthSummary(
      registeredDependencies: registeredCount,
      resolvedDependencies: resolvedCount,
      memoryUsage: memoryUsage,
      averageResolutionTime: avgTime,
      circularDependencies: circularDeps,
      failedResolutions: failedCount
    )
  }

  // MARK: - Utility Methods

  /// 메모리 사용량 정보 가져오기
  private func getMemoryUsage() -> (usedMemory: Double, totalMemory: Double) {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
        task_info(mach_task_self_,
                  task_flavor_t(MACH_TASK_BASIC_INFO),
                  $0,
                  &count)
      }
    }

    if result == KERN_SUCCESS {
      return (usedMemory: Double(info.resident_size), totalMemory: Double(info.virtual_size))
    } else {
      return (usedMemory: 0, totalMemory: 0)
    }
  }
}

// MARK: - Extensions

extension UnifiedRegistry {
  func getRegisteredCount() -> Int {
    // 실제 구현에서는 internal 메서드를 통해 등록된 의존성 수를 반환
    // 임시로 기본값 반환
    return 0
  }
}

// MARK: - Health Check Convenience Methods

extension DILogger {
  /// 헬스체크 결과를 로그로 출력
  public static func logHealthStatus(_ status: DIHealthStatus) {
    let overallStatus = status.overallHealth ? "HEALTHY" : "UNHEALTHY"
    info(channel: .health, "DI Health Status: \(overallStatus)")

    for check in status.checks {
      let checkStatus = check.status ? "✅" : "❌"
      let message = "\(checkStatus) \(check.name): \(check.message)"

      switch check.severity {
        case .info:
          info(channel: .health, message)
        case .warning:
          warning(channel: .health, message)
        case .critical:
          error(channels: [.health], message)
      }
    }

    // 요약 정보 로깅
    let summary = status.summary
    info(channel: .health, """
            Health Summary:
            - Registered: \(summary.registeredDependencies)
            - Resolved: \(summary.resolvedDependencies)
            - Memory: \(String(format: "%.2f", summary.memoryUsage))MB
            - Avg Time: \(String(format: "%.2f", summary.averageResolutionTime))ms
            - Circular Deps: \(summary.circularDependencies)
            - Failed: \(summary.failedResolutions)
            """)
  }
}
