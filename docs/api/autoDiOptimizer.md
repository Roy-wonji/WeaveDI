# Automatic DI Optimization

WeaveDI's system that automatically generates dependency graphs and optimizes performance in the background.

## Overview

WeaveDI provides an intelligent system that automatically tracks dependency relationships and optimizes performance without any additional configuration. It runs automatically in the background, monitoring usage patterns and providing real-time optimization suggestions.

## Automatic Features

### 🔄 Automatic Dependency Graph Generation

The dependency graph is automatically updated every time dependencies are registered or resolved.

```swift
// Simply register and it's automatically added to the graph
let service = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}

// Auto-generated graph is automatically logged via LogMacro
// No separate calls needed - auto logging: 📊 Auto tracking registration: UserService
```

### 🎯 Automatic Actor Hop Detection and Optimization

Automatically detects Actor hop patterns during dependency resolution and provides optimization suggestions for Swift Concurrency.

```swift
// Simply resolve and Actor hops are automatically detected
let service = await UnifiedDI.resolveAsync(UserService.self)

// Auto log (when 5+ hops occur):
// 🎯 Actor optimization suggestion for UserService: Recommend moving to MainActor (hops: 12, avg: 85.3ms)
```

### 🔒 Automatic Type Safety Verification

Automatically detects and safely handles type safety issues at runtime, especially for Swift 6 Sendable compliance.

```swift
// Type safety is automatically verified during resolution
let service = UnifiedDI.resolve(UserService.self)

// Auto log (when issues detected):
// 🔒 Type safety issue: UserService is not Sendable
// 🚨 Auto safety check: UserService resolved to nil - dependency not registered
```

### ⚡ Automatic Performance Optimization

Analyzes usage patterns to automatically optimize frequently used types using TypeID caching.

```swift
// Automatically optimized when used multiple times
for _ in 1...15 {
    let service = UnifiedDI.resolve(UserService.self)
}

// Optimized types are automatically logged
// Auto log: ⚡ Auto optimized: UserService (10 uses, 75% faster resolution)
```

### 📊 Automatic Usage Statistics Collection

Usage frequency and performance metrics for each type are automatically tracked.

```swift
// Usage statistics are automatically logged every 30 seconds
// Auto log: 📊 [AutoDI] Current stats: ["UserService": 15, "DataRepository": 8]
// Performance stats: avg resolution time: 0.2ms (optimized), 0.8ms (non-optimized)
```

### ⚠️ Automatic Circular Dependency Detection

Automatically detects and warns about circular dependencies during dependency registration.

```swift
// If circular dependencies exist, they're automatically detected and error logged
// Auto log: ⚠️ Auto detected circular dependencies: {ServiceA -> ServiceB -> ServiceA}
```

## API Reference

### Accessing Auto-collected Information

```swift
// 🔄 Auto-generated dependency graph
let graph = UnifiedDI.autoGraph
print("Dependencies: \(graph.dependencies)")
print("Graph structure: \(graph.visualization)")

// ⚡ Auto-optimized types
let optimizedTypes = UnifiedDI.optimizedTypes
print("Optimized: \(optimizedTypes)")

// 📊 Auto-collected usage statistics
let stats = UnifiedDI.stats
print("Usage counts: \(stats)")

// ⚠️ Auto-detected circular dependencies
let circularDeps = UnifiedDI.circularDependencies
if !circularDeps.isEmpty {
    print("Circular dependencies detected: \(circularDeps)")
}

// 🎯 Actor optimization suggestions
let actorOptimizations = UnifiedDI.actorOptimizations
for suggestion in actorOptimizations {
    print("Actor optimization: \(suggestion)")
}

// 🔒 Type safety issue list
let typeSafetyIssues = UnifiedDI.typeSafetyIssues
for issue in typeSafetyIssues {
    print("Type safety issue: \(issue)")
}

// 🛠️ Auto-fixed types
let autoFixedTypes = UnifiedDI.autoFixedTypes
print("Auto-fixed: \(autoFixedTypes)")

// ⚡ Actor hop statistics
let actorHopStats = UnifiedDI.actorHopStats
print("Actor hops: \(actorHopStats)")

// 📊 Async performance statistics (milliseconds)
let asyncPerformanceStats = UnifiedDI.asyncPerformanceStats
print("Async performance: \(asyncPerformanceStats)")
```

### Optimization Control

```swift
// Disable auto optimization (default: enabled)
UnifiedDI.setAutoOptimization(false)

// Check optimization status for specific type
let isOptimized = UnifiedDI.isOptimized(UserService.self)
print("UserService optimized: \(isOptimized)")

// Reset all statistics and start fresh
UnifiedDI.resetStats()

// Force optimization for a specific type
UnifiedDI.forceOptimize(UserService.self)
```

### Logging Level Control

**Default**: All logs are enabled (`.all`)

#### Settings by Usage Scenario:

```swift
// ✅ Default state: Output all logs (recommended for development)
UnifiedDI.setLogLevel(.all)
// 📊 Auto tracking registration: UserService
// ⚡ Auto optimized: UserService (10 uses)
// 📊 [AutoDI] Current stats: {...}

// 📝 When you want to see only registration tracking
UnifiedDI.setLogLevel(.registration)
// 📊 Auto tracking registration: UserService (registration logs only)

// ⚡ When you want to see only performance optimization info
UnifiedDI.setLogLevel(.optimization)
// ⚡ Auto optimized: UserService (10 uses) (optimization logs only)

// ⚠️ When you want to see only errors and warnings
UnifiedDI.setLogLevel(.errors)
// ⚠️ Auto detected circular dependencies: {...} (errors only)

// 🔇 When you want to turn off all auto logging (production)
UnifiedDI.setLogLevel(.off)
// (no logs)

// 🔄 Reset to default
UnifiedDI.setLogLevel(.all)

// 📋 Check current setting
print("Current logging level: \(UnifiedDI.logLevel)")
```

## Advanced Usage

### Custom Optimization Thresholds

```swift
// Set custom thresholds for auto-optimization
UnifiedDI.setOptimizationThreshold(usageCount: 5, timeThreshold: 100) // 100ms

// Set memory limits for caching
UnifiedDI.setMemoryLimits(maxCachedTypes: 50, maxGraphNodes: 200)
```

### Performance Monitoring

```swift
// Enable detailed performance tracking
UnifiedDI.enableDetailedProfiling(true)

// Get detailed performance breakdown
let performanceReport = UnifiedDI.getPerformanceReport()
print("Resolution times: \(performanceReport.resolutionTimes)")
print("Actor hop overhead: \(performanceReport.actorHopOverhead)")
print("Memory usage: \(performanceReport.memoryUsage)")
```

### Integration with Instruments

```swift
// Enable signposts for Instruments profiling
UnifiedDI.enableInstrumentsSignposts(true)

// Custom signpost categories
UnifiedDI.configureSignposts(
    categories: [.registration, .resolution, .optimization]
)
```

## Key Features

- **Zero Configuration**: Works automatically without any setup
- **Background Execution**: Runs asynchronously without affecting app performance
- **Real-time Updates**: Continuously monitors and optimizes every 30 seconds
- **Memory Efficient**: Keeps only frequently used types in optimized cache
- **Swift 6 Compatible**: Full support for Sendable and strict concurrency

## Performance Impact

The automation system is designed to have minimal performance impact:

- **Registration overhead**: < 0.1ms per dependency
- **Resolution overhead**: < 0.05ms for optimized types
- **Background processing**: Runs asynchronously with low priority
- **Memory usage**: < 1MB for typical applications

## Best Practices

### Development Environment

```swift
// Enable full logging for development
#if DEBUG
UnifiedDI.setLogLevel(.all)
UnifiedDI.enableDetailedProfiling(true)
#endif
```

### Production Environment

```swift
// Minimal logging for production
#if !DEBUG
UnifiedDI.setLogLevel(.errors)
UnifiedDI.setAutoOptimization(true) // Keep optimization enabled
#endif
```

### Testing Environment

```swift
// Clean state for each test
override func setUp() async throws {
    await super.setUp()
    await UnifiedDI.releaseAll()
    UnifiedDI.resetStats()
}
```

## Troubleshooting

### High Actor Hop Count

If you see frequent actor hop warnings:

```swift
// Check actor optimization suggestions
let suggestions = UnifiedDI.actorOptimizations
for suggestion in suggestions {
    print("Consider: \(suggestion.description)")
    // Example: "Move UserService to @MainActor for UI operations"
}
```

### Memory Usage Concerns

```swift
// Monitor memory usage
let memoryStats = UnifiedDI.getMemoryStats()
if memoryStats.cacheSize > 10_000_000 { // 10MB
    UnifiedDI.clearOptimizationCache()
}
```

### Performance Regression

```swift
// Compare performance over time
let baseline = UnifiedDI.getPerformanceBaseline()
let current = UnifiedDI.getCurrentPerformance()

if current.averageResolutionTime > baseline.averageResolutionTime * 1.5 {
    print("Performance regression detected")
    UnifiedDI.resetOptimizations()
}
```

## Migration Guide

### From Manual Optimization

If you were previously using manual optimization:

```swift
// Before (manual)
DIContainer.enableOptimization(for: UserService.self)
DIContainer.setCacheSize(100)

// After (automatic)
// Nothing needed - automatic optimization handles this
```

### Deprecated APIs

The following APIs have been replaced:

| Deprecated (AutoDIOptimizer) | Replacement |
|---|---|
| `getCurrentStats()` | `UnifiedDI.stats` |
| `visualizeGraph()` | `UnifiedDI.autoGraph` |
| `getFrequentlyUsedTypes()` | `UnifiedDI.optimizedTypes` |
| `isOptimized(_:)` | `UnifiedDI.isOptimized(_:)` |

The automatic system provides better performance and requires no manual intervention.

---

📖 **Documentation**: [한국어](../ko/api/appDiIntegration) | [English](appDiIntegration)
