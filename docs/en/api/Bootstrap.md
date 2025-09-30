---
title: Bootstrap
lang: en-US
---

# Bootstrap Guide

How to safely and consistently prepare dependencies at app startup. WeaveDI provides various bootstrap patterns to flexibly configure synchronous/asynchronous initialization, test isolation, conditional initialization, and more.

## Overview

- Goal: Clearly initialize necessary dependencies in one place at app startup
- Features:
  - Synchronous/asynchronous/mixed bootstrap support
  - Atomic replacement of global container (thread-safe)
  - Test isolation/reset API provided

## When to Use

- Called only once in AppDelegate/SceneDelegate/app entry points
- In SwiftUI App structure, at `@main` entry point or initial View-Model configuration

## Synchronous Bootstrap

```swift
import WeaveDI

await DIContainer.bootstrap { container in
    container.register(Logger.self) { ConsoleLogger() }
    container.register(Networking.self) { DefaultNetworking() }
    container.register(UserRepository.self) { UserRepositoryImpl() }
}

// Afterwards, DIContainer.shared.resolve(...) can be used anywhere
let logger = DIContainer.shared.resolve(Logger.self)
```

## Asynchronous Bootstrap

When asynchronous initialization is needed (e.g., remote configuration, database connections), use `bootstrapAsync`.

```swift
let ok = await DIContainer.bootstrapAsync { container in
    // Example: Load remote configuration
    let config = try await RemoteConfig.load()
    container.register(AppConfig.self) { config }

    // Example: Initialize async resources
    let db = try await Database.open()
    container.register(Database.self) { db }
}

guard ok else { /* Handle failure (splash/notification/retry) */ return }
```

> Note: `bootstrapAsync` can be configured to `fatalError` on failure in DEBUG builds and return `false` in RELEASE builds. Current implementation provides Bool return with internal logging.

## Mixed Bootstrap (sync + async)

Useful when you want core dependencies immediately and supplementary dependencies asynchronously.

```swift
@MainActor
await DIContainer.bootstrapMixed(
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

When you want to minimize app startup delay, you can perform asynchronous bootstrap in the background.

```swift
DIContainer.bootstrapInTask { container in
    let featureFlags = try await FeatureFlags.fetch()
    container.register(FeatureFlags.self) { featureFlags }
}
```

## Conditional Bootstrap

Use when you want to skip if already initialized.

```swift
let didInit = await DIContainer.bootstrapIfNeeded { container in
    container.register(Logger.self) { ConsoleLogger() }
}

if !didInit {
    // Already prepared
}
```

Asynchronous version is also provided.

```swift
let didInit = await DIContainer.bootstrapAsyncIfNeeded { container in
    let config = try await RemoteConfig.load()
    container.register(AppConfig.self) { config }
}
```

## Reset for Testing

In test environments, you can reset and reconfigure the container.

```swift
// In test setup
await DIContainer.resetForTesting()

await DIContainer.bootstrap { container in
    // Register test doubles
    container.register(Logger.self) { MockLogger() }
    container.register(UserRepository.self) { TestUserRepository() }
}
```

## Production Example

```swift
@main
struct MyApp: App {
    @State private var isInitialized = false

    var body: some Scene {
        WindowGroup {
            if isInitialized {
                ContentView()
            } else {
                SplashView()
                    .task {
                        await initializeDependencies()
                        isInitialized = true
                    }
            }
        }
    }

    private func initializeDependencies() async {
        await DIContainer.bootstrapMixed(
            sync: { container in
                // Core dependencies
                container.register(Logger.self) { ProductionLogger() }
                container.register(Networking.self) { URLSessionNetworking() }
            },
            async: { container in
                // Async dependencies
                let config = try? await RemoteConfig.load()
                container.register(AppConfig.self) { config ?? AppConfig.default }
            }
        )
    }
}
```

## Best Practices

1. **Single bootstrap**: Call bootstrap only once at app startup
2. **Error handling**: Always handle bootstrap failures gracefully
3. **Test isolation**: Use `resetForTesting()` in test setup
4. **Performance**: Use mixed bootstrap for optimal startup time
5. **Conditional**: Use `bootstrapIfNeeded` for hot reloading scenarios

---

📖 **Documentation**: [한국어](../ko.lproj/Bootstrap) | [English](Bootstrap)
