# Environment Flags Performance Optimization

## Overview

WeaveDI's environment flag system controls performance optimizations at compile time, eliminating unnecessary overhead in production environments. The `DI_MONITORING_ENABLED` flag enables performance monitoring only in debug mode.

## 🚀 Core Advantages

- **✅ 0% Production Overhead**: Complete removal of monitoring code in release builds
- **✅ Compile-time Optimization**: Leverages Swift's conditional compilation
- **✅ Selective Activation**: Enables features only needed in development
- **✅ Memory Efficiency**: Prevents unnecessary Task creation

## Environment Flag Configuration

### Build Settings Configuration

```swift
// Configure in Build Settings
// Debug Configuration:
SWIFT_ACTIVE_COMPILATION_CONDITIONS = DI_MONITORING_ENABLED DEBUG

// Release Configuration:
SWIFT_ACTIVE_COMPILATION_CONDITIONS = RELEASE
```

### Package.swift Configuration

```swift
// Package.swift
.target(
    name: "YourTarget",
    dependencies: ["WeaveDI"],
    swiftSettings: [
        .define("DI_MONITORING_ENABLED", .when(configuration: .debug))
    ]
)
```

## Optimized API Behavior

### UnifiedDI.resolve() Optimization

```swift
// WeaveDI internal implementation
public static func resolve<T>(_ type: T.Type) -> T? where T: Sendable {
    let resolved = WeaveDI.Container.live.resolve(type)

    // Conditional compilation: tracking only in debug mode
#if DEBUG && DI_MONITORING_ENABLED
    Task { @DIActor in
        AutoDIOptimizer.shared.trackResolution(type)
    }
#endif

    return resolved
}
```

### Performance Tracking Activation Control

```swift
// Runs only in development environment
public static func enableOptimization() {
#if DEBUG && DI_MONITORING_ENABLED
    Task { @DIActor in
        AutoDIOptimizer.shared.setOptimizationEnabled(true)
    }
#endif
    // Does nothing in production
}
```

## Real Performance Comparison

### Before (Always Tracking)
```swift
// Task creation in all environments
public static func resolve<T>(_ type: T.Type) -> T? {
    let resolved = container.resolve(type)
    Task { @DIActor in  // Created even in production!
        AutoDIOptimizer.shared.trackResolution(type)
    }
    return resolved
}
```

### After Optimization (Conditional Tracking)
```swift
// Task creation only in debug
public static func resolve<T>(_ type: T.Type) -> T? {
    let resolved = container.resolve(type)
#if DEBUG && DI_MONITORING_ENABLED
    Task { @DIActor in  // Created only in debug
        AutoDIOptimizer.shared.trackResolution(type)
    }
#endif
    return resolved
}
```

## Flag Application Scope

### 1. UnifiedDI Class
- `resolve()`: Dependency resolution tracking
- `setLogLevel()`: Log level configuration
- `enableOptimization()`: Optimization activation

### 2. DIAdvanced.Performance
- `resolveWithTracking()`: Resolution with performance tracking
- `markAsFrequentlyUsed()`: Mark frequently used types
- `enableOptimization()`: Performance optimization activation

### 3. AutoDIOptimizer Integration
- All performance monitoring features controlled by flags
- Completely disabled in production

## Development Workflow

### During Development (Monitoring Enabled)
```swift
// 1. Enable DI_MONITORING_ENABLED in Build Settings
// 2. Use performance tracking
let stats = await DIAdvanced.Performance.getStats()
print("Dependency resolution stats: \(stats)")

// 3. Enable optimization
DIAdvanced.Performance.enableOptimization()
```

### Production Deployment (Monitoring Disabled)
```swift
// 1. Automatically disabled in Release builds
// 2. Runs with 0% performance overhead
let service = UnifiedDI.resolve(UserService.self)  // No tracking code
```

## Build Verification

### Compile-time Verification
```bash
# Verify flag configuration
swift build -c debug   # Includes DI_MONITORING_ENABLED
swift build -c release # Excludes DI_MONITORING_ENABLED
```

### Runtime Verification
```swift
#if DEBUG && DI_MONITORING_ENABLED
print("🔍 DI monitoring is enabled")
#else
print("🚀 Production mode: monitoring disabled")
#endif
```

## Memory and Performance Impact

### Memory Usage
- **Development Environment**: Minimal overhead from Task creation
- **Production**: 0% additional memory usage

### CPU Usage
- **Development Environment**: Minimal overhead from AutoDIOptimizer tracking
- **Production**: 0% overhead with complete tracking code removal

### App Launch Time
- **Development Environment**: Minimal delay from monitoring initialization
- **Production**: Optimized launch time

## Troubleshooting

### Q: Flag not applied correctly?
**A:** Check `SWIFT_ACTIVE_COMPILATION_CONDITIONS` in Build Settings and verify that `DI_MONITORING_ENABLED` is included in the correct configuration.

### Q: Need statistics in production?
**A:** Implement a separate lightweight metrics collection system or conditionally enable flags.

### Q: Need different behavior per build configuration?
**A:** Define additional flags for more granular control (e.g., `DI_ANALYTICS_ENABLED`).

## Related APIs

- [`AutoDIOptimizer`](./autoDiOptimizer.md) - Performance optimization engine
- [`UnifiedDI`](./unifiedDI.md) - Unified DI API
- [`DIAdvanced.Performance`](./diAdvanced.md#performance) - Advanced performance features

---

*This optimization was added in WeaveDI v3.2.1. It's an innovative performance optimization technique leveraging Swift's conditional compilation.*