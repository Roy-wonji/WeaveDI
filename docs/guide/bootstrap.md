# Bootstrap Guide

Comprehensive guide to safely and efficiently initializing your dependency injection container at app startup. WeaveDI provides powerful bootstrap patterns supporting Swift 5/6 concurrency, test isolation, conditional initialization, and production-ready configuration patterns.

## Overview

### Core Goals
- **🎧 Centralized Setup**: Initialize all dependencies in one place at app startup
- **🔒 Type Safety**: Compile-time dependency verification
- **⚡ Performance**: Optimized container initialization
- **🧪 Testing**: Isolated test environments

### Key Features
- **🔄 Concurrency Support**: Full async/await and Swift 6 strict concurrency
- **🎯 Atomic Operations**: Thread-safe container replacement
- **🔍 Environment Awareness**: Different setups for dev/staging/production
- **🧬 Test Isolation**: Clean slate for each test

### Swift Version Compatibility

| Feature | Swift 5.8+ | Swift 5.9+ | Swift 6.0+ |
|---------|------------|------------|------------|
| Basic Bootstrap | ✅ | ✅ | ✅ |
| Async Bootstrap | ✅ | ✅ | ✅ |
| Mixed Bootstrap | ✅ | ✅ | ✅ |
| Actor Isolation | ⚠️ | ✅ | ✅ |
| Strict Sendable | ❌ | ⚠️ | ✅ |

## When to Use Bootstrap

### Required Scenarios
- **🚀 App Launch**: Always bootstrap at app startup
- **🧪 Unit Tests**: Bootstrap before each test suite
- **🔄 Integration Tests**: Bootstrap with test-specific configuration
- **🛠️ Environment Changes**: Re-bootstrap when switching environments

### Application Entry Points

#### SwiftUI App (Recommended)
```swift
@main
struct MyApp: App {
    init() {
        WeaveDIConfiguration.applyFromEnvironment()
        Task {
            await bootstrapDependencies()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

#### UIKit App
```swift
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        WeaveDIConfiguration.applyFromEnvironment()
        Task {
            await bootstrapDependencies()
        }
        return true
    }
}
```

### Auto-configure for the current environment

Call `WeaveDIConfiguration.applyFromEnvironment()` before bootstrapping to automatically align optimizer, monitor, and logging flags with your build context.

```swift
enum Bootstrap {
    static func configure() {
        // Reads environment variables injected via scheme, xcconfig, or CI
        WeaveDIConfiguration.applyFromEnvironment()

        Task.detached {
            await bootstrapDependencies()
        }
    }
}

@main
struct MyApp: App {
    init() {
        Bootstrap.configure()
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

Supported environment variables:

| Key | Default | Description |
|-----|---------|-------------|
| `WEAVEDI_ENABLE_OPTIMIZER` | `true` | Enables AutoDI optimizer tracking |
| `WEAVEDI_ENABLE_MONITOR` | `true` | Turns on automatic monitoring |
| `WEAVEDI_VERBOSE_LOGGING` | `false` | Switches internal logging to verbose mode |
| `WEAVEDI_REGISTRY_AUTO_HEALTH` | `true` | Enables UnifiedRegistry auto health-check loop |
| `WEAVEDI_REGISTRY_AUTO_FIX` | `true` | Attempts automatic fixes when health score drops |
| `WEAVEDI_REGISTRY_HEALTH_LOGGING` | `false` | Emits health-check/auto-fix logs |

Inject different values per scheme/CI job to ensure production keeps optimizers enabled while local debugging can turn on verbose logging early in the bootstrap sequence.

## Synchronous Bootstrap

```swift
import WeaveDI

await WeaveDI.Container.bootstrap { container in
    container.register(Logger.self) { ConsoleLogger() }
    container.register(Networking.self) { DefaultNetworking() }
    container.register(UserRepository.self) { UserRepositoryImpl() }
}

// After bootstrap, use WeaveDI.Container.shared.resolve(...) anywhere
let logger = WeaveDI.Container.shared.resolve(Logger.self)
```

## Asynchronous Bootstrap

Use `bootstrapAsync` when async initialization is needed (e.g., remote config, database connection).

```swift
let ok = await WeaveDI.Container.bootstrapAsync { container in
    // Example: Load remote configuration
    let config = try await RemoteConfig.load()
    container.register(AppConfig.self) { config }

    // Example: Initialize async resources
    let db = try await Database.open()
    container.register(Database.self) { db }
}

guard ok else { /* Handle failure (splash/alert/retry) */ return }
```

> Note: `bootstrapAsync` can be configured to `fatalError` in DEBUG builds and return `false` in RELEASE builds on failure. Current implementation provides Bool return with internal logging.

## Mixed Bootstrap (sync + async)

Useful when you want core dependencies immediately and supplementary dependencies asynchronously.

```swift
@MainActor
await WeaveDI.Container.bootstrapMixed(
    sync: { container in
        container.register(Logger.self) { ConsoleLogger() }
        container.register(Networking.self) { DefaultNetworking() }
    },
    async: { container in
        // Async extended dependencies
        let analytics = await AnalyticsClient.make()
        container.register(AnalyticsClient.self) { analytics }
    }
)
```

## Bootstrap in Background Task

When you want to minimize app launch delay, perform async bootstrap in background.

```swift
WeaveDI.Container.bootstrapInTask { container in
    let featureFlags = try await FeatureFlags.fetch()
    container.register(FeatureFlags.self) { featureFlags }
}
```

## Conditional Bootstrap

Use when you want to skip if already initialized.

```swift
let didInit = await WeaveDI.Container.bootstrapIfNeeded { container in
    container.register(Logger.self) { ConsoleLogger() }
}

if !didInit {
    // Already initialized
}
```

Async version is also available:

```swift
let didInit = await WeaveDI.Container.bootstrapAsyncIfNeeded { container in
    let remote = try await RemoteConfig.load()
    container.register(RemoteConfig.self) { remote }
}
```

## Ensure Bootstrapped (Assert)

Use to enforce that bootstrap occurred before DI access.

```swift
WeaveDI.Container.ensureBootstrapped() // Precondition failure if not bootstrapped
```

## Testing Guide

Use reset API when you want a clean container for each test.

```swift
@MainActor
override func setUp() async throws {
    try await super.setUp()
    await WeaveDI.Container.resetForTesting() // Only allowed in DEBUG builds

    // Test-specific registration
    WeaveDI.Container.shared.register(MockService.self) { MockService() }
}
```

## Best Practices

- **Single bootstrap**: Call only once at app entry point (or test setUp)
- **Handle failures**: Prepare user experience path when async bootstrap fails
- **Use mixed pattern**: Register essential dependencies synchronously, supplementary asynchronously
- **Ensure access**: Use `ensureBootstrapped()` in development to catch mistakes early
- **Test isolation**: Call `resetForTesting()` before each test
