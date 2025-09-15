# UnifiedDI / DI API Quick Reference

이 문서는 UnifiedDI와 DI의 핵심 사용 패턴을 한눈에 확인할 수 있는 요약 가이드입니다. 등록(Register) / 해결(Resolve) / 해제(Release) / 스코프(Scope) 사용법을 정리했습니다.

## UnifiedDI

### 등록(Registration)
```swift
// 기본 등록
UnifiedDI.register(Service.self) { ServiceImpl() }

// 조건부 등록
UnifiedDI.registerIf(Analytics.self,
                     condition: isProd,
                     factory: { FirebaseAnalytics() },
                     fallback: { NoOpAnalytics() })

// 스코프 등록 (동기)
UnifiedDI.registerScoped(UserService.self, scope: .session) { UserServiceImpl() }

// 스코프 등록 (비동기)
UnifiedDI.registerAsyncScoped(ProfileCache.self, scope: .screen) {
    await ProfileCache.make()
}
```

### 해결(Resolution)
```swift
// 옵셔널 해결
let s1: Service? = UnifiedDI.resolve(Service.self)

// 필수 해결 (미등록 시 fatalError)
let s2: Service = UnifiedDI.requireResolve(Service.self)

// throws 기반 해결
let s3: Service = try UnifiedDI.resolveThrows(Service.self)

// 기본값과 함께 해결
let s4: Service = UnifiedDI.resolve(Service.self, default: MockService())

// 비동기 해결
let s5: Service? = await UnifiedDI.resolveAsync(Service.self)
```

### 해제(Release)
```swift
// 타입 해제
UnifiedDI.release(Service.self)

// 전체 해제 (테스트/디버그 용도)
await UnifiedDI.releaseAll()

// 스코프 전체 해제
UnifiedDI.releaseScope(.session, id: userID)

// 특정 타입의 스코프 인스턴스 해제
UnifiedDI.releaseScoped(UserService.self, kind: .session, id: userID)
```

### 팁(Tips)
- 스코프: `.screen`, `.session`, `.request` 제공. 수명주기에 맞춰 `ScopeContext.shared.setCurrent/clear`를 사용하세요.
- 비동기 싱글톤: `GlobalUnifiedRegistry.registerAsyncSingleton(Type.self) { await ... }` 패턴으로 최초 1회 생성 후 재사용합니다.
- 그래프 자동 수집(선택): `CircularDependencyDetector.shared.setAutoRecordingEnabled(true)` 설정 시, 해석 경로에서 자동으로 의존 엣지를 기록합니다.

---

## DI (단순화 API)

### 등록(Registration)
```swift
// 기본 등록
DI.register(Service.self) { ServiceImpl() }

// 조건부 등록
DI.registerIf(Service.self, condition: flag,
              factory: { RealService() },
              fallback: { MockService() })

// 스코프 등록 (동기/비동기)
DI.registerScoped(UserService.self, scope: .request) { UserServiceImpl() }
DI.registerAsyncScoped(RequestContext.self, scope: .request) { await RequestContext.create() }
```

### 해결(Resolution)
```swift
let d1: Service? = DI.resolve(Service.self)
let d2: Result<Service, DIError> = DI.resolveResult(Service.self)
let d3: Service = try DI.resolveThrows(Service.self)
```

### 해제(Release)
```swift
DI.release(Service.self)
DI.releaseScope(.request, id: requestID)
DI.releaseScoped(UserService.self, kind: .request, id: requestID)
```

> 참고: 심볼 링크는 공개(public) API에 대해서만 자동 노출됩니다. DI의 일부 메서드는 모듈 외부 노출이 아니면 문서 심볼 목록에 보이지 않을 수 있습니다. 문서의 예제 코드를 참고하시거나, 외부 사용이 필요하면 public으로 승격하는 것을 고려하세요.

