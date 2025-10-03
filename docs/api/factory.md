# @Factory Property Wrapper

The `@Factory` property wrapper provides factory-based dependency injection with dynamic instance creation, generating new instances each time the property is accessed. This is fundamentally different from `@Injected` which caches resolved dependencies, making `@Factory` ideal for stateful objects, session-scoped services, or scenarios requiring fresh instances with independent state.

## Overview

Unlike `@Injected` which caches resolved dependencies for singleton-like behavior, `@Factory` implements a dynamic creation pattern that instantiates a new object every time you access the property. This ensures complete state isolation between usages, which is crucial for:

- **Stateful Services**: Objects that maintain internal state that shouldn't be shared
- **Session-Scoped Objects**: Request or user session-specific instances
- **Temporary Workers**: Short-lived processing objects with specific configurations
- **Thread-Safe Operations**: Independent instances for concurrent processing
- **Clean State Requirements**: Objects that need reset state for each operation

**Performance Characteristics**:
- **Memory Usage**: Higher memory usage due to multiple instances
- **Creation Overhead**: Small instantiation cost on each access (~0.1-2ms depending on object complexity)
- **Garbage Collection**: Instances can be collected after use, preventing memory leaks
- **Thread Safety**: Each access gets an independent instance, eliminating shared state issues

```swift
import WeaveDI

class DataProcessor {
    @Factory var taskManager: TaskManager?
    @Factory var reportGenerator: ReportGenerator?

    func processData() {
        // Each access creates a new TaskManager instance
        let manager1 = taskManager // New instance
        let manager2 = taskManager // Another new instance

        manager1?.startTask("Task A")
        manager2?.startTask("Task B") // Independent instances
    }
}
```

## Basic Usage

### Simple Factory Injection

**Purpose**: Basic factory-based dependency injection for creating new instances on each property access.

**When to use**:
- Objects that maintain mutable state
- Services that need clean initialization for each operation
- Processing objects that configure themselves based on input
- Temporary or short-lived workers

**Performance Impact**:
- **Memory**: Each access creates a new instance (~1-100KB depending on object size)
- **CPU**: Minimal instantiation overhead per access
- **Threading**: Thread-safe due to independent instances

```swift
class DocumentService {
    @Factory var pdfGenerator: PDFGenerator?

    func createDocument() -> Document? {
        // New PDFGenerator instance for each document
        return pdfGenerator?.generatePDF()
    }
}
```

### With Session-Based Objects

**Purpose**: Factory injection for session or request-scoped objects that require independent state management and lifecycle control.

**Benefits**:
- **State Isolation**: Each session gets independent state
- **Concurrent Safety**: Multiple sessions can run simultaneously
- **Resource Management**: Sessions can be individually managed and cleaned up
- **Configuration Flexibility**: Each session can have different configurations

**Use Cases**:
- HTTP request processing
- User session management
- Transaction scoped operations
- Batch processing jobs

Factory injection is perfect for session or request-scoped objects:

```swift
class APIService {
    @Factory var httpSession: HTTPSession?
    @Factory var requestBuilder: RequestBuilder?

    func makeRequest() async {
        // Fresh session for each request
        guard let session = httpSession,
              let builder = requestBuilder else { return }

        let request = builder.buildRequest()
        await session.execute(request)
    }
}
```

## Real-World Examples from Tutorial

### CountApp with Factory Pattern

Based on our tutorial code, here's how @Factory can be used for creating fresh instances:

```swift
/// Factory-based counter for independent counting sessions
class CounterSessionManager {
    @Factory var counterSession: CounterSession?
    @Factory var logger: LoggerProtocol?

    func startNewCountingSession(name: String) async {
        guard let session = counterSession else { return }

        logger?.info("🆕 새로운 카운터 세션 시작: \(name)")

        // Each session is independent
        session.sessionName = name
        session.startTime = Date()
        await session.initialize()
    }

    func createMultipleSessions() async {
        // Each call creates a new independent session
        await startNewCountingSession(name: "Session A")
        await startNewCountingSession(name: "Session B")
        await startNewCountingSession(name: "Session C")

        // All sessions are independent instances
    }
}

/// Session-scoped counter implementation
class CounterSession {
    var sessionName: String = ""
    var startTime: Date = Date()
    var currentCount: Int = 0

    @Injected var repository: CounterRepository?
    @Injected var logger: LoggerProtocol?

    func initialize() async {
        logger?.info("📊 세션 '\(sessionName)' 초기화됨")
        currentCount = await repository?.getCurrentCount() ?? 0
    }

    func increment() async {
        currentCount += 1
        await repository?.saveCount(currentCount)
        logger?.info("⬆️ 세션 '\(sessionName)': \(currentCount)")
    }
}
```

### WeatherApp with Factory for Report Generation

```swift
/// Weather report service using factory pattern for fresh reports
class WeatherReportService {
    @Factory var reportGenerator: WeatherReportGenerator?
    @Factory var chartBuilder: WeatherChartBuilder?
    @Injected var weatherService: WeatherServiceProtocol?

    func generateDailyReport(for city: String) async throws -> WeatherReport? {
        guard let generator = reportGenerator,
              let weather = try await weatherService?.fetchCurrentWeather(for: city) else {
            return nil
        }

        // Fresh generator for each report
        generator.configure(for: .daily)
        return await generator.generateReport(weather: weather)
    }

    func generateWeeklyReport(for city: String) async throws -> WeatherReport? {
        guard let generator = reportGenerator,
              let forecast = try await weatherService?.fetchForecast(for: city) else {
            return nil
        }

        // New generator instance with different configuration
        generator.configure(for: .weekly)
        return await generator.generateWeeklyReport(forecast: forecast)
    }

    func createWeatherChart(for city: String) async throws -> WeatherChart? {
        guard let builder = chartBuilder,
              let forecast = try await weatherService?.fetchForecast(for: city) else {
            return nil
        }

        // Fresh chart builder for each chart
        return await builder.buildChart(data: forecast)
    }
}

/// Factory-created report generator
class WeatherReportGenerator {
    enum ReportType {
        case daily, weekly, monthly
    }

    private var reportType: ReportType = .daily
    private var generationTime: Date = Date()

    @Injected var logger: LoggerProtocol?

    func configure(for type: ReportType) {
        self.reportType = type
        self.generationTime = Date()
        logger?.info("📋 리포트 생성기 구성: \(type)")
    }

    func generateReport(weather: Weather) async -> WeatherReport {
        logger?.info("📊 \(reportType) 리포트 생성 중...")

        return WeatherReport(
            type: reportType,
            city: weather.city,
            temperature: weather.temperature,
            generatedAt: generationTime,
            summary: generateSummary(weather: weather)
        )
    }

    func generateWeeklyReport(forecast: [WeatherForecast]) async -> WeatherReport {
        logger?.info("📈 주간 리포트 생성 중...")

        let avgTemp = forecast.reduce(0.0) { $0 + ($1.maxTemperature + $1.minTemperature) / 2 } / Double(forecast.count)

        return WeatherReport(
            type: .weekly,
            city: forecast.first?.formattedDate ?? "Unknown",
            temperature: avgTemp,
            generatedAt: generationTime,
            summary: "주간 평균 온도: \(String(format: "%.1f", avgTemp))°C"
        )
    }

    private func generateSummary(weather: Weather) -> String {
        switch reportType {
        case .daily:
            return "\(weather.city)의 오늘 날씨: \(weather.description), \(weather.formattedTemperature)"
        case .weekly:
            return "\(weather.city)의 주간 날씨 요약"
        case .monthly:
            return "\(weather.city)의 월간 날씨 요약"
        }
    }
}
```

## Factory vs Inject Comparison

### When to Use @Factory

**Decision Criteria**: Choose `@Factory` over `@Injected` based on state management requirements and lifecycle needs.

**@Factory is ideal for**:
- **Stateful Objects**: Objects that maintain changing internal state
- **Session-Scoped Services**: Request or user-specific instances
- **Configurable Workers**: Objects that need different configurations per use
- **Short-Lived Objects**: Temporary processing objects
- **Thread-Safe Requirements**: Independent instances for concurrent access

**@Injected is ideal for**:
- **Stateless Services**: Pure functions or utility classes
- **Shared Resources**: Database connections, loggers, configuration
- **Expensive Objects**: Heavy initialization that should happen once
- **Global State**: Application-wide singleton services

```swift
class DocumentProcessor {
    // ✅ Use @Factory for stateful, short-lived objects
    @Factory var documentBuilder: DocumentBuilder?
    @Factory var validator: DocumentValidator?

    // ✅ Use @Injected for long-lived, stateless services
    @Injected var documentRepository: DocumentRepository?
    @Injected var logger: LoggerProtocol?

    func processDocument(_ content: String) async {
        // Fresh builder and validator for each document
        guard let builder = documentBuilder,
              let validator = validator else { return }

        builder.setContent(content)
        let document = builder.build()

        if validator.isValid(document) {
            // Shared repository for all operations
            await documentRepository?.save(document)
            logger?.info("문서 처리 완료")
        }
    }
}
```

### Memory and Performance Considerations

**Memory Management Strategies**:
- **Instance Lifecycle**: Factory instances are created on-demand and can be garbage collected
- **Memory Footprint**: Consider the cumulative memory usage of multiple instances
- **Pool Pattern**: For expensive objects, consider implementing object pooling

**Performance Optimization Guidelines**:
- **Batch Operations**: Reuse factory instances across batch operations when possible
- **Resource Monitoring**: Monitor memory usage patterns in production
- **Garbage Collection**: Factory instances are eligible for immediate GC after use

**Threading Considerations**:
- **Concurrency Safety**: Each thread gets independent instances
- **Resource Contention**: No shared state between factory instances
- **Parallel Processing**: Safe for concurrent operations without synchronization

```swift
class PerformanceTestService {
    @Factory var heavyProcessor: HeavyProcessor? // New instance each time
    @Injected var cacheService: CacheService?      // Shared instance

    func processData() {
        // ⚠️ Consider memory usage with @Factory
        for i in 0..<1000 {
            // This creates 1000 HeavyProcessor instances!
            heavyProcessor?.process(data: "item \(i)")
        }

        // ✅ Better approach: reuse when possible
        guard let processor = heavyProcessor else { return }
        for i in 0..<1000 {
            processor.process(data: "item \(i)")
        }
    }
}
```

## Configuration and Registration

### Registering Factory Dependencies

**Purpose**: Register dependencies for factory injection using the same registration API as singleton injection.

**Key Differences**:
- **Registration**: Same API as `@Injected` dependencies
- **Resolution**: Creates new instances on each `@Factory` access
- **Lifecycle**: Container manages factory closure, not instances
- **Thread Safety**: Registration is thread-safe, instances are independent

**Registration Patterns**:
- **Simple Registration**: Basic factory closure registration
- **Parameterized Factories**: Factories that accept configuration parameters
- **Dependency Injection**: Factory closures can resolve other dependencies

Factory dependencies are registered the same way as regular dependencies:

```swift
// DependencyBootstrap.swift
await WeaveDI.Container.bootstrap { container in
    // Register for factory injection
    container.register(TaskManager.self) {
        TaskManagerImpl()
    }

    container.register(ReportGenerator.self) {
        WeatherReportGenerator()
    }

    container.register(DocumentBuilder.self) {
        PDFDocumentBuilder()
    }

    // These will create new instances each time @Factory resolves them
}
```

### Factory with Parameters

**Purpose**: Advanced factory patterns that support parameterized instance creation with dynamic configuration.

**Benefits**:
- **Dynamic Configuration**: Create instances with specific parameters
- **Context-Aware Creation**: Factories that adapt based on runtime context
- **Type Safety**: Compile-time parameter validation
- **Flexible Instantiation**: Support multiple creation patterns

**Implementation Strategies**:
- **Service Factory Pattern**: Dedicated factory services for complex creation logic
- **Builder Integration**: Combine with builder pattern for complex objects
- **Dependency Resolution**: Factories can resolve other dependencies during creation

For more complex factory patterns, you can use closure-based factories:

```swift
class ServiceFactory {
    @Injected var container: WeaveDI.Container?

    func createTaskManager(for taskType: TaskType) -> TaskManager? {
        // Create configured instances based on parameters
        let manager = container?.resolve(TaskManager.self)
        manager?.configure(for: taskType)
        return manager
    }
}
```

## Thread Safety

**Thread Safety Guarantees**: `@Factory` provides comprehensive thread safety through instance isolation and safe resolution mechanisms.

**Safety Mechanisms**:
- **Independent Instances**: Each property access creates isolated instances
- **No Shared State**: Factory instances don't share mutable state
- **Thread-Safe Resolution**: Container resolution is internally synchronized
- **Concurrent Access**: Multiple threads can safely access factory properties

**Concurrency Benefits**:
- **Parallel Processing**: Each thread gets independent instances
- **No Synchronization**: No need for manual thread synchronization
- **Race Condition Prevention**: Instance isolation prevents race conditions
- **Scalable Concurrency**: Performance scales with thread count

**Performance Characteristics**:
- **Resolution Overhead**: Minimal synchronized access during resolution
- **Instance Creation**: No synchronization after instance creation
- **Memory Barriers**: Automatic memory barrier handling

@Factory is thread-safe and can be used across different queues:

```swift
class ConcurrentProcessor {
    @Factory var workItem: WorkItem?

    func processConcurrently() async {
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    // Each task gets its own WorkItem instance
                    self.workItem?.execute(id: i)
                }
            }
        }
    }
}
```

## Testing with @Factory

### Mock Factory Dependencies

**Testing Strategy**: Factory dependencies enable powerful testing patterns through fresh mock instances and state isolation.

**Testing Benefits**:
- **Fresh Mocks**: Each test gets new mock instances
- **State Isolation**: Tests don't interfere with each other
- **Behavior Verification**: Can verify creation patterns and instance usage
- **Independent Assertions**: Each test validates independent object behavior

**Mock Patterns**:
- **State Verification**: Verify mock state after operations
- **Interaction Counting**: Track how many instances were created
- **Configuration Testing**: Verify factory instances are properly configured
- **Lifecycle Testing**: Test instance creation and cleanup patterns

```swift
class FactoryServiceTests: XCTestCase {

    func testDocumentProcessing() async throws {
        // Register factory mocks
        await WeaveDI.Container.bootstrap { container in
            container.register(DocumentBuilder.self) { MockDocumentBuilder() }
            container.register(DocumentValidator.self) { MockDocumentValidator() }
        }

        let processor = DocumentProcessor()

        // Each test gets fresh mock instances
        await processor.processDocument("test content")

        // Verify new instances were created
        XCTAssertNotNil(processor.documentBuilder)
        XCTAssertNotNil(processor.validator)
    }
}

class MockDocumentBuilder: DocumentBuilder {
    private(set) var buildCallCount = 0

    func build() -> Document {
        buildCallCount += 1
        return Document(content: "mock content")
    }
}
```

## Advanced Patterns

### Factory with Lifecycle Management

**Purpose**: Advanced lifecycle management for factory-created instances, providing tracking, cleanup, and resource management.

**Lifecycle Management Features**:
- **Instance Tracking**: Monitor active factory instances
- **Resource Cleanup**: Automatic cleanup of resources when instances complete
- **Memory Management**: Prevent memory leaks from abandoned instances
- **Performance Monitoring**: Track instance creation and destruction patterns

**Implementation Strategies**:
- **Weak References**: Use weak references to avoid retain cycles
- **Completion Callbacks**: Register cleanup callbacks for instance completion
- **Resource Pooling**: Implement pooling for expensive factory instances
- **Automatic Cleanup**: Cleanup resources during object deinitialization

**Use Cases**:
- **Session Management**: Track and cleanup user sessions
- **Resource Management**: Manage database connections or file handles
- **Batch Processing**: Coordinate lifecycle of batch processing workers
- **Temporary Services**: Manage lifecycle of temporary service instances

```swift
class ManagedFactoryService {
    @Factory var sessionManager: SessionManager?
    private var activeSessions: [SessionManager] = []

    func createManagedSession() -> SessionManager? {
        guard let session = sessionManager else { return nil }

        // Track factory-created instances
        activeSessions.append(session)

        // Setup cleanup
        session.onComplete = { [weak self] completedSession in
            self?.cleanupSession(completedSession)
        }

        return session
    }

    private func cleanupSession(_ session: SessionManager) {
        activeSessions.removeAll { $0 === session }
    }

    deinit {
        // Clean up all managed sessions
        activeSessions.forEach { $0.cleanup() }
    }
}
```

### Factory with Builder Pattern

**Purpose**: Combine factory injection with builder pattern for flexible, fluent object construction with method chaining.

**Pattern Benefits**:
- **Fluent Interface**: Chain configuration methods for readable construction
- **Flexible Configuration**: Support multiple configuration scenarios
- **Type Safety**: Compile-time validation of builder configurations
- **Immutable Results**: Create immutable objects through builder pattern

**Implementation Features**:
- **Method Chaining**: Fluent API for step-by-step configuration
- **Validation**: Builder can validate configuration before object creation
- **Default Values**: Provide sensible defaults with override capability
- **Complex Construction**: Handle complex object initialization logic

**Use Cases**:
- **Report Generation**: Configure and build complex reports
- **UI Component Creation**: Build configured UI components
- **Data Processing**: Configure data processors with specific parameters
- **Service Configuration**: Build services with complex configuration requirements

```swift
class ReportBuilderService {
    @Factory var reportBuilder: ReportBuilder?

    func createCustomReport() -> Report? {
        return reportBuilder?
            .setTitle("Custom Report")
            .addSection("Weather Data")
            .addSection("Analysis")
            .setFormat(.pdf)
            .build()
    }

    func createSimpleReport() -> Report? {
        return reportBuilder?
            .setTitle("Simple Report")
            .setFormat(.text)
            .build()
    }
}
```

## Best Practices

### 1. Use Factory for Stateful Objects

**Guideline**: Reserve `@Factory` for objects that maintain internal state or require fresh initialization for each use.

**Stateful Object Indicators**:
- **Mutable Properties**: Objects with properties that change during their lifetime
- **Configuration State**: Objects that need different configurations per use
- **Session Context**: Objects that maintain user or request-specific context
- **Processing State**: Objects that maintain processing progress or intermediate results

**Decision Framework**:
- If the object maintains state → Use `@Factory`
- If the object is stateless → Use `@Injected`
- If state isolation is required → Use `@Factory`
- If shared state is acceptable → Use `@Injected`
```swift
// ✅ Good - stateful objects that need fresh instances
@Factory var userSession: UserSession?
@Factory var shoppingCart: ShoppingCart?
@Factory var gameState: GameState?

// ❌ Avoid - stateless services (use @Injected instead)
@Factory var mathUtils: MathUtils? // Should be @Inject
```

### 2. Consider Memory Impact

**Memory Management Strategy**: Carefully evaluate the memory implications of factory injection, especially for frequently accessed properties.

**Memory Considerations**:
- **Instance Size**: Consider the memory footprint of factory-created objects
- **Creation Frequency**: Analyze how often factory properties are accessed
- **Lifecycle Duration**: Evaluate how long instances remain in memory
- **Cumulative Usage**: Monitor total memory usage across all factory instances

**Optimization Strategies**:
- **Instance Reuse**: Reuse factory instances within a single operation when appropriate
- **Object Pooling**: Implement pooling for expensive factory objects
- **Lazy Creation**: Only create instances when actually needed
- **Resource Cleanup**: Ensure proper cleanup of factory instances

**Monitoring and Profiling**:
- Use memory profilers to monitor factory instance creation
- Track allocation patterns in production environments
- Set up alerts for excessive memory usage
- Regularly review factory usage patterns
```swift
class MemoryAwareService {
    @Factory var heavyObject: HeavyObject?

    func processItems(_ items: [String]) {
        // ❌ Bad - creates many instances
        items.forEach { item in
            heavyObject?.process(item)
        }

        // ✅ Better - reuse when possible
        guard let processor = heavyObject else { return }
        items.forEach { item in
            processor.process(item)
        }
    }
}
```

### 3. Document Factory Usage

**Documentation Strategy**: Clearly document why factory injection is used and what behavior it provides to help maintainers understand the design decisions.

**Documentation Elements**:
- **Purpose**: Explain why factory injection is necessary
- **State Management**: Describe the state isolation benefits
- **Lifecycle**: Document the expected instance lifecycle
- **Performance**: Note any performance implications

**Documentation Best Practices**:
- Use clear, descriptive comments
- Explain the trade-offs between factory and singleton injection
- Document any special lifecycle requirements
- Provide examples of proper usage patterns
```swift
class DocumentService {
    /// Creates a new PDF generator for each document to ensure clean state
    @Factory var pdfGenerator: PDFGenerator?

    /// Shared repository for all document operations
    @Injected var documentRepository: DocumentRepository?
}
```

### 4. Test Factory Behavior

**Testing Strategy**: Verify that factory injection creates new instances as expected and that state isolation works correctly.

**Testing Requirements**:
- **Instance Uniqueness**: Verify that each access creates a new instance
- **State Isolation**: Confirm that instances don't share state
- **Creation Patterns**: Test that factory creation follows expected patterns
- **Resource Management**: Verify proper cleanup and resource management

**Test Categories**:
- **Behavioral Tests**: Verify factory creation behavior
- **Performance Tests**: Measure factory creation performance
- **Memory Tests**: Validate memory usage patterns
- **Concurrency Tests**: Test thread safety and concurrent access

**Testing Tools**:
- Use object identity comparison for instance uniqueness
- Implement creation counters in mock objects
- Monitor memory usage during factory tests
- Use concurrent testing frameworks for thread safety validation
```swift
func testFactoryCreatesNewInstances() {
    let service = DocumentService()

    let generator1 = service.pdfGenerator
    let generator2 = service.pdfGenerator

    // Verify different instances
    XCTAssertNotIdentical(generator1, generator2)
}
```

## Performance Considerations

### Memory Management

**Garbage Collection Benefits**:
- **Automatic Cleanup**: Factory instances are not cached, enabling automatic garbage collection
- **Memory Efficiency**: Unused instances can be immediately collected
- **No Memory Leaks**: No permanent references to factory instances
- **Predictable Memory Usage**: Memory usage patterns are more predictable

**Memory Usage Guidelines**:
- **Expensive Objects**: Be mindful of creating expensive objects frequently
- **Batch Operations**: Consider reusing instances for batch operations
- **Resource Monitoring**: Monitor memory usage patterns in production
- **Object Pooling**: Implement pooling for heavy factory objects when appropriate

**Performance Optimization Strategies**:
- **Profiling**: Regular profiling to identify performance bottlenecks
- **Lazy Loading**: Defer factory instance creation until actually needed
- **Resource Caching**: Cache expensive resources used by factory instances
- **Allocation Patterns**: Optimize allocation patterns for better garbage collection

### Optimization Tips

**Performance Optimization Guidelines**: Implement strategic optimizations to balance the benefits of factory injection with performance requirements.

**Optimization Strategies**:
- **Object Pooling**: Reuse expensive objects through pooling mechanisms
- **Lazy Evaluation**: Delay instance creation until absolutely necessary
- **Resource Sharing**: Share expensive resources across factory instances
- **Batch Processing**: Group operations to reduce instance creation overhead

**Monitoring and Metrics**:
- **Creation Rate**: Monitor factory instance creation frequency
- **Memory Usage**: Track memory consumption patterns
- **Performance Impact**: Measure the performance impact of factory injection
- **Resource Utilization**: Monitor resource utilization across factory instances
```swift
class OptimizedFactoryService {
    @Factory var expensiveProcessor: ExpensiveProcessor?
    private var processorPool: [ExpensiveProcessor] = []

    func getOptimizedProcessor() -> ExpensiveProcessor? {
        // Use pooling for expensive factory objects
        if let pooled = processorPool.popLast() {
            pooled.reset()
            return pooled
        }
        return expensiveProcessor
    }

    func returnProcessor(_ processor: ExpensiveProcessor) {
        processorPool.append(processor)
    }
}
```

## Common Pitfalls

### 1. Overusing Factory

**Problem**: Using `@Factory` for stateless services that would benefit from singleton behavior, leading to unnecessary object creation and memory overhead.

**Symptoms**:
- Creating many instances of stateless services
- Unnecessary memory allocation for simple utilities
- Performance degradation due to excessive instantiation
- Missing opportunities for resource sharing

**Solution Strategy**:
- **Evaluate State Requirements**: Carefully assess whether objects truly need independent state
- **Default to @Injected**: Use `@Injected` as the default choice unless state isolation is required
- **Performance Analysis**: Measure the performance impact of factory vs singleton injection
- **Design Review**: Review dependency injection choices during code reviews

**Decision Guidelines**:
- Has mutable state → Consider `@Factory`
- Is stateless → Use `@Injected`
- Expensive to create → Prefer `@Injected`
- Requires configuration per use → Consider `@Factory`
```swift
// ❌ Bad - using factory for stateless services
@Factory var logger: Logger? // Should be @Inject

// ✅ Good - using factory for stateful objects
@Factory var dataProcessor: DataProcessor?
```

### 2. Not Managing Factory Lifecycles

**Problem**: Creating many factory instances without proper lifecycle management, leading to memory leaks, resource exhaustion, or performance degradation.

**Symptoms**:
- Memory usage continuously growing
- Resource handles not being released
- Performance degrading over time
- Excessive garbage collection pressure

**Root Causes**:
- **Excessive Creation**: Creating new instances in tight loops
- **No Cleanup**: Not properly releasing resources held by factory instances
- **Resource Leaks**: Factory instances holding onto expensive resources
- **Poor Usage Patterns**: Using factory injection inappropriately for frequent operations

**Solution Strategies**:
- **Instance Reuse**: Reuse factory instances within operation scopes
- **Resource Management**: Implement proper resource cleanup in factory instances
- **Usage Patterns**: Review and optimize factory usage patterns
- **Monitoring**: Monitor instance creation and resource usage patterns

**Best Practices**:
- Cache factory instances within single operations
- Implement proper resource cleanup in factory instance deinitializers
- Use weak references to avoid retain cycles
- Regular profiling to identify lifecycle issues
```swift
// ❌ Bad - creating many instances without cleanup
func processLargeDataset() {
    for item in largeDataset {
        dataProcessor?.process(item) // Creates new instance each time
    }
}

// ✅ Good - reusing instance when appropriate
func processLargeDataset() {
    guard let processor = dataProcessor else { return }
    for item in largeDataset {
        processor.process(item)
    }
}
```

## See Also

- [@Injected Property Wrapper](./inject.md) - For singleton-like injection
- [@SafeInject Property Wrapper](./safeInject.md) - For guaranteed injection
- [Property Wrappers Guide](../guide/propertyWrappers.md) - Comprehensive guide to all property wrappers