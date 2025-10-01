# Complete Testing Guide with WeaveDI

Comprehensive testing documentation for WeaveDI applications, covering unit testing, integration testing, performance testing, UI testing, and continuous integration strategies.

## 🎯 What You'll Learn

- **Unit Testing**: Testing individual components with dependency injection
- **Integration Testing**: Testing component interactions and full workflows
- **Performance Testing**: Measuring DI container performance and optimization
- **UI Testing**: Testing SwiftUI views with mocked dependencies
- **Test Data Management**: Organizing and managing test data effectively
- **Continuous Integration**: Setting up automated testing pipelines

## Table of Contents

1. [Unit Testing](#unit-testing)
2. [Integration Testing](#integration-testing)
3. [Performance Testing](#performance-testing)
4. [UI Testing with Mocked Dependencies](#ui-testing-with-mocked-dependencies)
5. [Test Data Management](#test-data-management)
6. [Continuous Integration Setup](#continuous-integration-setup)

## Unit Testing

### Basic Test Setup

```swift
import XCTest
import WeaveDI
@testable import MyApp

class UserServiceTests: XCTestCase {

    override func setUp() async throws {
        // Reset container for each test
        await WeaveDI.Container.resetForTesting()

        // Register test dependencies
        await WeaveDI.Container.bootstrap { container in
            container.register(UserRepository.self) { MockUserRepository() }
            container.register(Logger.self) { MockLogger() }
            container.register(NetworkClient.self) { MockNetworkClient() }
        }
    }

    override func tearDown() async throws {
        // Clean up after each test
        await WeaveDI.Container.resetForTesting()
    }
}
```

### Testing Services with @Injected

Based on our tutorial CountApp and WeatherApp examples:

```swift
class CounterServiceTests: XCTestCase {

    func testCounterIncrement() async throws {
        // Given
        let mockRepository = MockCounterRepository()
        let mockLogger = MockLogger()

        await WeaveDI.Container.bootstrap { container in
            container.register(CounterRepository.self, instance: mockRepository)
            container.register(LoggerProtocol.self, instance: mockLogger)
        }

        let viewModel = CounterViewModel()

        // When
        await viewModel.increment()

        // Then
        XCTAssertEqual(viewModel.count, 1)
        XCTAssertEqual(mockRepository.savedCount, 1)
        XCTAssertTrue(mockLogger.loggedMessages.contains { $0.contains("카운트 증가") })
    }

    func testWeatherServiceIntegration() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        let weatherData = createMockWeatherData()
        mockHTTPClient.responses[weatherURL] = weatherData

        await WeaveDI.Container.bootstrap { container in
            container.register(HTTPClientProtocol.self, instance: mockHTTPClient)
            container.register(LoggerProtocol.self) { MockLogger() }
        }

        let weatherService = WeatherService()

        // When
        let weather = try await weatherService.fetchCurrentWeather(for: "Seoul")

        // Then
        XCTAssertEqual(weather.city, "Seoul")
        XCTAssertNotNil(weather.temperature)
    }
}
```

### Mock Objects for Tutorial Examples

```swift
// MARK: - Mock Counter Repository
class MockCounterRepository: CounterRepository {
    var savedCount: Int = 0
    var history: [CounterHistoryItem] = []
    var shouldThrowError = false

    func getCurrentCount() async -> Int {
        return savedCount
    }

    func saveCount(_ count: Int) async {
        if shouldThrowError {
            return
        }
        savedCount = count
        let historyItem = CounterHistoryItem(
            count: count,
            timestamp: Date(),
            action: count > savedCount ? .increment : .decrement
        )
        history.append(historyItem)
    }

    func getCountHistory() async -> [CounterHistoryItem] {
        return history
    }

    func resetCount() async {
        savedCount = 0
        let resetItem = CounterHistoryItem(
            count: 0,
            timestamp: Date(),
            action: .reset
        )
        history.append(resetItem)
    }
}

// MARK: - Mock Weather Service
class MockWeatherService: WeatherServiceProtocol {
    var shouldThrowError = false
    var mockWeather: Weather?

    func fetchCurrentWeather(for city: String) async throws -> Weather {
        if shouldThrowError {
            throw WeatherError.networkError
        }

        return mockWeather ?? Weather(
            temperature: 20.0,
            humidity: 50,
            description: "Sunny",
            iconName: "sun",
            city: city,
            timestamp: Date()
        )
    }

    func fetchForecast(for city: String) async throws -> [WeatherForecast] {
        if shouldThrowError {
            throw WeatherError.networkError
        }

        return (0..<5).map { index in
            WeatherForecast(
                date: Date().addingTimeInterval(TimeInterval(index * 86400)),
                maxTemperature: 25.0,
                minTemperature: 15.0,
                description: "Partly Cloudy",
                iconName: "cloud.sun"
            )
        }
    }
}

// MARK: - Mock Logger
class MockLogger: LoggerProtocol {
    var loggedMessages: [String] = []

    func info(_ message: String) {
        loggedMessages.append("INFO: \(message)")
    }

    func error(_ message: String) {
        loggedMessages.append("ERROR: \(message)")
    }

    func debug(_ message: String) {
        loggedMessages.append("DEBUG: \(message)")
    }
}
```

## Integration Testing

### Testing Component Integration

Integration tests verify that multiple components work together correctly:

```swift
class WeatherAppIntegrationTests: XCTestCase {

    func testFullWeatherWorkflow() async throws {
        // Setup real-like dependencies with mock network
        let mockNetworkClient = MockNetworkClient()
        let weatherJSONData = createWeatherJSONData()
        mockNetworkClient.responses[URL(string: "https://api.openweathermap.org/data/2.5/weather?q=London&appid=test&units=metric")!] = weatherJSONData

        await WeaveDI.Container.bootstrap { container in
            // Mock network but real other services
            container.register(HTTPClientProtocol.self, instance: mockNetworkClient)
            container.register(CacheServiceProtocol.self) { UserDefaultsCacheService() }
            container.register(LoggerProtocol.self) { ConsoleLogger() }

            // Real weather service that integrates all dependencies
            container.register(WeatherServiceProtocol.self) { WeatherService() }
        }

        // Test the full integration
        let weatherService = WeaveDI.Container.shared.resolve(WeatherServiceProtocol.self)!
        let cacheService = WeaveDI.Container.shared.resolve(CacheServiceProtocol.self)!

        // Fetch weather
        let weather = try await weatherService.fetchCurrentWeather(for: "London")

        // Verify weather data
        XCTAssertEqual(weather.city, "London")
        XCTAssertEqual(weather.temperature, 18.5)

        // Verify caching integration
        let cachedWeather: Weather? = try await cacheService.retrieve(forKey: "current_weather_London")
        XCTAssertNotNil(cachedWeather)
        XCTAssertEqual(cachedWeather?.city, "London")
    }

    func testCounterAppFullIntegration() async throws {
        // Test the complete CountApp workflow
        await WeaveDI.Container.bootstrap { container in
            container.register(LoggerProtocol.self) { MockLogger() }
            container.register(CounterRepository.self) { UserDefaultsCounterRepository() }
        }

        // Test repository integration
        let repository = WeaveDI.Container.shared.resolve(CounterRepository.self)!

        // Initial state
        await repository.resetCount()
        XCTAssertEqual(await repository.getCurrentCount(), 0)

        // Increment operations
        await repository.saveCount(1)
        await repository.saveCount(2)
        await repository.saveCount(3)

        // Verify current count
        XCTAssertEqual(await repository.getCurrentCount(), 3)

        // Verify history
        let history = await repository.getCountHistory()
        XCTAssertEqual(history.count, 4) // reset + 3 increments

        // Test ViewModel integration
        let viewModel = CounterViewModel()
        await viewModel.loadInitialData()

        XCTAssertEqual(viewModel.count, 3)
        XCTAssertEqual(viewModel.history.count, 4)
    }
}
```

### Database Integration Testing

```swift
class DatabaseIntegrationTests: XCTestCase {
    var testDatabase: TestCoreDataStack!

    override func setUp() async throws {
        // Setup in-memory test database
        testDatabase = try await TestCoreDataStack.create()

        await WeaveDI.Container.bootstrap { container in
            container.register(DatabaseProtocol.self, instance: testDatabase)
            container.register(UserRepository.self) { CoreDataUserRepository() }
            container.register(LoggerProtocol.self) { MockLogger() }
        }
    }

    override func tearDown() async throws {
        try await testDatabase.cleanup()
    }

    func testUserPersistence() async throws {
        let repository = WeaveDI.Container.shared.resolve(UserRepository.self)!

        let user = User(name: "Test User", email: "test@example.com")
        try await repository.save(user)

        let retrievedUser = try await repository.findById(user.id)
        XCTAssertEqual(retrievedUser?.name, "Test User")
        XCTAssertEqual(retrievedUser?.email, "test@example.com")
    }
}
```

## Performance Testing

### DI Container Performance Testing

```swift
class DependencyPerformanceTests: XCTestCase {

    func testResolutionPerformance() async throws {
        // Setup complex dependency graph
        await WeaveDI.Container.bootstrap { container in
            // Register many dependencies
            for i in 0..<1000 {
                container.register(TestService.self, name: "service_\(i)") {
                    TestServiceImpl(id: i)
                }
            }

            // Register services with dependencies
            container.register(ComplexService.self) {
                let dependencies = (0..<10).compactMap { index in
                    container.resolve(TestService.self, name: "service_\(index)")
                }
                return ComplexServiceImpl(dependencies: dependencies)
            }
        }

        // Measure resolution performance
        measure {
            for _ in 0..<1000 {
                let service = WeaveDI.Container.shared.resolve(ComplexService.self)
                XCTAssertNotNil(service)
            }
        }
    }

    func testContainerBootstrapPerformance() async throws {
        measure {
            Task {
                await WeaveDI.Container.bootstrap { container in
                    // Register 1000 services to test bootstrap performance
                    for i in 0..<1000 {
                        container.register(TestService.self, name: "service_\(i)") {
                            TestServiceImpl(id: i)
                        }
                    }
                }
            }
        }
    }

    func testMemoryUsageUnderLoad() async throws {
        let initialMemory = getCurrentMemoryUsage()

        // Create many dependencies
        await WeaveDI.Container.bootstrap { container in
            for i in 0..<5000 {
                container.register(MemoryTestService.self, name: "service_\(i)") {
                    MemoryTestServiceImpl(data: Array(repeating: i, count: 100))
                }
            }
        }

        // Resolve all dependencies
        var resolvedServices: [MemoryTestService] = []
        for i in 0..<5000 {
            if let service = WeaveDI.Container.shared.resolve(MemoryTestService.self, name: "service_\(i)") {
                resolvedServices.append(service)
            }
        }

        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory

        // Verify memory usage is reasonable
        XCTAssertLessThan(memoryIncrease, 50_000_000) // 50MB limit
        XCTAssertEqual(resolvedServices.count, 5000)
    }

    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}
```

### Concurrent Performance Testing

```swift
class ConcurrentPerformanceTests: XCTestCase {

    func testConcurrentResolution() async throws {
        await WeaveDI.Container.bootstrap { container in
            container.register(ThreadSafeService.self) { ThreadSafeServiceImpl() }
            container.register(CounterRepository.self) { UserDefaultsCounterRepository() }
        }

        // Test concurrent access from multiple tasks
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    let service = WeaveDI.Container.shared.resolve(ThreadSafeService.self)
                    let repository = WeaveDI.Container.shared.resolve(CounterRepository.self)
                    return service != nil && repository != nil
                }
            }

            var successCount = 0
            for await success in group {
                if success { successCount += 1 }
            }

            XCTAssertEqual(successCount, 100)
        }
    }

    func testCounterConcurrentOperations() async throws {
        await WeaveDI.Container.bootstrap { container in
            container.register(CounterRepository.self) { UserDefaultsCounterRepository() }
            container.register(LoggerProtocol.self) { MockLogger() }
        }

        let repository = WeaveDI.Container.shared.resolve(CounterRepository.self)!
        await repository.resetCount()

        // Perform concurrent increments
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    await repository.saveCount(i + 1)
                }
            }
        }

        // The final count should be one of the saved values
        let finalCount = await repository.getCurrentCount()
        XCTAssertGreaterThan(finalCount, 0)
        XCTAssertLessThanOrEqual(finalCount, 50)
    }
}
```

## UI Testing with Mocked Dependencies

### SwiftUI View Testing

```swift
import SwiftUI
import ViewInspector

class SwiftUIViewTests: XCTestCase {

    func testCounterView() async throws {
        // Setup test dependencies
        let mockRepository = MockCounterRepository()
        mockRepository.savedCount = 5
        let mockLogger = MockLogger()

        await WeaveDI.Container.bootstrap { container in
            container.register(CounterRepository.self, instance: mockRepository)
            container.register(LoggerProtocol.self, instance: mockLogger)
        }

        // Create and test view
        let counterView = AdvancedCounterView()

        // Test initial state (Note: ViewInspector testing would require the actual implementation)
        // This is a conceptual example of how you would test SwiftUI views

        let viewModel = CounterViewModel()
        await viewModel.loadInitialData()

        XCTAssertEqual(viewModel.count, 5)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testWeatherViewWithMockData() async throws {
        // Setup mock weather service
        let mockWeatherService = MockWeatherService()
        mockWeatherService.mockWeather = Weather(
            temperature: 25.0,
            humidity: 60,
            description: "Sunny",
            iconName: "sun",
            city: "Test City",
            timestamp: Date()
        )

        await WeaveDI.Container.bootstrap { container in
            container.register(WeatherServiceProtocol.self, instance: mockWeatherService)
            container.register(LoggerProtocol.self) { MockLogger() }
        }

        let weatherViewModel = WeatherViewModel()
        await weatherViewModel.loadWeatherData()

        XCTAssertEqual(weatherViewModel.currentWeather?.city, "Test City")
        XCTAssertEqual(weatherViewModel.currentWeather?.temperature, 25.0)
        XCTAssertFalse(weatherViewModel.isLoading)
    }
}
```

### UI Integration Testing

```swift
class UIIntegrationTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        app = XCUIApplication()
        app.launchEnvironment["TESTING_MODE"] = "true"
        app.launchEnvironment["USE_MOCK_SERVICES"] = "true"
        app.launch()
    }

    func testWeatherAppFullFlow() {
        // Test main weather screen
        let weatherLabel = app.staticTexts["current-weather-label"]
        XCTAssertTrue(weatherLabel.waitForExistence(timeout: 5))

        // Test city selection
        let cityButton = app.buttons["select-city-button"]
        cityButton.tap()

        let londonOption = app.buttons["London"]
        londonOption.tap()

        // Verify weather updates
        let loadingIndicator = app.activityIndicators["weather-loading"]
        XCTAssertTrue(loadingIndicator.waitForExistence(timeout: 2))
        XCTAssertTrue(loadingIndicator.waitForNonExistence(timeout: 5))

        // Verify London weather is displayed
        XCTAssertTrue(app.staticTexts["London"].exists)
    }

    func testCounterAppFullFlow() {
        // Navigate to counter tab
        let counterTab = app.tabBars.buttons["카운터"]
        counterTab.tap()

        // Test initial state
        let countLabel = app.staticTexts.matching(identifier: "count-display").firstMatch
        XCTAssertTrue(countLabel.exists)

        // Test increment
        let incrementButton = app.buttons["+"]
        incrementButton.tap()

        // Verify count updated
        XCTAssertTrue(countLabel.waitForExistence(timeout: 2))

        // Test decrement
        let decrementButton = app.buttons["-"]
        decrementButton.tap()

        // Test reset
        let resetButton = app.buttons["초기화"]
        resetButton.tap()

        // Test history view
        let historyButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '히스토리'")).firstMatch
        historyButton.tap()

        let historyView = app.scrollViews["history-scroll-view"]
        XCTAssertTrue(historyView.waitForExistence(timeout: 2))
    }
}
```

## Test Data Management

### Test Data Factory

```swift
struct TestDataFactory {
    // Counter App Test Data
    static func createCounterHistoryItems(count: Int = 5) -> [CounterHistoryItem] {
        return (0..<count).map { index in
            CounterHistoryItem(
                count: index,
                timestamp: Date().addingTimeInterval(TimeInterval(-index * 60)),
                action: index % 3 == 0 ? .reset : (index % 2 == 0 ? .increment : .decrement)
            )
        }
    }

    // Weather App Test Data
    static func createWeatherData(
        city: String = "Test City",
        temperature: Double = 20.0,
        humidity: Int = 50
    ) -> Weather {
        Weather(
            temperature: temperature,
            humidity: humidity,
            description: "Test Weather",
            iconName: "sun",
            city: city,
            timestamp: Date()
        )
    }

    static func createWeatherForecast(days: Int = 5, city: String = "Test City") -> [WeatherForecast] {
        return (0..<days).map { index in
            WeatherForecast(
                date: Date().addingTimeInterval(TimeInterval(index * 86400)),
                maxTemperature: 25.0 + Double(index),
                minTemperature: 15.0 + Double(index),
                description: "Day \(index + 1) Weather",
                iconName: index % 2 == 0 ? "sun" : "cloud"
            )
        }
    }

    // Network Response Test Data
    static func createWeatherJSONData(city: String = "London", temperature: Double = 18.5) -> Data {
        let json = """
        {
            "name": "\(city)",
            "main": {
                "temp": \(temperature),
                "humidity": 65
            },
            "weather": [
                {
                    "description": "clear sky",
                    "icon": "01d"
                }
            ]
        }
        """
        return json.data(using: .utf8)!
    }
}
```

### Test Database Management

```swift
class TestCoreDataStack {
    private let container: NSPersistentContainer

    static func create() async throws -> TestCoreDataStack {
        let container = NSPersistentContainer(name: "TestDataModel")

        // Use in-memory store for testing
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        return try await withCheckedThrowingContinuation { continuation in
            container.loadPersistentStores { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: TestCoreDataStack(container: container))
                }
            }
        }
    }

    private init(container: NSPersistentContainer) {
        self.container = container
    }

    func cleanup() async throws {
        let context = container.viewContext

        // Delete all test entities
        let entityNames = ["User", "WeatherData", "CounterHistory"]

        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try context.execute(deleteRequest)
            } catch {
                // Entity might not exist, continue
            }
        }

        try context.save()
    }
}
```

## Continuous Integration Setup

### GitHub Actions Configuration

```yaml
# .github/workflows/tests.yml
name: Comprehensive Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  unit-tests:
    runs-on: macos-13
    steps:
    - uses: actions/checkout@v4

    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: latest-stable

    - name: Cache SPM dependencies
      uses: actions/cache@v3
      with:
        path: .build
        key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}

    - name: Run Unit Tests
      run: |
        swift test --enable-code-coverage --filter UnitTests

    - name: Generate Coverage Report
      run: |
        xcrun llvm-cov export -format="lcov" \
          .build/debug/MyAppPackageTests.xctest/Contents/MacOS/MyAppPackageTests \
          -instr-profile .build/debug/codecov/default.profdata > coverage.lcov

    - name: Upload Coverage
      uses: codecov/codecov-action@v3
      with:
        file: coverage.lcov

  integration-tests:
    runs-on: macos-13
    steps:
    - uses: actions/checkout@v4

    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: latest-stable

    - name: Run Integration Tests
      run: |
        swift test --filter IntegrationTests

  performance-tests:
    runs-on: macos-13
    steps:
    - uses: actions/checkout@v4

    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: latest-stable

    - name: Run Performance Tests
      run: |
        swift test --filter PerformanceTests

  ui-tests:
    runs-on: macos-13
    steps:
    - uses: actions/checkout@v4

    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: latest-stable

    - name: Setup iOS Simulator
      run: |
        xcrun simctl create test-device com.apple.CoreSimulator.SimDeviceType.iPhone-14 com.apple.CoreSimulator.SimRuntime.iOS-16-0

    - name: Run UI Tests
      run: |
        xcodebuild test \
          -scheme MyApp \
          -destination 'platform=iOS Simulator,name=test-device' \
          -testPlan UITests
```

### Test Configuration Management

```swift
// Tests/TestConfiguration.swift
enum TestConfiguration {
    static let isRunningTests: Bool = {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }()

    static let isUITesting: Bool = {
        ProcessInfo.processInfo.environment["TESTING_MODE"] == "true"
    }()

    static let useMockServices: Bool = {
        ProcessInfo.processInfo.environment["USE_MOCK_SERVICES"] == "true"
    }()

    static func setupTestEnvironment() async {
        guard isRunningTests else { return }

        await WeaveDI.Container.resetForTesting()

        if useMockServices {
            await setupMockDependencies()
        } else {
            await setupTestDependencies()
        }
    }

    private static func setupMockDependencies() async {
        await WeaveDI.Container.bootstrap { container in
            // Register all mock services for UI testing
            container.register(WeatherServiceProtocol.self) { MockWeatherService() }
            container.register(CounterRepository.self) { MockCounterRepository() }
            container.register(LoggerProtocol.self) { MockLogger() }
            container.register(NetworkClient.self) { MockNetworkClient() }
        }
    }

    private static func setupTestDependencies() async {
        await WeaveDI.Container.bootstrap { container in
            // Register test implementations for unit/integration tests
            container.register(LoggerProtocol.self) { TestLogger() }
            container.register(DatabaseProtocol.self) { InMemoryDatabase() }
        }
    }
}

// App delegate integration
@main
struct MyApp: App {
    init() {
        Task {
            await TestConfiguration.setupTestEnvironment()
            if !TestConfiguration.isRunningTests {
                await ProductionDependencies.setup()
            }
        }
    }
}
```

## Best Practices

### 1. Test Isolation
Ensure each test is independent:

```swift
override func setUp() async throws {
    await WeaveDI.Container.resetForTesting()
    await setupTestDependencies()
}
```

### 2. Descriptive Test Names
Use clear, descriptive test names:

```swift
func testCounterViewModel_WhenIncrementingFromZero_ShouldUpdateCountToOne() async throws { }
func testWeatherService_WhenNetworkFails_ShouldUseCachedData() async throws { }
```

### 3. Test Edge Cases
Always test boundary conditions:

```swift
func testCounterRepository_WhenCountReachesMaxValue_ShouldHandleOverflow() async throws { }
func testWeatherService_WhenInvalidCityName_ShouldThrowValidationError() async throws { }
```

### 4. Mock External Dependencies
Never test against real external services:

```swift
// ✅ Good - isolated testing
container.register(APIClient.self) { MockAPIClient() }

// ❌ Bad - external dependency
container.register(APIClient.self) { RealAPIClient(baseURL: "https://api.example.com") }
```

### 5. Verify Interactions
Test that dependencies are used correctly:

```swift
func testUserService_WhenCreatingUser_ShouldLogUserCreation() async throws {
    let mockLogger = MockLogger()
    // ... setup and test
    XCTAssertTrue(mockLogger.loggedMessages.contains { $0.contains("User created") })
}
```

## Conclusion

This comprehensive testing guide provides patterns for testing WeaveDI applications at all levels. From unit tests with mocked dependencies to full integration tests and performance benchmarks, these patterns ensure your DI-powered applications are robust, maintainable, and performant.

## See Also

- [Property Wrappers Guide](../guide/propertyWrappers.md) - Dependency injection patterns
- [Bootstrap API](../api/bootstrap.md) - Container initialization
- [Performance Optimization](./performanceOptimization.md) - Optimizing DI performance