# @Factory Property Wrapper

The `@Factory` property wrapper provides factory-based dependency injection, creating new instances each time the property is accessed. This is ideal for stateful objects or when you need fresh instances.

## Overview

Unlike `@Inject` which caches resolved dependencies, `@Factory` creates a new instance every time you access the property. This ensures you always get a fresh object, which is crucial for stateful services or temporary objects.

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

    @Inject var repository: CounterRepository?
    @Inject var logger: LoggerProtocol?

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
    @Inject var weatherService: WeatherServiceProtocol?

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

    @Inject var logger: LoggerProtocol?

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

```swift
class DocumentProcessor {
    // ✅ Use @Factory for stateful, short-lived objects
    @Factory var documentBuilder: DocumentBuilder?
    @Factory var validator: DocumentValidator?

    // ✅ Use @Inject for long-lived, stateless services
    @Inject var documentRepository: DocumentRepository?
    @Inject var logger: LoggerProtocol?

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

```swift
class PerformanceTestService {
    @Factory var heavyProcessor: HeavyProcessor? // New instance each time
    @Inject var cacheService: CacheService?      // Shared instance

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

Factory dependencies are registered the same way as regular dependencies:

```swift
// DependencyBootstrap.swift
await DIContainer.bootstrap { container in
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

For more complex factory patterns, you can use closure-based factories:

```swift
class ServiceFactory {
    @Inject var container: DIContainer?

    func createTaskManager(for taskType: TaskType) -> TaskManager? {
        // Create configured instances based on parameters
        let manager = container?.resolve(TaskManager.self)
        manager?.configure(for: taskType)
        return manager
    }
}
```

## Thread Safety

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

```swift
class FactoryServiceTests: XCTestCase {

    func testDocumentProcessing() async throws {
        // Register factory mocks
        await DIContainer.bootstrap { container in
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
```swift
// ✅ Good - stateful objects that need fresh instances
@Factory var userSession: UserSession?
@Factory var shoppingCart: ShoppingCart?
@Factory var gameState: GameState?

// ❌ Avoid - stateless services (use @Inject instead)
@Factory var mathUtils: MathUtils? // Should be @Inject
```

### 2. Consider Memory Impact
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
```swift
class DocumentService {
    /// Creates a new PDF generator for each document to ensure clean state
    @Factory var pdfGenerator: PDFGenerator?

    /// Shared repository for all document operations
    @Inject var documentRepository: DocumentRepository?
}
```

### 4. Test Factory Behavior
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
- Factory instances are not cached, so they can be garbage collected after use
- Be mindful of creating expensive objects frequently
- Consider object pooling for heavy factory objects

### Optimization Tips
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
```swift
// ❌ Bad - using factory for stateless services
@Factory var logger: Logger? // Should be @Inject

// ✅ Good - using factory for stateful objects
@Factory var dataProcessor: DataProcessor?
```

### 2. Not Managing Factory Lifecycles
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

- [@Inject Property Wrapper](./inject.md) - For singleton-like injection
- [@SafeInject Property Wrapper](./safeInject.md) - For guaranteed injection
- [Property Wrappers Guide](../guide/propertyWrappers.md) - Comprehensive guide to all property wrappers