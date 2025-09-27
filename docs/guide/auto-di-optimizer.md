# Automatic DI Optimization

System that automatically generates dependency graphs and optimizes performance

## Overview

WeaveDI provides a system that automatically tracks dependency relationships and optimizes performance without any additional configuration. It runs automatically in the background without developers needing to worry about it.

## Automatic Features

### 🔄 Automatic Dependency Graph Generation

The graph is automatically updated every time dependencies are registered or resolved.

```swift
// Simply register and it's automatically added to the graph
let service = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}

// Auto-generated graph is automatically output via LogMacro
// No separate calls needed - auto logging: 📊 Auto tracking registration: UserService
```

### 🎯 Automatic Actor Hop Detection and Optimization

Automatically detects Actor hop patterns during dependency resolution and provides optimization suggestions.

```swift
// Simply resolve and Actor hops are automatically detected
let service = UnifiedDI.resolve(UserService.self)

// Auto log (when 5+ hops occur):
// 🎯 Actor optimization suggestion for UserService: Recommend moving to MainActor (hops: 12, avg: 85.3ms)
```

### 🔒 Automatic Type Safety Verification

Automatically detects and safely handles type safety issues at runtime.

```swift
// Type safety is automatically verified during resolution
let service = UnifiedDI.resolve(UserService.self)

// Auto log (when issues detected):
// 🔒 Type safety issue: UserService is not Sendable
// 🚨 Auto safety check: UserService resolved to nil - dependency not registered
```

### ⚡ Automatic Performance Optimization

Analyzes usage patterns to automatically optimize frequently used types.

```swift
// Automatically optimized when used multiple times
for _ in 1...15 {
    let service = UnifiedDI.resolve(UserService.self)
}

// Optimized types are automatically logged
// Auto log: ⚡ Auto optimized: UserService (10 uses)
```

### 📊 Automatic Usage Statistics Collection

Usage frequency for each type is automatically tracked.

```swift
// Usage statistics are automatically logged every 30 seconds
// Auto log: 📊 [AutoDI] Current stats: ["UserService": 15, "DataRepository": 8]
```

### ⚠️ Automatic Circular Dependency Detection

Automatically detects and warns about circular dependencies during dependency registration.

```swift
// If circular dependencies exist, they're automatically detected and error logged
// Auto log: ⚠️ Auto detected circular dependencies: {ServiceA, ServiceB}
```

## API Reference

### Checking Auto-collected Information

```swift
// 🔄 Auto-generated dependency graph
UnifiedDI.autoGraph

// ⚡ Auto-optimized types
UnifiedDI.optimizedTypes

// 📊 Auto-collected usage statistics
UnifiedDI.stats

// ⚠️ Auto-detected circular dependencies
UnifiedDI.circularDependencies

// 🎯 Actor optimization suggestion list
UnifiedDI.actorOptimizations

// 🔒 Type safety issue list
UnifiedDI.typeSafetyIssues

// 🛠️ Auto-fixed types
UnifiedDI.autoFixedTypes

// ⚡ Actor hop statistics
UnifiedDI.actorHopStats

// 📊 Async performance statistics (milliseconds)
UnifiedDI.asyncPerformanceStats
```

### Optimization Control

```swift
// Disable auto optimization (default: true)
UnifiedDI.setAutoOptimization(false)

// Check optimization status for specific type
UnifiedDI.isOptimized(UserService.self)

// Reset statistics
UnifiedDI.resetStats()
```

### Logging Level Control

**Default**: All logs are enabled (`.all`)

#### Settings by Usage Scenario:

```swift
// ✅ Default state: Output all logs (recommended)
// 📊 Auto tracking registration: UserService
// ⚡ Auto optimized: UserService (10 uses)
// 📊 [AutoDI] Current stats: {...}

// 📝 When you want to see only registered dependencies
UnifiedDI.setLogLevel(.registration)
// 📊 Auto tracking registration: UserService (registration logs only)

// ⚡ When you want to see only performance optimization info
UnifiedDI.setLogLevel(.optimization)
// ⚡ Auto optimized: UserService (10 uses) (optimization logs only)

// ⚠️ When you want to see only circular dependency errors
UnifiedDI.setLogLevel(.errors)
// ⚠️ Auto detected circular dependencies: {...} (errors only)

// 🔇 When you want to turn off all auto logging
UnifiedDI.setLogLevel(.off)
// (no logs)

// 🔄 Reset to default
UnifiedDI.setLogLevel(.all)

// 📋 Check current setting
Log.debug("Current logging level: \(UnifiedDI.logLevel)")
```

## Key Features

- **No Configuration**: Works automatically without any setup
- **Background Execution**: Runs in background without affecting performance
- **Real-time Updates**: Automatically performs optimization every 30 seconds
- **Memory Efficient**: Keeps only top 20 types in cache

## Performance Impact

The automation system is designed to have minimal performance impact:

- Only microsecond-level overhead during registration/resolution
- Runs asynchronously in background
- Optimized memory usage

All these features run automatically without developers needing to call or configure anything separately.

## Deprecated Read API Guide

The read APIs of `AutoDIOptimizer` below have been restructured based on internal snapshots, and external use is deprecated. Use synchronous helpers from `UnifiedDI` or `DIContainer` externally.

| Deprecated (AutoDIOptimizer) | Replacement |
|---|---|
| `getCurrentStats()` | `UnifiedDI.stats()` / `DIContainer.getUsageStatistics()` |
| `visualizeGraph()` | `UnifiedDI.autoGraph()` / `DIContainer.getAutoGeneratedGraph()` |
| `getFrequentlyUsedTypes()` | `UnifiedDI.optimizedTypes()` / `DIContainer.getOptimizedTypes()` |
| `getDetectedCircularDependencies()` | `UnifiedDI.circularDependencies()` / `DIContainer.getDetectedCircularDependencies()` |
| `isOptimized(_:)` | `UnifiedDI.isOptimized(_:)` / `DIContainer.isAutoOptimized(_:)` |
| `getActorOptimizationSuggestions()` | `UnifiedDI.actorOptimizations` |
| `getDetectedTypeSafetyIssues()` | `UnifiedDI.typeSafetyIssues` |
| `getDetectedAutoFixedTypes()` | `UnifiedDI.autoFixedTypes` |
| `getActorHopStats()` | `UnifiedDI.actorHopStats` |
| `getAsyncPerformanceStats()` | `UnifiedDI.asyncPerformanceStats` |
| `getRecentGraphChanges(...)` | `UnifiedDI.getGraphChanges(...)` |
| `getCurrentLogLevel()` | `UnifiedDI.logLevel` / `UnifiedDI.getLogLevel()` |

> For internal use, use `AutoDIOptimizer.readSnapshot()` to read snapshots and calculate necessary information.