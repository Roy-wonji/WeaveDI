---
title: AutoDIOptimizer
lang: en-US
---

# AutoDIOptimizer

Automatic dependency injection optimization system
Streamlined system focusing on core tracking and optimization features

## ⚠️ Thread Safety Notes
- Primarily used in single-threaded context during app initialization
- Minor inconsistencies in statistics data do not affect functionality
- Complex synchronization removed for high performance

## Basic Usage

```swift
import WeaveDI

// AutoDIOptimizer automatically tracks registrations and resolutions
await WeaveDI.Container.bootstrap { container in
    container.register(UserService.self) {
        UserServiceImpl()
    }
}

// Access statistics
let stats = await AutoDIOptimizer.shared.currentStats()
print("Registered types: \(stats.registeredTypes.count)")
print("Resolved types: \(stats.resolvedTypes.count)")
```

## Core API

```swift
@DIActor
public final class AutoDIOptimizer {
    public static let shared = AutoDIOptimizer()

    /// Track type registration
    public func trackRegistration<T>(_ type: T.Type)

    /// Track type resolution with optimization hints
    public func trackResolution<T>(_ type: T.Type)

    /// Track dependency relationships
    public func trackDependency<From, To>(from: From.Type, to: To.Type)

    /// Get current statistics
    public func currentStats() -> DIStatsSnapshot

    /// Get optimization suggestions
    public func optimizationSuggestions() -> [String]

    /// Get frequently used types (top N)
    public func frequentlyUsedTypes(top: Int = 10) -> [(String, Int)]

    /// Detect circular dependencies
    public func circularDependencies() -> Set<String>

    /// Enable/disable optimization
    public func setOptimizationEnabled(_ enabled: Bool)

    /// Set log level
    public func setLogLevel(_ level: LogLevel)

    /// Reset statistics
    public func reset()
}
```

## Statistics Snapshot

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

## Logging Levels

```swift
public enum LogLevel: String, CaseIterable, Sendable {
    /// Log everything (default)
    case all = "all"

    /// Log registrations only
    case registration = "registration"

    /// Log optimizations only
    case optimization = "optimization"

    /// Log errors only
    case errors = "errors"

    /// Disable logging
    case off = "off"
}
```

## Optimization Features

### Automatic Hot Path Detection

AutoDIOptimizer automatically detects frequently used types (10+ resolutions) and suggests singleton optimization:

```swift
// When a type is resolved 10+ times, you'll see:
// ⚡ 최적화 권장: UserService이 자주 사용됩니다 (싱글톤 고려)

// Consider registering as singleton:
await WeaveDI.Container.bootstrap { container in
    container.register(UserService.self, scope: .singleton) {
        UserServiceImpl()
    }
}
```

### Circular Dependency Detection

```swift
// Detect circular dependencies
let circular = await AutoDIOptimizer.shared.circularDependencies()
if !circular.isEmpty {
    print("⚠️ Circular dependencies detected:")
    for cycle in circular {
        print("  - \(cycle)")
    }
}
```

### Usage Statistics

```swift
// Get frequently used types
let topTypes = await AutoDIOptimizer.shared.frequentlyUsedTypes(top: 5)
print("Top 5 most used types:")
for (typeName, count) in topTypes {
    print("  \(typeName): \(count) times")
}
```

## Advanced Configuration

### Debounce Interval

Control how often statistics snapshots are taken (50-1000ms):

```swift
// Set snapshot debounce to 200ms
await AutoDIOptimizer.shared.setDebounceInterval(ms: 200)
```

### Custom Log Level

```swift
// Only log errors
await AutoDIOptimizer.shared.setLogLevel(.errors)

// Only log optimizations
await AutoDIOptimizer.shared.setLogLevel(.optimization)

// Disable all logging
await AutoDIOptimizer.shared.setLogLevel(.off)
```

## Actor Optimization

```swift
public struct ActorOptimization: Sendable {
    public let suggestion: String

    public init(suggestion: String) {
        self.suggestion = suggestion
    }
}
```

Actor optimization suggestions help identify types that would benefit from actor isolation:

```swift
// Get actor optimization suggestions
let suggestions = await AutoDIOptimizer.shared.actorOptimizationSuggestions()
for suggestion in suggestions {
    print("💡 \(suggestion.suggestion)")
}
```

## Integration with AutoMonitor

AutoDIOptimizer automatically integrates with `AutoMonitor` for module lifecycle tracking:

```swift
// AutoDIOptimizer automatically notifies AutoMonitor on registration
await WeaveDI.Container.bootstrap { container in
    container.register(MyService.self) {
        MyServiceImpl()  // AutoMonitor.shared.onModuleRegistered() called automatically
    }
}
```

## Best Practices

1. **Keep Optimization Enabled in Development**: Helps identify performance bottlenecks early
2. **Monitor Frequently Used Types**: Consider singleton scope for types resolved 10+ times
3. **Check for Circular Dependencies**: Run checks during development and testing
4. **Adjust Log Level for Production**: Use `.errors` or `.off` in production builds
5. **Review Statistics Periodically**: Use `currentStats()` to understand your DI graph

## See Also

- [AutoMonitor](./performanceMonitoring.md) - Module lifecycle monitoring
- [DIActor](./diActor.md) - Actor-based thread-safe DI
- [Performance Monitoring](./performanceMonitoring.md) - Performance tracking tools
