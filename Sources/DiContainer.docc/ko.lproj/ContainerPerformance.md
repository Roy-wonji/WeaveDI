# Container Performance

Container는 모듈 배열을 스냅샷한 뒤 TaskGroup으로 병렬 등록하여 불필요한 actor hop을 줄입니다.

## 핵심 아이디어
- 스냅샷 후 작업 생성 → actor hop 최소화
- 등록은 `build()`에서 일괄 실행 → 체감 속도 향상

## 코드 스니펫
```swift
let snapshot = modules
await withTaskGroup(of: Void.self) { group in
  for module in snapshot {
    group.addTask { @Sendable in await module.register() }
  }
  await group.waitForAll()
}
```

## 팁
- 모듈 수집 단계에서는 즉시 실행하지 말고 누적하세요.
- 너무 많은 모듈(1000+)일 경우 배치 크기를 조정해 메모리를 관리하세요.

