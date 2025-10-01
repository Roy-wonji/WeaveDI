# Troubleshooting Guide

Common issues and solutions when using WeaveDI in your applications.

## Dependency Resolution Issues

### Symptom 1: Injected Dependency is Nil

```swift
class ViewModel {
    @Inject var userService: UserService?

    func loadUser() {
        guard let service = userService else {
            print("❌ UserService is nil")  // This message prints
            return
        }
        // ...
    }
}
```

**Causes:**
- Dependency not registered
- Wrong type registered
- Container not initialized before dependency access

**Solutions:**

```swift
// Solution 1: Verify dependency is registered
await WeaveDI.Container.bootstrap { container in
    container.register(UserService.self) {
        UserServiceImpl()
    }
}

// Solution 2: Use @Injected with InjectedKey (v3.2.0+)
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    static var testValue: UserService = MockUserService()
}

extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

// Usage - always has a value (liveValue as fallback)
class ViewModel {
    @Injected(\.userService) var userService  // Never nil
}

// Solution 3: Check registration
let isRegistered = await WeaveDI.Container.isRegistered(UserService.self)
if !isRegistered {
    print("⚠️ UserService not registered!")
}
```

### Symptom 2: Wrong Type Resolved

```swift
protocol Animal {
    func makeSound()
}

class Dog: Animal {
    func makeSound() { print("Woof!") }
}

class Cat: Animal {
    func makeSound() { print("Meow!") }
}

// Registration
container.register(Animal.self) { Dog() }

// Usage
@Inject var animal: Animal?
animal?.makeSound()  // Prints "Woof!" - expected Cat?
```

**Causes:**
- Multiple registrations for same protocol
- Last registration overwrites previous ones

**Solutions:**

```swift
// Solution 1: Use concrete types
container.register(Dog.self) { Dog() }
container.register(Cat.self) { Cat() }

@Inject var dog: Dog?
@Inject var cat: Cat?

// Solution 2: Use named dependencies (key-based)
struct DogKey: InjectedKey {
    static var liveValue: Animal = Dog()
}

struct CatKey: InjectedKey {
    static var liveValue: Animal = Cat()
}

extension InjectedValues {
    var dog: Animal {
        get { self[DogKey.self] }
        set { self[DogKey.self] = newValue }
    }

    var cat: Animal {
        get { self[CatKey.self] }
        set { self[CatKey.self] = newValue }
    }
}

// Usage
@Injected(\.dog) var dog
@Injected(\.cat) var cat

dog.makeSound()  // "Woof!"
cat.makeSound()  // "Meow!"

// Solution 3: Use wrapper types
struct DogService {
    let animal: Animal = Dog()
}

struct CatService {
    let animal: Animal = Cat()
}

container.register(DogService.self) { DogService() }
container.register(CatService.self) { CatService() }
```

### Symptom 3: Dependency Resolved Too Late

```swift
class AppViewModel {
    @Inject var service: UserService?

    init() {
        // service is nil during init!
        print("Service: \(service)")  // nil
    }

    func start() {
        // Works here
        print("Service: \(service)")  // UserService instance
    }
}
```

**Causes:**
- Property wrappers are evaluated after init
- Attempting to access injected properties during init

**Solutions:**

```swift
// Solution 1: Don't access injected properties in init
class AppViewModel {
    @Inject var service: UserService?

    init() {
        // Don't use service during init
    }

    func configure() {
        // Called later
        service?.setup()
    }
}

// Solution 2: Use @Injected (non-optional)
class AppViewModel {
    @Injected(\.userService) var service

    init() {
        // Use service after init
    }

    func start() {
        service.fetchUser()  // Works
    }
}

// Solution 3: Use constructor injection
class AppViewModel {
    private let service: UserService

    init(service: UserService) {
        self.service = service
        // Can use service during init
        service.setup()
    }
}

// Inject in factory
container.register(AppViewModel.self) {
    let service = container.resolve(UserService.self)
    return AppViewModel(service: service)
}
```

## Circular Dependencies

### Symptom: Infinite Loop or Stack Overflow

```swift
// ServiceA depends on ServiceB
class ServiceA {
    @Injected(\.serviceB) var serviceB

    func doWork() {
        serviceB.doWork()
    }
}

// ServiceB depends on ServiceA
class ServiceB {
    @Injected(\.serviceA) var serviceA  // ⚠️ Circular!

    func doWork() {
        serviceA.doWork()  // Infinite loop!
    }
}
```

**Causes:**
- ServiceA ↔ ServiceB circular dependency
- Recursive static initialization in InjectedKey
- Mutual dependencies during object creation

**Solutions:**

```swift
// Solution 1: Introduce abstraction (Event Bus pattern)
protocol EventBus {
    func publish(_ event: Event)
    func subscribe<T: Event>(_ eventType: T.Type, handler: @escaping (T) -> Void)
}

class ServiceA {
    @Injected(\.eventBus) var eventBus

    func doWork() {
        // Instead of calling ServiceB directly, publish event
        eventBus.publish(WorkRequestEvent())
    }
}

class ServiceB {
    @Injected(\.eventBus) var eventBus

    init() {
        // Subscribe to events
        eventBus.subscribe(WorkRequestEvent.self) { [weak self] event in
            self?.handleWorkRequest(event)
        }
    }
}

// Solution 2: Break cycle with protocols
protocol ServiceBProtocol {
    func doWork()
}

class ServiceA {
    private weak var serviceB: ServiceBProtocol?  // weak reference

    func setServiceB(_ service: ServiceBProtocol) {
        self.serviceB = service
    }

    func doWork() {
        serviceB?.doWork()
    }
}

class ServiceB: ServiceBProtocol {
    @Injected(\.serviceA) var serviceA

    func doWork() {
        // Use serviceA
    }
}

// Registration
container.register(ServiceA.self) { ServiceA() }
container.register(ServiceBProtocol.self) {
    let serviceB = ServiceB()
    let serviceA = container.resolve(ServiceA.self)
    serviceA.setServiceB(serviceB)
    return serviceB
}

// Solution 3: Refactor to shared dependency
class SharedDependency {
    func performSharedWork() {
        // Work that both services need
    }
}

class ServiceA {
    @Injected(\.shared) var shared

    func doWork() {
        shared.performSharedWork()
    }
}

class ServiceB {
    @Injected(\.shared) var shared

    func doWork() {
        shared.performSharedWork()
    }
}
```

### Diagnosis: Detecting Circular Dependencies

```swift
// Check dependency graph
let graph = await WeaveDI.Container.getAutoGeneratedGraph()
print("Dependency graph:\n\(graph)")

// Check for circular dependencies
let circular = await WeaveDI.Container.getDetectedCircularDependencies()
if !circular.isEmpty {
    print("⚠️ Circular dependencies detected:")
    circular.forEach { print("  - \($0)") }
}
```

## Memory Leaks

### Symptom: Memory Usage Continuously Increases

```swift
class ViewManager {
    @Injected(\.service) var service

    var views: [UIView] = []

    func addView(_ view: UIView) {
        views.append(view)
        // Views never deallocated - memory leak!
    }
}
```

**Causes:**
- Strong reference cycles
- Singletons holding strong references to views or view controllers
- Closure captures keeping self strongly

**Solutions:**

```swift
// Solution 1: Use weak references
class ViewManager {
    @Injected(\.service) var service

    private var views: [WeakRef<UIView>] = []  // Use weak references

    func addView(_ view: UIView) {
        views.append(WeakRef(view))
    }

    func cleanupDeallocatedViews() {
        views.removeAll { $0.value == nil }
    }
}

// WeakRef helper
class WeakRef<T: AnyObject> {
    weak var value: T?
    init(_ value: T) {
        self.value = value
    }
}

// Solution 2: Use [weak self] in closures
class DataService {
    @Injected(\.api) var api

    func fetchData(completion: @escaping (Data) -> Void) {
        api.fetch { [weak self] data in
            guard let self = self else { return }
            self.process(data)
            completion(data)
        }
    }
}

// Solution 3: Cleanup in deinit
class CacheService {
    @Injected(\.cache) var cache
    private var data: [String: Any] = [:]

    deinit {
        // Cleanup
        data.removeAll()
        cache.clear()
    }
}

// Solution 4: Use request scope for temporary objects
container.register(TemporaryService.self, scope: .request) {
    TemporaryService()
}
```

### Diagnosis: Detecting Memory Leaks

```swift
// Use Instruments: Leaks template

// Code-based detection:
class MemoryMonitor {
    static func trackMemory() {
        let usage = reportMemory()
        print("Memory usage: \(usage) MB")
    }

    private static func reportMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        return result == KERN_SUCCESS ? info.resident_size / (1024 * 1024) : 0
    }
}

// Call periodically
Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
    MemoryMonitor.trackMemory()
}
```

## Performance Problems

### Symptom 1: Slow Dependency Resolution

```swift
class HeavyService {
    @Injected(\.database) var database
    @Injected(\.networkClient) var networkClient
    @Injected(\.cache) var cache
    @Injected(\.logger) var logger
    @Injected(\.analytics) var analytics

    func performOperation() {
        // Too many dependencies = slow startup
    }
}
```

**Causes:**
- Too many dependencies
- Heavy initialization
- Synchronous resolution bottlenecks

**Solutions:**

```swift
// Solution 1: Reduce dependency count (Facade pattern)
struct ServiceFacade {
    @Injected(\.database) var database
    @Injected(\.networkClient) var networkClient
    @Injected(\.cache) var cache

    func performComplexOperation() {
        // Coordinate multiple services
    }
}

class HeavyService {
    @Injected(\.serviceFacade) var facade  // Single dependency

    func performOperation() {
        facade.performComplexOperation()
    }
}

// Solution 2: Use lazy initialization
class HeavyService {
    @Injected(\.database) var database

    // Initialize only when needed
    private lazy var expensiveResource: ExpensiveResource = {
        ExpensiveResource(database: database)
    }()

    func performOperation() {
        // Created only on first access
        expensiveResource.process()
    }
}

// Solution 3: Enable runtime optimization
UnifiedRegistry.shared.enableOptimization()

// Solution 4: Cache frequently used dependencies
struct CachedDependencies {
    static var shared = CachedDependencies()

    @Injected(\.userService) var userService
    @Injected(\.apiClient) var apiClient

    private init() {}
}

// Usage
let service = CachedDependencies.shared.userService
```

### Symptom 2: High CPU Usage

```swift
class RealtimeService {
    @Factory var generator: DataGenerator  // New instance every time

    func processStream() {
        for _ in 0..<1000 {
            let gen = generator  // Creates 1000 instances!
            gen.generate()
        }
    }
}
```

**Causes:**
- Too many @Factory instance creations
- Unnecessary resolution
- Wrong scope usage

**Solutions:**

```swift
// Solution 1: Use @Injected (singleton)
class RealtimeService {
    @Injected(\.generator) var generator  // Reuse

    func processStream() {
        for _ in 0..<1000 {
            generator.generate()  // Same instance
        }
    }
}

// Solution 2: Reuse instances
class RealtimeService {
    @Factory var generatorFactory: () -> DataGenerator

    func processStream() {
        let generator = generatorFactory()  // Create once

        for _ in 0..<1000 {
            generator.generate()
        }
    }
}

// Solution 3: Batch operations
class RealtimeService {
    @Injected(\.batchProcessor) var processor

    func processStream() {
        let items = (0..<1000).map { Item(id: $0) }
        processor.processBatch(items)  // Single operation
    }
}
```

### Diagnosis: Performance Measurement

```swift
// Performance monitoring
class PerformanceMonitor {
    static func measureResolutionTime() {
        let start = CFAbsoluteTimeGetCurrent()

        // Resolve dependency
        _ = InjectedValues.current.userService

        let duration = CFAbsoluteTimeGetCurrent() - start
        print("Resolution time: \(duration * 1000)ms")
    }

    static func measureInjectionOverhead() {
        class TestClass {
            @Injected(\.userService) var service
        }

        let iterations = 1000
        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0..<iterations {
            let instance = TestClass()
            _ = instance.service
        }

        let duration = CFAbsoluteTimeGetCurrent() - start
        let avgTime = (duration / Double(iterations)) * 1000
        print("Average injection time: \(avgTime)ms")
    }
}
```

## Actor Isolation Errors

### Symptom: "Expression is 'async' but is not marked with 'await'"

```swift
@MainActor
class ViewModel {
    @Injected(\.userService) var userService  // ❌ Actor isolation error

    func loadData() {
        // Compilation error: Actor isolation boundary
    }
}
```

**Causes:**
- InjectedValues not isolated to MainActor
- Crossing actor boundaries
- Swift 6 strict concurrency

**Solutions:**

```swift
// Solution 1: Use non-actor isolated service
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
}

extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

@MainActor
class ViewModel {
    @Injected(\.userService) var userService  // Works

    func loadData() async {
        await userService.fetchUser()
    }
}

// Solution 2: Use nonisolated
@MainActor
class ViewModel {
    nonisolated(unsafe) @Injected(\.userService) var userService

    func loadData() {
        // Synchronous access possible
        userService.fetchUser()
    }
}

// Solution 3: Use DIContainerActor
await WeaveDI.Container.bootstrapInTask { @DIContainerActor container in
    container.register(UserService.self) {
        UserServiceImpl()
    }
}

@DIContainerActor
class ViewModel {
    @Injected(\.userService) var userService  // Same actor

    func loadData() {
        userService.fetchUser()
    }
}
```

### Symptom: Sendable Conformance Warning

```swift
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    // ⚠️ Warning: UserService doesn't conform to Sendable
}
```

**Solutions:**

```swift
// Solution 1: Add Sendable conformance
protocol UserService: Sendable {
    func fetchUser() async -> User
}

actor UserServiceImpl: UserService {
    func fetchUser() async -> User {
        // Implementation
    }
}

// Solution 2: Use @unchecked Sendable (use carefully)
class UserServiceImpl: UserService, @unchecked Sendable {
    private let queue = DispatchQueue(label: "user.service")

    func fetchUser() -> User {
        queue.sync {
            // Thread-safe implementation
        }
    }
}

// Solution 3: Wrap in actor
actor UserServiceActor {
    private let impl: UserServiceImpl

    init() {
        self.impl = UserServiceImpl()
    }

    func fetchUser() async -> User {
        await impl.fetchUser()
    }
}
```

## Testing Issues

### Symptom: Tests Use Previous Dependencies

```swift
func testUserLogin() async {
    // Previous test set mock object
    InjectedValues.current.userService = MockUserService()

    let viewModel = LoginViewModel()
    await viewModel.login()

    // Next test still has previous mock!
}

func testUserLogout() async {
    let viewModel = LogoutViewModel()
    await viewModel.logout()
    // ❌ Still using MockUserService
}
```

**Causes:**
- InjectedValues not cleaned between tests
- Global state pollution
- No proper isolation

**Solutions:**

```swift
// Solution 1: Use withInjectedValues (recommended)
func testUserLogin() async {
    await withInjectedValues { values in
        values.userService = MockUserService()
    } operation: {
        let viewModel = LoginViewModel()
        await viewModel.login()
        XCTAssertTrue(viewModel.isLoggedIn)
    }
    // Automatically reverted!
}

func testUserLogout() async {
    await withInjectedValues { values in
        values.userService = MockUserService()
    } operation: {
        let viewModel = LogoutViewModel()
        await viewModel.logout()
        XCTAssertFalse(viewModel.isLoggedIn)
    }
    // Clean state
}

// Solution 2: Use setUp/tearDown
class ViewModelTests: XCTestCase {
    override func setUp() async throws {
        // Clean before each test
        await WeaveDI.Container.releaseAll()
    }

    override func tearDown() async throws {
        // Clean after each test
        await WeaveDI.Container.releaseAll()
    }
}

// Solution 3: Create test helper
extension XCTestCase {
    func withCleanDependencies(
        operation: () async throws -> Void
    ) async rethrows {
        await WeaveDI.Container.releaseAll()
        try await operation()
        await WeaveDI.Container.releaseAll()
    }
}

// Usage
func testExample() async throws {
    await withCleanDependencies {
        // Test code
    }
}
```

### Symptom: Mock Objects Not Called

```swift
class MockUserService: UserService {
    var fetchUserCalled = false

    func fetchUser() async -> User {
        fetchUserCalled = true
        return User(id: "test")
    }
}

func testFetchUser() async {
    let mock = MockUserService()

    await withInjectedValues { values in
        values.userService = mock
    } operation: {
        let service = InjectedValues.current.userService
        await service.fetchUser()
    }

    XCTAssertTrue(mock.fetchUserCalled)  // ❌ Fails - false
}
```

**Causes:**
- Different instance resolved
- InjectedKey liveValue ignoring override
- Wrong KeyPath used

**Solutions:**

```swift
// Solution 1: Test within withInjectedValues
func testFetchUser() async {
    let mock = MockUserService()

    await withInjectedValues { values in
        values.userService = mock
    } operation: {
        let viewModel = UserViewModel()
        await viewModel.loadUser()

        // Verify within operation
        XCTAssertTrue(mock.fetchUserCalled)  // ✅ Success
    }
}

// Solution 2: Use constructor injection
class UserViewModel {
    private let userService: UserService

    init(userService: UserService) {
        self.userService = userService
    }

    func loadUser() async {
        await userService.fetchUser()
    }
}

func testFetchUser() async {
    let mock = MockUserService()
    let viewModel = UserViewModel(userService: mock)

    await viewModel.loadUser()

    XCTAssertTrue(mock.fetchUserCalled)  // ✅ Success
}

// Solution 3: Use testValue
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    static var testValue: UserService = MockUserService()  // Default mock
}

func testFetchUser() async {
    // testValue automatically used
    let viewModel = UserViewModel()
    await viewModel.loadUser()
}
```

## Build and Compilation Errors

### Symptom: "Cannot find 'WeaveDI' in scope"

```swift
import WeaveDI  // ❌ Error: Cannot find WeaveDI

@Injected(\.userService) var userService
```

**Causes:**
- WeaveDI not added to project
- Wrong import path
- SPM package resolution issues

**Solutions:**

```swift
// Solution 1: Verify WeaveDI is added
// File > Add Package Dependencies
// URL: https://github.com/Roy-wonji/WeaveDI.git
// Version: 3.2.0+

// Solution 2: Clean Build
// Product > Clean Build Folder (⇧⌘K)
// Then rebuild

// Solution 3: Check Package.swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.2.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["WeaveDI"]
    )
]

// Solution 4: Reset package caches
// File > Packages > Reset Package Caches
```

### Symptom: Type Inference Failed

```swift
struct ServiceKey: InjectedKey {
    static var liveValue = ServiceImpl()  // ❌ Error: Type inference failed
}
```

**Causes:**
- Compiler can't infer protocol conformance
- Ambiguous type
- Missing explicit type

**Solutions:**

```swift
// Solution 1: Add explicit type
struct ServiceKey: InjectedKey {
    static var liveValue: UserService = ServiceImpl()  // ✅ Explicit type
}

// Solution 2: Use where clause
struct ServiceKey: InjectedKey where Value == UserService {
    static var liveValue: UserService {
        ServiceImpl()
    }
}

// Solution 3: Use typealias
struct ServiceKey: InjectedKey {
    typealias Value = UserService
    static var liveValue: Value = ServiceImpl()
}
```

### Symptom: "Ambiguous use of 'Injected'"

```swift
@Injected(\.service) var service  // ❌ Error: Ambiguous use
```

**Causes:**
- Multiple InjectedValues extensions define same name
- Name conflicts between different modules
- Import conflicts

**Solutions:**

```swift
// Solution 1: Use unique names
extension InjectedValues {
    var userService: UserService { /* ... */ }  // "userService" unique
    var authService: AuthService { /* ... */ }  // "authService" unique
}

// Solution 2: Use module qualifiers
@Injected(MyModule.InjectedValues.userService) var service

// Solution 3: Use namespaces
enum UserFeature {
    struct ServiceKey: InjectedKey {
        static var liveValue: UserService = UserServiceImpl()
    }
}

extension InjectedValues {
    var userFeatureService: UserService {
        get { self[UserFeature.ServiceKey.self] }
        set { self[UserFeature.ServiceKey.self] = newValue }
    }
}
```

## Debugging Tips

### Enable Logging

```swift
// WeaveDI logging
UnifiedRegistry.shared.enableLogging()

// Custom logger
class DILogger {
    static func logResolution<T>(_ type: T.Type) {
        print("✅ Resolved: \(type)")
    }

    static func logRegistration<T>(_ type: T.Type) {
        print("📝 Registered: \(type)")
    }

    static func logError(_ message: String) {
        print("❌ Error: \(message)")
    }
}

// Wrapper with logging
@propertyWrapper
struct LoggedInjected<T> {
    @Injected var wrappedValue: T

    init(_ keyPath: KeyPath<InjectedValues, T>) {
        self._wrappedValue = Injected(keyPath)
        DILogger.logResolution(T.self)
    }
}
```

### Inspect Dependency Graph

```swift
// Print all registered dependencies
let graph = await WeaveDI.Container.getAutoGeneratedGraph()
print("Dependency Graph:")
print(graph)

// Check specific type dependencies
let dependencies = await WeaveDI.Container.getDependencies(for: UserViewModel.self)
print("UserViewModel dependencies:")
dependencies.forEach { print("  - \($0)") }

// Trace resolution path
func traceDependencyResolution<T>(_ type: T.Type) {
    print("Resolving: \(type)")

    let start = CFAbsoluteTimeGetCurrent()
    let instance = InjectedValues.current[keyPath: \.userService as! KeyPath<InjectedValues, T>]
    let duration = CFAbsoluteTimeGetCurrent() - start

    print("Resolved: \(type) (\(duration * 1000)ms)")
}
```

### Performance Profiling

```swift
class DIPerformanceProfiler {
    static var resolutionTimes: [String: TimeInterval] = [:]

    static func profile<T>(_ type: T.Type, operation: () -> T) -> T {
        let typeName = String(describing: type)
        let start = CFAbsoluteTimeGetCurrent()

        let result = operation()

        let duration = CFAbsoluteTimeGetCurrent() - start
        resolutionTimes[typeName] = duration

        return result
    }

    static func printReport() {
        print("\n📊 DI Performance Report:")
        resolutionTimes.sorted { $0.value > $1.value }.forEach { type, time in
            print("  \(type): \(time * 1000)ms")
        }
    }
}

// Usage
let service = DIPerformanceProfiler.profile(UserService.self) {
    InjectedValues.current.userService
}

// Later
DIPerformanceProfiler.printReport()
```

### Breakpoints and lldb

```swift
// Set breakpoint in property wrapper init
@propertyWrapper
struct DebugInjected<T> {
    @Injected var wrappedValue: T

    init(_ keyPath: KeyPath<InjectedValues, T>) {
        print("🔍 Injecting: \(T.self)")  // Set breakpoint here
        self._wrappedValue = Injected(keyPath)
    }
}

// lldb commands:
// br set -n "DebugInjected.init"
// po keyPath
// po T.self
// continue
```

### Memory Inspection

```swift
// Track dependencies with weak references
class DependencyTracker {
    private static var tracked: [String: WeakBox] = [:]

    class WeakBox {
        weak var value: AnyObject?
        init(_ value: AnyObject) {
            self.value = value
        }
    }

    static func track<T: AnyObject>(_ instance: T, name: String) {
        tracked[name] = WeakBox(instance)
    }

    static func checkForLeaks() {
        print("🔍 Leak check:")
        tracked.forEach { name, box in
            if box.value != nil {
                print("  ⚠️ \(name) still in memory")
            } else {
                print("  ✅ \(name) deallocated")
            }
        }
    }
}

// Usage
let service = UserServiceImpl()
DependencyTracker.track(service, name: "UserService")

// Later
DependencyTracker.checkForLeaks()
```

## Getting Help

If problems persist:

1. **Check Documentation**: [WeaveDI Documentation](https://roy-wonji.github.io/WeaveDI/)
2. **Review Examples**: [GitHub Examples](https://github.com/Roy-wonji/WeaveDI/tree/main/Examples)
3. **Report Issues**: [GitHub Issues](https://github.com/Roy-wonji/WeaveDI/issues)
4. **Join Discussions**: [GitHub Discussions](https://github.com/Roy-wonji/WeaveDI/discussions)

When reporting issues, include:
- WeaveDI version
- Swift version
- Minimal reproducible example
- Error messages and stack traces
- Expected vs actual behavior

## Next Steps

- [Best Practices](./bestPractices.md) - Recommended patterns
- [Migration Guide](./migrationInjectToInjected.md) - @Inject → @Injected
- [Performance Optimization](./runtimeOptimization.md) - Performance tuning
- [Testing Guide](../tutorial/testing.md) - Advanced testing strategies
