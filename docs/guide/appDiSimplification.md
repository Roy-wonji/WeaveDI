# AppDI Simplification Guide

## Overview

WeaveDI 3.2.0 introduces automatic dependency registration, eliminating the need for manual `registerRepositories()` and `registerUseCases()` calls. The framework now automatically invokes these methods through the improved `registerAllDependencies()` system.

## What Changed

### Before (Manual Registration)

```swift
// ❌ Old approach - manual calls required
@main
struct MyApp: App {
    init() {
        Task {
            await WeaveDI.Container.bootstrap { container in
                // Manual registration
                await WeaveDI.Container.registerRepositories()
                await WeaveDI.Container.registerUseCases()
            }
        }
    }
}
```

### After (Automatic Registration)

```swift
// ✅ New approach - automatic registration
@main
struct MyApp: App {
    init() {
        WeaveDI.Container.bootstrapInTask { @DIContainerActor _ in
            await AppDIManager.shared.registerDefaultDependencies()
        }
    }
}
```

## How It Works

The `AppDIManager.shared.registerDefaultDependencies()` method automatically calls both `registerRepositories()` and `registerUseCases()`:

```swift
// AppDIManager automatically registers all dependencies
public actor AppDIManager {
    public static let shared = AppDIManager()

    public func registerDefaultDependencies() async {
        // Automatically calls these methods
        await WeaveDI.Container.registerRepositories()
        await WeaveDI.Container.registerUseCases()

        #if DEBUG
        print("✅ AppDIManager.registerDefaultDependencies() completed")
        #endif
    }
}
```

## Module-Based Registration Pattern

### Define Your Modules

```swift
extension WeaveDI.Container {
    private static let helper = RegisterModule()

    /// 📦 Repository Registration
    static func registerRepositories() async {
        let repositories = [
            helper.exchangeRepositoryModule(),
            helper.userRepositoryModule(),
            // Add more repository modules...
        ]

        await repositories.asyncForEach { module in
            await module.register()
        }
    }

    /// 🔧 UseCase Registration
    static func registerUseCases() async {
        let useCases = [
            helper.exchangeUseCaseModule(),
            helper.userUseCaseModule(),
            // Add more useCase modules...
        ]

        await useCases.asyncForEach { module in
            await module.register()
        }
    }
}
```

### Create Module Extensions

```swift
extension RegisterModule {
    var exchangeUseCaseModule: @Sendable () -> Module {
        makeUseCaseWithRepository(
            ExchangeRateInterface.self,
            repositoryProtocol: ExchangeRateInterface.self,
            repositoryFallback: MockExchangeRepositoryImpl(),
            factory: { repo in
                ExchangeUseCaseImpl(repository: repo)
            }
        )
    }

    var exchangeRepositoryModule: @Sendable () -> Module {
        makeDependency(ExchangeRateInterface.self) {
            ExchangeRepositoryImpl()
        }
    }
}
```

## Benefits

### 1. Less Boilerplate

- **Before**: Manual registration calls in every app
- **After**: Framework handles registration automatically

### 2. Cleaner App Initialization

```swift
// Clean and simple app initialization
@main
struct CurrencyConverterApp: App {
    init() {
        WeaveDI.Container.bootstrapInTask { @DIContainerActor _ in
            await AppDIManager.shared.registerDefaultDependencies()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 3. Better Organization

Organize dependencies by feature using module extensions:

```swift
// Authentication Module
extension RegisterModule {
    var authRepositoryModule: @Sendable () -> Module { ... }
    var authUseCaseModule: @Sendable () -> Module { ... }
}

// User Module
extension RegisterModule {
    var userRepositoryModule: @Sendable () -> Module { ... }
    var userUseCaseModule: @Sendable () -> Module { ... }
}

// Currency Module
extension RegisterModule {
    var exchangeRepositoryModule: @Sendable () -> Module { ... }
    var exchangeUseCaseModule: @Sendable () -> Module { ... }
}
```

## Migration Guide

### Step 1: Remove Manual Calls

Remove explicit `registerRepositories()` and `registerUseCases()` calls from your app initialization:

```swift
// ❌ Remove these lines
await WeaveDI.Container.registerRepositories()
await WeaveDI.Container.registerUseCases()
```

### Step 2: Verify Extensions Exist

Ensure your `WeaveDI.Container` extensions override the default implementations:

```swift
extension WeaveDI.Container {
    static func registerRepositories() async {
        // Your repository registration logic
    }

    static func registerUseCases() async {
        // Your useCase registration logic
    }
}
```

### Step 3: Test Your App

Use `bootstrapInTask` with `AppDIManager` to register dependencies:

```swift
@main
struct MyApp: App {
    init() {
        WeaveDI.Container.bootstrapInTask { @DIContainerActor _ in
            await AppDIManager.shared.registerDefaultDependencies()
        }
    }
}
```

## Advanced: asyncForEach

Use `asyncForEach` for parallel module registration:

```swift
static func registerRepositories() async {
    let repositories = [
        helper.exchangeRepositoryModule(),
        helper.userRepositoryModule(),
        helper.authRepositoryModule(),
    ]

    // Registers all modules in parallel
    await repositories.asyncForEach { module in
        await module.register()
    }
}
```

## Real-World Example

```swift
// AutoDIRegistry.swift
import WeaveDI

extension WeaveDI.Container {
    private static let helper = RegisterModule()

    static func registerRepositories() async {
        let repositories = [
            helper.exchangeRepositoryModule(),
        ]

        await repositories.asyncForEach { module in
            await module.register()
        }
    }

    static func registerUseCases() async {
        let useCases = [
            helper.exchangeUseCaseModule(),
        ]

        await useCases.asyncForEach { module in
            await module.register()
        }
    }
}

extension RegisterModule {
    var exchangeUseCaseModule: @Sendable () -> Module {
        makeUseCaseWithRepository(
            ExchangeRateInterface.self,
            repositoryProtocol: ExchangeRateInterface.self,
            repositoryFallback: MockExchangeRepositoryImpl(),
            factory: { repo in
                ExchangeUseCaseImpl(repository: repo)
            }
        )
    }

    var exchangeRepositoryModule: @Sendable () -> Module {
        makeDependency(ExchangeRateInterface.self) {
            ExchangeRepositoryImpl()
        }
    }
}

// App.swift
@main
struct CurrencyConverterApp: App {
    init() {
        WeaveDI.Container.bootstrapInTask { @DIContainerActor _ in
            await AppDIManager.shared.registerDefaultDependencies()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## Best Practices

### 1. Organize by Feature

Group related dependencies into feature-based modules:

```swift
// Feature: Authentication
extension RegisterModule {
    var authModule: @Sendable () -> [Module] {
        [
            authRepositoryModule(),
            authUseCaseModule(),
        ]
    }
}
```

### 2. Use Descriptive Names

```swift
// ✅ Good - clear and descriptive
var exchangeRateRepositoryModule: @Sendable () -> Module { ... }
var userAuthenticationUseCaseModule: @Sendable () -> Module { ... }

// ❌ Avoid - unclear names
var repo1Module: @Sendable () -> Module { ... }
var module2: @Sendable () -> Module { ... }
```

### 3. Document Dependencies

```swift
extension RegisterModule {
    /// Exchange rate repository module
    /// Provides currency exchange rate data access
    var exchangeRepositoryModule: @Sendable () -> Module {
        makeDependency(ExchangeRateInterface.self) {
            ExchangeRepositoryImpl()
        }
    }
}
```

## Troubleshooting

### Dependencies Not Registered

If dependencies aren't being registered automatically:

1. Verify you have `registerRepositories()` and `registerUseCases()` extensions
2. Check that `bootstrap` is being called
3. Ensure your extensions are in the same target as your app

### Debug Logging

Enable debug logging to see registration progress:

```swift
#if DEBUG
extension WeaveDI.Container {
    static func registerRepositories() async {
        print("📦 Registering repositories...")
        // ... registration logic
        print("✅ Repositories registered")
    }
}
#endif
```

## See Also

- [@Injected](../api/injected.md) - Modern dependency injection
- [Module System](./moduleSystem.md) - Module-based organization
- [Testing Guide](/tutorial/testing) - Testing with automatic registration