# 자동 DI 최적화

자동으로 의존성 그래프를 생성하고 성능을 최적화하는 시스템

## 개요

WeaveDI는 별도 설정 없이 자동으로 의존성 관계를 추적하고 성능을 최적화하는 시스템을 제공합니다. 개발자가 신경쓰지 않아도 백그라운드에서 자동으로 실행됩니다.

## 자동 기능들

### 🔄 자동 의존성 그래프 생성

```swift
// 등록하기만 하면 자동으로 그래프에 추가
let service = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}
// 자동 로깅: 📊 Auto tracking registration: UserService
```

### 🎯 자동 Actor Hop 감지 및 최적화

```swift
let service = UnifiedDI.resolve(UserService.self)
// 자동 로그: 🎯 Actor optimization suggestion for UserService: MainActor로 이동 권장 (hops: 12, avg: 85.3ms)
```

### 🔒 자동 타입 안전성 검증

```swift
let service = UnifiedDI.resolve(UserService.self)
// 자동 로그: 🔒 Type safety issue: UserService is not Sendable
```

### ⚡ 자동 성능 최적화

```swift
for _ in 1...15 {
    let service = UnifiedDI.resolve(UserService.self)
}
// 자동 로그: ⚡ Auto optimized: UserService (10 uses)
```

## API 참조

### 자동 수집 정보 확인

```swift
UnifiedDI.autoGraph              // 🔄 자동 생성된 의존성 그래프
UnifiedDI.optimizedTypes         // ⚡ 자동 최적화된 타입들
UnifiedDI.stats                  // 📊 자동 수집된 사용 통계
UnifiedDI.circularDependencies   // ⚠️ 자동 감지된 순환 의존성
UnifiedDI.actorOptimizations     // 🎯 Actor 최적화 제안 목록
UnifiedDI.typeSafetyIssues       // 🔒 타입 안전성 이슈 목록
UnifiedDI.autoFixedTypes         // 🛠️ 자동 수정된 타입들
UnifiedDI.actorHopStats          // ⚡ Actor hop 통계
UnifiedDI.asyncPerformanceStats  // 📊 비동기 성능 통계 (밀리초)
```

### 최적화 제어

```swift
UnifiedDI.setAutoOptimization(false)     // 자동 최적화 비활성화
UnifiedDI.isOptimized(UserService.self)  // 특정 타입의 최적화 상태 확인
UnifiedDI.resetStats()                   // 통계 초기화
```

### 로깅 레벨 제어

```swift
UnifiedDI.setLogLevel(.all)          // ✅ 모든 로그 출력 (기본값)
UnifiedDI.setLogLevel(.registration) // 📝 등록된 의존성만
UnifiedDI.setLogLevel(.optimization) // ⚡ 성능 최적화 정보만
UnifiedDI.setLogLevel(.errors)       // ⚠️ 순환 의존성 에러만
UnifiedDI.setLogLevel(.off)          // 🔇 모든 자동 로깅 끄기
```

## 주요 특징

- **무설정**: 별도 설정 없이 자동으로 동작
- **백그라운드 실행**: 성능에 영향 없이 백그라운드에서 실행
- **실시간 업데이트**: 30초마다 자동으로 최적화 수행
- **메모리 효율적**: 상위 20개 타입만 캐시에 유지

이 모든 기능은 개발자가 별도로 호출하거나 설정할 필요 없이 자동으로 실행됩니다.