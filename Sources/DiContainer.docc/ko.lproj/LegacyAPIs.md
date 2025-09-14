# Legacy APIs & Migration

일부 레거시 API는 UnifiedDI/UnifiedRegistry 기반으로 수렴되었습니다. 기존 코드를 다음 치트시트에 따라 전환하세요.

## 치트시트
- `DI.register(T.self) { ... }` → `UnifiedDI.register(T.self) { ... }`
- `DI.resolve(T.self)` → `UnifiedDI.resolve(T.self)`
- `DI.requireResolve(T.self)` → `UnifiedDI.requireResolve(T.self)`

## 레거시 Inject
```swift
// Before
@LegacyInject var service: Service

// After
@Inject(\.service) var service: Service
```

