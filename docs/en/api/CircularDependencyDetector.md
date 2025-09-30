---
title: CircularDependencyDetector
lang: en-US
---

# CircularDependencyDetector

순환 의존성 경로

```swift
public struct CircularDependencyPath: Hashable, CustomStringConvertible, Sendable {
  public let path: [String]
}
```

의존성 체인 분석 결과

```swift
public struct DependencyChainAnalysis: Sendable {
  public let rootType: String
  public let directDependencies: [String]
  public let allDependencies: [String]
  public let maxDepth: Int
  public let hasCycles: Bool
}
```

의존성 그래프 통계

```swift
public struct DependencyGraphStatistics: Codable, Sendable {
  public let totalTypes: Int
  public let totalDependencies: Int
  public let averageDependenciesPerType: Double
  public let maxDependenciesPerType: Int
  public let typesWithoutDependencies: Int
  public let detectedCycles: Int
}
```

  /// 순환 의존성 탐지와 함께 안전한 의존성 해결
