# TCA 정책 설정 (브릿지 유연성 향상)

## 개요

WeaveDI의 TCA 브릿지 정책 시스템은 The Composable Architecture와의 통합에서 의존성 우선순위를 동적으로 제어할 수 있게 합니다. `TCABridgePolicy`를 통해 테스트, 프로덕션, 컨텍스트별 환경에서 각각 다른 의존성 해결 전략을 사용할 수 있습니다.

## 🎯 핵심 장점

- **✅ 동적 정책 변경**: 런타임에 의존성 우선순위 조정
- **✅ 환경별 최적화**: 테스트/프로덕션 환경에 맞는 전략
- **✅ 컨텍스트 인식**: 상황에 따른 지능적 의존성 선택
- **✅ TCA 완벽 호환**: Dependency Values와 완전 통합

## TCABridgePolicy 열거형

### 정책 종류

```swift
/// TCA 브릿지에서 사용할 의존성 우선순위 정책
@MainActor
public enum TCABridgePolicy: String, CaseIterable, Sendable {
    /// 테스트 우선: TestDependencyKey.testValue 우선 사용
    case testPriority = "testPriority"

    /// 라이브 우선: TestDependencyKey.liveValue 우선 사용
    case livePriority = "livePriority"

    /// 컨텍스트별: 실행 환경에 따라 동적 선택
    case contextual = "contextual"
}
```

## 정책 설정 및 사용

### 기본 설정

```swift
import WeaveDI

// 앱 시작 시 정책 설정
@MainActor
func configureApp() {
    // 프로덕션 환경: 라이브 값 우선
    TCASmartSync.configure(policy: .livePriority)

    print("🎯 TCA 브릿지 정책이 'livePriority'로 설정되었습니다!")
}
```

### 테스트 환경 설정

```swift
import XCTest
import WeaveDI

class MyFeatureTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // 테스트에서는 Mock 데이터 우선 사용
        TCASmartSync.configure(policy: .testPriority)
    }

    override func tearDown() {
        // 테스트 정책으로 리셋
        TCASmartSync.resetForTesting()
        super.tearDown()
    }
}
```

### 컨텍스트별 정책 사용

```swift
// 개발 환경에서 동적 선택
@MainActor
func setupDevelopmentEnvironment() {
    // 디버그 빌드에서는 컨텍스트에 따라 자동 선택
    #if DEBUG
    TCASmartSync.configure(policy: .contextual)
    #else
    TCASmartSync.configure(policy: .livePriority)
    #endif
}
```

## 실제 동작 방식

### 의존성 해결 우선순위

```swift
// TCASmartSync 내부 구현
@MainActor
private static func getValueByPolicy<T>(
    testValue: @autoclosure () -> T,
    liveValue: @autoclosure () -> T,
    fallback: @autoclosure () -> T
) -> T {
    switch currentPolicy {
    case .testPriority:
        return testValue()

    case .livePriority:
        return liveValue()

    case .contextual:
        // 실행 컨텍스트에 따라 동적 선택
        #if DEBUG
        return testValue()
        #else
        return liveValue()
        #endif
    }
}
```

### syncSingle() 메서드에서의 활용

```swift
@MainActor
public static func syncSingle<T: TestDependencyKey>(
    _ key: T.Type,
    to dependencyKeyPath: WritableKeyPath<DependencyValues, T.Value>
) where T.Value: Sendable {

    let value = getValueByPolicy(
        testValue: key.testValue,
        liveValue: key.liveValue,
        fallback: key.testValue
    )

    DependencyValues.live[keyPath: dependencyKeyPath] = value
    Log.info("🔄 \(T.self) 동기화 완료 (정책: \(currentPolicy.rawValue))")
}
```

## 실전 활용 시나리오

### 1. A/B 테스트 환경

```swift
// A/B 테스트에서 다른 API 엔드포인트 사용
@MainActor
func setupABTestEnvironment(isTestGroup: Bool) {
    if isTestGroup {
        TCASmartSync.configure(policy: .testPriority)
        // 테스트 API 엔드포인트 사용
    } else {
        TCASmartSync.configure(policy: .livePriority)
        // 프로덕션 API 엔드포인트 사용
    }
}
```

### 2. 개발 모드 전환

```swift
// 개발자가 런타임에 모드 전환
@MainActor
class DeveloperSettings {
    static func enableMockMode() {
        TCASmartSync.configure(policy: .testPriority)
        // UI에서 "Mock 모드 활성화됨" 표시
    }

    static func enableLiveMode() {
        TCASmartSync.configure(policy: .livePriority)
        // UI에서 "실제 API 모드 활성화됨" 표시
    }
}
```

### 3. 단계적 배포

```swift
// 기능 플래그와 함께 사용
@MainActor
func setupFeatureFlag(useNewFeature: Bool) {
    if useNewFeature {
        // 새 기능: 라이브 데이터 사용
        TCASmartSync.configure(policy: .livePriority)
    } else {
        // 기존 기능: 안정적인 테스트 데이터 사용
        TCASmartSync.configure(policy: .testPriority)
    }
}
```

## SwiftUI 통합 예시

### 환경별 의존성 설정

```swift
import SwiftUI
import ComposableArchitecture

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    setupDependencyPolicy()
                }
        }
    }

    @MainActor
    private func setupDependencyPolicy() {
        #if DEBUG
        TCASmartSync.configure(policy: .testPriority)
        #else
        TCASmartSync.configure(policy: .livePriority)
        #endif
    }
}
```

### 설정 화면에서 정책 변경

```swift
struct DeveloperSettingsView: View {
    @State private var currentPolicy: TCABridgePolicy = .livePriority

    var body: some View {
        VStack {
            Picker("브릿지 정책", selection: $currentPolicy) {
                ForEach(TCABridgePolicy.allCases, id: \.self) { policy in
                    Text(policy.rawValue).tag(policy)
                }
            }
            .onChange(of: currentPolicy) { _, newPolicy in
                TCASmartSync.configure(policy: newPolicy)
            }
        }
    }
}
```

## 성능 및 동작 특성

### 메모리 사용량
- **정책 변경**: O(1) 시간 복잡도
- **메모리 오버헤드**: 최소 (enum 하나만 저장)

### 스레드 안전성
- **@MainActor**: 모든 정책 설정은 메인 액터에서 실행
- **동시성 안전**: Race condition 없음

### 실행 성능
- **우선순위 확인**: 단순 switch 문으로 최적화
- **캐싱**: 정책 변경 시에만 재계산

## 문제 해결

### Q: 정책 변경이 즉시 반영되지 않는 경우
**A:** `TCASmartSync.configure()`는 @MainActor에서 실행되므로, 메인 큐에서 호출하거나 `Task { @MainActor in }` 사용하세요.

### Q: 테스트에서 정책이 초기화되지 않는 경우
**A:** 각 테스트의 `setUp()`에서 `TCASmartSync.resetForTesting()`을 호출하세요.

### Q: 컨텍스트별 정책이 예상과 다르게 동작하는 경우
**A:** 컴파일 플래그 설정을 확인하고, 필요시 명시적으로 `.testPriority` 또는 `.livePriority`를 사용하세요.

## 고급 활용

### 커스텀 정책 로직

```swift
// 특별한 요구사항이 있는 경우
extension TCASmartSync {
    @MainActor
    public static func configureCustom<T: TestDependencyKey>(
        _ key: T.Type,
        customValue: T.Value
    ) where T.Value: Sendable {
        // 특정 키에 대해서만 커스텀 값 사용
        DependencyValues.live[keyPath: \.[key]] = customValue
    }
}
```

## 관련 API

- [`TCASmartSync`](./tcaSmartSync.md) - TCA 통합 시스템
- [`TestDependencyKey`](./testDependencyKey.md) - 테스트 의존성 키
- [`DependencyValues`](./dependencyValues.md) - TCA 의존성 값

---

*이 기능은 WeaveDI v3.2.1에서 추가되었습니다. TCA와의 유연한 통합을 위한 혁신적인 정책 시스템입니다.*