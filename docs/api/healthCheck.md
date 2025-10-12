# Health Check System

WeaveDI provides a comprehensive health check system to monitor the state and performance of your dependency injection container in real-time.

## Overview

The health check system consists of:

- **DIHealthCheck**: Actor-based health monitoring service
- **DIHealthStatus**: Comprehensive health status reporting
- **DIMonitor**: Unified monitoring interface with automatic health checks
- **Integration**: Seamless integration with logging and performance monitoring

## Quick Start

### Basic Health Check

```swift
// Perform immediate health check
let status = await UnifiedDI.performHealthCheck()
print("System Health: \(status.overallHealth ? "✅ Healthy" : "❌ Unhealthy")")

// Check specific issues
for check in status.checks {
    print("\(check.name): \(check.status ? "✅" : "❌") - \(check.message)")
}
```

### Continuous Monitoring

```swift
// Start continuous health monitoring
await UnifiedDI.startDevelopmentMonitoring()

// Generate comprehensive monitoring report
let report = await UnifiedDI.generateMonitoringReport()
print("Health Score: \(await UnifiedDI.getRegistryHealthScore())")
print("Recommendations:")
report.recommendations.forEach { print("  • \($0)") }
```

## DIHealthCheck Actor

The core health monitoring service that performs various system checks.

### Basic Usage

```swift
// Get the shared health check instance
let healthCheck = DIHealthCheck.shared

// Perform immediate health check
let status = await healthCheck.performHealthCheck()

// Start continuous monitoring (60-second intervals)
await healthCheck.startMonitoring()

// Start with custom interval
await healthCheck.startMonitoring(interval: 300) // 5 minutes

// Stop monitoring
await healthCheck.stopMonitoring()

// Get last health check result
if let lastStatus = await healthCheck.getLastHealthStatus() {
    print("Last check: \(lastStatus.timestamp)")
}
```

## Health Check Types

The system performs six types of health checks:

### 1. Container Status Check

```swift
private func checkContainerStatus() async -> DIHealthCheckResult
```

Verifies that the DI container is operational and properly initialized.

### 2. Memory Usage Check

```swift
private func checkMemoryUsage() async -> DIHealthCheckResult
```

Monitors memory consumption with configurable thresholds:
- **Normal**: < 50MB
- **Warning**: 50-100MB
- **Critical**: > 100MB

### 3. Performance Metrics Check

```swift
private func checkPerformanceMetrics() async -> DIHealthCheckResult
```

Analyzes dependency resolution performance:
- **Normal**: < 50ms average resolution
- **Warning**: 50-100ms
- **Critical**: > 100ms

### 4. Dependency Graph Check

```swift
private func checkDependencyGraph() async -> DIHealthCheckResult
```

Validates the dependency graph structure and registration count.

### 5. Circular Dependencies Check

```swift
private func checkCircularDependencies() async -> DIHealthCheckResult
```

Detects circular dependencies in the registration graph.

### 6. Registration Integrity Check

```swift
private func checkRegistrationIntegrity() async -> DIHealthCheckResult
```

Verifies registration consistency and identifies potential issues.

## Health Status Data Types

### DIHealthStatus

```swift
public struct DIHealthStatus: Sendable {
    public let timestamp: Date
    public let overallHealth: Bool
    public let checks: [DIHealthCheckResult]
    public let summary: DIHealthSummary
}
```

### DIHealthCheckResult

```swift
public struct DIHealthCheckResult: Sendable {
    public let name: String
    public let status: Bool
    public let message: String
    public let severity: DIHealthSeverity
    public let metrics: [String: String]?
}
```

### DIHealthSeverity

```swift
public enum DIHealthSeverity: String, CaseIterable, Sendable {
    case info = "INFO"
    case warning = "WARNING"
    case critical = "CRITICAL"
}
```

### DIHealthSummary

```swift
public struct DIHealthSummary: Sendable {
    public let registeredDependencies: Int
    public let resolvedDependencies: Int
    public let memoryUsage: Double // MB
    public let averageResolutionTime: Double // ms
    public let circularDependencies: Int
    public let failedResolutions: Int
}
```

## Continuous Monitoring

### Automatic Health Checks

```swift
// Enable automatic health monitoring
await DIHealthCheck.shared.startMonitoring(interval: 60.0) // Every 60 seconds

// The system will:
// 1. Perform regular health checks
// 2. Log results automatically
// 3. Track performance trends
// 4. Generate alerts for issues
```

### Environment-Based Configuration

```swift
#if DEBUG && DI_MONITORING_ENABLED
// Full monitoring in development
await healthCheck.startMonitoring(interval: 60.0)
#else
// Minimal monitoring in production
await healthCheck.startMonitoring(interval: 600.0) // 10 minutes
#endif
```

## Integration with DIMonitor

### Unified Monitoring

```swift
// DIMonitor automatically includes health checks
let monitor = DIMonitor.shared

// Start comprehensive monitoring
await monitor.startMonitoring()

// Monitor events
monitor.addEventHandler { event in
    switch event {
    case .healthCheckCompleted(let status):
        print("Health check completed: \(status.overallHealth)")
    case .criticalError(let message):
        print("Critical issue detected: \(message)")
    case .performanceThresholdExceeded(let operation, let duration):
        print("Performance issue: \(operation) took \(duration)s")
    default:
        break
    }
}
```

### Health Event Types

```swift
public enum DIMonitorEvent: Sendable {
    case healthCheckCompleted(DIHealthStatus)
    case performanceThresholdExceeded(operation: String, duration: TimeInterval)
    case criticalError(message: String)
    case warningDetected(message: String)
    case systemStarted
    case systemStopped
}
```

## Registry Health Verification

### Advanced Registry Checks

```swift
// Verify registry synchronization
let report = await UnifiedDI.verifyRegistryHealth()
print("Health Score: \(report.healthScore)")

// Attempt automatic fixes
let fixReport = await UnifiedDI.autoFixRegistry()
print("Fixed Issues: \(fixReport.fixedIssues.count)")

// Print detailed status
await UnifiedDI.printRegistryStatus()
```

### Registry Health Report

```swift
public struct RegistrySyncReport: Sendable {
    public let healthScore: Double // 0-100
    public let summary: String
    public let factoryInconsistencies: [String]
    public let optimizationStats: OptimizationStats
    public let totalRegistrations: Int
}
```

## Performance Thresholds

### Memory Thresholds

- **Green**: < 50MB memory usage
- **Yellow**: 50-100MB memory usage
- **Red**: > 100MB memory usage

### Performance Thresholds

- **Green**: < 50ms average resolution time
- **Yellow**: 50-100ms average resolution time
- **Red**: > 100ms average resolution time

### Registration Thresholds

- **Warning**: > 100 registered dependencies (consider modularization)
- **Critical**: Circular dependencies detected
- **Info**: No registrations found

## Monitoring Reports

### Generate Comprehensive Reports

```swift
let report = await UnifiedDI.generateMonitoringReport()

print("📊 Monitoring Report")
print("Period: \(report.period)s")
print("Health: \(report.healthStatus.overallHealth ? "✅" : "❌")")
print("Total Logs: \(report.logSummary.totalLogs)")
print("Errors: \(report.logSummary.errorCount)")

print("\n💡 Recommendations:")
report.recommendations.forEach {
    print("  • \($0)")
}
```

### Report Data Structure

```swift
public struct DIMonitorReport: Sendable {
    public let timestamp: Date
    public let period: TimeInterval
    public let healthStatus: DIHealthStatus
    public let logSummary: DILogSummary
    public let recommendations: [String]
}

public struct DILogSummary: Sendable {
    public let totalLogs: Int
    public let errorCount: Int
    public let warningCount: Int
    public let infoCount: Int
    public let debugCount: Int
    public let channelBreakdown: [DILogChannel: Int]
}
```

## Best Practices

### Development Environment

```swift
#if DEBUG
// Frequent health checks for development
await DIHealthCheck.shared.startMonitoring(interval: 30.0)

// Enable detailed health logging
DILogger.configure(level: .health, severityThreshold: .info)

// Add custom event handlers
DIMonitor.shared.addEventHandler { event in
    // Custom development monitoring logic
}
#endif
```

### Production Environment

```swift
// Less frequent health checks for production
await DIHealthCheck.shared.startMonitoring(interval: 600.0) // 10 minutes

// Monitor only critical issues
DILogger.configure(level: .errorsOnly, severityThreshold: .error)

// Set up alerting for critical issues
DIMonitor.shared.addEventHandler { event in
    switch event {
    case .criticalError(let message):
        // Send alert to monitoring system
        AlertSystem.send("DI Critical Error: \(message)")
    default:
        break
    }
}
```

### Testing

```swift
func testHealthCheck() async {
    // Perform health check
    let status = await DIHealthCheck.shared.performHealthCheck()

    // Verify all checks pass
    XCTAssertTrue(status.overallHealth)

    // Check individual components
    let containerCheck = status.checks.first { $0.name == "Container Status" }
    XCTAssertNotNil(containerCheck)
    XCTAssertTrue(containerCheck?.status ?? false)
}
```

## Thread Safety

All health check operations are thread-safe:

- **Actor Isolation**: DIHealthCheck is an actor
- **Sendable Compliance**: All data types are Sendable
- **Concurrent Access**: Safe concurrent health check execution

## See Also

- [Logging System](./logging.md)
- [Performance Monitoring](./performanceMonitoring.md)
- [DIMonitor Integration](./monitoring.md)