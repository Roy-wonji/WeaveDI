---
title: DIStatsSnapshot
lang: ko-KR
---

# DIStatsSnapshot

Immutable snapshot for DI stats/graph to support synchronous reads.

```swift
public struct DIStatsSnapshot: Sendable {
  public let frequentlyUsed: [String: Int]
  public let registered: Set<String>
  public let resolved: Set<String>
  public let dependencies: [(from: String, to: String)]
  public let logLevel: LogLevel
  public let graphText: String
}
```

Thread-safe cache to expose last snapshot to synchronous callers.

```swift
public final class DIStatsCache: @unchecked Sendable {
  public static let shared = DIStatsCache()
}
```

