---
title: CoreAPIs
lang: en-US
---

# Core APIs

Essential WeaveDI APIs for dependency injection

## Overview

WeaveDI provides a clean, type-safe API for dependency registration and resolution. This guide covers the most important APIs you'll use daily.

## UnifiedDI

The recommended API for most use cases.

### Registration

```swift
// Basic registration
let service = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}

// KeyPath registration
let repository = UnifiedDI.register(\.userRepository) {
    UserRepositoryImpl()
}

// Conditional registration
let analytics = UnifiedDI.Conditional.registerIf(
    AnalyticsService.self,
    condition: !isDebugMode,
    factory: { FirebaseAnalytics() },
    fallback: { MockAnalytics() }
)
```

### Resolution

```swift
// Basic resolution
let service = await UnifiedDI.resolve(UserService.self)

// Safe resolution with error handling
do {
    let service: UserService = try await UnifiedDI.resolveSafely(UserService.self)
} catch {
    print("Resolution failed: \(error)")
}

// KeyPath resolution
let repository = await UnifiedDI.resolve(\.userRepository)
```

## Property Wrappers

Type-safe injection at point of use.

### @Inject

For optional dependencies:

```swift
class ViewController {
    @Inject var userService: UserService?

    func loadData() async {
        guard let service = userService else { return }
        let user = await service.fetchUser()
    }
}
```

### @Factory

For new instances each time:

```swift
class DocumentProcessor {
    @Factory var pdfGenerator: PDFGenerator

    func createDocument() {
        let generator = pdfGenerator // New instance
        generator.generate()
    }
}
```

### @SafeInject

For required dependencies with error handling:

```swift
class DataManager {
    @SafeInject var database: Database?

    func save(_ data: Data) throws {
        guard let db = database else {
            throw DIError.dependencyNotFound
        }
        try db.save(data)
    }
}
```

## DIContainer

Low-level container for advanced scenarios.

### Registration

```swift
DIContainer.shared.register(UserService.self) {
    UserServiceImpl()
}
```

### Resolution

```swift
let service = DIContainer.shared.resolve(UserService.self)
```

## Runtime Optimization

Enable high-performance mode:

```swift
// Enable optimization
UnifiedRegistry.shared.enableOptimization()

// Check optimization status
let isEnabled = UnifiedRegistry.shared.isOptimizationEnabled
```

## Error Handling

```swift
enum DIError: Error {
    case dependencyNotFound
    case circularDependency
    case registrationFailed
}
```

## Best Practices

1. **Use UnifiedDI** for most scenarios
2. **Enable optimization** for performance-critical apps
3. **Use property wrappers** for clean code
4. **Handle errors gracefully** with SafeInject

## See Also

- <doc:PropertyWrappers> - Detailed property wrapper guide
- <doc:RuntimeOptimization> - Performance optimization
- <doc:UnifiedDI> - Advanced UnifiedDI features

---

📖 **Documentation**: [한국어](../ko.lproj/CoreAPIs) | [English](CoreAPIs)
