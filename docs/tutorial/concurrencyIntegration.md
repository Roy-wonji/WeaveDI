# WeaveDI Swift Concurrency Integration

Master WeaveDI's Swift concurrency features including @DIActor, async/await patterns, and actor-safe dependency injection.

## 🎯 Learning Objectives

- **@DIActor**: Thread-safe dependency management
- **Async Registration**: Background dependency setup
- **Actor Isolation**: Safe concurrent access
- **Performance Optimization**: Hot path caching
- **Real-world Patterns**: Practical async/await usage

## 🧵 Thread-Safe Dependency Injection

### Using @DIActor for Safe Operations

```swift
import WeaveDI

// Register dependencies safely using @DIActor
@DIActor
func setupAppDependencies() async {
    print("🚀 Setting up dependencies on background thread...")

    // Thread-safe registration using actual WeaveDI @DIActor
    let networkService = await DIActor.shared.register(NetworkService.self) {
        URLSessionNetworkService()
    }

    let cacheService = await DIActor.shared.register(CacheService.self) {
        CoreDataCacheService()
    }

    print("✅ Dependencies registered safely")
}

// Resolve dependencies safely
@DIActor
func getDependencies() async {
    let networkService = await DIActor.shared.resolve(NetworkService.self)
    let cacheService = await DIActor.shared.resolve(CacheService.self)

    print("📦 Dependencies resolved: \(networkService != nil)")
}
```

**🔍 Code Explanation:**

1. **@DIActor Functions**: Using the `@DIActor` attribute ensures functions execute in DIActor context
2. **Thread-safe Registration**: `DIActor.shared.register` safely handles concurrent registrations
3. **Async Resolution**: Use `await` to resolve dependencies asynchronously
4. **Background Execution**: Dependencies are set up without blocking the main thread

### Actor-Safe Property Injection

```swift
@MainActor
class WeatherViewModel: ObservableObject {
    // UI updates on main actor
    @Published var weather: Weather?
    @Published var isLoading = false
    @Published var error: String?

    // Services can be injected safely
    @Inject var weatherService: WeatherService?

    func loadWeather(for city: String) async {
        isLoading = true
        error = nil

        do {
            // Background work with injected service
            guard let service = weatherService else {
                throw WeatherError.serviceUnavailable
            }

            // Execute on background thread
            let weatherData = try await service.fetchWeather(for: city)

            // UI updates automatically on main actor
            self.weather = weatherData
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
```

**🔍 Code Explanation:**

1. **@MainActor Class**: All methods and properties execute on the main thread
2. **@Published Properties**: SwiftUI-compatible state for UI binding
3. **@Inject Properties**: Safe dependency injection through WeaveDI
4. **Background Work**: Network calls performed in the background
5. **Automatic UI Updates**: State changes automatically handled on main thread

## 🏭 Advanced Concurrency Patterns

### Parallel Dependency Initialization

```swift
/// Advanced bootstrap with parallel service initialization (based on actual tutorial code)
class ConcurrentBootstrap {

    @DIActor
    static func setupServicesInParallel() async {
        print("⚡ Starting parallel service initialization")

        // Use TaskGroup to initialize multiple services concurrently
        await withTaskGroup(of: Void.self) { group in

            // Initialize network service (time-consuming)
            group.addTask {
                let service = await initializeNetworkService()
                await DIActor.shared.register(NetworkService.self) {
                    service
                }
                print("🌐 NetworkService initialization complete")
            }

            // Initialize database service (time-consuming)
            group.addTask {
                let service = await initializeDatabaseService()
                await DIActor.shared.register(DatabaseService.self) {
                    service
                }
                print("🗄️ DatabaseService initialization complete")
            }

            // Initialize cache service (fast)
            group.addTask {
                let service = await initializeCacheService()
                await DIActor.shared.register(CacheService.self) {
                    service
                }
                print("💾 CacheService initialization complete")
            }

            // Initialize auth service (has dependencies)
            group.addTask {
                // Wait for network service to be ready
                let networkService = await DIActor.shared.resolve(NetworkService.self)
                let authService = await initializeAuthService(networkService: networkService)

                await DIActor.shared.register(AuthService.self) {
                    authService
                }
                print("🔐 AuthService initialization complete")
            }
        }

        print("✅ All services parallel initialization complete")
    }

    /// Initialize network service asynchronously
    private static func initializeNetworkService() async -> NetworkService {
        // Simulation: network setup takes time
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        return URLSessionNetworkService()
    }

    /// Initialize database service asynchronously
    private static func initializeDatabaseService() async -> DatabaseService {
        // Simulation: database connection takes time
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        return CoreDataService()
    }

    /// Initialize cache service asynchronously (fast)
    private static func initializeCacheService() async -> CacheService {
        return InMemoryCacheService()
    }

    /// Initialize auth service asynchronously (has dependencies)
    private static func initializeAuthService(networkService: NetworkService?) async -> AuthService {
        guard let network = networkService else {
            fatalError("AuthService requires NetworkService")
        }
        return OAuth2AuthService(networkService: network)
    }
}
```

**🔍 Code Explanation:**

1. **TaskGroup**: Swift concurrency API for running multiple tasks in parallel
2. **Async Initialization**: Each service initializes independently
3. **Dependency Resolution**: Services like AuthService ensure order when they depend on others
4. **Performance Improvement**: Parallel initialization instead of sequential reduces time

### Actor Hop Patterns

**Actor hopping** is a crucial concept in Swift concurrency that occurs when execution moves between different actors. Understanding and optimizing actor hops is essential for performance.

```swift
/// Advanced actor hop optimization patterns
actor DataProcessor {
    private var cache: [String: ProcessedData] = [:]

    @Inject var networkService: NetworkService?
    @Inject var logger: LoggerProtocol?

    /// Example of controlled actor hopping
    func processDataWithOptimizedHops(input: String) async -> ProcessedData? {
        // ✅ We're on DataProcessor actor
        logger?.info("🔄 Starting data processing on DataProcessor actor")

        // Check cache first (no actor hop needed)
        if let cached = cache[input] {
            logger?.info("📋 Cache hit, no processing needed")
            return cached
        }

        // ❌ AVOID: Multiple unnecessary actor hops
        // Bad pattern that causes multiple hops:
        /*
        await MainActor.run {
            // Hop to MainActor
            updateUI()
        }
        let networkData = await networkService?.fetchData(input) // Hop to network actor
        await MainActor.run {
            // Another hop to MainActor
            updateProgress()
        }
        */

        // ✅ OPTIMAL: Batch operations to minimize hops

        // Batch all network operations together
        guard let networkService = networkService else { return nil }
        let networkData = await networkService.fetchData(input)

        // Process on current actor (no hop)
        let processed = await processInternalData(networkData)

        // Cache result (no hop needed, we're still on DataProcessor actor)
        cache[input] = processed

        // Single hop to MainActor for UI updates at the end
        await MainActor.run {
            NotificationCenter.default.post(
                name: .dataProcessingComplete,
                object: processed
            )
        }

        return processed
    }

    /// Internal processing that stays on the same actor
    private func processInternalData(_ data: Data?) async -> ProcessedData {
        // This method runs on DataProcessor actor - no hop
        guard let data = data else {
            return ProcessedData.empty
        }

        // Simulate processing work
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        return ProcessedData(
            id: UUID().uuidString,
            content: String(data: data, encoding: .utf8) ?? "",
            timestamp: Date(),
            processingDuration: 0.1
        )
    }

    /// Efficient batch processing that minimizes actor hops
    func processBatchWithMinimalHops(_ inputs: [String]) async -> [ProcessedData] {
        var results: [ProcessedData] = []

        // Process all inputs on current actor
        for input in inputs {
            if let result = await processDataWithOptimizedHops(input: input) {
                results.append(result)
            }
        }

        // Single hop to MainActor for final notification
        await MainActor.run {
            NotificationCenter.default.post(
                name: .batchProcessingComplete,
                object: results.count
            )
        }

        return results
    }
}

/// Main actor coordinator that demonstrates proper actor hop management
@MainActor
class ActorHopCoordinator: ObservableObject {
    @Published var processingStatus: String = "Ready"
    @Published var results: [ProcessedData] = []

    @Inject var dataProcessor: DataProcessor?
    @Inject var logger: LoggerProtocol?

    /// Demonstrates optimal actor hop patterns
    func performOptimizedProcessing(inputs: [String]) async {
        // ✅ Start on MainActor (UI updates)
        processingStatus = "Starting processing..."
        logger?.info("🚀 Starting optimized processing")

        // ✅ Single hop to DataProcessor actor for all work
        guard let processor = dataProcessor else {
            processingStatus = "Error: No processor available"
            return
        }

        // All processing happens on DataProcessor actor
        let processedResults = await processor.processBatchWithMinimalHops(inputs)

        // ✅ Return to MainActor for UI updates (automatic hop)
        self.results = processedResults
        self.processingStatus = "Completed: \(processedResults.count) items"

        logger?.info("✅ Processing completed with minimal actor hops")
    }

    /// Example of what NOT to do - excessive actor hopping
    func performPoorlyOptimizedProcessing(inputs: [String]) async {
        // ❌ This is a bad example - too many actor hops

        for input in inputs {
            // Hop 1: Update UI for each item
            processingStatus = "Processing \(input)..."

            // Hop 2: Go to processor
            let result = await dataProcessor?.processDataWithOptimizedHops(input: input)

            // Hop 3: Back to MainActor
            if let result = result {
                results.append(result)
            }

            // This creates 3 * inputs.count actor hops!
        }
    }
}

struct ProcessedData {
    let id: String
    let content: String
    let timestamp: Date
    let processingDuration: TimeInterval

    static let empty = ProcessedData(
        id: "",
        content: "",
        timestamp: Date(),
        processingDuration: 0
    )
}

extension Notification.Name {
    static let dataProcessingComplete = Notification.Name("dataProcessingComplete")
    static let batchProcessingComplete = Notification.Name("batchProcessingComplete")
}
```

**🔍 Actor Hop Optimization Principles:**

1. **Minimize Hops**: Group operations that need to happen on the same actor
2. **Batch UI Updates**: Update UI once at the end rather than continuously
3. **Stay on Actor**: Prefer private methods that stay on the current actor
4. **Measure Performance**: Use Instruments to identify hop bottlenecks
5. **Strategic Hopping**: Plan when and where actor switches are necessary

### Actor-Based Service Design

```swift
/// Thread-safe service implementation using actor (actual tutorial pattern)
actor ThreadSafeDataService {
    private var cache: [String: Data] = [:]
    private var isInitialized = false

    /// Dependency injection through WeaveDI (safe within actor)
    @Inject var networkService: NetworkService?
    @Inject var logger: LoggerProtocol?

    /// Safely initialize actor internal state
    func initialize() async {
        guard !isInitialized else { return }

        logger?.info("🔄 ThreadSafeDataService initialization started")

        // Verify network service
        guard let network = networkService else {
            logger?.error("❌ NetworkService unavailable")
            return
        }

        // Load initial data
        do {
            let initialData = try await network.fetchInitialData()
            cache["initial"] = initialData
            isInitialized = true
            logger?.info("✅ ThreadSafeDataService initialization complete")
        } catch {
            logger?.error("❌ Initialization failed: \(error)")
        }
    }

    /// Safely store data (executes in actor context)
    func storeData(_ data: Data, forKey key: String) {
        cache[key] = data
        logger?.info("💾 Data stored: \(key)")
    }

    /// Safely retrieve data (executes in actor context)
    func retrieveData(forKey key: String) -> Data? {
        let data = cache[key]
        logger?.info("📖 Data retrieved: \(key) -> \(data != nil ? "success" : "failure")")
        return data
    }

    /// Check cache status (safely callable from outside)
    var cacheSize: Int {
        cache.count
    }
}
```

**🔍 Code Explanation:**

1. **Actor Keyword**: Using actor instead of class for automatic synchronization
2. **Internal State Protection**: cache and isInitialized are protected from concurrent access
3. **@Inject Safety**: WeaveDI injection works safely within actors
4. **Async Methods**: Actor methods are called with await from outside

### Concurrency Optimization Patterns

```swift
/// Performance-optimized concurrency service manager (tutorial-based advanced pattern)
@MainActor
class ConcurrencyOptimizedServiceManager {

    // MARK: - Dependencies (injected through WeaveDI)
    @Inject var dataService: ThreadSafeDataService?
    @Inject var networkService: NetworkService?
    @Inject var logger: LoggerProtocol?

    // MARK: - Internal State
    private var operationQueue: [UUID: Task<Void, Never>] = [:]
    private var resultCache: [String: Any] = [:]

    /// Efficiently handle multiple operations in parallel
    func performBatchOperations<T: Sendable>(
        _ operations: [(id: String, operation: () async throws -> T)]
    ) async -> [String: Result<T, Error>] {

        logger?.info("🚀 Batch operations started: \(operations.count) operations")

        var results: [String: Result<T, Error>] = [:]

        // Parallel processing using TaskGroup
        await withTaskGroup(of: (String, Result<T, Error>).self) { group in

            for (id, operation) in operations {
                group.addTask { [weak self] in
                    // Check cache (safe on main actor)
                    if let cached = await self?.getCachedResult(id: id) as? T {
                        self?.logger?.info("📋 Using cached result: \(id)")
                        return (id, .success(cached))
                    }

                    // Perform actual operation
                    do {
                        let result = try await operation()
                        await self?.cacheResult(id: id, result: result)
                        return (id, .success(result))
                    } catch {
                        self?.logger?.error("❌ Operation failed [\(id)]: \(error)")
                        return (id, .failure(error))
                    }
                }
            }

            // Collect all results
            for await (id, result) in group {
                results[id] = result
            }
        }

        logger?.info("✅ Batch operations complete: \(results.count) results")
        return results
    }

    /// Cancellable long-running task
    func startLongRunningTask(id: String) -> UUID {
        let taskId = UUID()

        let task = Task { [weak self] in
            guard let self = self else { return }

            await self.logger?.info("⏳ Long-running task started: \(id)")

            // Task simulation (cancellable)
            for i in 1...100 {
                // Check for cancellation
                if Task.isCancelled {
                    await self.logger?.info("🛑 Task cancelled: \(id)")
                    return
                }

                // Progress update
                if i % 10 == 0 {
                    await self.logger?.info("📊 Progress [\(id)]: \(i)%")
                }

                // Work simulation
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }

            await self.logger?.info("✅ Long-running task complete: \(id)")
            await self.removeTask(taskId: taskId)
        }

        operationQueue[taskId] = task
        return taskId
    }

    /// Cancel task
    func cancelTask(taskId: UUID) {
        operationQueue[taskId]?.cancel()
        operationQueue.removeValue(forKey: taskId)
        logger?.info("🛑 Task cancellation requested: \(taskId)")
    }

    /// Cancel all tasks
    func cancelAllTasks() {
        logger?.info("🛑 Cancelling all tasks")
        for task in operationQueue.values {
            task.cancel()
        }
        operationQueue.removeAll()
    }

    // MARK: - Private Methods

    /// Retrieve cached result (safe on main actor)
    private func getCachedResult(id: String) -> Any? {
        return resultCache[id]
    }

    /// Cache result (safe on main actor)
    private func cacheResult<T>(id: String, result: T) {
        resultCache[id] = result
        logger?.info("💾 Result cached: \(id)")
    }

    /// Remove completed task
    private func removeTask(taskId: UUID) {
        operationQueue.removeValue(forKey: taskId)
    }
}
```

**🔍 Code Explanation:**

1. **@MainActor Management**: Safely manage UI-related state on main actor
2. **TaskGroup Utilization**: Parallel processing and result collection for multiple tasks
3. **Cancellable Tasks**: Graceful cancellation handling using Task.isCancelled
4. **Result Caching**: Prevent duplicate work through result caching
5. **Task Tracking**: Track and manage running tasks

## 📋 Real-World Examples

### Integration in Real Apps

```swift
/// Example of using WeaveDI concurrency features in a real app
@main
struct ConcurrentApp: App {

    /// Async initialization on app startup
    init() {
        Task {
            await initializeApp()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Additional initialization when view appears
                    await finalizeAppSetup()
                }
        }
    }

    /// App initialization (performed in background)
    @DIActor
    private func initializeApp() async {
        print("🚀 App initialization started")

        // Parallel service initialization
        await ConcurrentBootstrap.setupServicesInParallel()

        // Additional setup
        await configureLogging()
        await setupAnalytics()

        print("✅ App initialization complete")
    }

    /// Final setup steps
    private func finalizeAppSetup() async {
        // Tasks to perform after UI is ready
        await preloadCriticalData()
        await startBackgroundTasks()
    }

    @DIActor
    private func configureLogging() async {
        // Configure logging system
        print("📝 Logging system setup complete")
    }

    @DIActor
    private func setupAnalytics() async {
        // Configure analytics system
        print("📊 Analytics system setup complete")
    }

    private func preloadCriticalData() async {
        // Preload critical data
        print("📥 Critical data preload complete")
    }

    private func startBackgroundTasks() async {
        // Start background tasks
        print("🔄 Background tasks started")
    }
}
```

### SwiftUI and Concurrency Integration

```swift
/// SwiftUI view demonstrating async data loading with WeaveDI
struct AsyncDataView: View {
    @StateObject private var viewModel = AsyncDataViewModel()
    @State private var isLoading = false
    @State private var data: [DataItem] = []
    @State private var error: String?

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = error {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Error: \(error)")
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await loadData()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(data, id: \.id) { item in
                        DataItemRow(item: item)
                    }
                }
            }
            .navigationTitle("Async Data")
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
        }
    }

    @MainActor
    private func loadData() async {
        isLoading = true
        error = nil

        do {
            data = try await viewModel.fetchData()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

/// ViewModel with async operations using WeaveDI
@MainActor
class AsyncDataViewModel: ObservableObject {
    @Inject var dataService: ThreadSafeDataService?
    @Inject var networkService: NetworkService?
    @Inject var logger: LoggerProtocol?

    func fetchData() async throws -> [DataItem] {
        logger?.info("📥 Data fetch started")

        // Ensure data service initialization
        await dataService?.initialize()

        // Check cached data first
        if let cachedData = await dataService?.retrieveData(forKey: "main_data"),
           let items = try? JSONDecoder().decode([DataItem].self, from: cachedData) {
            logger?.info("📋 Using cached data")
            return items
        }

        // Fetch fresh data
        guard let network = networkService else {
            throw DataError.serviceUnavailable
        }

        let freshData = try await network.fetchDataItems()
        let encoded = try JSONEncoder().encode(freshData)
        await dataService?.storeData(encoded, forKey: "main_data")

        logger?.info("✅ Fresh data fetch and cache complete")
        return freshData
    }
}

struct DataItem: Codable {
    let id: String
    let title: String
    let description: String
}

struct DataItemRow: View {
    let item: DataItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.headline)
            Text(item.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

enum DataError: Error, LocalizedError {
    case serviceUnavailable
    case networkError

    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Data service is unavailable"
        case .networkError:
            return "Network error occurred"
        }
    }
}
```

## 🎯 Real Tutorial Code Examples

### CountApp with Concurrency Integration

```swift
/// Example integrating CountApp from tutorial with concurrency features
struct AsyncCounterView: View {
    @State private var count = 0
    @State private var isLoading = false
    @Inject var counterRepository: CounterRepository?
    @Inject var logger: LoggerProtocol?

    var body: some View {
        VStack(spacing: 20) {
            Text("Async WeaveDI Counter")
                .font(.largeTitle)
                .fontWeight(.bold)

            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                Text("\(count)")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.blue)
            }

            HStack(spacing: 20) {
                AsyncButton("−", color: .red) {
                    await decrementCounter()
                }

                AsyncButton("+", color: .green) {
                    await incrementCounter()
                }
            }

            Button("View History") {
                Task {
                    await showHistory()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .task {
            await loadInitialCount()
        }
    }

    @MainActor
    private func loadInitialCount() async {
        isLoading = true
        count = await counterRepository?.getCurrentCount() ?? 0
        isLoading = false
        logger?.info("📊 Initial count loaded: \(count)")
    }

    @MainActor
    private func incrementCounter() async {
        isLoading = true
        count += 1
        await counterRepository?.saveCount(count)
        isLoading = false
        logger?.info("⬆️ Counter incremented: \(count)")
    }

    @MainActor
    private func decrementCounter() async {
        isLoading = true
        count -= 1
        await counterRepository?.saveCount(count)
        isLoading = false
        logger?.info("⬇️ Counter decremented: \(count)")
    }

    private func showHistory() async {
        let history = await counterRepository?.getCountHistory() ?? []
        logger?.info("📈 History: \(history.count) items")
    }
}

struct AsyncButton: View {
    let title: String
    let color: Color
    let action: () async -> Void

    var body: some View {
        Button(title) {
            Task {
                await action()
            }
        }
        .font(.title)
        .frame(width: 50, height: 50)
        .background(color)
        .foregroundColor(.white)
        .clipShape(Circle())
    }
}
```

---

**Congratulations!** You've mastered WeaveDI's Swift concurrency integration. You can now build high-performance iOS apps with safe and efficient concurrent programming.

📖 **Related Documentation**: [Getting Started](/en/tutorial/gettingStarted) | [Property Wrappers](/en/tutorial/propertyWrappers)