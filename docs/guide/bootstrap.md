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

## When to Use

- Call only once at AppDelegate/SceneDelegate/app entry point
- In SwiftUI App structure, use at `@main` entry point or during initial View-Model configuration

## Synchronous Bootstrap

```swift
import WeaveDI

await WeaveDI.Container.bootstrap { container in
    container.register(Logger.self) { ConsoleLogger() }
    container.register(Networking.self) { DefaultNetworking() }
    container.register(UserRepository.self) { UserRepositoryImpl() }
}

// After this, you can use WeaveDI.Container.shared.resolve(...) anywhere
let logger = WeaveDI.Container.shared.resolve(Logger.self)
```

## Asynchronous Bootstrap

When asynchronous initialization is required (e.g., remote configuration, database connection), use `bootstrapAsync`.

```swift
let ok = await WeaveDI.Container.bootstrapAsync { container in
    // Example: Load remote configuration
    let config = try await RemoteConfig.load()
    container.register(AppConfig.self) { config }

    // Example: Initialize async resources
    let db = try await Database.open()
    container.register(Database.self) { db }
}

guard ok else { /* Handle failure (splash/notification/retry) */ return }
```

> Note: `bootstrapAsync` can be configured to call `fatalError` in DEBUG builds and return `false` in RELEASE builds on failure. The current implementation provides Bool return with internal logging.

## Mixed Bootstrap (sync + async)

Useful when you want to prepare core dependencies immediately and additional dependencies asynchronously.

```swift
@MainActor
await WeaveDI.Container.bootstrapMixed(
    sync: { container in
        container.register(Logger.self) { ConsoleLogger() }
        container.register(Networking.self) { DefaultNetworking() }
    },
    async: { container in
        // Extended async dependencies
        let analytics = await AnalyticsClient.make()
        container.register(AnalyticsClient.self) { analytics }
    }
)
```

## Bootstrap in Background Task

You can perform asynchronous bootstrap in the background to minimize app startup delay.

```swift
WeaveDI.Container.bootstrapInTask { container in
    let featureFlags = try await FeatureFlags.fetch()
    container.register(FeatureFlags.self) { featureFlags }
}
```

## Conditional Bootstrap

Use this when you want to skip if already initialized.

```swift
let didInit = await WeaveDI.Container.bootstrapIfNeeded { container in
    container.register(Logger.self) { ConsoleLogger() }
}

if !didInit {
    // Already prepared
}
```

An asynchronous version is also provided.

```swift
let didInit = await WeaveDI.Container.bootstrapAsyncIfNeeded { container in
    let remote = try await RemoteConfig.load()
    container.register(RemoteConfig.self) { remote }
}
```

## Access Guarantee (Assert)

Use this to enforce that DI is not accessed before bootstrap.

```swift
WeaveDI.Container.ensureBootstrapped() // Fails precondition if not bootstrapped
```

## Testing Guide

If you want a clean container for each test, use the reset API.

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

- Bootstrap in one place only: Only once at app entry point (or test setUp)
- Handle failure branches: For async bootstrap, prepare paths that consider user experience on failure
- Recommend mixed pattern: Synchronous registration for essential dependencies, asynchronous for additional dependencies
- Access guarantee: Use `ensureBootstrapped()` during development to catch mistakes early
- Test isolation: Call `resetForTesting()` before each test starts