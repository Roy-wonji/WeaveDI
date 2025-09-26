# 스코프 가이드 (Screen / Session / Request)

WeaveDI는 화면/세션/요청 등 컨텍스트 단위로 의존성을 격리·캐시할 수 있는 스코프 기능을 제공합니다.

## 왜 스코프가 필요한가?
- 한 화면에서만 유지되어야 할 상태(예: 화면 캐시)
- 사용자 세션과 함께 사라져야 하는 데이터(예: 사용자별 서비스)
- 요청 단위로 재사용되는 객체(예: RequestContext)

## 핵심 타입
- `ScopeKind`: `.screen`, `.session`, `.request`
- `ScopeContext`: 현재 스코프 ID 관리 (`setCurrent(_:, id:)`, `clear(_:)`, `currentID(for:)`)
- `registerScoped` / `registerAsyncScoped`: 스코프 단위 등록

## 사용 예제

### 스크린 스코프
```swift
// 화면 진입 시
ScopeContext.shared.setCurrent(.screen, id: "Home")

await GlobalUnifiedRegistry.registerScoped(HomeViewModel.self, scope: .screen) {
    HomeViewModel()
}

let vm = UnifiedDI.resolve(HomeViewModel.self)

// 화면 종료 시
ScopeContext.shared.clear(.screen)
```

### 세션 스코프
```swift
// 로그인 성공 시
ScopeContext.shared.setCurrent(.session, id: user.id)
await GlobalUnifiedRegistry.registerScoped(UserSession.self, scope: .session) {
    UserSession(user: user)
}

// 세션 내 어디서든 재사용
let session = UnifiedDI.resolve(UserSession.self)

// 로그아웃 시
ScopeContext.shared.clear(.session)
```

### 요청 스코프
```swift
ScopeContext.shared.setCurrent(.request, id: UUID().uuidString)
await GlobalUnifiedRegistry.registerAsyncScoped(RequestContext.self, scope: .request) {
    await RequestContext.create()
}
let ctx = await UnifiedDI.resolveAsync(RequestContext.self)
ScopeContext.shared.clear(.request)
```

## 수명 주기 헬퍼 (권장 패턴)
- iOS 화면: `viewWillAppear`에서 `.screen` 설정, `viewDidDisappear`에서 해제
- 세션: 로그인/로그아웃 이벤트에서 `.session` 설정/해제
- 서버/백엔드 유사 아키텍처: 요청 수신 시 `.request` 설정, 완료 시 해제

> 주의: 스코프 ID가 설정되지 않은 경우, 스코프 등록은 일회성 생성으로 동작(캐시 없음)합니다.

## 문제 해결
- “스코프가 적용되지 않아요” → `ScopeContext.shared.currentID(for:)`가 nil인지 확인
- “메모리 누수?” → 화면/세션 종료 시 `clear(_:)` 호출했는지 확인
- “동시성 안전?” → UnifiedRegistry는 actor 기반이며 스코프 캐시는 내부에서 안전하게 동기화됩니다.
