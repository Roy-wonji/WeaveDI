# Bootstrap Rationale

DiContainer의 Bootstrap은 의존성 초기화를 원자적으로 보장하고, 초기 접근 순서를 통제하여 반쪽 상태를 방지합니다.

## 왜 필요한가
- 원자적 초기화: 컨테이너 교체 + 상태 플래그를 한 번에 처리
- 초기 접근 보호: 시작 전에 resolve 호출 방지
- 동시성 안전: 초기화 경합 직렬화

## 사용 예시
```swift
await DependencyContainer.bootstrap { c in
  c.register(Logger.self) { ConsoleLogger() }
}

await DependencyContainer.bootstrapAsync { c in
  let db = await Database.open()
  c.register(Database.self, instance: db)
}
```

## 모범 사례
- 앱 시작 시 한 번만 수행
- sync/async 분리 또는 bootstrapMixed로 단계적 초기화
- 부트스트랩 이후에는 UnifiedDI/DI로 런타임 추가 등록 가능
