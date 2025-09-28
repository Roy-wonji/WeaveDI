# Performance Optimization with WeaveDI

Master performance optimization techniques for WeaveDI-powered applications. Learn caching strategies, memory management, and benchmarking approaches.

## 🎯 What You'll Learn

- **Hot Path Optimization**: Optimizing frequently accessed dependencies
- **Memory Management**: Reducing memory footprint and preventing leaks
- **Lazy Loading**: Deferring expensive dependency initialization
- **Caching Strategies**: Intelligent dependency result caching
- **Benchmarking**: Measuring and improving DI performance
- **Production Patterns**: Real-world optimization techniques

## 🚀 Hot Path Optimization

### Identifying Performance Bottlenecks

```swift
import WeaveDI

/// Performance monitoring service to identify bottlenecks
/// This service tracks dependency resolution times and frequency
class DIPerformanceMonitor {

    /// Tracks how many times each dependency type is resolved
    /// Higher numbers indicate "hot paths" that need optimization
    private var resolutionCounts: [String: Int] = [:]

    /// Tracks total time spent resolving each dependency type
    /// Helps identify slow-resolving dependencies
    private var resolutionTimes: [String: TimeInterval] = [:]

    /// Tracks the last resolution time for each dependency
    /// Useful for debugging intermittent performance issues
    private var lastResolutionTimes: [String: Date] = [:]

    /// Monitor dependency resolution performance
    /// Call this method before and after dependency resolution
    func trackResolution<T>(for type: T.Type, executionTime: TimeInterval) {
        let typeName = String(describing: type)

        // Update resolution count
        resolutionCounts[typeName, default: 0] += 1

        // Update total time
        resolutionTimes[typeName, default: 0] += executionTime

        // Update last resolution time
        lastResolutionTimes[typeName] = Date()

        // Log if resolution is taking too long
        if executionTime > 0.1 { // More than 100ms is considered slow
            print("⚠️ Slow dependency resolution: \(typeName) took \(executionTime)s")
        }

        // Log if this is a frequently accessed dependency
        let count = resolutionCounts[typeName] ?? 0
        if count > 0 && count % 100 == 0 { // Every 100 resolutions
            print("🔥 Hot path detected: \(typeName) resolved \(count) times")
        }
    }

    /// Get performance statistics for analysis
    /// Returns data that can be used to identify optimization opportunities
    func getPerformanceStats() -> PerformanceStats {
        var hotPaths: [String] = []
        var slowDependencies: [String] = []

        for (type, count) in resolutionCounts {
            // Identify hot paths (frequently accessed dependencies)
            if count > 50 {
                hotPaths.append("\(type): \(count) times")
            }

            // Identify slow dependencies (high average resolution time)
            let totalTime = resolutionTimes[type] ?? 0
            let averageTime = totalTime / Double(count)
            if averageTime > 0.05 { // More than 50ms average
                slowDependencies.append("\(type): \(averageTime)s avg")
            }
        }

        return PerformanceStats(
            hotPaths: hotPaths,
            slowDependencies: slowDependencies,
            totalResolutions: resolutionCounts.values.reduce(0, +),
            totalTime: resolutionTimes.values.reduce(0, +)
        )
    }
}

/// Performance statistics for analysis
struct PerformanceStats {
    let hotPaths: [String]           // Frequently accessed dependencies
    let slowDependencies: [String]   // Slow-resolving dependencies
    let totalResolutions: Int        // Total number of resolutions
    let totalTime: TimeInterval      // Total time spent on resolution
}
```

**🔍 Code Explanation:**
- **Resolution Tracking**: Monitors how often each dependency is resolved
- **Performance Measurement**: Tracks resolution times to identify bottlenecks
- **Hot Path Detection**: Automatically identifies frequently accessed dependencies
- **Slow Dependency Detection**: Flags dependencies that take too long to resolve

### Optimized Dependency Resolution

```swift
/// Optimized service that caches frequently accessed dependencies
/// This pattern significantly improves performance for hot paths
class OptimizedServiceManager {

    // MARK: - Cached Dependencies (Hot Path Optimization)

    /// Cache for frequently accessed network service
    /// Avoids repeated DI resolution overhead
    private var cachedNetworkService: NetworkService?

    /// Cache for database service (expensive to initialize)
    /// Stores the resolved instance to avoid re-initialization
    private var cachedDatabaseService: DatabaseService?

    /// Cache for logger service (used everywhere)
    /// Most frequently accessed dependency in typical apps
    private var cachedLogger: LoggerProtocol?

    // MARK: - Direct DI Injection (Less Frequently Used)

    /// Authentication service - used less frequently
    /// No caching needed as it's not a hot path
    @Inject private var authService: AuthService?

    /// Analytics service - used less frequently
    /// No caching needed, and fresh instances might be preferred
    @Inject private var analyticsService: AnalyticsService?

    /// Configuration service - rarely accessed after startup
    /// No caching needed as it's accessed infrequently
    @Inject private var configService: ConfigurationService?

    // MARK: - Optimized Accessors

    /// Get network service with caching optimization
    /// First access resolves via DI, subsequent accesses use cache
    var networkService: NetworkService? {
        if let cached = cachedNetworkService {
            return cached
        }

        // Resolve via WeaveDI.Container and cache the result
        let resolved = WeaveDI.Container.live.resolve(NetworkService.self)
        cachedNetworkService = resolved

        if resolved != nil {
            print("🚀 NetworkService cached for future use")
        }

        return resolved
    }

    /// Get database service with lazy initialization and caching
    /// Database services are often expensive to initialize
    var databaseService: DatabaseService? {
        if let cached = cachedDatabaseService {
            return cached
        }

        print("📀 Initializing database service (expensive operation)")
        let startTime = Date()

        let resolved = WeaveDI.Container.live.resolve(DatabaseService.self)
        cachedDatabaseService = resolved

        let initTime = Date().timeIntervalSince(startTime)
        print("📀 Database service initialized in \(initTime)s")

        return resolved
    }

    /// Get logger with ultra-fast caching
    /// Logger is typically the most frequently accessed dependency
    var logger: LoggerProtocol? {
        if let cached = cachedLogger {
            return cached
        }

        let resolved = WeaveDI.Container.live.resolve(LoggerProtocol.self)
        cachedLogger = resolved
        print("📝 Logger cached (hot path optimization)")

        return resolved
    }

    // MARK: - Cache Management

    /// Clear cached dependencies to force re-resolution
    /// Useful for testing or when dependencies might have changed
    func clearCache() {
        cachedNetworkService = nil
        cachedDatabaseService = nil
        cachedLogger = nil
        print("🧹 Dependency cache cleared")
    }

    /// Warm up cache by pre-resolving all cached dependencies
    /// Call this during app startup to avoid first-access delays
    func warmUpCache() async {
        print("🔥 Warming up dependency cache...")

        await withTaskGroup(of: Void.self) { group in
            // Pre-resolve all cached dependencies in parallel
            group.addTask { [weak self] in
                _ = self?.networkService
            }

            group.addTask { [weak self] in
                _ = self?.databaseService
            }

            group.addTask { [weak self] in
                _ = self?.logger
            }
        }

        print("✅ Cache warm-up complete")
    }
}
```

**🔍 Code Explanation:**
- **Selective Caching**: Only caches frequently accessed (hot path) dependencies
- **Lazy Initialization**: Resolves dependencies only when first accessed
- **Performance Monitoring**: Logs initialization times for expensive operations
- **Cache Management**: Provides methods to clear and warm up the cache

## 💾 Memory Management

### Memory-Efficient Dependency Patterns

```swift
/// Memory-efficient dependency management with automatic cleanup
/// This pattern prevents memory leaks and reduces memory footprint
class MemoryEfficientManager {

    // MARK: - Weak References for Non-Critical Dependencies

    /// Use weak references for dependencies that can be recreated
    /// This allows the system to free memory when under pressure
    private weak var weakCacheService: CacheService?
    private weak var weakImageProcessor: ImageProcessor?
    private weak var weakAnalyticsService: AnalyticsService?

    // MARK: - Strong References for Critical Dependencies

    /// Keep strong references for critical dependencies
    /// These are essential and should not be deallocated unexpectedly
    @Inject private var databaseService: DatabaseService?
    @Inject private var authService: AuthService?
    @Inject private var networkService: NetworkService?

    // MARK: - Memory-Aware Accessors

    /// Get cache service with memory-aware resolution
    /// Recreates the service if it was deallocated due to memory pressure
    var cacheService: CacheService? {
        // Check if weak reference is still valid
        if let existing = weakCacheService {
            return existing
        }

        // Resolve new instance if deallocated
        print("💾 Recreating cache service (memory optimized)")
        let newService = WeaveDI.Container.live.resolve(CacheService.self)
        weakCacheService = newService

        return newService
    }

    /// Get image processor with automatic recreation
    /// Image processors can be memory-intensive and benefit from weak references
    var imageProcessor: ImageProcessor? {
        if let existing = weakImageProcessor {
            return existing
        }

        print("🖼️ Recreating image processor (memory pressure recovery)")
        let newProcessor = WeaveDI.Container.live.resolve(ImageProcessor.self)
        weakImageProcessor = newProcessor

        return newProcessor
    }

    /// Get analytics service with lazy recreation
    /// Analytics is non-critical and can be recreated as needed
    var analyticsService: AnalyticsService? {
        if let existing = weakAnalyticsService {
            return existing
        }

        print("📊 Recreating analytics service (memory efficient)")
        let newService = WeaveDI.Container.live.resolve(AnalyticsService.self)
        weakAnalyticsService = newService

        return newService
    }

    // MARK: - Memory Monitoring

    /// Monitor memory usage and trigger cleanup if needed
    /// Call this periodically or when receiving memory warnings
    func handleMemoryPressure() {
        print("⚠️ Memory pressure detected - performing cleanup")

        // Clear weak references to allow deallocation
        weakCacheService = nil
        weakImageProcessor = nil
        weakAnalyticsService = nil

        // Force garbage collection (iOS will handle this automatically)
        print("🧹 Non-critical dependencies cleared for memory recovery")

        // Log current memory state
        logMemoryUsage()
    }

    /// Log current memory usage for monitoring
    /// Helps track memory efficiency improvements
    private func logMemoryUsage() {
        let memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let usedMemory = memoryInfo.resident_size / 1024 / 1024 // Convert to MB
            print("📊 Current memory usage: \(usedMemory) MB")
        }
    }
}
```

**🔍 Code Explanation:**
- **Weak References**: Uses weak references for non-critical dependencies to allow memory reclamation
- **Strong References**: Keeps strong references for critical dependencies that must persist
- **Automatic Recreation**: Recreates deallocated dependencies when accessed again
- **Memory Monitoring**: Provides tools to monitor and respond to memory pressure

## ⚡ Lazy Loading Strategies

### Advanced Lazy Initialization

```swift
/// Advanced lazy loading with dependency prioritization
/// This pattern optimizes app startup time by deferring expensive initializations
class LazyDependencyManager {

    // MARK: - Lazy Properties with Custom Logic

    /// Expensive machine learning service - only initialize when needed
    /// ML services often have large memory footprints and long initialization times
    private lazy var mlService: MachineLearningService? = {
        print("🧠 Initializing ML service (expensive operation)")
        let startTime = Date()

        let service = WeaveDI.Container.live.resolve(MachineLearningService.self)

        let initTime = Date().timeIntervalSince(startTime)
        print("🧠 ML service initialized in \(initTime)s")

        return service
    }()

    /// Image processing service - lazy load with memory monitoring
    /// Image processors can be memory-intensive
    private lazy var imageProcessor: ImageProcessingService? = {
        print("🖼️ Initializing image processor")

        // Check available memory before initialization
        if isMemoryAvailable() {
            let service = WeaveDI.Container.live.resolve(ImageProcessingService.self)
            print("🖼️ Image processor initialized")
            return service
        } else {
            print("⚠️ Insufficient memory for image processor")
            return nil
        }
    }()

    /// Video processing service - heaviest dependency, most aggressive lazy loading
    /// Video processing requires significant resources
    private lazy var videoProcessor: VideoProcessingService? = {
        print("🎥 Initializing video processor (very expensive)")

        // Only initialize if device has sufficient resources
        guard hasVideoCapabilities() else {
            print("❌ Device lacks video processing capabilities")
            return nil
        }

        let startTime = Date()
        let service = WeaveDI.Container.live.resolve(VideoProcessingService.self)
        let initTime = Date().timeIntervalSince(startTime)

        print("🎥 Video processor initialized in \(initTime)s")
        return service
    }()

    // MARK: - Prioritized Initialization

    /// Initialize dependencies in order of priority
    /// Critical dependencies are initialized first
    func initializeDependenciesByPriority() async {
        print("🚀 Starting prioritized dependency initialization")

        // Priority 1: Essential services (fast initialization)
        await initializeEssentialServices()

        // Priority 2: Important but non-critical services (medium time)
        await initializeImportantServices()

        // Priority 3: Optional services (can be deferred)
        await initializeOptionalServices()

        print("✅ Prioritized initialization complete")
    }

    /// Initialize essential services that the app cannot function without
    /// These are loaded immediately during app startup
    private func initializeEssentialServices() async {
        print("⚡ Initializing essential services...")

        await withTaskGroup(of: Void.self) { group in
            // Authentication - critical for user experience
            group.addTask {
                _ = WeaveDI.Container.live.resolve(AuthService.self)
                print("🔐 Auth service ready")
            }

            // Network service - needed for most operations
            group.addTask {
                _ = WeaveDI.Container.live.resolve(NetworkService.self)
                print("🌐 Network service ready")
            }

            // Logger - needed for debugging and monitoring
            group.addTask {
                _ = WeaveDI.Container.live.resolve(LoggerProtocol.self)
                print("📝 Logger ready")
            }
        }

        print("✅ Essential services initialized")
    }

    /// Initialize important but non-critical services
    /// These improve user experience but aren't required for basic functionality
    private func initializeImportantServices() async {
        print("📦 Initializing important services...")

        // Initialize these services sequentially to manage resource usage
        let cacheService = WeaveDI.Container.live.resolve(CacheService.self)
        if cacheService != nil {
            print("💾 Cache service ready")
        }

        let pushService = WeaveDI.Container.live.resolve(PushNotificationService.self)
        if pushService != nil {
            print("🔔 Push notification service ready")
        }

        let analyticsService = WeaveDI.Container.live.resolve(AnalyticsService.self)
        if analyticsService != nil {
            print("📊 Analytics service ready")
        }

        print("✅ Important services initialized")
    }

    /// Initialize optional services that enhance the user experience
    /// These can be safely deferred until actually needed
    private func initializeOptionalServices() async {
        print("🎨 Initializing optional services...")

        // These services are initialized in the background
        Task.detached(priority: .background) { [weak self] in
            // Pre-load ML service if device supports it
            if await self?.isMLCapable() == true {
                _ = self?.mlService
            }

            // Pre-load image processor for better UX
            _ = self?.imageProcessor

            print("🎨 Optional services initialization complete")
        }
    }

    // MARK: - Resource Checking

    /// Check if device has sufficient memory for resource-intensive operations
    private func isMemoryAvailable() -> Bool {
        let availableMemory = getAvailableMemory()
        let requiredMemory: UInt64 = 100 * 1024 * 1024 // 100 MB required

        return availableMemory > requiredMemory
    }

    /// Check if device supports machine learning operations
    private func isMLCapable() async -> Bool {
        // Check device capabilities, OS version, available memory, etc.
        guard #available(iOS 13.0, *) else { return false }
        return isMemoryAvailable() && hasMLFramework()
    }

    /// Check if device has video processing capabilities
    private func hasVideoCapabilities() -> Bool {
        // Check for hardware video encoding/decoding support
        return isMemoryAvailable() && hasVideoHardware()
    }

    /// Get available system memory
    private func getAvailableMemory() -> UInt64 {
        // Implementation would query system memory
        // This is simplified for demonstration
        return 512 * 1024 * 1024 // Assume 512 MB available
    }

    /// Check if ML framework is available
    private func hasMLFramework() -> Bool {
        // Check if Core ML or other ML frameworks are available
        return true // Simplified for demonstration
    }

    /// Check if hardware video processing is available
    private func hasVideoHardware() -> Bool {
        // Check for hardware video encoding/decoding capabilities
        return true // Simplified for demonstration
    }
}
```

**🔍 Code Explanation:**
- **Lazy Properties**: Uses Swift's lazy keyword for automatic deferred initialization
- **Priority-Based Loading**: Initializes dependencies in order of importance
- **Resource Checking**: Verifies device capabilities before expensive initializations
- **Background Initialization**: Uses background tasks for non-critical dependencies

## 📊 Benchmarking and Measurement

### Performance Benchmarking Suite

```swift
import XCTest
import WeaveDI

/// Comprehensive benchmarking suite for WeaveDI performance
/// Use this to measure and track performance improvements over time
class WeaveDIPerformanceBenchmarks: XCTestCase {

    // MARK: - Benchmark Configuration

    /// Number of iterations for each benchmark
    /// Higher numbers provide more accurate results but take longer
    private let benchmarkIterations = 1000

    /// Number of different dependency types to test with
    /// Tests scalability with increasing numbers of dependencies
    private let dependencyTypeCount = 100

    // MARK: - Resolution Performance Benchmarks

    /// Benchmark basic dependency resolution performance
    /// Measures how fast WeaveDI can resolve a single dependency
    func testBasicResolutionPerformance() {
        // Setup: Register a simple service
        let container = WeaveDI.Container.live
        container.register(TestService.self) {
            TestService()
        }

        // Benchmark: Measure resolution time
        measure {
            for _ in 0..<benchmarkIterations {
                _ = container.resolve(TestService.self)
            }
        }

        print("📊 Basic resolution: \(benchmarkIterations) iterations completed")
    }

    /// Benchmark cached vs non-cached resolution performance
    /// Compares performance of singleton vs factory patterns
    func testCachedVsNonCachedResolution() {
        let container = WeaveDI.Container.live

        // Register singleton (cached)
        container.register(TestService.self, scope: .singleton) {
            TestService()
        }

        // Register factory (non-cached)
        container.register(TestFactoryService.self, scope: .factory) {
            TestFactoryService()
        }

        // Benchmark cached resolution
        let cachedTime = measureTime {
            for _ in 0..<benchmarkIterations {
                _ = container.resolve(TestService.self)
            }
        }

        // Benchmark non-cached resolution
        let nonCachedTime = measureTime {
            for _ in 0..<benchmarkIterations {
                _ = container.resolve(TestFactoryService.self)
            }
        }

        print("📊 Cached resolution: \(cachedTime)s")
        print("📊 Non-cached resolution: \(nonCachedTime)s")
        print("📊 Performance ratio: \(nonCachedTime / cachedTime)x faster for cached")

        // Assert that cached resolution is significantly faster
        XCTAssertLessThan(cachedTime, nonCachedTime * 0.1, "Cached resolution should be at least 10x faster")
    }

    /// Benchmark resolution performance with many registered dependencies
    /// Tests how performance scales with container size
    func testScalabilityWithManyDependencies() {
        let container = WeaveDI.Container.live

        // Register many different service types
        for i in 0..<dependencyTypeCount {
            container.register(type(of: TestService()), identifier: "service_\(i)") {
                TestService()
            }
        }

        // Benchmark resolution time with many registered dependencies
        let resolutionTime = measureTime {
            for i in 0..<benchmarkIterations {
                let serviceId = "service_\(i % dependencyTypeCount)"
                _ = container.resolve(TestService.self, identifier: serviceId)
            }
        }

        print("📊 Resolution with \(dependencyTypeCount) dependencies: \(resolutionTime)s")
        print("📊 Average per resolution: \(resolutionTime / Double(benchmarkIterations) * 1000)ms")

        // Assert that performance doesn't degrade significantly with many dependencies
        let maxAcceptableTime = 0.001 // 1ms per resolution
        let avgTimePerResolution = resolutionTime / Double(benchmarkIterations)
        XCTAssertLessThan(avgTimePerResolution, maxAcceptableTime, "Resolution should be under 1ms even with many dependencies")
    }

    // MARK: - Concurrency Performance Benchmarks

    /// Benchmark concurrent dependency resolution performance
    /// Tests thread safety and concurrent access performance
    func testConcurrentResolutionPerformance() async {
        let container = WeaveDI.Container.live

        // Register thread-safe service
        container.register(ThreadSafeService.self) {
            ThreadSafeService()
        }

        // Benchmark concurrent access
        let concurrentTime = await measureAsyncTime {
            await withTaskGroup(of: Void.self) { group in
                // Create multiple concurrent tasks
                for _ in 0..<10 {
                    group.addTask {
                        for _ in 0..<(self.benchmarkIterations / 10) {
                            _ = container.resolve(ThreadSafeService.self)
                        }
                    }
                }

                // Wait for all tasks to complete
                for await _ in group {}
            }
        }

        print("📊 Concurrent resolution (10 threads): \(concurrentTime)s")

        // Compare with sequential resolution
        let sequentialTime = measureTime {
            for _ in 0..<benchmarkIterations {
                _ = container.resolve(ThreadSafeService.self)
            }
        }

        print("📊 Sequential resolution: \(sequentialTime)s")
        print("📊 Concurrency overhead: \(concurrentTime / sequentialTime)x")

        // Assert that concurrency overhead is reasonable
        XCTAssertLessThan(concurrentTime, sequentialTime * 2.0, "Concurrent access should not be more than 2x slower")
    }

    // MARK: - Memory Performance Benchmarks

    /// Benchmark memory usage during dependency resolution
    /// Tests for memory leaks and excessive memory allocation
    func testMemoryUsageDuringResolution() {
        let container = WeaveDI.Container.live

        container.register(MemoryIntensiveService.self) {
            MemoryIntensiveService()
        }

        let initialMemory = getCurrentMemoryUsage()

        // Resolve many instances to test memory behavior
        for _ in 0..<benchmarkIterations {
            _ = container.resolve(MemoryIntensiveService.self)
        }

        let finalMemory = getCurrentMemoryUsage()
        let memoryDelta = finalMemory - initialMemory

        print("📊 Memory usage delta: \(memoryDelta / 1024 / 1024) MB")

        // Assert that memory usage doesn't grow excessively
        let maxAcceptableMemoryGrowth: UInt64 = 50 * 1024 * 1024 // 50 MB
        XCTAssertLessThan(memoryDelta, maxAcceptableMemoryGrowth, "Memory usage should not grow excessively during resolution")
    }

    // MARK: - Property Wrapper Performance Benchmarks

    /// Benchmark @Inject property wrapper performance
    /// Compares property wrapper vs direct resolution performance
    func testPropertyWrapperPerformance() {
        // Setup test class with @Inject
        class TestClass {
            @Inject var service: TestService?
        }

        let container = WeaveDI.Container.live
        container.register(TestService.self) {
            TestService()
        }

        let testInstance = TestClass()

        // Benchmark property wrapper access
        let wrapperTime = measureTime {
            for _ in 0..<benchmarkIterations {
                _ = testInstance.service
            }
        }

        // Benchmark direct resolution
        let directTime = measureTime {
            for _ in 0..<benchmarkIterations {
                _ = container.resolve(TestService.self)
            }
        }

        print("📊 Property wrapper access: \(wrapperTime)s")
        print("📊 Direct resolution: \(directTime)s")
        print("📊 Property wrapper overhead: \(wrapperTime / directTime)x")

        // Assert that property wrapper overhead is minimal
        XCTAssertLessThan(wrapperTime, directTime * 1.5, "Property wrapper should have minimal overhead")
    }

    // MARK: - Utility Methods

    /// Measure execution time of a synchronous block
    private func measureTime(_ block: () -> Void) -> TimeInterval {
        let startTime = Date()
        block()
        return Date().timeIntervalSince(startTime)
    }

    /// Measure execution time of an asynchronous block
    private func measureAsyncTime(_ block: () async -> Void) async -> TimeInterval {
        let startTime = Date()
        await block()
        return Date().timeIntervalSince(startTime)
    }

    /// Get current memory usage of the app
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? info.resident_size : 0
    }
}

// MARK: - Test Services

/// Simple test service for benchmarking
class TestService {
    let id = UUID()
    let creationTime = Date()
}

/// Factory test service (new instance every time)
class TestFactoryService {
    let id = UUID()
    let creationTime = Date()
}

/// Thread-safe test service for concurrency testing
class ThreadSafeService {
    private let queue = DispatchQueue(label: "thread-safe-service")
    private var counter = 0

    func increment() {
        queue.sync {
            counter += 1
        }
    }

    var count: Int {
        queue.sync { counter }
    }
}

/// Memory-intensive service for memory testing
class MemoryIntensiveService {
    private let data = Data(count: 1024 * 1024) // 1MB of data
    let id = UUID()
}
```

**🔍 Code Explanation:**
- **Comprehensive Benchmarks**: Tests all aspects of DI performance
- **Scalability Testing**: Verifies performance doesn't degrade with container size
- **Concurrency Testing**: Measures thread safety performance overhead
- **Memory Testing**: Ensures no memory leaks or excessive allocation
- **Comparative Analysis**: Compares different resolution methods and patterns

## 📋 Production Optimization Checklist

### ✅ Performance Optimization Steps

1. **Identify Hot Paths**
   - Profile your app to find frequently accessed dependencies
   - Use performance monitoring to track resolution times
   - Focus optimization efforts on the most impactful areas

2. **Implement Caching Strategies**
   - Cache frequently accessed dependencies
   - Use lazy loading for expensive initializations
   - Implement memory-aware caching for optimal resource usage

3. **Optimize Memory Usage**
   - Use weak references for non-critical dependencies
   - Implement memory pressure handling
   - Monitor memory growth during dependency resolution

4. **Benchmark and Measure**
   - Set up automated performance tests
   - Track performance metrics over time
   - Compare different optimization strategies

5. **Production Monitoring**
   - Implement runtime performance monitoring
   - Set up alerts for performance degradation
   - Continuously optimize based on real-world usage data

---

**Congratulations!** You now have the knowledge and tools to optimize WeaveDI performance for production applications. Use these techniques to build fast, efficient, and scalable iOS apps.
