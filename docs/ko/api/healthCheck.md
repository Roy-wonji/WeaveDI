# 헬스체크 시스템

WeaveDI는 의존성 주입 컨테이너의 상태와 성능을 실시간으로 모니터링할 수 있는 포괄적인 헬스체크 시스템을 제공합니다.

## 개요

헬스체크 시스템은 다음 구성 요소로 이루어져 있습니다:

- **DIHealthCheck**: Actor 기반 헬스 모니터링 서비스
- **DIHealthStatus**: 포괄적인 헬스 상태 보고
- **DIMonitor**: 자동 헬스체크를 포함한 통합 모니터링 인터페이스
- **통합**: 로깅 및 성능 모니터링과의 완전한 통합

## 빠른 시작

### 기본 헬스체크

```swift
// 즉시 헬스체크 수행
let status = await UnifiedDI.performHealthCheck()
print("시스템 상태: \(status.overallHealth ? "✅ 정상" : "❌ 이상")")

// 특정 문제 확인
for check in status.checks {
    print("\(check.name): \(check.status ? "✅" : "❌") - \(check.message)")
}
```

### 지속적 모니터링

```swift
// 지속적 헬스 모니터링 시작
await UnifiedDI.startDevelopmentMonitoring()

// 포괄적 모니터링 리포트 생성
let report = await UnifiedDI.generateMonitoringReport()
print("헬스 점수: \(await UnifiedDI.getRegistryHealthScore())")
print("권장사항:")
report.recommendations.forEach { print("  • \($0)") }
```

## DIHealthCheck Actor

다양한 시스템 검사를 수행하는 핵심 헬스 모니터링 서비스입니다.

### 기본 사용법

```swift
// 공유 헬스체크 인스턴스 가져오기
let healthCheck = DIHealthCheck.shared

// 즉시 헬스체크 수행
let status = await healthCheck.performHealthCheck()

// 지속적 모니터링 시작 (60초 간격)
await healthCheck.startMonitoring()

// 사용자 정의 간격으로 시작
await healthCheck.startMonitoring(interval: 300) // 5분

// 모니터링 중지
await healthCheck.stopMonitoring()

// 마지막 헬스체크 결과 가져오기
if let lastStatus = await healthCheck.getLastHealthStatus() {
    print("마지막 검사: \(lastStatus.timestamp)")
}
```

## 헬스체크 유형

시스템은 6가지 유형의 헬스체크를 수행합니다:

### 1. 컨테이너 상태 검사

```swift
private func checkContainerStatus() async -> DIHealthCheckResult
```

DI 컨테이너가 작동 중이고 올바르게 초기화되었는지 확인합니다.

### 2. 메모리 사용량 검사

```swift
private func checkMemoryUsage() async -> DIHealthCheckResult
```

설정 가능한 임계값을 사용하여 메모리 소비를 모니터링합니다:
- **정상**: < 50MB
- **경고**: 50-100MB
- **위험**: > 100MB

### 3. 성능 지표 검사

```swift
private func checkPerformanceMetrics() async -> DIHealthCheckResult
```

의존성 해결 성능을 분석합니다:
- **정상**: < 50ms 평균 해결 시간
- **경고**: 50-100ms
- **위험**: > 100ms

### 4. 의존성 그래프 검사

```swift
private func checkDependencyGraph() async -> DIHealthCheckResult
```

의존성 그래프 구조와 등록 수를 검증합니다.

### 5. 순환 의존성 검사

```swift
private func checkCircularDependencies() async -> DIHealthCheckResult
```

등록 그래프에서 순환 의존성을 감지합니다.

### 6. 등록 무결성 검사

```swift
private func checkRegistrationIntegrity() async -> DIHealthCheckResult
```

등록 일관성을 확인하고 잠재적 문제를 식별합니다.

## 헬스 상태 데이터 타입

### DIHealthStatus

```swift
public struct DIHealthStatus: Sendable {
    public let timestamp: Date
    public let overallHealth: Bool
    public let checks: [DIHealthCheckResult]
    public let summary: DIHealthSummary
}
```

### DIHealthCheckResult

```swift
public struct DIHealthCheckResult: Sendable {
    public let name: String
    public let status: Bool
    public let message: String
    public let severity: DIHealthSeverity
    public let metrics: [String: String]?
}
```

### DIHealthSeverity

```swift
public enum DIHealthSeverity: String, CaseIterable, Sendable {
    case info = "INFO"
    case warning = "WARNING"
    case critical = "CRITICAL"
}
```

### DIHealthSummary

```swift
public struct DIHealthSummary: Sendable {
    public let registeredDependencies: Int
    public let resolvedDependencies: Int
    public let memoryUsage: Double // MB
    public let averageResolutionTime: Double // ms
    public let circularDependencies: Int
    public let failedResolutions: Int
}
```

## 지속적 모니터링

### 자동 헬스체크

```swift
// 자동 헬스 모니터링 활성화
await DIHealthCheck.shared.startMonitoring(interval: 60.0) // 60초마다

// 시스템이 수행하는 작업:
// 1. 정기적 헬스체크 수행
// 2. 결과 자동 로깅
// 3. 성능 트렌드 추적
// 4. 문제 발생 시 알림 생성
```

### 환경 기반 설정

```swift
#if DEBUG && DI_MONITORING_ENABLED
// 개발 환경에서 전체 모니터링
await healthCheck.startMonitoring(interval: 60.0)
#else
// 프로덕션에서 최소한의 모니터링
await healthCheck.startMonitoring(interval: 600.0) // 10분
#endif
```

## DIMonitor와의 통합

### 통합 모니터링

```swift
// DIMonitor가 자동으로 헬스체크 포함
let monitor = DIMonitor.shared

// 포괄적 모니터링 시작
await monitor.startMonitoring()

// 이벤트 모니터링
monitor.addEventHandler { event in
    switch event {
    case .healthCheckCompleted(let status):
        print("헬스체크 완료: \(status.overallHealth)")
    case .criticalError(let message):
        print("중요 문제 감지: \(message)")
    case .performanceThresholdExceeded(let operation, let duration):
        print("성능 문제: \(operation)이 \(duration)초 소요됨")
    default:
        break
    }
}
```

### 헬스 이벤트 타입

```swift
public enum DIMonitorEvent: Sendable {
    case healthCheckCompleted(DIHealthStatus)
    case performanceThresholdExceeded(operation: String, duration: TimeInterval)
    case criticalError(message: String)
    case warningDetected(message: String)
    case systemStarted
    case systemStopped
}
```

## 레지스트리 헬스 검증

### 고급 레지스트리 검사

```swift
// 레지스트리 동기화 검증
let report = await UnifiedDI.verifyRegistryHealth()
print("헬스 점수: \(report.healthScore)")

// 자동 수정 시도
let fixReport = await UnifiedDI.autoFixRegistry()
print("수정된 문제: \(fixReport.fixedIssues.count)")

// 상세 상태 출력
await UnifiedDI.printRegistryStatus()
```

### 레지스트리 헬스 리포트

```swift
public struct RegistrySyncReport: Sendable {
    public let healthScore: Double // 0-100
    public let summary: String
    public let factoryInconsistencies: [String]
    public let optimizationStats: OptimizationStats
    public let totalRegistrations: Int
}
```

## 성능 임계값

### 메모리 임계값

- **초록**: < 50MB 메모리 사용량
- **노랑**: 50-100MB 메모리 사용량
- **빨강**: > 100MB 메모리 사용량

### 성능 임계값

- **초록**: < 50ms 평균 해결 시간
- **노랑**: 50-100ms 평균 해결 시간
- **빨강**: > 100ms 평균 해결 시간

### 등록 임계값

- **경고**: > 100개 등록된 의존성 (모듈화 고려)
- **위험**: 순환 의존성 감지됨
- **정보**: 등록된 것이 없음

## 모니터링 리포트

### 포괄적 리포트 생성

```swift
let report = await UnifiedDI.generateMonitoringReport()

print("📊 모니터링 리포트")
print("기간: \(report.period)초")
print("상태: \(report.healthStatus.overallHealth ? "✅" : "❌")")
print("총 로그: \(report.logSummary.totalLogs)")
print("에러: \(report.logSummary.errorCount)")

print("\n💡 권장사항:")
report.recommendations.forEach {
    print("  • \($0)")
}
```

### 리포트 데이터 구조

```swift
public struct DIMonitorReport: Sendable {
    public let timestamp: Date
    public let period: TimeInterval
    public let healthStatus: DIHealthStatus
    public let logSummary: DILogSummary
    public let recommendations: [String]
}

public struct DILogSummary: Sendable {
    public let totalLogs: Int
    public let errorCount: Int
    public let warningCount: Int
    public let infoCount: Int
    public let debugCount: Int
    public let channelBreakdown: [DILogChannel: Int]
}
```

## 모범 사례

### 개발 환경

```swift
#if DEBUG
// 개발을 위한 빈번한 헬스체크
await DIHealthCheck.shared.startMonitoring(interval: 30.0)

// 상세 헬스 로깅 활성화
DILogger.configure(level: .health, severityThreshold: .info)

// 사용자 정의 이벤트 핸들러 추가
DIMonitor.shared.addEventHandler { event in
    // 사용자 정의 개발 모니터링 로직
}
#endif
```

### 프로덕션 환경

```swift
// 프로덕션을 위한 덜 빈번한 헬스체크
await DIHealthCheck.shared.startMonitoring(interval: 600.0) // 10분

// 중요한 문제만 모니터링
DILogger.configure(level: .errorsOnly, severityThreshold: .error)

// 중요한 문제에 대한 알림 설정
DIMonitor.shared.addEventHandler { event in
    switch event {
    case .criticalError(let message):
        // 모니터링 시스템에 알림 전송
        AlertSystem.send("DI 중요 에러: \(message)")
    default:
        break
    }
}
```

### 테스트

```swift
func testHealthCheck() async {
    // 헬스체크 수행
    let status = await DIHealthCheck.shared.performHealthCheck()

    // 모든 검사가 통과하는지 확인
    XCTAssertTrue(status.overallHealth)

    // 개별 구성 요소 확인
    let containerCheck = status.checks.first { $0.name == "Container Status" }
    XCTAssertNotNil(containerCheck)
    XCTAssertTrue(containerCheck?.status ?? false)
}
```

## 스레드 안전성

모든 헬스체크 작업은 스레드 안전합니다:

- **Actor 격리**: DIHealthCheck는 actor입니다
- **Sendable 준수**: 모든 데이터 타입이 Sendable입니다
- **동시 접근**: 안전한 동시 헬스체크 실행

## 관련 문서

- [로깅 시스템](./logging.md)
- [성능 모니터링](./performanceMonitoring.md)
- [DIMonitor 통합](./monitoring.md)