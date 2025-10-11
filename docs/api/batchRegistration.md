# Batch Registration DSL

## Overview

WeaveDI's Batch Registration DSL leverages Swift's Result Builder pattern to provide declarative syntax for registering multiple dependencies at once. Through `@BatchRegistrationBuilder`, you can perform bulk registration with clean, readable code.

## 🚀 Core Advantages

- **✅ Declarative Syntax**: Clean registration code with Swift Result Builder
- **✅ Type Safety**: Compile-time type validation
- **✅ Conditional Registration**: Flexible registration with if/else support
- **✅ Multiple Registration Types**: Supports factory, default value, and conditional registration

## Basic Usage

### DIAdvanced.Batch.registerMany

```swift
import WeaveDI

// Register multiple dependencies at once
DIAdvanced.Batch.registerMany {
    BatchRegistration(UserService.self) {
        UserServiceImpl()
    }

    BatchRegistration(NetworkService.self) {
        NetworkServiceImpl()
    }

    BatchRegistration(CacheService.self, default: CacheServiceImpl())
}
```

## BatchRegistration Types

### 1. Factory-based Registration

```swift
DIAdvanced.Batch.registerMany {
    // Basic factory registration
    BatchRegistration(APIClient.self) {
        APIClientImpl(baseURL: "https://api.example.com")
    }

    // Factory with dependencies
    BatchRegistration(UserRepository.self) {
        UserRepositoryImpl(
            apiClient: UnifiedDI.resolve(APIClient.self)!,
            cache: UnifiedDI.resolve(CacheService.self)!
        )
    }
}
```

### 2. Default Value Registration

```swift
// Register pre-created instances
let sharedLogger = LoggerImpl(level: .debug)
let defaultConfig = AppConfig.default

DIAdvanced.Batch.registerMany {
    BatchRegistration(Logger.self, default: sharedLogger)
    BatchRegistration(AppConfig.self, default: defaultConfig)
}
```

### 3. Conditional Registration

```swift
DIAdvanced.Batch.registerMany {
    // Environment-based conditional registration
    BatchRegistration(
        AnalyticsService.self,
        condition: Bundle.main.bundleIdentifier?.contains("debug") == true,
        factory: { DebugAnalyticsService() },
        fallback: { ProductionAnalyticsService() }
    )

    // Feature flag-based registration
    BatchRegistration(
        PaymentService.self,
        condition: FeatureFlags.newPaymentEnabled,
        factory: { NewPaymentServiceImpl() },
        fallback: { LegacyPaymentServiceImpl() }
    )
}
```

## BatchRegistrationBuilder Advanced Features

### Conditional Blocks

```swift
DIAdvanced.Batch.registerMany {
    // Always registered basic service
    BatchRegistration(CoreService.self) {
        CoreServiceImpl()
    }

    // Debug mode only
    #if DEBUG
    BatchRegistration(DebugService.self) {
        DebugServiceImpl()
    }
    #endif

    // Conditional registration
    if ProcessInfo.processInfo.arguments.contains("--mock-mode") {
        BatchRegistration(DataService.self) {
            MockDataService()
        }
    } else {
        BatchRegistration(DataService.self) {
            RealDataService()
        }
    }
}
```

### Array-based Registration

```swift
let services = [
    ("UserService", { UserServiceImpl() as any UserService }),
    ("OrderService", { OrderServiceImpl() as any OrderService }),
    ("NotificationService", { NotificationServiceImpl() as any NotificationService })
]

DIAdvanced.Batch.registerMany {
    for (name, factory) in services {
        // Note: Current implementation requires explicit types
        // This pattern will be improved in future updates
    }

    // Currently register with explicit types
    BatchRegistration(UserService.self) { UserServiceImpl() }
    BatchRegistration(OrderService.self) { OrderServiceImpl() }
    BatchRegistration(NotificationService.self) { NotificationServiceImpl() }
}
```

## Real-world Usage Examples

### App Module Configuration

```swift
class AppDependencySetup {
    static func registerCoreServices() {
        DIAdvanced.Batch.registerMany {
            // Networking layer
            BatchRegistration(HTTPClient.self) {
                URLSessionHTTPClient(session: .shared)
            }

            BatchRegistration(APIClient.self) {
                APIClientImpl(
                    httpClient: UnifiedDI.resolve(HTTPClient.self)!,
                    baseURL: Configuration.apiBaseURL
                )
            }

            // Data layer
            BatchRegistration(UserRepository.self) {
                UserRepositoryImpl(
                    apiClient: UnifiedDI.resolve(APIClient.self)!
                )
            }

            BatchRegistration(OrderRepository.self) {
                OrderRepositoryImpl(
                    apiClient: UnifiedDI.resolve(APIClient.self)!
                )
            }

            // Business logic layer
            BatchRegistration(UserUseCase.self) {
                UserUseCaseImpl(
                    repository: UnifiedDI.resolve(UserRepository.self)!
                )
            }

            BatchRegistration(OrderUseCase.self) {
                OrderUseCaseImpl(
                    repository: UnifiedDI.resolve(OrderRepository.self)!,
                    userUseCase: UnifiedDI.resolve(UserUseCase.self)!
                )
            }
        }
    }
}
```

### Test Environment Configuration

```swift
class TestDependencySetup {
    static func registerMockServices() {
        DIAdvanced.Batch.registerMany {
            // Mock services
            BatchRegistration(APIClient.self) {
                MockAPIClient()
            }

            BatchRegistration(UserRepository.self) {
                MockUserRepository()
            }

            BatchRegistration(OrderRepository.self) {
                MockOrderRepository()
            }

            // Test-only services
            BatchRegistration(TestDataGenerator.self) {
                TestDataGeneratorImpl()
            }

            // Conditional mock (only for specific tests)
            BatchRegistration(
                NetworkService.self,
                condition: TestContext.shouldMockNetwork,
                factory: { MockNetworkService() },
                fallback: { RealNetworkService() }
            )
        }
    }
}
```

### Environment-specific Configuration

```swift
class EnvironmentDependencySetup {
    static func registerEnvironmentServices() {
        DIAdvanced.Batch.registerMany {
            // Environment-specific API service
            BatchRegistration(
                APIService.self,
                condition: Environment.current == .development,
                factory: { DevelopmentAPIService() },
                fallback: { ProductionAPIService() }
            )

            // Environment-specific logging
            BatchRegistration(
                Logger.self,
                condition: Environment.current == .debug,
                factory: { VerboseLoggerImpl() },
                fallback: { ProductionLoggerImpl() }
            )

            // Environment-specific analytics
            BatchRegistration(
                AnalyticsService.self,
                condition: Environment.current == .production,
                factory: { FirebaseAnalyticsService() },
                fallback: { NoOpAnalyticsService() }
            )
        }
    }
}
```

## SwiftUI Integration

### Registration at App Startup

```swift
import SwiftUI
import ComposableArchitecture

@main
struct MyApp: App {
    init() {
        setupDependencies()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func setupDependencies() {
        DIAdvanced.Batch.registerMany {
            // Core services
            BatchRegistration(AppState.self, default: AppState())

            BatchRegistration(UserDefaults.self, default: .standard)

            // Environment-specific services
            #if DEBUG
            BatchRegistration(APIClient.self) {
                MockAPIClient()
            }
            #else
            BatchRegistration(APIClient.self) {
                ProductionAPIClient()
            }
            #endif
        }
    }
}
```

## Performance Characteristics

### Registration Performance
- **Batch Processing**: ~20% faster than individual registrations
- **Memory Efficiency**: Optimized memory usage with Result Builder
- **Lazy Execution**: Factories execute only when dependencies are resolved

### Best Practices
1. **Group Related Dependencies**: Use batch registration per module
2. **Leverage Conditional Registration**: Register different implementations per environment
3. **Optimize Factories**: Use lazy loading for heavy initialization
4. **Separate Testing**: Keep production and test registrations separate

## Troubleshooting

### Q: Can't use generic types in BatchRegistration?
**A:** Currently only concrete types are supported. Generic support will be added in future updates.

### Q: How to handle circular dependencies?
**A:** BatchRegistration uses lazy resolution regardless of registration order, so use `UnifiedDI.resolve()` within factories to resolve circular dependencies.

### Q: How to debug registration failures?
**A:** Test each BatchRegistration individually or enable logging in debug mode to identify issues.

## Migration Guide

### From Individual Registration to Batch Registration

```swift
// Before: Individual registration
DI.register(UserService.self) { UserServiceImpl() }
DI.register(OrderService.self) { OrderServiceImpl() }
DI.register(PaymentService.self) { PaymentServiceImpl() }

// After: Batch registration
DIAdvanced.Batch.registerMany {
    BatchRegistration(UserService.self) { UserServiceImpl() }
    BatchRegistration(OrderService.self) { OrderServiceImpl() }
    BatchRegistration(PaymentService.self) { PaymentServiceImpl() }
}
```

## Related APIs

- [`DIAdvanced`](./diAdvanced.md) - Advanced DI features
- [`UnifiedDI`](./unifiedDI.md) - Unified DI API
- [`@Component`](./componentMacro.md) - Component-based registration

---

*This feature was enhanced in WeaveDI v3.2.1. It's a modern batch registration system leveraging Swift's Result Builder pattern.*