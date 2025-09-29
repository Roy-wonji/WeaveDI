# Debugging Tools API Reference

WeaveDI provides comprehensive debugging tools to help you trace dependency resolution, identify configuration issues, and optimize your dependency injection setup. These tools are essential for development and troubleshooting.

## Overview

The debugging tools in WeaveDI offer real-time insights into your dependency container state, resolution paths, and performance characteristics. They help you understand how dependencies are being resolved and identify potential issues early in development.

```swift
import WeaveDI

// Enable debugging for development
#if DEBUG
WeaveDI.Container.enableDebugging()
WeaveDI.Container.setLogLevel(.verbose)
#endif

class MyService {
    @Inject var logger: LoggerProtocol?

    func performOperation() {
        // Debugging automatically traces this resolution
        logger?.info("Operation performed")
    }
}
```

## Core Debugging Features

### Container State Inspection

#### `WeaveDI.Container.printDependencyGraph()`

**Purpose**: Visualizes the complete dependency graph showing all registered dependencies and their relationships. This is invaluable for understanding your application's dependency structure and identifying potential issues.

**When to use**:
- During development to verify dependency registration
- When debugging missing or incorrect dependencies
- To understand complex dependency chains
- For documentation and architecture review

**Parameters**: None

**Returns**: Void (prints to console)

**Example output format**:
```
📊 WeaveDI Dependency Graph
┌─ ServiceType → ConcreteImplementation
├─ AnotherService → Implementation
│   ├── depends on: ServiceType
│   └── depends on: ThirdService
```

Prints the complete dependency graph showing all registered dependencies and their relationships:

```swift
await WeaveDI.Container.bootstrap { container in
    container.register(LoggerProtocol.self) { FileLogger() }
    container.register(CounterRepository.self) { UserDefaultsCounterRepository() }
    container.register(CounterService.self) {
        let logger = container.resolve(LoggerProtocol.self)!
        let repository = container.resolve(CounterRepository.self)!
        return CounterService(logger: logger, repository: repository)
    }
}

// Print complete dependency graph
WeaveDI.Container.printDependencyGraph()
```

Output:
```
📊 WeaveDI Dependency Graph
┌─ LoggerProtocol → FileLogger
├─ CounterRepository → UserDefaultsCounterRepository
└─ CounterService → CounterService
    ├── depends on: LoggerProtocol
    └── depends on: CounterRepository
```

#### `WeaveDI.Container.getDependencyInfo(_:)`

**Purpose**: Retrieves comprehensive metadata about a specific registered dependency, including its type, scope, registration time, and dependency relationships.

**When to use**:
- To inspect individual dependency configurations
- When troubleshooting dependency resolution issues
- For performance analysis of specific services
- To verify dependency registration details

**Parameters**:
- `type: Any.Type` - The type of the dependency to inspect

**Returns**: `DependencyInfo` struct containing:
- `type`: The dependency type
- `scope`: Registration scope (singleton, transient, etc.)
- `dependencies`: Array of types this dependency depends on
- `registrationTime`: When the dependency was registered
- `instanceCount`: Number of instances created
- `lastAccessTime`: When last accessed

Get detailed information about a specific dependency:

```swift
let info = WeaveDI.Container.getDependencyInfo(CounterService.self)
print("Type: \(info.type)")
print("Scope: \(info.scope)")
print("Dependencies: \(info.dependencies)")
print("Registration Time: \(info.registrationTime)")
```

### Resolution Tracing

#### `WeaveDI.Container.enableResolutionTracing()`

**Purpose**: Activates real-time tracing of all dependency resolution operations, providing detailed logs of the resolution process including timing information and dependency paths.

**When to use**:
- During development to understand resolution flow
- When debugging slow dependency resolution
- To identify unused dependencies
- For optimizing container performance

**Parameters**: None

**Returns**: Void

**Side effects**:
- Enables console logging for all resolution attempts
- Adds minimal performance overhead (recommended for DEBUG only)
- Logs include timing information and success/failure status

**Configuration options**:
- Set log verbosity with `setLogLevel(.verbose)` for detailed output
- Use `setLogLevel(.minimal)` for basic resolution tracking
- Combine with performance profiling for comprehensive analysis

Enable detailed tracing of dependency resolution:

```swift
// Enable tracing
WeaveDI.Container.enableResolutionTracing()

class CounterViewModel: ObservableObject {
    @Inject var repository: CounterRepository?
    @Inject var logger: LoggerProtocol?

    func increment() {
        // Resolution is automatically traced
        repository?.saveCount(count + 1)
        logger?.info("Count incremented")
    }
}
```

Trace output:
```
🔍 [RESOLUTION] Resolving CounterRepository
  └── ✅ Found: UserDefaultsCounterRepository (0.2ms)
🔍 [RESOLUTION] Resolving LoggerProtocol
  └── ✅ Found: FileLogger (0.1ms)
```

### Performance Profiling

#### `WeaveDI.Container.enablePerformanceProfiling()`

**Purpose**: Activates comprehensive performance monitoring for all dependency injection operations, collecting detailed metrics on resolution times, memory usage, and container efficiency.

**When to use**:
- To identify performance bottlenecks in dependency resolution
- During load testing to understand DI overhead
- For production monitoring (with careful consideration)
- When optimizing application startup times
- To detect memory leaks in dependency creation

**Parameters**: None

**Returns**: Void

**Collected Metrics**:
- **Resolution Time**: Microsecond-precision timing for each dependency resolution
- **Memory Usage**: Memory allocated during dependency creation
- **Cache Hit/Miss Ratios**: Efficiency of dependency caching
- **Registration Count**: Number of registered dependencies
- **Instance Count**: Active dependency instances in memory
- **Garbage Collection Impact**: Dependencies eligible for cleanup

**Performance Impact**:
- **Development**: Minimal overhead (~1-3% performance impact)
- **Production**: Consider enabling only for critical path monitoring
- **Memory**: Small memory footprint for metric storage
- **Thread Safety**: All profiling operations are thread-safe

**Best Practices**:
- Enable during development and testing phases
- Use conditional compilation (`#if DEBUG`) for development-only profiling
- Combine with `enableResolutionTracing()` for comprehensive debugging
- Export metrics to external monitoring systems in production

Profile dependency resolution performance:

```swift
WeaveDI.Container.enablePerformanceProfiling()

// Profiling data is collected automatically
let viewModel = CounterViewModel() // Resolution times tracked

// Get performance report
let report = WeaveDI.Container.getPerformanceReport()
print("Total resolutions: \(report.totalResolutions)")
print("Average resolution time: \(report.averageResolutionTime)ms")
print("Slowest dependency: \(report.slowestDependency)")
```

## Real-World Examples from Tutorial

### CountApp Debugging Setup

**Overview**: This comprehensive example demonstrates how to integrate WeaveDI's debugging tools into a real-world application. The CountApp example shows production-ready debugging patterns that you can adapt to your own projects.

**Key Features Demonstrated**:
- **Conditional Debugging**: Enable debugging only in development builds
- **Dependency Verification**: Automatic validation of critical dependencies
- **Performance Monitoring**: Track resolution times and memory usage
- **Debug Information Display**: Runtime dependency status reporting
- **Error Handling**: Graceful handling of missing dependencies

**Architecture Benefits**:
- **Zero Production Overhead**: All debugging code is conditionally compiled
- **Comprehensive Coverage**: Every dependency resolution is monitored
- **Real-time Insights**: Immediate feedback on dependency issues
- **Maintainable Structure**: Clean separation of debug and production code

Based on our tutorial CountApp, here's how to implement comprehensive debugging:

```swift
/// Enhanced CountApp with debugging tools
@main
struct CountApp: App {
    init() {
        setupDebugging()
        setupDependencies()
    }

    var body: some Scene {
        WindowGroup {
            CounterView()
                .onAppear {
                    printDebugInfo()
                }
        }
    }

    private func setupDebugging() {
        #if DEBUG
        WeaveDI.Container.enableDebugging()
        WeaveDI.Container.enableResolutionTracing()
        WeaveDI.Container.enablePerformanceProfiling()
        WeaveDI.Container.setLogLevel(.verbose)
        #endif
    }

    private func setupDependencies() {
        Task {
            await WeaveDI.Container.bootstrap { container in
                // Register with debugging info
                container.register(LoggerProtocol.self, name: "main") {
                    FileLogger(filename: "counter.log")
                }

                container.register(CounterRepository.self) {
                    UserDefaultsCounterRepository()
                }

                // Complex dependency for debugging demonstration
                container.register(CounterService.self) {
                    let logger = container.resolve(LoggerProtocol.self, name: "main")!
                    let repository = container.resolve(CounterRepository.self)!
                    return CounterService(logger: logger, repository: repository)
                }
            }

            // Print dependency graph after setup
            WeaveDI.Container.printDependencyGraph()
        }
    }

    private func printDebugInfo() {
        #if DEBUG
        print("\n🔧 CountApp Debug Information")
        print("Container State: \(WeaveDI.Container.isBootstrapped ? "Ready" : "Not Ready")")
        print("Registered Dependencies: \(WeaveDI.Container.getRegisteredDependencies().count)")

        // Check specific dependencies
        let hasLogger = WeaveDI.Container.canResolve(LoggerProtocol.self, name: "main")
        let hasRepository = WeaveDI.Container.canResolve(CounterRepository.self)
        let hasService = WeaveDI.Container.canResolve(CounterService.self)

        print("Logger Available: \(hasLogger)")
        print("Repository Available: \(hasRepository)")
        print("Service Available: \(hasService)")
        #endif
    }
}

/// Enhanced CounterService with debugging
class CounterService {
    private let logger: LoggerProtocol
    private let repository: CounterRepository

    init(logger: LoggerProtocol, repository: CounterRepository) {
        self.logger = logger
        self.repository = repository

        #if DEBUG
        logger.debug("🔧 CounterService initialized with:")
        logger.debug("  - Logger: \(type(of: logger))")
        logger.debug("  - Repository: \(type(of: repository))")
        #endif
    }

    func increment() async -> Int {
        #if DEBUG
        let startTime = CFAbsoluteTimeGetCurrent()
        #endif

        let currentCount = await repository.getCurrentCount()
        let newCount = currentCount + 1
        await repository.saveCount(newCount)

        #if DEBUG
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        logger.debug("⚡ increment() completed in \(String(format: "%.3f", duration * 1000))ms")
        #endif

        logger.info("📊 Count incremented to \(newCount)")
        return newCount
    }
}

/// Debugging-enhanced ViewModel
@MainActor
class CounterViewModel: ObservableObject {
    @Published var count = 0
    @Published var isLoading = false

    @Inject var counterService: CounterService?
    @Inject var logger: LoggerProtocol?

    init() {
        #if DEBUG
        // Verify dependencies during initialization
        verifyDependencies()
        #endif

        Task {
            await loadInitialData()
        }
    }

    func increment() async {
        isLoading = true

        #if DEBUG
        logger?.debug("🔄 Starting increment operation")
        #endif

        guard let service = counterService else {
            #if DEBUG
            logger?.error("❌ CounterService not available")
            #endif
            isLoading = false
            return
        }

        count = await service.increment()
        isLoading = false

        #if DEBUG
        logger?.debug("✅ Increment operation completed")
        #endif
    }

    private func loadInitialData() async {
        guard let service = counterService else {
            #if DEBUG
            logger?.error("❌ Cannot load initial data: CounterService not available")
            #endif
            return
        }

        count = await service.getCurrentCount()

        #if DEBUG
        logger?.debug("📥 Initial data loaded: count = \(count)")
        #endif
    }

    #if DEBUG
    private func verifyDependencies() {
        let serviceAvailable = counterService != nil
        let loggerAvailable = logger != nil

        print("🔍 CounterViewModel Dependency Check:")
        print("  - CounterService: \(serviceAvailable ? "✅" : "❌")")
        print("  - Logger: \(loggerAvailable ? "✅" : "❌")")

        if !serviceAvailable || !loggerAvailable {
            print("⚠️  Missing dependencies detected!")
        }
    }
    #endif
}
```

### WeatherApp Debug Configuration

```swift
/// Weather app with comprehensive debugging
class WeatherAppDebugManager {
    static func setupDebugging() {
        #if DEBUG
        WeaveDI.Container.enableDebugging()
        WeaveDI.Container.enableResolutionTracing()
        WeaveDI.Container.enablePerformanceProfiling()

        // Custom debug filters
        WeaveDI.Container.setDebugFilter { dependencyType in
            // Only trace weather-related dependencies
            return String(describing: dependencyType).contains("Weather")
        }
        #endif
    }

    static func printWeatherDependencyHealth() {
        #if DEBUG
        print("\n🌤️ Weather App Dependency Health Check")

        let criticalDependencies = [
            (HTTPClientProtocol.self, "HTTP Client"),
            (WeatherServiceProtocol.self, "Weather Service"),
            (CacheServiceProtocol.self, "Cache Service"),
            (LoggerProtocol.self, "Logger")
        ]

        for (type, name) in criticalDependencies {
            let available = WeaveDI.Container.canResolve(type)
            let status = available ? "✅" : "❌"
            print("\(status) \(name): \(available ? "Available" : "Missing")")

            if available {
                let info = WeaveDI.Container.getDependencyInfo(type)
                print("   Scope: \(info.scope), Created: \(info.registrationTime)")
            }
        }

        // Print resolution performance
        let report = WeaveDI.Container.getPerformanceReport()
        print("\n📊 Performance Metrics:")
        print("  Total Resolutions: \(report.totalResolutions)")
        print("  Average Time: \(String(format: "%.2f", report.averageResolutionTime))ms")

        if let slowest = report.slowestDependency {
            print("  Slowest: \(slowest.name) (\(String(format: "%.2f", slowest.time))ms)")
        }
        #endif
    }
}

/// Enhanced Weather Service with debug logging
class WeatherService: WeatherServiceProtocol {
    @Inject var httpClient: HTTPClientProtocol?
    @Inject var cache: CacheServiceProtocol?
    @Inject var logger: LoggerProtocol?

    func fetchCurrentWeather(for city: String) async throws -> Weather {
        #if DEBUG
        logger?.debug("🌐 Starting weather fetch for \(city)")
        let startTime = CFAbsoluteTimeGetCurrent()
        #endif

        // Check dependencies
        guard let client = httpClient else {
            #if DEBUG
            logger?.error("❌ HTTP Client not available")
            #endif
            throw WeatherError.httpClientUnavailable
        }

        do {
            let weather = try await client.fetchWeather(for: city)

            #if DEBUG
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger?.debug("✅ Weather fetch completed in \(String(format: "%.2f", duration * 1000))ms")
            #endif

            // Cache the result
            try? await cache?.store(weather, forKey: "weather_\(city)")

            return weather
        } catch {
            #if DEBUG
            logger?.error("❌ Weather fetch failed: \(error.localizedDescription)")
            #endif

            // Try cached data
            if let cached: Weather = try? await cache?.retrieve(forKey: "weather_\(city)") {
                #if DEBUG
                logger?.debug("📱 Using cached weather data for \(city)")
                #endif
                return cached
            }

            throw error
        }
    }
}
```

## Advanced Debugging Tools

### Memory Leak Detection

**Purpose**: Advanced memory analysis tools to detect potential memory leaks and inefficient memory usage patterns in dependency injection.

**How it works**:
- **Instance Tracking**: Monitors the number of active instances for each dependency type
- **Memory Attribution**: Tracks memory usage attributed to specific dependencies
- **Leak Detection**: Compares actual instance counts with expected counts
- **Growth Analysis**: Identifies dependencies with continuously growing memory usage

**Detection Algorithms**:
- **Expected vs Actual**: Compares expected singleton instances with actual counts
- **Retention Analysis**: Identifies objects that should have been garbage collected
- **Memory Growth Patterns**: Detects unusual memory allocation patterns
- **Dependency Chains**: Analyzes memory impact of entire dependency chains

```swift
/// **Advanced Memory Debugging System**
///
/// **Features**:
/// - Real-time memory leak detection
/// - Dependency memory attribution
/// - Memory growth pattern analysis
/// - Automated leak reporting
///
/// **Usage Scenarios**:
/// - Long-running application testing
/// - Memory optimization during development
/// - Production memory monitoring
/// - Automated testing pipelines
class MemoryDebugger {

    /// **Purpose**: Performs comprehensive memory analysis to detect potential leaks
    ///
    /// **Detection Criteria**:
    /// - Instance count exceeds expected threshold
    /// - Memory usage grows continuously without bounds
    /// - Objects persist beyond expected lifecycle
    /// - Circular reference detection
    ///
    /// **Performance**: Low overhead (~0.1% CPU impact)
    /// **Thread Safety**: All operations are thread-safe
    /// **Memory Impact**: ~50KB for tracking metadata
    static func detectPotentialLeaks() {
        #if DEBUG
        let report = WeaveDI.Container.getMemoryReport()

        print("🧠 Advanced Memory Analysis Report:")
        print("  📊 Active Instances: \(report.activeInstances)")
        print("  💾 Memory Usage: \(ByteCountFormatter().string(fromByteCount: Int64(report.estimatedMemoryUsage)))")
        print("  🕐 Analysis Time: \(Date())")

        // **Advanced Leak Detection Algorithm**
        var leakCount = 0
        for dependency in report.dependencies {
            if dependency.instanceCount > dependency.expectedCount {
                leakCount += 1
                let excessInstances = dependency.instanceCount - dependency.expectedCount

                print("⚠️  **POTENTIAL LEAK DETECTED**")
                print("     Type: \(dependency.type)")
                print("     Expected: \(dependency.expectedCount) instances")
                print("     Actual: \(dependency.instanceCount) instances")
                print("     Excess: \(excessInstances) instances")
                print("     Memory Impact: ~\(excessInstances * dependency.averageInstanceSize) bytes")
                print("     Last Created: \(dependency.lastCreationTime)")

                // **Provide actionable recommendations**
                provideLeakRecommendations(for: dependency)
            }
        }

        if leakCount == 0 {
            print("✅ No memory leaks detected - All dependencies within expected bounds")
        } else {
            print("🚨 Detected \(leakCount) potential memory leaks - Review recommended")
        }
        #endif
    }

    /// **Purpose**: Provides specific recommendations for addressing detected memory issues
    private static func provideLeakRecommendations(for dependency: DependencyAnalysis) {
        print("     💡 **Recommendations**:")

        if dependency.hasCircularReferences {
            print("       - Break circular references using weak references")
            print("       - Consider dependency inversion patterns")
        }

        if dependency.isFactory && dependency.instanceCount > 100 {
            print("       - Consider object pooling for factory dependencies")
            print("       - Implement proper lifecycle management")
        }

        if dependency.memoryGrowthRate > 0.1 {
            print("       - Memory usage growing at \(String(format: "%.1f", dependency.memoryGrowthRate * 100))% per minute")
            print("       - Review object retention policies")
        }
    }
}
```

### Dependency Cycle Detection

```swift
extension WeaveDI.Container {
    static func detectCycles() -> [DependencyCycle] {
        #if DEBUG
        let cycles = WeaveDI.Container.analyzeDependencyCycles()

        for cycle in cycles {
            print("🔄 Dependency Cycle Detected:")
            for (index, dependency) in cycle.path.enumerated() {
                let arrow = index < cycle.path.count - 1 ? " → " : ""
                print("  \(dependency)\(arrow)")
            }
        }

        return cycles
        #else
        return []
        #endif
    }
}
```

### Runtime Configuration Validation

```swift
class ConfigurationValidator {
    static func validateConfiguration() -> ValidationResult {
        #if DEBUG
        var issues: [ValidationIssue] = []

        // Check for missing dependencies
        let registeredTypes = WeaveDI.Container.getRegisteredDependencies()
        let requiredTypes = findRequiredDependencies()

        for requiredType in requiredTypes {
            if !registeredTypes.contains(where: { $0.type == requiredType }) {
                issues.append(.missingDependency(requiredType))
            }
        }

        // Check for circular dependencies
        let cycles = WeaveDI.Container.detectCycles()
        for cycle in cycles {
            issues.append(.circularDependency(cycle))
        }

        // Check for performance issues
        let report = WeaveDI.Container.getPerformanceReport()
        if report.averageResolutionTime > 10.0 { // 10ms threshold
            issues.append(.slowResolution(report.averageResolutionTime))
        }

        return ValidationResult(issues: issues)
        #else
        return ValidationResult(issues: [])
        #endif
    }

    private static func findRequiredDependencies() -> [Any.Type] {
        // Scan code for @Inject property wrappers
        // This would be implemented using reflection or compile-time analysis
        return []
    }
}

struct ValidationResult {
    let issues: [ValidationIssue]

    var isValid: Bool {
        return issues.isEmpty
    }
}

enum ValidationIssue {
    case missingDependency(Any.Type)
    case circularDependency(DependencyCycle)
    case slowResolution(Double)
}
```

## Testing and Debugging Integration

### Test Debugging Setup

```swift
class DIDebugTests: XCTestCase {
    override func setUp() async throws {
        await WeaveDI.Container.resetForTesting()

        #if DEBUG
        WeaveDI.Container.enableDebugging()
        WeaveDI.Container.enableResolutionTracing()
        #endif
    }

    func testDependencyResolution() async throws {
        await WeaveDI.Container.bootstrap { container in
            container.register(LoggerProtocol.self) { TestLogger() }
            container.register(CounterRepository.self) { MockCounterRepository() }
        }

        // Verify registration
        XCTAssertTrue(WeaveDI.Container.canResolve(LoggerProtocol.self))
        XCTAssertTrue(WeaveDI.Container.canResolve(CounterRepository.self))

        // Test resolution with tracing
        let logger = WeaveDI.Container.resolve(LoggerProtocol.self)
        XCTAssertNotNil(logger)

        #if DEBUG
        let report = WeaveDI.Container.getPerformanceReport()
        XCTAssertGreaterThan(report.totalResolutions, 0)
        #endif
    }

    func testDependencyGraphIntegrity() async throws {
        await WeaveDI.Container.bootstrap { container in
            container.register(CounterService.self) {
                let logger = container.resolve(LoggerProtocol.self)!
                let repository = container.resolve(CounterRepository.self)!
                return CounterService(logger: logger, repository: repository)
            }
            container.register(LoggerProtocol.self) { TestLogger() }
            container.register(CounterRepository.self) { MockCounterRepository() }
        }

        #if DEBUG
        // Validate no circular dependencies
        let cycles = WeaveDI.Container.detectCycles()
        XCTAssertTrue(cycles.isEmpty, "Circular dependencies detected")

        // Validate all dependencies can be resolved
        let validation = ConfigurationValidator.validateConfiguration()
        XCTAssertTrue(validation.isValid, "Configuration validation failed")
        #endif
    }
}
```

### Debug Views for SwiftUI

```swift
#if DEBUG
struct DebugView: View {
    @State private var dependencyInfo: [DependencyInfo] = []
    @State private var performanceReport: PerformanceReport?

    var body: some View {
        NavigationView {
            List {
                Section("Dependencies") {
                    ForEach(dependencyInfo, id: \.type) { info in
                        VStack(alignment: .leading) {
                            Text(info.name)
                                .font(.headline)
                            Text("Scope: \(info.scope)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if let report = performanceReport {
                    Section("Performance") {
                        HStack {
                            Text("Total Resolutions")
                            Spacer()
                            Text("\(report.totalResolutions)")
                        }

                        HStack {
                            Text("Average Time")
                            Spacer()
                            Text("\(String(format: "%.2f", report.averageResolutionTime))ms")
                        }
                    }
                }
            }
            .navigationTitle("DI Debug Info")
            .onAppear {
                loadDebugInfo()
            }
        }
    }

    private func loadDebugInfo() {
        dependencyInfo = WeaveDI.Container.getRegisteredDependencies()
        performanceReport = WeaveDI.Container.getPerformanceReport()
    }
}

struct DIDebugModifier: ViewModifier {
    @State private var showDebug = false

    func body(content: Content) -> some View {
        content
            .onShake {
                showDebug.toggle()
            }
            .sheet(isPresented: $showDebug) {
                DebugView()
            }
    }
}

extension View {
    func debugDI() -> some View {
        self.modifier(DIDebugModifier())
    }
}
#endif
```

## Production Debugging

### Safe Production Debugging

```swift
class ProductionDebugger {
    private static let isDebugEnabled = UserDefaults.standard.bool(forKey: "WeaveDI_Debug_Enabled")

    static func enableSafeDebugging() {
        guard isDebugEnabled else { return }

        // Only enable non-intrusive debugging in production
        WeaveDI.Container.enablePerformanceProfiling()
        WeaveDI.Container.setLogLevel(.error) // Only log errors
    }

    static func generateDiagnosticReport() -> DiagnosticReport {
        return DiagnosticReport(
            containerState: WeaveDI.Container.isBootstrapped,
            dependencyCount: WeaveDI.Container.getRegisteredDependencies().count,
            performanceMetrics: WeaveDI.Container.getPerformanceReport(),
            timestamp: Date()
        )
    }
}

struct DiagnosticReport: Codable {
    let containerState: Bool
    let dependencyCount: Int
    let performanceMetrics: PerformanceReport
    let timestamp: Date
}
```

### Remote Debugging

```swift
class RemoteDebugger {
    static func sendDiagnostics() async {
        #if DEBUG
        let report = ProductionDebugger.generateDiagnosticReport()

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(report)

            // Send to debugging service
            await sendToDebugService(data)
        } catch {
            print("Failed to send diagnostics: \(error)")
        }
        #endif
    }

    private static func sendToDebugService(_ data: Data) async {
        // Implementation for sending diagnostics to remote service
    }
}
```

## Best Practices

### 1. Use Conditional Compilation

```swift
#if DEBUG
WeaveDI.Container.enableDebugging()
WeaveDI.Container.enableResolutionTracing()
#endif
```

### 2. Implement Comprehensive Logging

```swift
class DebugLogger: LoggerProtocol {
    func debug(_ message: String) {
        #if DEBUG
        print("🔧 [DEBUG] \(message)")
        #endif
    }

    func info(_ message: String) {
        print("ℹ️ [INFO] \(message)")
    }

    func error(_ message: String) {
        print("❌ [ERROR] \(message)")
    }
}
```

### 3. Validate Dependencies Early

```swift
func validateDependencies() {
    #if DEBUG
    let validation = ConfigurationValidator.validateConfiguration()
    assert(validation.isValid, "Dependency configuration is invalid")
    #endif
}
```

### 4. Monitor Performance

```swift
func monitorPerformance() {
    #if DEBUG
    let report = WeaveDI.Container.getPerformanceReport()
    if report.averageResolutionTime > 5.0 {
        print("⚠️ Slow dependency resolution detected: \(report.averageResolutionTime)ms")
    }
    #endif
}
```

## See Also

- [Performance Monitoring API](./performanceMonitoring.md) - Monitor DI performance
- [UnifiedDI API](./unifiedDI.md) - Simplified DI interface
- [Bootstrap API](./bootstrap.md) - Container initialization
- [Testing Guide](../tutorial/testing.md) - Testing strategies