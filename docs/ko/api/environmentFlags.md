# 환경 플래그 성능 최적화

## 개요

WeaveDI의 환경 플래그 시스템은 컴파일 타임에 성능 최적화를 제어하여 프로덕션 환경에서 불필요한 오버헤드를 제거합니다. `DI_MONITORING_ENABLED` 플래그를 통해 디버그 모드에서만 성능 모니터링을 활성화할 수 있습니다.

## 🚀 핵심 장점

- **✅ 0% 프로덕션 오버헤드**: 릴리즈 빌드에서 모니터링 코드 완전 제거
- **✅ 컴파일 타임 최적화**: Swift의 조건부 컴파일 활용
- **✅ 선택적 활성화**: 개발 환경에서만 필요한 기능 활성화
- **✅ 메모리 효율성**: 불필요한 Task 생성 방지

## 환경 플래그 설정

### Build Settings 구성

```swift
// Build Settings에서 설정
// Debug 구성:
SWIFT_ACTIVE_COMPILATION_CONDITIONS = DI_MONITORING_ENABLED DEBUG

// Release 구성:
SWIFT_ACTIVE_COMPILATION_CONDITIONS = RELEASE
```

### Package.swift 구성

```swift
// Package.swift
.target(
    name: "YourTarget",
    dependencies: ["WeaveDI"],
    swiftSettings: [
        .define("DI_MONITORING_ENABLED", .when(configuration: .debug))
    ]
)
```

## 최적화된 API 동작

### UnifiedDI.resolve() 최적화

```swift
// WeaveDI 내부 구현
public static func resolve<T>(_ type: T.Type) -> T? where T: Sendable {
    let resolved = WeaveDI.Container.live.resolve(type)

    // 조건부 컴파일: 디버그 모드에서만 추적
#if DEBUG && DI_MONITORING_ENABLED
    Task { @DIActor in
        AutoDIOptimizer.shared.trackResolution(type)
    }
#endif

    return resolved
}
```

### 성능 추적 활성화 제어

```swift
// 개발 환경에서만 실행
public static func enableOptimization() {
#if DEBUG && DI_MONITORING_ENABLED
    Task { @DIActor in
        AutoDIOptimizer.shared.setOptimizationEnabled(true)
    }
#endif
    // 프로덕션에서는 아무것도 실행하지 않음
}
```

## 실제 성능 비교

### 기존 (항상 추적)
```swift
// 모든 환경에서 Task 생성
public static func resolve<T>(_ type: T.Type) -> T? {
    let resolved = container.resolve(type)
    Task { @DIActor in  // 프로덕션에서도 생성!
        AutoDIOptimizer.shared.trackResolution(type)
    }
    return resolved
}
```

### 최적화 후 (조건부 추적)
```swift
// 디버그에서만 Task 생성
public static func resolve<T>(_ type: T.Type) -> T? {
    let resolved = container.resolve(type)
#if DEBUG && DI_MONITORING_ENABLED
    Task { @DIActor in  // 디버그에서만 생성
        AutoDIOptimizer.shared.trackResolution(type)
    }
#endif
    return resolved
}
```

## 플래그 적용 범위

### 1. UnifiedDI 클래스
- `resolve()`: 의존성 해결 추적
- `setLogLevel()`: 로그 레벨 설정
- `enableOptimization()`: 최적화 활성화

### 2. DIAdvanced.Performance
- `resolveWithTracking()`: 성능 추적과 함께 해결
- `markAsFrequentlyUsed()`: 자주 사용되는 타입 표시
- `enableOptimization()`: 성능 최적화 활성화

### 3. AutoDIOptimizer 통합
- 모든 성능 모니터링 기능이 플래그에 의해 제어됨
- 프로덕션에서는 완전히 비활성화

## 개발 워크플로우

### 개발 중 (모니터링 활성화)
```swift
// 1. Build Settings에서 DI_MONITORING_ENABLED 활성화
// 2. 성능 추적 사용
let stats = await DIAdvanced.Performance.getStats()
print("의존성 해결 통계: \(stats)")

// 3. 최적화 활성화
DIAdvanced.Performance.enableOptimization()
```

### 프로덕션 배포 (모니터링 비활성화)
```swift
// 1. Release 빌드에서 자동으로 비활성화
// 2. 0% 성능 오버헤드로 실행
let service = UnifiedDI.resolve(UserService.self)  // 추적 코드 없음
```

## 빌드 검증

### 컴파일 타임 확인
```bash
# 플래그가 제대로 설정되었는지 확인
swift build -c debug   # DI_MONITORING_ENABLED 포함
swift build -c release # DI_MONITORING_ENABLED 제외
```

### 런타임 확인
```swift
#if DEBUG && DI_MONITORING_ENABLED
print("🔍 DI 모니터링이 활성화되었습니다")
#else
print("🚀 프로덕션 모드: 모니터링 비활성화")
#endif
```

## 메모리 및 성능 영향

### 메모리 사용량
- **개발 환경**: Task 생성으로 인한 최소 오버헤드
- **프로덕션**: 0% 추가 메모리 사용

### CPU 사용량
- **개발 환경**: AutoDIOptimizer 추적으로 인한 미미한 오버헤드
- **프로덕션**: 추적 코드 완전 제거로 0% 오버헤드

### 앱 시작 시간
- **개발 환경**: 모니터링 초기화로 인한 미미한 지연
- **프로덕션**: 최적화된 시작 시간

## 문제 해결

### Q: 플래그가 제대로 적용되지 않는 경우
**A:** Build Settings에서 `SWIFT_ACTIVE_COMPILATION_CONDITIONS`를 확인하고, 정확한 구성에 `DI_MONITORING_ENABLED`가 포함되어 있는지 확인하세요.

### Q: 프로덕션에서 통계가 필요한 경우
**A:** 별도의 경량 메트릭 수집 시스템을 구현하거나, 조건부로 플래그를 활성화할 수 있습니다.

### Q: 빌드 구성별로 다른 동작이 필요한 경우
**A:** 추가 플래그를 정의하여 더 세밀한 제어가 가능합니다 (예: `DI_ANALYTICS_ENABLED`).

## 관련 API

- [`AutoDIOptimizer`](./autoDiOptimizer.md) - 성능 최적화 엔진
- [`UnifiedDI`](./unifiedDI.md) - 통합 DI API
- [`DIAdvanced.Performance`](./diAdvanced.md#performance) - 고급 성능 기능

---

*이 최적화는 WeaveDI v3.2.1에서 추가되었습니다. Swift의 조건부 컴파일을 활용한 혁신적인 성능 최적화 기법입니다.*