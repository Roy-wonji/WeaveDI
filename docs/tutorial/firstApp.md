# Building Your First App with WeaveDI

Create a simple yet complete iOS Counter app using WeaveDI. This tutorial demonstrates the fundamental concepts of dependency injection through a practical example.

## 🎯 Project Overview

We'll build a Counter app that demonstrates:
- **Basic Dependency Injection**: Using `@Inject` property wrapper
- **Service Layer Pattern**: Separating business logic from UI
- **Protocol-based Design**: Creating testable and flexible code
- **SwiftUI Integration**: Modern UI with dependency injection

## 📱 App Features

The Counter app includes:
- Increment and decrement buttons
- Reset functionality
- Dependency injection status indicator
- Logging service integration
- Clean SwiftUI interface

## 🔗 Complete Source Code

This tutorial is based on the official WeaveDI documentation tutorial available in the WeaveDI.docc resources.

## 🏗️ Step-by-Step Implementation

### Step 1: Project Setup

Create a new iOS project and add WeaveDI dependency:

```swift
// Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WeaveDICounterApp",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    dependencies: [
        .package(
            url: "https://github.com/Roy-wonji/WeaveDI.git",
            from: "3.0.0"
        )
    ],
    targets: [
        .target(
            name: "WeaveDICounterApp",
            dependencies: ["WeaveDI"]
        )
    ]
)
```

### Step 2: Define the Service Layer

Create the CounterService protocol and implementation:

```swift
// CounterService.swift
import Foundation

// MARK: - CounterService Protocol

/// Protocol defining counter business logic operations
/// Using Sendable for thread safety across async contexts
protocol CounterService: Sendable {
    /// Increment the counter value
    /// - Parameter value: Current counter value
    /// - Returns: New incremented value
    func increment(_ value: Int) -> Int

    /// Decrement the counter value
    /// - Parameter value: Current counter value
    /// - Returns: New decremented value
    func decrement(_ value: Int) -> Int

    /// Reset counter to zero
    /// - Returns: Reset value (0)
    func reset() -> Int
}

// MARK: - CounterService Implementation

/// Default implementation of CounterService
/// Provides basic arithmetic operations with logging
final class DefaultCounterService: CounterService {

    func increment(_ value: Int) -> Int {
        let newValue = value + 1
        print("🔢 [CounterService] Increment: \(value) → \(newValue)")
        return newValue
    }

    func decrement(_ value: Int) -> Int {
        let newValue = value - 1
        print("🔢 [CounterService] Decrement: \(value) → \(newValue)")
        return newValue
    }

    func reset() -> Int {
        print("🔢 [CounterService] Reset to 0")
        return 0
    }
}
```

### Step 3: Set Up Dependency Registration

Configure WeaveDI container in your App file:

```swift
// App.swift
import SwiftUI
import WeaveDI

@main
struct CounterApp: App {

    init() {
        // Register dependencies when app starts
        setupDependencies()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    /// Configure all app dependencies
    private func setupDependencies() {
        // Register CounterService with its default implementation
        // This creates a singleton instance that will be reused
        UnifiedDI.register(CounterService.self) {
            DefaultCounterService()
        }

        print("✅ Dependencies registered successfully")
    }
}
```

### Step 4: Create the SwiftUI View with Dependency Injection

Build the main interface with `@Inject` property wrapper:

```swift
// ContentView.swift
import SwiftUI
import WeaveDI

struct ContentView: View {
    // State for the counter value
    @State private var count = 0

    // 🔥 WeaveDI's @Inject Property Wrapper
    // Automatically resolves CounterService from the DI container
    @Inject private var counterService: CounterService?

    var body: some View {
        VStack(spacing: 20) {
            // App title
            Text("WeaveDI Counter")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Counter display
            Text("\(count)")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(.blue)

            // Control buttons
            HStack(spacing: 20) {
                // Decrement button
                Button("-") {
                    if let service = counterService {
                        count = service.decrement(count)
                    }
                }
                .buttonStyle(CounterButtonStyle(color: .red))

                // Increment button
                Button("+") {
                    if let service = counterService {
                        count = service.increment(count)
                    }
                }
                .buttonStyle(CounterButtonStyle(color: .green))

                // Reset button
                Button("Reset") {
                    if let service = counterService {
                        count = service.reset()
                    }
                }
                .font(.title2)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

            // Dependency injection status indicator
            DependencyStatusView(isInjected: counterService != nil)
        }
        .padding()
    }
}

// MARK: - Supporting Views

/// Custom button style for counter buttons
struct CounterButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title)
            .frame(width: 50, height: 50)
            .background(color)
            .foregroundColor(.white)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// View showing dependency injection status
struct DependencyStatusView: View {
    let isInjected: Bool

    var body: some View {
        HStack {
            Image(systemName: isInjected ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isInjected ? .green : .red)
            Text("CounterService: \(isInjected ? "Injected" : "Not Available")")
                .font(.caption)
        }
        .padding(.top)
    }
}

#Preview {
    ContentView()
}
```

### Step 5: Enhanced Service with Logging

Add a logging service to demonstrate multiple dependencies:

```swift
// LoggingService.swift
import Foundation

// MARK: - LoggingService Protocol

protocol LoggingService: Sendable {
    var sessionId: String { get }
    func logAction(_ action: String)
    func logInfo(_ message: String)
}

// MARK: - LoggingService Implementation

final class DefaultLoggingService: LoggingService {
    let sessionId: String

    init() {
        // Generate new session ID each time (demonstrates Factory pattern)
        self.sessionId = UUID().uuidString.prefix(8).uppercased().description
        print("📝 [LoggingService] New session started: \(sessionId)")
    }

    func logAction(_ action: String) {
        print("📝 [\(sessionId)] ACTION: \(action)")
    }

    func logInfo(_ message: String) {
        print("📝 [\(sessionId)] INFO: \(message)")
    }
}
```

Update the CounterService to use logging:

```swift
// Enhanced CounterService with logging
final class DefaultCounterService: CounterService {
    // Inject logging service into counter service
    @Inject private var logger: LoggingService?

    func increment(_ value: Int) -> Int {
        let newValue = value + 1
        logger?.logAction("INCREMENT: \(value) → \(newValue)")
        return newValue
    }

    func decrement(_ value: Int) -> Int {
        let newValue = value - 1
        logger?.logAction("DECREMENT: \(value) → \(newValue)")
        return newValue
    }

    func reset() -> Int {
        logger?.logAction("RESET to 0")
        return 0
    }
}
```

Register the logging service in your app setup:

```swift
private func setupDependencies() {
    // Register LoggingService as Factory (new instance each time)
    UnifiedDI.register(LoggingService.self) {
        DefaultLoggingService()
    }

    // Register CounterService as Singleton
    UnifiedDI.register(CounterService.self) {
        DefaultCounterService()
    }

    print("✅ All dependencies registered successfully")
}
```

## 🧪 Testing with WeaveDI

Create unit tests using dependency injection:

```swift
// CounterServiceTests.swift
import XCTest
import WeaveDI
@testable import WeaveDICounterApp

class CounterServiceTests: XCTestCase {

    override func setUp() async throws {
        // Reset container for each test
        await WeaveDI.Container.resetForTesting()

        // Register mock dependencies
        UnifiedDI.register(LoggingService.self) {
            MockLoggingService()
        }

        UnifiedDI.register(CounterService.self) {
            DefaultCounterService()
        }
    }

    func testIncrement() {
        let service = DefaultCounterService()
        let result = service.increment(5)
        XCTAssertEqual(result, 6)
    }

    func testDecrement() {
        let service = DefaultCounterService()
        let result = service.decrement(5)
        XCTAssertEqual(result, 4)
    }

    func testReset() {
        let service = DefaultCounterService()
        let result = service.reset()
        XCTAssertEqual(result, 0)
    }
}

// Mock implementation for testing
class MockLoggingService: LoggingService {
    let sessionId = "TEST-SESSION"
    var loggedActions: [String] = []

    func logAction(_ action: String) {
        loggedActions.append(action)
    }

    func logInfo(_ message: String) {
        // Mock implementation
    }
}
```

## 🚀 Key Learning Points

This Counter app demonstrates:

1. **Property Wrapper Usage**: `@Inject` for automatic dependency resolution
2. **Protocol-based Design**: Service interfaces for testability
3. **Dependency Registration**: Setting up the DI container
4. **Graceful Handling**: Dealing with optional injected dependencies
5. **Service Composition**: Services depending on other services
6. **Testing Strategy**: Mocking dependencies for unit tests

## 🔧 Advanced Features

### Multiple Property Wrappers

The example can be extended to show different injection patterns:

```swift
struct AdvancedCounterView: View {
    @State private var count = 0

    // Different injection strategies
    @Inject private var counterService: CounterService?          // Optional injection
    @SafeInject private var logger: LoggingService?              // Safe injection with error handling
    @Factory private var sessionLogger: LoggingService?         // Factory pattern (new instance each access)

    var body: some View {
        // Implementation...
    }
}
```

### Conditional Registration

Register different implementations based on environment:

```swift
private func setupDependencies() {
    #if DEBUG
    // Use mock services in debug builds
    UnifiedDI.register(LoggingService.self) {
        MockLoggingService()
    }
    #else
    // Use real services in production
    UnifiedDI.register(LoggingService.self) {
        DefaultLoggingService()
    }
    #endif
}
```

## 📚 Next Steps

After completing this Counter app:

1. Experiment with different property wrapper types (`@Factory`, `@SafeInject`)
2. Add more services and create dependency chains
3. Implement error handling and edge cases
4. Write comprehensive unit tests
5. Explore advanced WeaveDI features

## 🔗 Related Resources

- [Property Wrappers Guide](/guide/propertyWrappers)
- [Testing with WeaveDI](/tutorial/testing)
- [Performance Optimization](/tutorial/performanceOptimization)
- [Advanced Dependency Injection](/tutorial/advancedFeatures)

---

Congratulations! You've built your first app with WeaveDI. This Counter app demonstrates the fundamental concepts of dependency injection and sets the foundation for building more complex applications with clean architecture.