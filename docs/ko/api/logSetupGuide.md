# WeaveDI 로그 설정 가이드

> 🚀 WeaveDI의 새로운 로깅 시스템을 빠르게 설정하고 사용하는 방법

## 🚀 빠른 설정

### 1. 기본 로그 설정 (30초)

```swift
import WeaveDI

// AppDelegate 또는 앱 시작 시점에 추가
class AppDelegate: UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // 🔧 개발용 설정 - 모든 로그 보기
        #if DEBUG
        UnifiedDI.setLogLevel(.all)
        #else
        // 🏭 릴리즈용 설정 - 에러만 보기
        UnifiedDI.setLogLevel(.errors)
        #endif

        return true
    }
}
```

### 2. SwiftUI 프로젝트에서 설정

```swift
import SwiftUI
import WeaveDI

@main
struct MyApp: App {
    init() {
        // 로그 설정
        setupLogging()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func setupLogging() {
        #if DEBUG
        UnifiedDI.setLogLevel(.all)
        #else
        UnifiedDI.setLogLevel(.errors)
        #endif
    }
}
```

---

## 🏗️ 환경별 설정

### 개발 환경 (Development)

```swift
// 모든 로그 + 모니터링 활성화
func setupDevelopmentLogging() {
    UnifiedDI.setLogLevel(.all)

    // 상세한 모니터링 시작
    Task {
        await UnifiedDI.startDevelopmentMonitoring()
    }
}
```

### 테스트 환경 (Testing)

```swift
// 테스트 시 필요한 로그만
func setupTestingLogging() {
    UnifiedDI.setLogLevel(.registration)  // 등록 과정만 확인
    UnifiedDI.setLogSeverity(.info)       // 정보 레벨 이상만
}
```

### 프로덕션 환경 (Production)

```swift
// 최소한의 로그만
func setupProductionLogging() {
    UnifiedDI.setLogLevel(.errors)  // 에러만

    Task {
        await UnifiedDI.startProductionMonitoring()  // 가벼운 모니터링
    }
}
```

---

## ⚙️ 고급 설정

### 1. 채널별 세부 설정

```swift
// DILogger로 더 세밀한 제어
DILogger.configure(
    level: .all,                    // 모든 채널
    severityThreshold: .warning     // 경고 이상만
)

// 특정 채널만 로그
UnifiedDI.setLogLevel(.performance)  // 성능 관련만
UnifiedDI.setLogLevel(.health)       // 헬스체크만
```

### 2. 런타임 로그 레벨 변경

```swift
// 앱 실행 중에 로그 레벨 변경 가능
class DebugSettings {
    static func enableVerboseLogging() {
        DILogger.configure(level: .all, severityThreshold: .debug)
    }

    static func enableErrorsOnly() {
        DILogger.configure(level: .errorsOnly, severityThreshold: .error)
    }

    static func disableLogging() {
        DILogger.configure(level: .off)
    }
}
```

### 3. 커스텀 로그 매크로 활용

```swift
// LogMacro를 사용한 성능 최적화된 로깅
import LogMacro

class MyService {
    func doSomething() {
        // 컴파일 타임에 최적화되는 로그
        UnifiedDI.logInfo(channel: .general, "작업 시작")

        // 작업 수행...

        UnifiedDI.logInfo(channel: .general, "작업 완료")
    }
}
```

---

## 💡 실제 사용 예제

### 예제 1: 의존성 주입 모듈 만들기

```swift
import WeaveDI

class NetworkModule {
    static func register() {
        // 로그가 자동으로 기록됩니다
        UnifiedDI.register(NetworkService.self) {
            NetworkServiceImpl()
        }
        // 출력: "✅ Successfully registered NetworkService"

        UnifiedDI.register(APIClient.self) {
            APIClientImpl()
        }
        // 출력: "✅ Successfully registered APIClient"
    }
}

class UserModule {
    static func register() {
        UnifiedDI.register(UserRepository.self) {
            let networkService = UnifiedDI.resolve(NetworkService.self)
            return UserRepositoryImpl(networkService: networkService)
        }
        // 출력: "✅ Successfully resolved NetworkService (took 0.12ms)"
        // 출력: "✅ Successfully registered UserRepository"
    }
}
```

### 예제 2: 헬스체크와 모니터링

```swift
class DIHealthManager {
    static func performHealthCheck() async {
        // 헬스체크 실행
        let healthStatus = await UnifiedDI.performHealthCheck()

        if healthStatus.isHealthy {
            print("🟢 DI 컨테이너 상태: 정상")
        } else {
            print("🔴 DI 컨테이너 상태: 문제 발견")
            print("문제: \(healthStatus.issues)")
        }

        // 성능 리포트 생성
        let report = await UnifiedDI.generateMonitoringReport()
        print("📊 성능 리포트: \(report.recommendations)")
    }
}
```

### 예제 3: 로그 출력 최적화

```swift
// convert_to_logmacro.py 스크립트로 자동 변환된 코드
class OptimizedService {
    func processData() {
        #logInfo("🔄 데이터 처리 시작")    // 원래: print("🔄 데이터 처리 시작")

        // 처리 로직...

        #logInfo("✅ 데이터 처리 완료")    // 원래: print("✅ 데이터 처리 완료")
    }

    func handleError() {
        #logError("❌ 처리 중 오류 발생")  // 원래: print("❌ 처리 중 오류 발생")
    }
}
```

---

## 🔧 문제 해결

### Q1: 로그가 출력되지 않아요

**해결방법:**
```swift
// 1. 로그 레벨 확인
let config = UnifiedDI.getLogConfiguration()
print("현재 로그 레벨: \(config.level)")
print("현재 심각도: \(config.severity)")

// 2. 강제로 모든 로그 활성화
UnifiedDI.setLogLevel(.all)
DILogger.configure(level: .all, severityThreshold: .debug)
```

### Q2: 너무 많은 로그가 출력돼요

**해결방법:**
```swift
// 에러만 보기
UnifiedDI.setLogLevel(.errors)

// 또는 특정 채널만
UnifiedDI.setLogLevel(.performance)  // 성능 관련만
```

### Q3: 릴리즈 빌드에서 로그가 보여요

**해결방법:**
```swift
// 환경별 조건부 설정 확인
#if DEBUG
UnifiedDI.setLogLevel(.all)
#else
UnifiedDI.setLogLevel(.off)  // 완전히 끄기
#endif
```

### Q4: LogMacro를 찾을 수 없다는 오류

**해결방법:**
1. Package.swift에 LogMacro 의존성 추가 확인
2. `import LogMacro` 추가
3. 프로젝트 클린 빌드 (`⌘ + Shift + K`)

---

## 📚 추가 리소스

- **상세 문서**: [logging.md](./logging.md)
- **헬스체크**: [healthCheck.md](./healthCheck.md)
- **성능 모니터링**: [performanceMonitoring.md](./performanceMonitoring.md)

---

## 🎯 빠른 체크리스트

- [ ] 앱 시작시 `UnifiedDI.setLogLevel()` 호출
- [ ] 개발/릴리즈 환경별 로그 레벨 설정
- [ ] LogMacro import 추가
- [ ] 필요시 모니터링 시작
- [ ] 헬스체크 설정 (선택사항)

**설정 완료! 🎉**

이제 WeaveDI의 강력한 로깅 시스템을 활용하여 의존성 주입을 효과적으로 모니터링하고 디버깅할 수 있습니다.