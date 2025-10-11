# WeaveDI v3.2.1 마이그레이션 가이드 & 릴리스 노트

테스트 환경 안정성과 개발 경험을 개선하는 집중적인 버그 수정 릴리스입니다.

## 🚀 v3.2.1의 새로운 기능

### 주요 개선사항

#### 1. AutoMonitor 테스트 환경 지능
- **스마트 테스트 감지**: AutoMonitor가 테스트 실행 중 자동으로 비활성화됨
- **테스트 간섭 제로**: 모니터링 출력으로 인한 테스트 차단 방지
- **원활한 개발**: 개발 환경에서는 전체 모니터링, 테스트에서는 무음
- **환경 감지**: 자동 `XCTestConfigurationFilePath` 감지

#### 2. 향상된 테스트 안정성
- **66/66 테스트 통과**: 완전한 테스트 스위트 신뢰성
- **빠른 테스트 실행**: AutoMonitor 병목 현상 제거
- **CI/CD 친화적**: 자동화된 테스트 파이프라인에 최적
- **설정 불필요**: 자동으로 작동

#### 3. 개발 경험 개선
- **더 나은 디버깅**: 개발 모드에서 명확한 모니터링
- **무음 테스트**: 테스트 실행 중 불필요한 로그 없음
- **일관된 동작**: 예측 가능한 모니터링 상태 관리

## 📈 성능 & 안정성 개선

### v3.2.1 이전 vs 이후

| 영역 | v3.2.0 | v3.2.1 | 개선도 |
|-----|--------|---------|---------|
| 테스트 실행 | 로그로 차단됨 | 원활함 | **100% 신뢰성** |
| AutoMonitor 오버헤드 | 항상 활성 | 테스트 인식 | **테스트 영향 제로** |
| CI/CD 파이프라인 | 불일치 | 신뢰성 | **완벽한 자동화** |
| 개발 로그 | 수동 제어 | 자동 | **스마트 동작** |

### AutoMonitor 지능

```swift
// v3.2.1: 스마트 환경 감지
public static var isEnabled: Bool = {
    // 테스트 환경에서는 자동으로 비활성화
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
        return false
    }
    // 일반 DEBUG 환경에서는 활성화
    return true
}()
```

## 🔧 API 변경사항

### 브레이킹 체인지 없음! ✅

모든 v3.2.0 API가 완전히 호환됩니다. 이것은 순수한 향상 릴리스입니다.

### 향상된 AutoMonitor 동작

```swift
// ✅ 개발: 전체 모니터링 활성
#if DEBUG
    // 모니터링 로그 출력
    AutoMonitor.shared.onModuleRegistered(UserService.self)
    // 출력: [AutoMonitor] modules=1 dependencies=0 active=1
#endif

// ✅ 테스트: 완전히 무음
// swift test -> AutoMonitor 출력 없음
// XCTest 실행 -> 모니터링 로그 제로
```

## 📝 마이그레이션 단계

### 모든 프로젝트: 마이그레이션 제로 필요! 🎉

v3.2.1은 드롭인 교체입니다:

1. **Package.swift 업데이트**:
   ```swift
   .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.2.1")
   ```

2. **테스트 실행 확인**:
   ```bash
   swift test  # AutoMonitor 간섭 없이 원활하게 실행되어야 함
   ```

3. **개발 모니터링 확인**:
   ```bash
   swift run YourApp  # DEBUG 빌드에서 AutoMonitor 로그가 표시되어야 함
   ```

## 🧪 테스트 환경 향상

### 자동 테스트 감지

시스템이 이제 여러 신호를 통해 테스트 환경을 자동으로 감지합니다:

```swift
// 주요 감지 방법
if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
    return false  // AutoMonitor 비활성화
}

// 대안 감지 패턴
if ProcessInfo.processInfo.arguments.contains("xctest") {
    return false  // Xcode 테스트 실행에 대해서도 비활성화
}
```

### 테스트 실행 흐름

1. **테스트 시작**: 환경 감지 실행
2. **AutoMonitor 상태**: 자동으로 비활성화로 설정
3. **테스트 실행**: 모니터링 로그나 간섭 없음
4. **테스트 완료**: 깔끔하고 집중된 출력

### CI/CD 통합

자동화된 테스트에 완벽:

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v3
    - name: Run Tests
      run: swift test  # ✅ 이제 AutoMonitor 로그 없이 깔끔하게 실행됨
```

## 🐛 버그 수정

### v3.2.1에서 수정된 문제

1. **AutoMonitor 테스트 간섭**: 테스트 실행 중 "[AutoMonitor] modules=X dependencies=Y active=Z" 로그 차단 제거
2. **테스트 타임아웃 문제**: 모니터링 출력으로 인한 테스트 정지 해결
3. **CI/CD 신뢰성**: 자동화된 환경에서 일관되지 않은 테스트 동작 수정
4. **개발 vs 테스트 혼동**: 환경 간 모니터링 동작의 명확한 분리

### 기술적 세부사항

#### AutoMonitor 상태 관리

```swift
// 강력한 환경 감지
public static var isEnabled: Bool = {
    // 1. XCTest 설정 확인
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
        return false
    }

    // 2. 테스트 인수 확인
    if ProcessInfo.processInfo.arguments.contains("xctest") {
        return false
    }

    // 3. 일반 DEBUG 빌드에서 활성화
    #if DEBUG
        return true
    #else
        return false
    #endif
}()
```

## ⚡ 개발 경험 개선

### 스마트 모니터링

- **개발 모드**: 전기능 모니터링 및 로깅
- **테스트 모드**: 완전히 무음 작동
- **프로덕션 모드**: 기본적으로 비활성화
- **커스텀 제어**: 수동 재정의 여전히 가능

### 디버깅 워크플로우

```swift
// 개발: 풍부한 모니터링
class UserService {
    init() {
        // AutoMonitor 로그: "📦 UserService 등록됨"
        // AutoMonitor 로그: "🔗 UserService → NetworkService 의존성"
    }
}

// 테스트: 무음 작동
class UserServiceTests: XCTestCase {
    func testUserService() {
        let service = UserService()
        // AutoMonitor 출력 없음 - 깔끔한 테스트 로그
        XCTAssertNotNil(service)
    }
}
```

## 🔮 미래 호환성

v3.2.1은 v3.2.0과 동일한 미래 대비 기반을 유지합니다:

- **Swift 6 준비**: 완전한 호환성 유지
- **API 안정성**: 3.x 시리즈에서 브레이킹 체인지 없음
- **AutoMonitor 진화**: 지능형 모니터링 기능의 기반
- **테스트 통합**: 향상된 테스트 환경 감지 기능

## 📚 문서 업데이트

### 업데이트된 콘텐츠

- **AutoMonitor 문서**: 테스트 환경 감지 세부사항 추가
- **테스트 가이드**: 무음 테스트 실행을 위해 업데이트
- **CI/CD 통합**: 자동화된 테스트 예제
- **개발 워크플로우**: 향상된 디버깅 가이드

### 설정 예제

```swift
// 커스텀 테스트 환경 감지 (필요시)
class CustomTestDetection {
    static var isTestEnvironment: Bool {
        return ProcessInfo.processInfo.environment["CUSTOM_TEST_FLAG"] != nil
    }
}

// 수동 AutoMonitor 제어 (고급 사용 케이스)
class TestSetup {
    static func disableMonitoringForTesting() {
        AutoMonitor.isEnabled = false
    }

    static func enableMonitoringForDevelopment() {
        AutoMonitor.isEnabled = true
    }
}
```

## 🤝 기여하기

v3.2.1은 향상된 테스트 요구사항과 함께 동일한 기여 가이드라인을 유지합니다:

- 모든 변경사항은 전체 66-테스트 스위트를 통과해야 함
- 테스트 환경 간섭이 허용되지 않음
- AutoMonitor 동작은 환경을 인식해야 함
- 모니터링 변경사항에 대한 문서 업데이트 필요

## 📞 지원

v3.2.1 특정 문제의 경우:

1. **테스트 실행 문제**: `swift test`가 AutoMonitor 로그 없이 실행되는지 확인
2. **모니터링 누락**: DEBUG 빌드 설정 확인
3. **CI/CD 문제**: 테스트 환경 감지가 작동하는지 확인
4. **성능 질문**: v3.2.0 벤치마크와 비교

## 🎯 요약

WeaveDI v3.2.1이 제공하는 것:

- ✅ **완벽한 테스트 실행** - AutoMonitor 간섭 방지
- ✅ **스마트 환경 감지** - 자동 테스트 vs 개발 모드
- ✅ **설정 불필요** - 자동으로 즉시 작동
- ✅ **100% 호환성** - v3.2.0의 드롭인 교체
- ✅ **향상된 CI/CD** - 신뢰할 수 있는 자동화된 테스트

**가장 부드러운 테스트 경험을 위해 지금 업그레이드하세요!**

---

*AutoMonitor 설정 세부사항은 [AutoMonitor 문서](../api/performanceMonitoring.md)를 참조하세요*

*테스트 모범 사례는 [테스트 가이드](./testing.md)를 참조하세요*