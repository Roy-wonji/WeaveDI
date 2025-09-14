# Actor Hop Explanation

Actor hop은 서로 다른 actor 격리 간 이동 비용입니다. DiContainer는 스냅샷 후 병렬 등록으로 hop을 최소화합니다.

## 핵심 아이디어
- 스냅샷: 등록할 모듈 배열을 actor 내부에서 복사
- 병렬 처리: TaskGroup으로 비즈니스 로직 등록 실행
- 정리: 완료 후 필요한 만큼만 상태 갱신

## 예시
```swift
let snapshot = modules
await withTaskGroup(of: Void.self) { group in
  for module in snapshot {
    group.addTask { await module.register() }
  }
  await group.waitForAll()
}
```

## 베스트 프랙티스
- build() 단계에서만 병렬화
- 등록 시점에는 누적만 하고 즉시 실행하지 않기
