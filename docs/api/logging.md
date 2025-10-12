# Logging System

WeaveDI provides a comprehensive logging system that allows you to monitor dependency injection operations with configurable levels and channels.

## Overview

The logging system consists of three main components:

- **DILogger**: Core logging functionality with channel-based filtering
- **DIMonitor**: Unified monitoring system that integrates logging and health checks
- **UnifiedDI Logging API**: Simple interface for configuring logging through UnifiedDI

## Quick Start

### Basic Configuration

```swift
// Set log level to errors only
UnifiedDI.setLogLevel(.errors)

// Enable all logging for development
UnifiedDI.setLogLevel(.all)

// Start development monitoring (includes logging + health checks)
await UnifiedDI.startDevelopmentMonitoring()
```

### Manual Logging

```swift
import WeaveDI

// Log dependency registration
DILogger.logRegistration(type: UserService.self, success: true)

// Log dependency resolution with performance tracking
DILogger.logResolution(type: UserService.self, success: true, duration: 0.002)

// Log performance metrics
DILogger.logPerformance(operation: "bulk_registration", duration: 0.1)

// Log health check results
DILogger.logHealth(component: "UserModule", status: true, details: "All services registered")
```

## DILogger

The core logging component with channel-based filtering and environment flag optimization.

### Log Channels

```swift
public enum DILogChannel: String, CaseIterable, Sendable {
    case registration = "REG"      // Dependency registration
    case resolution = "RES"        // Dependency resolution
    case optimization = "OPT"      // Performance optimization
    case health = "HEALTH"         // Health checks
    case diagnostics = "DIAG"      // Diagnostics
    case general = "GEN"           // General logging
    case error = "ERROR"           // Errors
    case performance = "PERF"      // Performance measurements
}
```

### Log Severity Levels

```swift
public enum DILogSeverity: String, CaseIterable, Comparable, Sendable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}
```

### Log Level Configuration

```swift
public enum DILogLevel: String, CaseIterable, Sendable {
    case all = "ALL"               // All logs
    case registration = "REG"      // Registration only
    case optimization = "OPT"      // Optimization only
    case health = "HEALTH"         // Health checks only
    case errorsOnly = "ERROR"      // Errors only
    case off = "OFF"               // Disable logging
}
```

### Dynamic Configuration

```swift
// Configure log level and severity threshold
DILogger.configure(level: .all, severityThreshold: .debug)

// Get current configuration
let config = DILogger.getCurrentLogLevel()
let severity = DILogger.getCurrentSeverityThreshold()

// Reset to compile-time defaults
DILogger.resetToDefaults()
```

### Specialized Logging Methods

```swift
// Dependency registration logging
DILogger.logRegistration(type: UserRepository.self, success: true)

// Dependency resolution with performance tracking
DILogger.logResolution(type: UserService.self, success: true, duration: 0.002)

// Performance measurement logging
DILogger.logPerformance(operation: "container_initialization", duration: 0.05)

// Health check logging
DILogger.logHealth(component: "NetworkModule", status: true, details: "All endpoints responding")
```

## UnifiedDI Logging API

Simplified interface for configuring logging through UnifiedDI.

### Log Level Configuration

```swift
public extension UnifiedDI {
    enum LogLevel {
        case all         // All logs
        case errors      // Errors only
        case warnings    // Warnings and above
        case performance // Performance related
        case registration // Registration related
        case health      // Health checks related
        case off         // Disable logging
    }
}
```

### Configuration Methods

```swift
// Set log level
UnifiedDI.setLogLevel(.all)              // Enable all logging
UnifiedDI.setLogLevel(.errors)           // Errors only
UnifiedDI.setLogLevel(.performance)      // Performance logs only

// Set severity threshold
UnifiedDI.setLogSeverity(.info)          // Info level and above
UnifiedDI.setLogSeverity(.error)         // Errors only

// Get current configuration
let config = UnifiedDI.getLogConfiguration()
print("Level: \(config.level), Severity: \(config.severity)")

// Reset to defaults
UnifiedDI.resetLogConfiguration()
```

### Monitoring Control

```swift
// Start development monitoring (full logging + health checks)
await UnifiedDI.startDevelopmentMonitoring()

// Start production monitoring (minimal logging)
await UnifiedDI.startProductionMonitoring()

// Stop all monitoring
await UnifiedDI.stopMonitoring()

// Generate monitoring report
let report = await UnifiedDI.generateMonitoringReport()
print("Recommendations: \(report.recommendations)")
```

## Environment Flags

### Build-Time Optimization

For maximum production performance, logging can be completely disabled at compile time:

```swift
// In Release builds: logging automatically disabled (0% performance overhead)
// In Debug builds: minimal logging (errors only)
// With DI_MONITORING_ENABLED flag: full logging + monitoring
```

### Build Configuration

Add to your Xcode build settings for development monitoring:

```bash
# Swift Compiler - Custom Flags > Other Swift Flags
-D DI_MONITORING_ENABLED
```

### Performance Impact

- **Without DI_MONITORING_ENABLED**: Zero overhead in production
- **With DI_MONITORING_ENABLED**: Full monitoring + statistics collection
- **Debug builds**: Error logging only (minimal overhead)

## Integration with UnifiedDI

The logging system is automatically integrated into UnifiedDI operations:

```swift
// Automatic logging of registration
let service = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}
// Logs: "Successfully registered UserService"

// Automatic logging of resolution with performance tracking
let resolved = UnifiedDI.resolve(UserService.self)
// Logs: "Successfully resolved UserService (took 0.15ms)"

// Automatic performance optimization tracking
#if DEBUG && DI_MONITORING_ENABLED
// Tracks resolution patterns for optimization suggestions
#endif
```

## Log Output Format

```
[14:30:25.123] [INFO] [REG] UnifiedDI.swift:85 register(_:factory:) - Successfully registered UserService
[14:30:25.124] [INFO] [PERF] UnifiedDI.swift:89 register(_:factory:) - register(UserService) completed in 0.85ms
[14:30:25.125] [INFO] [RES] UnifiedDI.swift:225 resolve(_:) - Successfully resolved UserService (took 0.12ms)
[14:30:25.126] [INFO] [HEALTH] DIHealthCheck.swift:53 performHealthCheck() - Starting DI health check
```

## Best Practices

### Development

```swift
#if DEBUG
// Enable full monitoring in development
UnifiedDI.setLogLevel(.all)
await UnifiedDI.startDevelopmentMonitoring()
#endif
```

### Production

```swift
// Minimal logging in production
UnifiedDI.setLogLevel(.errors)
await UnifiedDI.startProductionMonitoring()
```

### Testing

```swift
override func setUp() {
    super.setUp()
    // Enable detailed logging for test debugging
    UnifiedDI.setLogLevel(.all)
}

override func tearDown() {
    UnifiedDI.resetLogConfiguration()
    super.tearDown()
}
```

## Thread Safety

All logging operations are thread-safe:

- **NSLock**: Protects dynamic configuration changes
- **Actor Isolation**: DIMonitor uses MainActor for UI updates
- **Sendable Compliance**: All logging types conform to Sendable

## See Also

- [Health Check System](./healthCheck.md)
- [Performance Monitoring](./performanceMonitoring.md)
- [UnifiedDI API](./unifiedDI.md)