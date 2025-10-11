# ComponentDiagnostics API

## 개요

`ComponentDiagnostics`는 WeaveDI의 혁신적인 자동 진단 시스템입니다. 다른 DI 프레임워크에서는 찾을 수 없는 독점적인 기능으로, 컴파일 타임에 의존성 설정 문제를 자동으로 감지하고 해결책을 제안합니다.

## 🚀 Needle/Swinject 대비 압도적 장점

| 기능 | WeaveDI | Needle | Swinject |
|------|---------|--------|----------|
| **자동 중복 검출** | ✅ 완전 자동 | ❌ 없음 | ❌ 없음 |
| **스코프 일관성 검사** | ✅ 자동 감지 | ⚠️ 수동 확인 | ❌ 없음 |
| **해결책 자동 제안** | ✅ 상세 리포트 | ❌ 없음 | ❌ 없음 |
| **컴파일 타임 검증** | ✅ 즉시 감지 | ⚠️ 제한적 | ❌ 런타임만 |

## 주요 기능

### 🔍 자동 중복 Provider 감지
```swift
// 문제 상황: 여러 Component에서 같은 타입 제공
@Component
struct AppComponent {
    @Provide var userService: UserService { UserServiceImpl() }
}

@Component
struct TestComponent {
    @Provide var userService: UserService { MockUserService() }  // 중복!
}

// 자동 감지 및 리포트
let diagnostics = UnifiedDI.analyzeComponentMetadata()
for issue in diagnostics.issues {
    print("⚠️ \(issue.type): \(issue.detail)")
    print("   Providers: \(issue.providers)")
}

// 출력:
// ⚠️ UserService: Multiple components provide this type.
//    Providers: [AppComponent, TestComponent]
```

### ⚙️ 스코프 불일치 자동 검사
```swift
// 문제 상황: 같은 타입에 다른 스코프 설정
@Component
struct NetworkComponent {
    @Provide(.singleton) var apiClient: APIClient { APIClientImpl() }
}

@Component
struct CacheComponent {
    @Provide(.transient) var apiClient: APIClient { APIClientImpl() }  // 스코프 불일치!
}

// 자동 감지
let diagnostics = UnifiedDI.analyzeComponentMetadata()
// 출력:
// ⚠️ APIClient: Inconsistent scopes: singleton, transient
//    Providers: [NetworkComponent, CacheComponent]
```

## API 레퍼런스

### ComponentDiagnostics 구조체

```swift
public struct ComponentDiagnostics: Codable, Sendable {
    public struct Issue: Codable, Sendable {
        public let type: String        // 문제가 있는 타입명
        public let providers: [String] // 해당 타입을 제공하는 Component들
        public let detail: String?     // 문제 상세 설명
    }

    public let issues: [Issue]
}
```

### 메타데이터 분석 메서드

```swift
/// 컴파일 타임 Component 메타데이터 분석
public static func analyzeComponentMetadata() -> ComponentDiagnostics
```

**사용법:**
```swift
let diagnostics = UnifiedDI.analyzeComponentMetadata()

if diagnostics.issues.isEmpty {
    print("✅ 모든 Component 설정이 완벽합니다!")
} else {
    print("⚠️ \(diagnostics.issues.count)개의 문제가 발견되었습니다:")

    for issue in diagnostics.issues {
        print("\n🔍 타입: \(issue.type)")
        print("   문제: \(issue.detail ?? "알 수 없음")")
        print("   관련 Component: \(issue.providers.joined(separator: ", "))")

        // 해결책 제안
        if issue.providers.count > 1 {
            print("   💡 해결책: 중복 provider 중 하나만 남기고 제거하세요")
        }
    }
}
```

## 실전 활용 예시

### 🏗️ CI/CD 파이프라인 통합

```swift
// build-phase-script.swift
let diagnostics = UnifiedDI.analyzeComponentMetadata()

if !diagnostics.issues.isEmpty {
    print("❌ DI 설정 문제 발견!")
    for issue in diagnostics.issues {
        print("   - \(issue.type): \(issue.detail ?? "")")
    }
    exit(1)  // 빌드 실패
}

print("✅ DI 설정 검증 완료!")
```

### 🧪 테스트 환경 검증

```swift
class DIConfigurationTests: XCTestCase {
    func testNoDuplicateProviders() {
        let diagnostics = UnifiedDI.analyzeComponentMetadata()
        let duplicateIssues = diagnostics.issues.filter {
            $0.detail?.contains("Multiple components") == true
        }

        XCTAssertTrue(duplicateIssues.isEmpty,
                     "중복 provider 발견: \(duplicateIssues)")
    }

    func testConsistentScopes() {
        let diagnostics = UnifiedDI.analyzeComponentMetadata()
        let scopeIssues = diagnostics.issues.filter {
            $0.detail?.contains("Inconsistent scopes") == true
        }

        XCTAssertTrue(scopeIssues.isEmpty,
                     "스코프 불일치 발견: \(scopeIssues)")
    }
}
```

### 🔧 개발 중 실시간 진단

```swift
#if DEBUG
// AppDelegate 또는 main.swift
let diagnostics = UnifiedDI.analyzeComponentMetadata()
if !diagnostics.issues.isEmpty {
    print("🔍 DI 설정 체크:")
    for issue in diagnostics.issues {
        print("   ⚠️ \(issue.type): \(issue.detail ?? "")")
    }
}
#endif
```

## 고급 활용

### 📊 진단 결과 JSON 내보내기

```swift
let diagnostics = UnifiedDI.analyzeComponentMetadata()
let jsonData = try JSONEncoder().encode(diagnostics)
try jsonData.write(to: URL(fileURLWithPath: "di-diagnostics.json"))

// 외부 도구에서 분석 가능한 JSON 파일 생성
```

### 🎯 특정 타입만 검사

```swift
let diagnostics = UnifiedDI.analyzeComponentMetadata()
let userServiceIssues = diagnostics.issues.filter { $0.type == "UserService" }

if !userServiceIssues.isEmpty {
    print("UserService 설정에 문제가 있습니다:")
    for issue in userServiceIssues {
        print("  - \(issue.detail ?? "")")
    }
}
```

## 성능 특성

- **✅ 컴파일 타임 실행**: 런타임 오버헤드 0%
- **✅ 메모리 효율적**: 메타데이터만 사용하여 최소 메모리 사용
- **✅ 즉시 실행**: 앱 시작 시 즉시 진단 완료
- **✅ 확장 가능**: 새로운 Component 추가 시 자동으로 포함

## 문제 해결 가이드

### Q: 진단에서 false positive가 나올 수 있나요?
**A:** WeaveDI는 정확한 컴파일 타임 메타데이터를 사용하므로 false positive는 거의 없습니다. 의도적으로 중복을 허용하려면 조건부 등록을 사용하세요.

### Q: 대규모 프로젝트에서도 빠르게 동작하나요?
**A:** 네! 컴파일 타임에 수집된 메타데이터만 분석하므로 Component 수와 관계없이 즉시 실행됩니다.

### Q: 기존 Needle/Swinject 프로젝트에서 마이그레이션할 때 도움이 되나요?
**A:** 매우 유용합니다! 마이그레이션 중 놓친 중복 설정이나 스코프 불일치를 자동으로 찾아줍니다.

## 관련 API

- [`UnifiedDI.componentMetadata()`](./unifiedDI.md#componentmetadata) - 메타데이터 조회
- [`UnifiedDI.detectComponentCycles()`](./componentCycleDetection.md) - 순환 의존성 검사
- [`UnifiedDI.performBatchRegistration()`](./batchRegistration.md) - 배치 등록

---

*이 기능은 WeaveDI v3.2.1에서 추가되었습니다. Needle과 Swinject에는 없는 WeaveDI만의 독점적인 혁신 기능입니다.*