# WeaveDI 2.0.0 Migration Guide

Complete guide for upgrading from WeaveDI 1.x to 2.0.0

## Overview

WeaveDI 2.0.0 is a major update that fully embraces Swift Concurrency and introduces Actor Hop optimization. This guide provides safe and efficient migration methods for existing 1.x code to the new version.

## Key Changes at a Glance

### ✅ New Features
- **Unified DI API**: Three levels of APIs: `UnifiedDI`, `DI`, `DIAsync`
- **Bootstrap System**: Safe app initialization with `WeaveDI.Container.bootstrap`
- **Actor Hop Optimization**: Performance optimization fully compatible with Swift Concurrency
- **Enhanced Property Wrappers**: Support for `@Inject`, `@RequiredInject`, `@Factory`
- **AppWeaveDI.Container**: Unified container for app-level dependency management
- **ModuleFactory System**: Repository, UseCase, Scope factory patterns

### 🔄 Changed APIs
- `WeaveDI.Container.live.register` → `UnifiedDI.register` or `DI.register`
- `RegisterAndReturn.register` → `UnifiedDI.register` or KeyPath-based registration
- Property Wrapper unification: `@Inject` supports both optional and required dependencies
- Bootstrap system: Must call `bootstrap` at app startup

## Quick Cheat Sheet (Before → After)

| 1.x (Before) | 2.0.0 (After) |
| --- | --- |
| `WeaveDI.Container.live.register(T.self) { ... }` | `DI.register(T.self) { ... }` |
| `WeaveDI.Container.live.resolve(T.self)` | `DI.resolve(T.self)` or `await DIAsync.resolve(T.self)` |
| `RegisterAndReturn.register(\.key) { ... }` | `DI.register(\.key) { ... }` or `await DIAsync.register(\.key) { ... }` |
| Direct instance cache management | Use `DI.register(T.self) { ... }` |
| GCD-based batch registration | `await DIAsync.registerMany { ... }` (TaskGroup parallel) |
| Complex locks + temporary bootstrap | Fixed to single path with `WeaveDI.Container.bootstrap(…)` |

## Bootstrap - Why Needed and How to Use

This is for safely initializing all dependencies at once before the app starts using them. Internally, it serializes initialization races through actors and atomically performs live container replacement.

```swift
// Synchronous initial registration
await WeaveDI.Container.bootstrap { c in
  c.register(Logger.self) { ConsoleLogger() }
  c.register(Config.self) { AppConfig() }
}

// Asynchronous initial registration (e.g., DB open, remote config load)
await WeaveDI.Container.bootstrapAsync { c in
  let db = await Database.open()
  c.register(Database.self, instance: db)
}
```

If `resolve`/`@Inject` is called before bootstrap, crashes or failures may occur. Always call bootstrap at the app's entry point.

## KeyPath-based Registration/Resolution

Provides both readability and type safety.

```swift
extension WeaveDI.Container {
  var bookListInterface: BookListInterface? { resolve(BookListInterface.self) }
}

// Sync: register and return simultaneously upon creation
let repo = DI.register(\.bookListInterface) { BookListRepositoryImpl() }

// Async: register and return simultaneously upon creation
let repo2 = await DIAsync.register(\.bookListInterface) { await BookListRepositoryImpl.make() }

// Don't recreate if already exists (idempotent)
let repo3 = await DIAsync.getOrCreate(\.bookListInterface) { await BookListRepositoryImpl.make() }
```

## Property Wrapper Changes

- `@Inject(\.keyPath)` supports both optional and required dependencies.
  - If variable type is Optional, returns `nil` when unregistered
  - If variable type is Non-Optional, `fatalError` with clear message when unregistered
- For stricter required dependencies, use `@RequiredDependency(\.keyPath)`.

If you were using wrappers like `@ContainerRegister`, we recommend replacing them with `@Inject` or `@RequiredDependency`.

## Module and Container

- `Module` has a lighter structure, with internal registration closures defined as `@Sendable`.
- `Container` provides the following build APIs:
  - `await build()` — Non-throwing default build
  - `await buildWithMetrics()` — Collect performance time/throughput metrics
  - `await buildWithResults()` — Detailed success/failure reports
  - `try await buildThrowing()` — Extension point for throwing registration

## DI vs DIAsync - When to Use What

- Use `DI` for synchronous factories, and `DIAsync` when you need asynchronous factories/parallel batch registration.

```swift
// DI (sync)
DI.register(Service.self) { ServiceImpl() }
let s = DI.resolve(Service.self)

// DIAsync (async)
await DIAsync.register(Service.self) { await ServiceImpl.make() }
let s2 = await DIAsync.resolve(Service.self)

// Check registration status
let ok = DI.isRegistered(Service.self)
let ok2 = await DIAsync.isRegistered(Service.self)
```

## Using UnifiedDI as Single Entry Point

If your team wants to unify with one API instead of `DI`/`DIAsync`, we recommend `UnifiedDI`. Internally, it uses `WeaveDI.Container.live` to provide type-safe registration/resolution.

Cheat sheet (Before → UnifiedDI)

- `DI.register(T.self) { ... }` → `UnifiedDI.register(T.self) { ... }`
- `DI.resolve(T.self)` → `UnifiedDI.resolve(T.self)`
- `DI.requireResolve(T.self)` → `UnifiedDI.requireResolve(T.self)`
- `DI.resolve(T.self, default: …)` → `UnifiedDI.resolve(T.self, default: …)`
- `DI.registerMany { … }` → `UnifiedDI.registerMany { … }`
- `DIAsync.registerMany { … }` → If async initialization is needed, create instances inside `WeaveDI.Container.bootstrapAsync` and register with `container.register(_:instance:)`, or register with `UnifiedDI.register`/`WeaveDI.Container.live.register` after creation.

Example

```swift
// Registration
UnifiedDI.register(ServiceProtocol.self) { ServiceImpl() }

// KeyPath registration
let repo = UnifiedDI.register(\.userRepository) { UserRepositoryImpl() }

// Resolution
let s1 = UnifiedDI.resolve(ServiceProtocol.self)
let s2 = UnifiedDI.requireResolve(ServiceProtocol.self)
let logger = UnifiedDI.resolve(LoggerProtocol.self, default: ConsoleLogger())

// Batch registration
UnifiedDI.registerMany {
  UnifiedRegistration(NetworkService.self) { DefaultNetworkService() }
  UnifiedRegistration(UserRepository.self) { UserRepositoryImpl() }
}
```

## Concurrency Considerations (Swift 6)

- Don't capture non-Sendable state inside `@Sendable` closures. Consider value snapshots/`Sendable` adoption when necessary.
- `Container.build` creates snapshots before task creation to reduce actor hop costs.

## Major Breaking Changes and Alternatives

1) Manual registration/resolution entry point changes

```swift
// Before (1.x)
WeaveDI.Container.live.register(ServiceProtocol.self) { Service() }
let s = WeaveDI.Container.live.resolve(ServiceProtocol.self)

// After (2.0.0)
DI.register(ServiceProtocol.self) { Service() }
let s = DI.resolve(ServiceProtocol.self)
```

2) KeyPath-based registration method cleanup

```swift
// Before (1.x)
RegisterAndReturn.register(\.userRepository) { UserRepository() }

// After (2.0.0)
DI.register(\.userRepository) { UserRepository() }
// Or when async initialization is needed
await DIAsync.register(\.userRepository) { await UserRepository.make() }
```

3) Property wrapper migration

```swift
// Before (e.g., using @ContainerRegister)
final class UserService {
  @ContainerRegister(\.userRepository)
  private var repo: UserRepositoryProtocol
}

// After (2.0.0)
final class UserService {
  // Non-Optional: clear crash when unregistered for quick discovery
  @Inject(\.userRepository) var repo: UserRepositoryProtocol

  // If declared as Optional, returns nil when unregistered (suitable for optional dependencies)
  // @Inject(\.userRepository) var repo: UserRepositoryProtocol?
}

// Stricter required dependencies
final class AuthService {
  @RequiredDependency(\.authRepository) var authRepo: AuthRepositoryProtocol
}
```

4) Batch registration — GCD → Concurrency

```swift
await DIAsync.registerMany {
  DIAsyncRegistration(ServiceA.self) { await ServiceA.make() }
  DIAsyncRegistration(ServiceB.self) { ServiceB() }
  DIAsyncRegistration(\.userRepository) { await UserRepository.make() }
}
```

## Step-by-Step Migration Guide

### Step 1: Choose and Unify API

Choose one of the following based on your team's preference:

#### Option A: UnifiedDI (Latest and Recommended)
```swift
// Unify all dependency work with UnifiedDI
UnifiedDI.register(ServiceProtocol.self) { ServiceImpl() }
let service = UnifiedDI.resolve(ServiceProtocol.self)
```

#### Option B: Separate DI/DIAsync Usage
```swift
// DI for synchronous work
DI.register(ServiceProtocol.self) { ServiceImpl() }

// DIAsync for asynchronous work
await DIAsync.register(ServiceProtocol.self) { await ServiceImpl.make() }
```

### Step 2: Update Registration Methods

```swift
// Before
          WeaveDI.Container.live.register(ServiceProtocol.self) { ServiceImpl() }
RegisterAndReturn.register(\.userRepository) { UserRepository() }

// After
UnifiedDI.register(ServiceProtocol.self) { ServiceImpl() }
UnifiedDI.register(\.userRepository) { UserRepository() }
```

### Step 3: Introduce Bootstrap System

```swift
// Must call at app entry point
@main
struct MyApp: App {
    init() {
        Task {
            await WeaveDI.Container.bootstrap { container in
                // Register all dependencies
                container.register(LoggerProtocol.self) { Logger() }
                container.register(NetworkProtocol.self) { NetworkService() }
            }
        }
    }
}
```

### Step 4: Update Property Wrappers

```swift
// Before
@ContainerRegister(\.userRepository) var repo: UserRepositoryProtocol

// After - Option 1: Optional injection (safe)
@Inject(\.userRepository) var repo: UserRepositoryProtocol?

// After - Option 2: Required injection (quick failure discovery)
@RequiredInject(\.userRepository) var repo: UserRepositoryProtocol
```

### Step 5: Update Test Code

```swift
class MyTests: XCTestCase {
    override func setUp() async throws {
        await super.setUp()

        // Reset test container
        await WeaveDI.Container.resetForTesting()

        // Register test dependencies
        await WeaveDI.Container.bootstrap { container in
            container.register(ServiceProtocol.self) { MockService() }
        }
    }

    override func tearDown() async throws {
        UnifiedDI.releaseAll()
        await super.tearDown()
    }
}
```

### Step 6: Utilize Advanced Features (AppWeaveDI.Container)

For large projects, utilize AppWeaveDI.Container:

```swift
// Utilize AppWeaveDI.Container
await AppWeaveDI.Container.shared.registerDefaultDependencies()

// Or custom registration
await AppWeaveDI.Container.shared.registerDependencies { container in
    var repositoryFactory = AppWeaveDI.Container.shared.repositoryFactory
    repositoryFactory.registerDefaultDefinitions()

    await repositoryFactory.makeAllModules().asyncForEach { module in
        await container.register(module)
    }
}
```

## AutoResolver Notes and Options

- In 2.0.0, AutoResolver operates on the main actor to enhance UI/injection safety.
- You can turn off automatic resolution entirely or exclude specific types.

**From 2.1.0, AutoDependencyResolver has been replaced with AutoDIOptimizer:**

```swift
// Control automatic optimization (default: enabled)
UnifiedDI.setAutoOptimization(true)  // Enable
UnifiedDI.setAutoOptimization(false) // Disable

// Automatically collected information is output through LogMacro
// No separate print calls needed - automatic logging during registration/resolution:
// 📊 Auto tracking registration: UserService
// ⚡ Auto optimized: UserService (10 uses)
// 📊 [AutoDI] Current stats: {"UserService": 15}
```

- Automation has become more convenient. All optimizations run automatically just by registering/resolving without additional configuration.

## TCA Integration Code Example (Updated)

```swift
import ComposableArchitecture
import WeaveDI

extension UserUseCase: DependencyKey {
  public static var liveValue: UserUseCaseProtocol = {
    // Resolve if registered, or register default implementation and use
    let repository = ContainerRegister.register(\.userRepository) { DefaultUserRepository() }
    return UserUseCase(repository: repository)
  }()
}

extension DependencyValues {
  var userUseCase: UserUseCaseProtocol {
    get { self[UserUseCase.self] }
    set { self[UserUseCase.self] = newValue }
  }
}
```

---

If you need specific code snippet transformations, please share the snippets. We'll convert them accurately to 2.0.0 style.
