# Migration Guide to WeaveDI 3.0.0

Comprehensive migration guide from WeaveDI 2.x to 3.0.0, covering new features, performance improvements, and breaking changes.

## Overview

WeaveDI 3.0.0 represents a major leap forward with automatic optimization, enhanced Swift 6 compatibility, and performance improvements of up to 80%. This version introduces the Auto DI Optimizer and significantly improves actor hop performance.

## What's New in 3.0.0

### 🚀 Major Features

- **Auto DI Optimizer**: Automatic dependency graph generation and performance optimization
- **Swift 6 Full Support**: Complete compatibility with strict concurrency
- **Actor Hop Optimization**: Up to 81% performance improvement in MainActor scenarios
- **Enhanced TypeID System**: O(1) resolution with lock-free reads
- **Module Factory System**: Advanced dependency organization

### 📊 Performance Improvements

| Scenario | 2.x Performance | 3.0.0 Performance | Improvement |
|----------|-----------------|-------------------|-------------|
| Single dependency resolution | 0.8ms | 0.2ms | **75%** |
| Complex dependency graph | 15.6ms | 3.1ms | **80%** |
| MainActor UI updates | 3.1ms | 0.6ms | **81%** |
| Multi-threaded resolution | Lock contention | Lock-free | **300%** |

## Breaking Changes

### 1. Enhanced Property Wrappers

**Before (2.x):**
```swift
@Inject var userService: UserService?
@RequiredInject var databaseService: DatabaseService
```

**After (3.0.0):**
```swift
@Inject var userService: UserService?           // No change
@SafeInject var databaseService: DatabaseService // Enhanced error handling
```

**Migration Required:**
- Replace `@RequiredInject` with `@SafeInject`
- Update error handling patterns

### 2. Auto Optimization by Default

**Before (2.x):**
```swift
// Manual optimization required
UnifiedDI.enableOptimization()
```

**After (3.0.0):**
```swift
// Automatic optimization - no action needed
// Everything is optimized automatically
```

**Migration Required:**
- Remove manual `enableOptimization()` calls
- Auto optimization is now enabled by default

### 3. Module System Enhancement

**Before (2.x):**
```swift
// Simple registration
UnifiedDI.register(UserService.self) { UserServiceImpl() }
```

**After (3.0.0):**
```swift
// Enhanced module system
let module = Module(UserService.self) {
    UserServiceImpl()
}
await module.register()
```

**Migration Required:**
- Consider migrating to module system for better organization
- Old registration style still works but modules are recommended

## Step-by-Step Migration

### Step 1: Update Package Dependencies

Update your Package.swift to use WeaveDI 3.0.0:

```swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.0.0")
]
```

### Step 2: Property Wrapper Migration

**Find and replace @RequiredInject:**

```swift
// Before (2.x):
class CriticalService {
    @RequiredInject var database: DatabaseService

    func performOperation() {
        database.execute() // Direct access
    }
}

// After (3.0.0):
class CriticalService {
    @SafeInject var database: DatabaseService

    func performOperation() throws {
        let db = try database.getValue() // Error handling required
        db.execute()
    }
}
```

### Step 3: Leverage Auto Optimization

**Before (2.x):**
```swift
// Manual optimization setup
await WeaveDI.Container.bootstrap { container in
    container.register(UserService.self) { UserServiceImpl() }
    container.register(OrderService.self) { OrderServiceImpl() }
}

// Manual optimization enable
UnifiedDI.enableOptimization()
```

**After (3.0.0):**
```swift
// Auto optimization - no manual setup needed
await WeaveDI.Container.bootstrap { container in
    container.register(UserService.self) { UserServiceImpl() }
    container.register(OrderService.self) { OrderServiceImpl() }
}

// Automatic optimization is enabled by default
// View optimization statistics:
print("Auto-optimized types: \(UnifiedDI.optimizedTypes)")
print("Performance stats: \(UnifiedDI.stats)")
```

### Step 4: Migrate to Module System (Optional but Recommended)

**Enhanced organization with modules:**

```swift
// Create organized modules
struct UserModule: ModuleFactory {
    var registerModule = RegisterModule()
    var definitions: [@Sendable () -> Module] = []

    mutating func setup() {
        definitions.append {
            registerModule.makeModule(UserService.self) {
                UserServiceImpl()
            }
        }

        definitions.append {
            registerModule.makeUseCaseWithRepository(
                UserUseCase.self,
                repositoryProtocol: UserRepository.self,
                repositoryFallback: DefaultUserRepository(),
                factory: { repository in
                    UserUseCaseImpl(repository: repository)
                }
            )()
        }
    }

    func makeAllModules() -> [Module] {
        definitions.map { $0() }
    }
}

// Use module factory manager
let manager = ModuleFactoryManager(
    repositoryFactory: RepositoryModuleFactory(),
    useCaseFactory: UseCaseModuleFactory(),
    scopeFactory: ScopeModuleFactory()
)

await manager.registerAll()
```

### Step 5: Swift 6 Compatibility Updates

**Ensure Sendable compliance:**

```swift
// Before (2.x):
class UserService {
    var cache: [String: User] = [:]

    func getUser(id: String) -> User? {
        return cache[id]
    }
}

// After (3.0.0) - Swift 6 compatible:
actor UserService: Sendable {
    private var cache: [String: User] = [:]

    func getUser(id: String) -> User? {
        return cache[id]
    }

    func setUser(_ user: User) {
        cache[user.id] = user
    }
}
```

## New Features to Adopt

### 1. Auto DI Optimizer Monitoring

```swift
// Monitor auto-optimization in real time
print("🔄 Dependency graph: \(UnifiedDI.autoGraph)")
print("⚡ Optimized types: \(UnifiedDI.optimizedTypes)")
print("📊 Usage statistics: \(UnifiedDI.stats)")
print("🎯 Actor optimization suggestions: \(UnifiedDI.actorOptimizations)")
print("🔒 Type safety issues: \(UnifiedDI.typeSafetyIssues)")

// Configure logging levels
UnifiedDI.setLogLevel(.optimization) // See only optimization logs
UnifiedDI.setLogLevel(.errors)       // See only errors
UnifiedDI.setLogLevel(.off)          // Turn off for production
```

### 2. Enhanced Error Handling

```swift
// Comprehensive error handling with SafeInject
class DataManager {
    @SafeInject var database: DatabaseService
    @SafeInject var networkService: NetworkService

    func synchronizeData() async throws {
        // SafeInject provides detailed error information
        do {
            let db = try database.getValue()
            let network = try networkService.getValue()

            let remoteData = try await network.fetchLatestData()
            try await db.save(remoteData)

        } catch SafeInjectError.notRegistered(let type) {
            throw DataError.serviceUnavailable("Required service \(type) not registered")
        } catch SafeInjectError.resolutionFailed(let type, let reason) {
            throw DataError.resolutionFailed("Failed to resolve \(type): \(reason)")
        }
    }
}
```

### 3. Advanced Module Patterns

```swift
// Environment-specific module configuration
struct EnvironmentModuleFactory {
    let environment: Environment

    func createNetworkModule() -> Module {
        switch environment {
        case .development:
            return Module(NetworkService.self) {
                MockNetworkService(delay: 0.1)
            }
        case .staging:
            return Module(NetworkService.self) {
                NetworkService(baseURL: "https://staging-api.example.com")
            }
        case .production:
            return Module(NetworkService.self) {
                NetworkService(
                    baseURL: "https://api.example.com",
                    certificatePinner: SSLCertificatePinner()
                )
            }
        }
    }
}
```

### 4. Actor Hop Optimization

```swift
// WeaveDI 3.0.0 automatically optimizes actor hops
@MainActor
class UIController {
    @Inject var dataService: DataService? // Automatically optimized for MainActor access

    func updateUI() async {
        // This resolution is automatically optimized to minimize actor hops
        guard let service = dataService else { return }

        let data = await service.fetchData()
        // UI updates happen on MainActor without unnecessary hops
        updateView(with: data)
    }
}

// Monitor actor hop optimization
print("🎯 Actor hop stats: \(UnifiedDI.actorHopStats)")
```

## Performance Optimization Guide

### 1. Leverage Automatic Optimization

```swift
// WeaveDI 3.0.0 automatically optimizes frequently used dependencies
// No manual intervention needed, but you can monitor:

func monitorOptimization() {
    let stats = UnifiedDI.asyncPerformanceStats
    print("Average resolution time: \(stats.averageTime)ms")
    print("Optimized dependencies: \(stats.optimizedCount)")
    print("Cache hit ratio: \(stats.cacheHitRatio)%")
}
```

### 2. Module-Based Architecture

```swift
// Organize dependencies by modules for better performance
await WeaveDI.Container.bootstrap { container in
    // Core infrastructure first
    let infrastructureModules = InfrastructureModuleFactory().makeAllModules()
    for module in infrastructureModules {
        await container.register(module)
    }

    // Business logic second
    let businessModules = BusinessModuleFactory().makeAllModules()
    for module in businessModules {
        await container.register(module)
    }

    // UI components last
    let uiModules = UIModuleFactory().makeAllModules()
    for module in uiModules {
        await container.register(module)
    }
}
```

## Testing Improvements

### Enhanced Test Support

```swift
class UserServiceTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()

        // 3.0.0 provides better test isolation
        await UnifiedDI.releaseAll()

        // Reset optimization statistics for clean tests
        UnifiedDI.resetStats()

        await WeaveDI.Container.bootstrap { container in
            container.register(UserService.self) { MockUserService() }
        }
    }

    func testServiceOptimization() async {
        // Test that services are properly optimized
        let service = UnifiedDI.resolve(UserService.self)
        XCTAssertNotNil(service)

        // Check optimization status
        XCTAssertTrue(UnifiedDI.isOptimized(UserService.self))
    }
}
```

## Troubleshooting

### Common Migration Issues

#### Issue 1: SafeInject Compilation Errors

**Error:**
```
Value of type 'SafeInjectResult<DatabaseService>' has no member 'performOperation'
```

**Solution:**
```swift
// Before (incorrect):
@SafeInject var database: DatabaseService
database.performOperation() // Error!

// After (correct):
@SafeInject var database: DatabaseService
let db = try database.getValue()
db.performOperation()
```

#### Issue 2: Actor Isolation Warnings

**Error:**
```
Call to actor-isolated method 'resolve' in a synchronous nonisolated context
```

**Solution:**
```swift
// Use async resolution in actor contexts
@MainActor
func updateData() async {
    let service = await UnifiedDI.resolveAsync(DataService.self)
    // Process data...
}
```

#### Issue 3: Module Registration Conflicts

**Error:**
```
Multiple registrations for the same type
```

**Solution:**
```swift
// Use conditional registration
if !UnifiedDI.isRegistered(NetworkService.self) {
    let service = UnifiedDI.register(NetworkService.self) {
        NetworkServiceImpl()
    }
}

// Or use module factory to avoid conflicts
let factory = ModuleFactoryManager(...)
await factory.registerAll() // Handles conflicts automatically
```

## Migration Checklist

- [ ] Update to WeaveDI 3.0.0 in Package.swift
- [ ] Replace `@RequiredInject` with `@SafeInject`
- [ ] Update error handling for SafeInject
- [ ] Remove manual `enableOptimization()` calls
- [ ] Test Swift 6 compatibility (Sendable conformance)
- [ ] Consider migrating to module system
- [ ] Update test setup for better isolation
- [ ] Monitor auto-optimization statistics
- [ ] Validate actor hop performance improvements
- [ ] Update documentation and team knowledge

## Benefits After Migration

After completing migration to WeaveDI 3.0.0, you'll gain:

- **Automatic Performance Optimization**: No manual tuning required
- **Better Error Diagnostics**: Detailed error messages and suggestions
- **Swift 6 Future-Proofing**: Ready for strict concurrency
- **Improved Developer Experience**: Auto-completion and better debugging
- **Enhanced Testing**: Better isolation and test utilities
- **Production Monitoring**: Real-time performance insights

## Support

- **Issues**: [GitHub Issues](https://github.com/Roy-wonji/WeaveDI/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Roy-wonji/WeaveDI/discussions)
- **Documentation**: [Complete API Reference](/api/coreApis)

WeaveDI 3.0.0 represents the future of dependency injection in Swift, with automatic optimization and enhanced developer experience.