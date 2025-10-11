# TCA Policy Configuration (Bridge Flexibility Enhancement)

## Overview

WeaveDI's TCA bridge policy system allows dynamic control of dependency priorities when integrating with The Composable Architecture. Through `TCABridgePolicy`, you can use different dependency resolution strategies for testing, production, and contextual environments.

## 🎯 Core Advantages

- **✅ Dynamic Policy Changes**: Adjust dependency priorities at runtime
- **✅ Environment-specific Optimization**: Tailored strategies for test/production environments
- **✅ Context Awareness**: Intelligent dependency selection based on situation
- **✅ Perfect TCA Compatibility**: Complete integration with Dependency Values

## TCABridgePolicy Enumeration

### Policy Types

```swift
/// Dependency priority policy for TCA bridge
@MainActor
public enum TCABridgePolicy: String, CaseIterable, Sendable {
    /// Test Priority: Prefer TestDependencyKey.testValue
    case testPriority = "testPriority"

    /// Live Priority: Prefer TestDependencyKey.liveValue
    case livePriority = "livePriority"

    /// Contextual: Dynamic selection based on execution environment
    case contextual = "contextual"
}
```

## Policy Configuration and Usage

### Basic Configuration

```swift
import WeaveDI

// Configure policy at app startup
@MainActor
func configureApp() {
    // Production environment: prioritize live values
    TCASmartSync.configure(policy: .livePriority)

    print("🎯 TCA bridge policy set to 'livePriority'!")
}
```

### Test Environment Configuration

```swift
import XCTest
import WeaveDI

class MyFeatureTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Prioritize mock data in tests
        TCASmartSync.configure(policy: .testPriority)
    }

    override func tearDown() {
        // Reset to test policy
        TCASmartSync.resetForTesting()
        super.tearDown()
    }
}
```

### Contextual Policy Usage

```swift
// Dynamic selection in development environment
@MainActor
func setupDevelopmentEnvironment() {
    // Automatic context-based selection in debug builds
    #if DEBUG
    TCASmartSync.configure(policy: .contextual)
    #else
    TCASmartSync.configure(policy: .livePriority)
    #endif
}
```

## Actual Operation Mechanism

### Dependency Resolution Priority

```swift
// TCASmartSync internal implementation
@MainActor
private static func getValueByPolicy<T>(
    testValue: @autoclosure () -> T,
    liveValue: @autoclosure () -> T,
    fallback: @autoclosure () -> T
) -> T {
    switch currentPolicy {
    case .testPriority:
        return testValue()

    case .livePriority:
        return liveValue()

    case .contextual:
        // Dynamic selection based on execution context
        #if DEBUG
        return testValue()
        #else
        return liveValue()
        #endif
    }
}
```

### Usage in syncSingle() Method

```swift
@MainActor
public static func syncSingle<T: TestDependencyKey>(
    _ key: T.Type,
    to dependencyKeyPath: WritableKeyPath<DependencyValues, T.Value>
) where T.Value: Sendable {

    let value = getValueByPolicy(
        testValue: key.testValue,
        liveValue: key.liveValue,
        fallback: key.testValue
    )

    DependencyValues.live[keyPath: dependencyKeyPath] = value
    Log.info("🔄 \(T.self) sync complete (policy: \(currentPolicy.rawValue))")
}
```

## Real-world Usage Scenarios

### 1. A/B Testing Environment

```swift
// Use different API endpoints in A/B testing
@MainActor
func setupABTestEnvironment(isTestGroup: Bool) {
    if isTestGroup {
        TCASmartSync.configure(policy: .testPriority)
        // Use test API endpoint
    } else {
        TCASmartSync.configure(policy: .livePriority)
        // Use production API endpoint
    }
}
```

### 2. Development Mode Switching

```swift
// Developer can switch modes at runtime
@MainActor
class DeveloperSettings {
    static func enableMockMode() {
        TCASmartSync.configure(policy: .testPriority)
        // Display "Mock mode activated" in UI
    }

    static func enableLiveMode() {
        TCASmartSync.configure(policy: .livePriority)
        // Display "Live API mode activated" in UI
    }
}
```

### 3. Gradual Deployment

```swift
// Use with feature flags
@MainActor
func setupFeatureFlag(useNewFeature: Bool) {
    if useNewFeature {
        // New feature: use live data
        TCASmartSync.configure(policy: .livePriority)
    } else {
        // Existing feature: use stable test data
        TCASmartSync.configure(policy: .testPriority)
    }
}
```

## SwiftUI Integration Examples

### Environment-specific Dependency Configuration

```swift
import SwiftUI
import ComposableArchitecture

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    setupDependencyPolicy()
                }
        }
    }

    @MainActor
    private func setupDependencyPolicy() {
        #if DEBUG
        TCASmartSync.configure(policy: .testPriority)
        #else
        TCASmartSync.configure(policy: .livePriority)
        #endif
    }
}
```

### Policy Changes in Settings Screen

```swift
struct DeveloperSettingsView: View {
    @State private var currentPolicy: TCABridgePolicy = .livePriority

    var body: some View {
        VStack {
            Picker("Bridge Policy", selection: $currentPolicy) {
                ForEach(TCABridgePolicy.allCases, id: \.self) { policy in
                    Text(policy.rawValue).tag(policy)
                }
            }
            .onChange(of: currentPolicy) { _, newPolicy in
                TCASmartSync.configure(policy: newPolicy)
            }
        }
    }
}
```

## Performance and Behavioral Characteristics

### Memory Usage
- **Policy Changes**: O(1) time complexity
- **Memory Overhead**: Minimal (only stores one enum)

### Thread Safety
- **@MainActor**: All policy configurations execute on main actor
- **Concurrency Safe**: No race conditions

### Execution Performance
- **Priority Check**: Optimized with simple switch statement
- **Caching**: Recalculation only when policy changes

## Troubleshooting

### Q: Policy changes not reflected immediately?
**A:** `TCASmartSync.configure()` runs on @MainActor, so call from main queue or use `Task { @MainActor in }`.

### Q: Policy not reset in tests?
**A:** Call `TCASmartSync.resetForTesting()` in each test's `setUp()` method.

### Q: Contextual policy behaving unexpectedly?
**A:** Check compilation flag settings and use explicit `.testPriority` or `.livePriority` if needed.

## Advanced Usage

### Custom Policy Logic

```swift
// For special requirements
extension TCASmartSync {
    @MainActor
    public static func configureCustom<T: TestDependencyKey>(
        _ key: T.Type,
        customValue: T.Value
    ) where T.Value: Sendable {
        // Use custom value only for specific keys
        DependencyValues.live[keyPath: \.[key]] = customValue
    }
}
```

## Related APIs

- [`TCASmartSync`](./tcaSmartSync.md) - TCA integration system
- [`TestDependencyKey`](./testDependencyKey.md) - Test dependency keys
- [`DependencyValues`](./dependencyValues.md) - TCA dependency values

---

*This feature was added in WeaveDI v3.2.1. It's an innovative policy system for flexible integration with TCA.*