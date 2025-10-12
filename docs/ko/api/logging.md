# 로깅 시스템

WeaveDI는 의존성 주입 작업을 모니터링할 수 있는 포괄적인 로깅 시스템을 제공하며, 설정 가능한 레벨과 채널을 지원합니다.

## 개요

로깅 시스템은 세 가지 주요 구성 요소로 이루어져 있습니다:

- **DILogger**: 채널 기반 필터링을 지원하는 핵심 로깅 기능
- **DIMonitor**: 로깅과 헬스체크를 통합하는 통합 모니터링 시스템
- **UnifiedDI 로깅 API**: UnifiedDI를 통한 로깅 설정을 위한 간단한 인터페이스

## 빠른 시작

### 기본 설정

```swift
// 에러만 로깅하도록 설정
UnifiedDI.setLogLevel(.errors)

// 개발용 전체 로깅 활성화
UnifiedDI.setLogLevel(.all)

// 개발 모니터링 시작 (로깅 + 헬스체크 포함)
await UnifiedDI.startDevelopmentMonitoring()
```

### 수동 로깅

```swift
import WeaveDI

// 의존성 등록 로그
DILogger.logRegistration(type: UserService.self, success: true)

// 성능 추적이 포함된 의존성 해결 로그
DILogger.logResolution(type: UserService.self, success: true, duration: 0.002)

// 성능 지표 로그
DILogger.logPerformance(operation: "bulk_registration", duration: 0.1)

// 헬스체크 결과 로그
DILogger.logHealth(component: "UserModule", status: true, details: "모든 서비스 등록됨")
```

## DILogger

채널 기반 필터링과 환경 플래그 최적화를 지원하는 핵심 로깅 구성 요소입니다.

### 로그 채널

```swift
public enum DILogChannel: String, CaseIterable, Sendable {
    case registration = "REG"      // 의존성 등록
    case resolution = "RES"        // 의존성 해결
    case optimization = "OPT"      // 성능 최적화
    case health = "HEALTH"         // 헬스체크
    case diagnostics = "DIAG"      // 진단
    case general = "GEN"           // 일반 로깅
    case error = "ERROR"           // 에러
    case performance = "PERF"      // 성능 측정
}
```

### 로그 심각도 레벨

```swift
public enum DILogSeverity: String, CaseIterable, Comparable, Sendable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}
```

### 로그 레벨 설정

```swift
public enum DILogLevel: String, CaseIterable, Sendable {
    case all = "ALL"               // 모든 로그
    case registration = "REG"      // 등록만
    case optimization = "OPT"      // 최적화만
    case health = "HEALTH"         // 헬스체크만
    case errorsOnly = "ERROR"      // 에러만
    case off = "OFF"               // 로깅 비활성화
}
```

### 동적 설정

```swift
// 로그 레벨 및 심각도 임계값 설정
DILogger.configure(level: .all, severityThreshold: .debug)

// 현재 설정 가져오기
let config = DILogger.getCurrentLogLevel()
let severity = DILogger.getCurrentSeverityThreshold()

// 컴파일 타임 기본값으로 재설정
DILogger.resetToDefaults()
```

### 전문 로깅 메서드

```swift
// 의존성 등록 로깅
DILogger.logRegistration(type: UserRepository.self, success: true)

// 성능 추적이 포함된 의존성 해결
DILogger.logResolution(type: UserService.self, success: true, duration: 0.002)

// 성능 측정 로깅
DILogger.logPerformance(operation: "container_initialization", duration: 0.05)

// 헬스체크 로깅
DILogger.logHealth(component: "NetworkModule", status: true, details: "모든 엔드포인트 응답 중")
```

## UnifiedDI 로깅 API

UnifiedDI를 통한 로깅 설정을 위한 간소화된 인터페이스입니다.

### 로그 레벨 설정

```swift
public extension UnifiedDI {
    enum LogLevel {
        case all         // 모든 로그
        case errors      // 에러만
        case warnings    // 경고 이상
        case performance // 성능 관련
        case registration // 등록 관련
        case health      // 헬스체크 관련
        case off         // 로깅 비활성화
    }
}
```

### 설정 메서드

```swift
// 로그 레벨 설정
UnifiedDI.setLogLevel(.all)              // 모든 로깅 활성화
UnifiedDI.setLogLevel(.errors)           // 에러만
UnifiedDI.setLogLevel(.performance)      // 성능 로그만

// 심각도 임계값 설정
UnifiedDI.setLogSeverity(.info)          // 정보 레벨 이상
UnifiedDI.setLogSeverity(.error)         // 에러만

// 현재 설정 가져오기
let config = UnifiedDI.getLogConfiguration()
print("레벨: \(config.level), 심각도: \(config.severity)")

// 기본값으로 재설정
UnifiedDI.resetLogConfiguration()
```

### 모니터링 제어

```swift
// 개발 모니터링 시작 (전체 로깅 + 헬스체크)
await UnifiedDI.startDevelopmentMonitoring()

// 프로덕션 모니터링 시작 (최소한의 로깅)
await UnifiedDI.startProductionMonitoring()

// 모든 모니터링 중지
await UnifiedDI.stopMonitoring()

// 모니터링 리포트 생성
let report = await UnifiedDI.generateMonitoringReport()
print("권장사항: \(report.recommendations)")
```

## 환경 플래그

### 빌드 타임 최적화

최대한의 프로덕션 성능을 위해 로깅을 컴파일 타임에 완전히 비활성화할 수 있습니다:

```swift
// Release 빌드: 로깅 자동 비활성화 (0% 성능 오버헤드)
// Debug 빌드: 최소한의 로깅 (에러만)
// DI_MONITORING_ENABLED 플래그 사용: 전체 로깅 + 모니터링
```

### 빌드 설정

개발 모니터링을 위해 Xcode 빌드 설정에 추가:

```bash
# Swift Compiler - Custom Flags > Other Swift Flags
-D DI_MONITORING_ENABLED
```

### 성능 영향

- **DI_MONITORING_ENABLED 없음**: 프로덕션에서 제로 오버헤드
- **DI_MONITORING_ENABLED 있음**: 전체 모니터링 + 통계 수집
- **Debug 빌드**: 에러 로깅만 (최소한의 오버헤드)

## UnifiedDI와의 통합

로깅 시스템은 UnifiedDI 작업에 자동으로 통합됩니다:

```swift
// 등록의 자동 로깅
let service = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}
// 로그: "Successfully registered UserService"

// 성능 추적이 포함된 해결의 자동 로깅
let resolved = UnifiedDI.resolve(UserService.self)
// 로그: "Successfully resolved UserService (took 0.15ms)"

// 자동 성능 최적화 추적
#if DEBUG && DI_MONITORING_ENABLED
// 최적화 제안을 위한 해결 패턴 추적
#endif
```

## 로그 출력 형식

```
[14:30:25.123] [INFO] [REG] UnifiedDI.swift:85 register(_:factory:) - Successfully registered UserService
[14:30:25.124] [INFO] [PERF] UnifiedDI.swift:89 register(_:factory:) - register(UserService) completed in 0.85ms
[14:30:25.125] [INFO] [RES] UnifiedDI.swift:225 resolve(_:) - Successfully resolved UserService (took 0.12ms)
[14:30:25.126] [INFO] [HEALTH] DIHealthCheck.swift:53 performHealthCheck() - Starting DI health check
```

## 모범 사례

### 개발 환경

```swift
#if DEBUG
// 개발 환경에서 전체 모니터링 활성화
UnifiedDI.setLogLevel(.all)
await UnifiedDI.startDevelopmentMonitoring()
#endif
```

### 프로덕션 환경

```swift
// 프로덕션에서 최소한의 로깅
UnifiedDI.setLogLevel(.errors)
await UnifiedDI.startProductionMonitoring()
```

### 테스트

```swift
override func setUp() {
    super.setUp()
    // 테스트 디버깅을 위한 상세 로깅 활성화
    UnifiedDI.setLogLevel(.all)
}

override func tearDown() {
    UnifiedDI.resetLogConfiguration()
    super.tearDown()
}
```

## 스레드 안전성

모든 로깅 작업은 스레드 안전합니다:

- **NSLock**: 동적 설정 변경 보호
- **Actor 격리**: DIMonitor는 UI 업데이트를 위해 MainActor 사용
- **Sendable 준수**: 모든 로깅 타입이 Sendable 프로토콜을 준수

## 관련 문서

- [헬스체크 시스템](./healthCheck.md)
- [성능 모니터링](./performanceMonitoring.md)
- [UnifiedDI API](./unifiedDI.md)