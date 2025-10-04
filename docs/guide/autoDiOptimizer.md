# Automatic DI Optimization

System that automatically generates dependency graphs and optimizes performance

## Overview

WeaveDI provides a system that automatically tracks dependency relationships and optimizes performance without any additional configuration. It runs automatically in the background without developers needing to worry about it.

## Automatic Features

### 🔄 Automatic Dependency Graph Generation

```swift
// Simply register and it's automatically added to the graph
let service = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}
// Auto logging: 📊 Auto tracking registration: UserService
```

### 🎯 Automatic Actor Hop Detection and Optimization

```swift
let service = UnifiedDI.resolve(UserService.self)
// Auto log: 🎯 Actor optimization suggestion for UserService: Recommend moving to MainActor (hops: 12, avg: 85.3ms)
```

### 🔒 Automatic Type Safety Verification

```swift
let service = UnifiedDI.resolve(UserService.self)
// Auto log: 🔒 Type safety issue: UserService is not Sendable
```

### ⚡ Automatic Performance Optimization

```swift
for _ in 1...15 {
    let service = UnifiedDI.resolve(UserService.self)
}
// Auto log: ⚡ Auto optimized: UserService (10 uses)
```

## API Reference

### Auto-collected Information

```swift
UnifiedDI.autoGraph              // 🔄 Auto-generated dependency graph
UnifiedDI.optimizedTypes         // ⚡ Auto-optimized types
UnifiedDI.stats                  // 📊 Auto-collected usage statistics
UnifiedDI.circularDependencies   // ⚠️ Auto-detected circular dependencies
UnifiedDI.actorOptimizations     // 🎯 Actor optimization suggestions
UnifiedDI.typeSafetyIssues       // 🔒 Type safety issue list
UnifiedDI.autoFixedTypes         // 🛠️ Auto-fixed types
UnifiedDI.actorHopStats          // ⚡ Actor hop statistics
UnifiedDI.asyncPerformanceStats  // 📊 Async performance statistics
```

### Control

```swift
UnifiedDI.setAutoOptimization(false)  // Disable auto optimization
UnifiedDI.isOptimized(UserService.self)  // Check optimization status
UnifiedDI.resetStats()  // Reset statistics
```

### Logging Level Control

```swift
UnifiedDI.setLogLevel(.all)          // ✅ All logs (default)
UnifiedDI.setLogLevel(.registration) // 📝 Registration only
UnifiedDI.setLogLevel(.optimization) // ⚡ Optimization only
UnifiedDI.setLogLevel(.errors)       // ⚠️ Errors only
UnifiedDI.setLogLevel(.off)          // 🔇 No logs
```

## Key Features

- **No Configuration**: Works automatically without any setup
- **Background Execution**: Runs in background without affecting performance
- **Real-time Updates**: Automatically performs optimization every 30 seconds
- **Memory Efficient**: Keeps only top 20 types in cache

All these features run automatically without developers needing to call or configure anything separately.