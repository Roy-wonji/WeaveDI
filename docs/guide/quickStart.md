# Quick Start Guide

Get up and running with WeaveDI in 5 minutes.

## Installation

### Swift Package Manager

Add WeaveDI to your project's Package.swift file. This configuration tells Swift Package Manager to download WeaveDI version 3.1.0 or later from the GitHub repository:

```swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.1.0")
]
```

**What this does:**
- Downloads the WeaveDI framework from the official repository
- Ensures you get version 3.1.0 or newer (with latest features and bug fixes)
- Integrates seamlessly with your Swift project's build system

### Xcode

1. File → Add Package Dependencies
2. Enter: `https://github.com/Roy-wonji/WeaveDI.git`
3. Add Package

## Basic Usage

### 1. Import

First, import WeaveDI into your Swift files where you need dependency injection. This gives you access to all WeaveDI features including property wrappers, registration APIs, and container management:

```swift
import WeaveDI
```

**What this enables:**
- Access to `@Inject`, `@Factory`, and `@SafeInject` property wrappers
- UnifiedDI registration and resolution APIs
- WeaveDI.Container bootstrap functionality
- All WeaveDI utility classes and protocols

### 2. Define Services

Create protocols (interfaces) and implementations for your services. This follows the dependency inversion principle - depend on abstractions, not concrete implementations:

```swift
// Define the service contract (what functionality is available)
protocol UserService {
    func fetchUser(id: String) async -> User?
}

// Implement the actual service logic
class UserServiceImpl: UserService {
    func fetchUser(id: String) async -> User? {
        // In real apps, this would call an API or database
        // For demo purposes, we return a simple User object
        return User(id: id, name: "John")
    }
}
```

**Why use protocols?**
- **Testability**: Easy to create mock implementations for testing
- **Flexibility**: Can swap implementations without changing dependent code
- **Maintainability**: Clear separation between interface and implementation
- **Best Practice**: Follows SOLID principles for clean architecture

### 3. Register Dependencies

Register your service implementations with WeaveDI's dependency injection container. This tells WeaveDI how to create instances when they're requested. Do this during app startup, typically in your App delegate or SwiftUI App struct:

```swift
// Register at app startup - this creates the binding between protocol and implementation
let userService = UnifiedDI.register(UserService.self) {
    UserServiceImpl()  // Factory closure that creates the actual implementation
}
```

**How registration works:**
- **Type Registration**: Maps the `UserService` protocol to `UserServiceImpl` class
- **Factory Closure**: The `{ UserServiceImpl() }` closure defines how to create instances
- **Lazy Creation**: Instances are only created when first requested (lazy loading)
- **Singleton by Default**: The same instance is reused across the app unless configured otherwise
- **Return Value**: Returns the created instance for immediate use if needed

### 4. Use Property Wrappers

Now inject and use your registered services in any class using WeaveDI's property wrappers. The `@Inject` wrapper automatically resolves the dependency from the container:

```swift
class UserViewController {
    // @Inject automatically resolves UserService from the DI container
    // The '?' makes it optional - the app won't crash if service isn't registered
    @Inject var userService: UserService?

    func loadUser() async {
        // Always safely unwrap injected dependencies
        guard let service = userService else {
            print("❌ UserService not available")
            return
        }

        // Use the injected service to perform operations
        let user = await service.fetchUser(id: "123")

        // Update UI with retrieved data
        DispatchQueue.main.async {
            // Update your UI here
            print("✅ User loaded: \(user?.name ?? "Unknown")")
        }
    }
}
```

**How @Inject works:**
- **Automatic Resolution**: WeaveDI automatically finds and injects the registered implementation
- **Optional Safety**: Returns `nil` if the service isn't registered (prevents crashes)
- **Lazy Loading**: The service is only resolved when first accessed
- **Thread Safe**: Safe to use across different threads and actors

## Property Wrappers

### @Inject - Optional Dependencies

Use `@Inject` for most dependency injection scenarios. It provides safe, optional injection that won't crash your app if a dependency isn't registered:

```swift
class ViewController {
    // Standard dependency injection - safe and optional
    @Inject var userService: UserService?

    func viewDidLoad() {
        super.viewDidLoad()

        // Safe optional chaining - won't crash if service is nil
        userService?.fetchUser(id: "current") { [weak self] user in
            DispatchQueue.main.async {
                self?.displayUser(user)
            }
        }

        // Alternative: Explicit nil checking for better error handling
        guard let service = userService else {
            showErrorMessage("User service unavailable")
            return
        }

        // Now we know the service is available
        service.fetchUser(id: "current") { user in
            // Handle user data
        }
    }
}
```

**When to use @Inject:**
- **Most scenarios**: Your primary choice for dependency injection
- **Optional dependencies**: Services that are nice-to-have but not critical
- **Safe injection**: When you want to prevent crashes from missing dependencies
- **Testing**: Easy to mock by not registering the real service

### @Factory - New Instance Each Time

Use `@Factory` when you need fresh instances rather than shared singletons. Perfect for stateless operations or when you need isolated instances:

```swift
class DocumentProcessor {
    // @Factory creates a new PDFGenerator instance every time it's accessed
    // Each document gets its own generator to avoid state conflicts
    @Factory var pdfGenerator: PDFGenerator

    func createDocument(content: String) {
        // Each access to pdfGenerator returns a brand new instance
        let generator = pdfGenerator // New instance created here

        // Configure this specific generator
        generator.setContent(content)
        generator.setFormat(.A4)

        // Generate the PDF
        let pdfData = generator.generate()
        savePDF(pdfData)
    }

    func createMultipleDocuments(contents: [String]) {
        for content in contents {
            // Each iteration gets a completely new PDFGenerator
            let generator = pdfGenerator // Fresh instance for each document

            generator.setContent(content)
            let pdf = generator.generate()
            savePDF(pdf)

            // No need to reset or clean up - each generator is independent
        }
    }
}
```

**When to use @Factory:**
- **Stateless operations**: PDF generation, image processing, data transformation
- **Concurrent processing**: Each thread/task needs its own instance
- **Avoiding shared state**: Prevent one operation from affecting another
- **Builder patterns**: Fresh builder for each construction
- **Short-lived objects**: Objects that don't need to persist

### @SafeInject - Error Handling

Use `@SafeInject` when you need explicit error handling for missing dependencies. This wrapper provides more control over dependency resolution failures:

```swift
class DataManager {
    // @SafeInject provides explicit error information when resolution fails
    @SafeInject var database: Database?

    func save(_ data: Data) throws {
        // Check if dependency injection succeeded
        guard let db = database else {
            // Log the specific error for debugging
            print("❌ Database dependency not found - check your DI registration")

            // Throw a descriptive error for the caller
            throw DIError.dependencyNotFound(type: "Database")
        }

        // Proceed with the database operation
        try db.save(data)
        print("✅ Data saved successfully")
    }

    func safeSave(_ data: Data) -> Result<Void, Error> {
        do {
            guard let db = database else {
                return .failure(DIError.dependencyNotFound(type: "Database"))
            }

            try db.save(data)
            return .success(())

        } catch {
            return .failure(error)
        }
    }
}

// Custom error type for better error handling
enum DIError: LocalizedError {
    case dependencyNotFound(type: String)

    var errorDescription: String? {
        switch self {
        case .dependencyNotFound(let type):
            return "Required dependency '\(type)' was not found. Please register it in your DI container."
        }
    }
}
```

**When to use @SafeInject:**
- **Critical dependencies**: Services that are absolutely required for operation
- **Error reporting**: When you need detailed error information about missing dependencies
- **Explicit failure handling**: When `nil` isn't descriptive enough
- **Production debugging**: To get better diagnostic information in logs

## Advanced Features

### Runtime Optimization

WeaveDI includes built-in performance optimizations that can significantly improve dependency resolution speed in production apps:

```swift
// Enable automatic runtime optimization
// This should be called early in your app lifecycle, typically in AppDelegate or App.swift
UnifiedRegistry.shared.enableOptimization()

// The optimization system will:
// 1. Cache frequently resolved dependencies for faster access
// 2. Optimize dependency graphs for minimal resolution overhead
// 3. Use lazy loading strategies for better memory management
// 4. Monitor performance and auto-tune based on usage patterns

print("🚀 WeaveDI optimization enabled - expect better performance!")
```

**What optimization does:**
- **Hot Path Caching**: Frequently accessed dependencies are cached for instant resolution
- **Graph Optimization**: Dependency resolution paths are optimized for minimal overhead
- **Memory Management**: Automatic cleanup of unused dependencies under memory pressure
- **Performance Monitoring**: Real-time analysis of resolution patterns for continuous improvement

**When to enable:**
- **Production builds**: Always enable in release builds for best performance
- **Large applications**: Essential for apps with many dependencies
- **Performance-critical apps**: Games, real-time apps, or apps with strict performance requirements

### Bootstrap Pattern

The bootstrap pattern is the recommended way to set up all your dependencies in one place. This ensures proper initialization order and makes dependency management more organized:

```swift
// Bootstrap all dependencies at app startup
// This is typically called in your App.swift or AppDelegate
await WeaveDI.Container.bootstrap { container in
    // Register services in logical order

    // 1. Core infrastructure services first
    container.register(LoggerProtocol.self) {
        ConsoleLogger() // Basic logging for debugging
    }

    // 2. Data layer services
    container.register(DatabaseService.self) {
        CoreDataService() // Database layer
    }

    // 3. Network services
    container.register(NetworkService.self) {
        URLSessionNetworkService() // HTTP client
    }

    // 4. Business logic services (depend on infrastructure)
    container.register(UserService.self) {
        UserServiceImpl() // Uses database and network services automatically
    }

    // 5. Presentation layer services
    container.register(AnalyticsService.self) {
        FirebaseAnalytics() // User tracking and analytics
    }

    print("✅ All dependencies registered successfully")
}

// Alternative: Environment-specific bootstrap
#if DEBUG
await WeaveDI.Container.bootstrap { container in
    // Use mock services for development
    container.register(UserService.self) { MockUserService() }
    container.register(NetworkService.self) { MockNetworkService() }
}
#else
await WeaveDI.Container.bootstrap { container in
    // Use real services for production
    container.register(UserService.self) { UserServiceImpl() }
    container.register(NetworkService.self) { URLSessionNetworkService() }
}
#endif
```

**Benefits of Bootstrap Pattern:**
- **Centralized Setup**: All dependency registration in one place
- **Proper Ordering**: Dependencies are registered in logical order
- **Environment Awareness**: Different setups for debug/release builds
- **Error Detection**: Easy to spot missing or incorrectly configured dependencies
- **Documentation**: Serves as a clear map of your app's dependencies

## Next Steps

- [Property Wrappers](/guide/propertyWrappers) - Detailed injection patterns
- [Core APIs](/api/coreApis) - Complete API reference
- [Runtime Optimization](/guide/runtimeOptimization) - Performance tuning