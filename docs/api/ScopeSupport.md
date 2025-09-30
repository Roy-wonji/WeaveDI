---
title: ScopeSupport
lang: en-US
---

# ScopeSupport

사전 정의된 스코프 종류

```swift
public enum ScopeKind: String, Hashable, Sendable {
  case singleton
  case screen
  case session
  case request
}
```

스코프 식별자

```swift
public struct ScopeID: Hashable, Sendable {
  public let kind: ScopeKind
  public let id: String
}
```

타입 + 스코프 키 조합

```swift
public struct ScopedTypeKey: Hashable, Sendable {
  public let type: AnyTypeIdentifier
  public let scope: ScopeID
}
```

현재 스코프 ID를 관리하는 컨텍스트
간단한 동기화 큐로 안전하게 관리합니다.

```swift
public final class ScopeContext: @unchecked Sendable {
  public static let shared = ScopeContext()
}
```

