---
title: BulkRegistrationDSL
lang: en-US
---

# Bulk Registration & DSL

Configure dependencies concisely using WeaveDI's powerful bulk registration and DSL features. These tools help you register multiple related dependencies efficiently while maintaining clean, readable code.

## Overview

Bulk Registration DSL provides three main features:
- **Interface Pattern Registration**: Register complete interface-implementation patterns
- **Bulk Interface DSL**: Use declarative syntax for multiple interface registrations
- **Easy Scope Registration**: Simplify scope-based dependency registration

## Interface Pattern Batch Registration

Register complete interface patterns with repository, use case, and fallback implementations in a single call.

### Basic Usage

```swift
let entries = registerModule.registerInterfacePattern(
  BookListInterface.self,
  repositoryFactory: { BookListRepositoryImpl() },
  useCaseFactory: { BookListUseCaseImpl(repository: $0) },
  repositoryFallback: { DefaultBookListRepositoryImpl() }
)
```

### Advanced Pattern Registration

```swift
// Register multiple layers with different scopes
let userModuleEntries = registerModule.registerInterfacePattern(
  UserInterface.self,
  repositoryFactory: { [weak self] in
    UserRepositoryImpl(apiClient: self?.apiClient)
  },
  useCaseFactory: { repository in
    UserUseCaseImpl(
      repository: repository,
      validator: UserValidator()
    )
  },
  repositoryFallback: { MockUserRepositoryImpl() }
)

// Access registered components
print("Registered \(userModuleEntries.count) components for UserInterface")
```

### Pattern Registration Benefits

- **Consistency**: Ensures all layers follow the same pattern
- **Type Safety**: Compile-time validation of factory signatures
- **Fallback Support**: Automatic fallback registration for testing
- **Batch Operations**: Register entire modules in one call

## Bulk DSL

Use declarative syntax to register multiple interfaces with a clean, readable format.

### Basic Bulk Registration

```swift
let modules = registerModule.bulkInterfaces {
  BookListInterface.self => (
    repository: { BookListRepositoryImpl() },
    useCase: { BookListUseCaseImpl(repository: $0) },
    fallback: { DefaultBookListRepositoryImpl() }
  )

  UserInterface.self => (
    repository: { UserRepositoryImpl() },
    useCase: { UserUseCaseImpl(repository: $0) },
    fallback: { MockUserRepositoryImpl() }
  )
}
```

### Complex Bulk Registration

```swift
let appModules = registerModule.bulkInterfaces {
  // Authentication Module
  AuthInterface.self => (
    repository: { AuthRepositoryImpl(keychain: Keychain.shared) },
    useCase: { AuthUseCaseImpl(repository: $0, biometrics: BiometricsService()) },
    fallback: { MockAuthRepositoryImpl() }
  )

  // Networking Module
  NetworkInterface.self => (
    repository: { NetworkRepositoryImpl(session: URLSession.shared) },
    useCase: { NetworkUseCaseImpl(repository: $0, cache: CacheService()) },
    fallback: { MockNetworkRepositoryImpl() }
  )

  // Analytics Module
  AnalyticsInterface.self => (
    repository: { AnalyticsRepositoryImpl(provider: FirebaseAnalytics()) },
    useCase: { AnalyticsUseCaseImpl(repository: $0) },
    fallback: { NoOpAnalyticsRepositoryImpl() }
  )
}

print("Bulk registered \(appModules.count) interface modules")
```

### DSL Syntax Features

- **Arrow Operator (=>)**: Clean interface-to-implementation mapping
- **Tuple Syntax**: Grouped factory definitions
- **Parameter Injection**: Automatic dependency injection between layers
- **Multiple Interfaces**: Register many interfaces in one block

## Easy Scope Registration

Simplify scope-based registration with automatic scope management.

### Basic Scope Registration

```swift
let modules = registerModule.easyScopes {
  register(UserService.self) { UserServiceImpl() }
  register(NetworkService.self) { NetworkServiceImpl() }
  register(CacheService.self) { CacheServiceImpl() }
}
```

### Scoped Registration with Dependencies

```swift
let scopedModules = registerModule.easyScopes {
  // Singleton services
  register(ConfigService.self, scope: .singleton) {
    ConfigServiceImpl(bundle: Bundle.main)
  }

  // Scoped services with dependencies
  register(UserService.self, scope: .weak) {
    UserServiceImpl(
      config: resolve(ConfigService.self),
      network: resolve(NetworkService.self)
    )
  }

  // Per-request services
  register(RequestLogger.self, scope: .transient) {
    RequestLoggerImpl(level: .debug)
  }
}
```

### Advanced Scope Patterns

```swift
let advancedModules = registerModule.easyScopes {
  // Factory pattern with lazy initialization
  register(DatabaseService.self, scope: .singleton) { [lazy] in
    DatabaseServiceImpl(path: DatabaseConfig.defaultPath)
  }

  // Conditional registration
  register(AnalyticsService.self) {
    #if DEBUG
      return DebugAnalyticsService()
    #else
      return ProductionAnalyticsService()
    #endif
  }

  // Service with cleanup
  register(ResourceManager.self, scope: .weak) {
    let manager = ResourceManagerImpl()
    manager.setupCleanupHandlers()
    return manager
  }
}
```

## Practical Examples

### Complete App Module Setup

```swift
class AppDependencyModule {
  static func configure() -> [Any] {
    let container = WeaveDI.Container()

    // Use bulk registration for core modules
    let coreModules = container.bulkInterfaces {
      AuthInterface.self => (
        repository: { AuthRepositoryImpl() },
        useCase: { AuthUseCaseImpl(repository: $0) },
        fallback: { MockAuthRepositoryImpl() }
      )

      UserInterface.self => (
        repository: { UserRepositoryImpl() },
        useCase: { UserUseCaseImpl(repository: $0) },
        fallback: { MockUserRepositoryImpl() }
      )
    }

    // Use easy scopes for utilities
    let utilityModules = container.easyScopes {
      register(Logger.self, scope: .singleton) {
        LoggerImpl(level: .info)
      }
      register(Cache.self, scope: .weak) {
        CacheImpl(maxSize: 1000)
      }
    }

    return coreModules + utilityModules
  }
}
```

### Testing Configuration

```swift
class TestDependencyModule {
  static func configureForTesting() -> [Any] {
    let container = WeaveDI.Container()

    // Override with mock implementations
    let testModules = container.bulkInterfaces {
      AuthInterface.self => (
        repository: { MockAuthRepositoryImpl() },
        useCase: { MockAuthUseCaseImpl() },
        fallback: { NoOpAuthRepositoryImpl() }
      )

      NetworkInterface.self => (
        repository: { MockNetworkRepositoryImpl() },
        useCase: { MockNetworkUseCaseImpl() },
        fallback: { OfflineNetworkRepositoryImpl() }
      )
    }

    let testUtilities = container.easyScopes {
      register(Logger.self) { TestLoggerImpl() }
      register(Cache.self) { InMemoryCacheImpl() }
    }

    return testModules + testUtilities
  }
}
```

## Performance Considerations

### Registration Performance

- **Bulk Operations**: ~10x faster than individual registrations
- **Memory Efficiency**: Shared factory closures reduce memory overhead
- **Lazy Evaluation**: Factories only execute when dependencies are resolved

### Best Practices

1. **Group Related Dependencies**: Use bulk registration for modules
2. **Separate Concerns**: Different DSL patterns for different use cases
3. **Test Overrides**: Use separate bulk configurations for testing
4. **Scope Appropriately**: Choose the right scope for each dependency

```swift
// ✅ Good: Grouped by feature
let authModules = registerModule.bulkInterfaces {
  AuthInterface.self => (/* auth implementations */)
  TokenInterface.self => (/* token implementations */)
}

// ❌ Avoid: Mixed unrelated dependencies
let mixedModules = registerModule.bulkInterfaces {
  AuthInterface.self => (/* auth implementations */)
  DatabaseInterface.self => (/* unrelated database */)
}
```

## Integration with Other WeaveDI Features

### With Property Wrappers

```swift
class FeatureViewModel {
  @Injected(\.userUseCase) var userUseCase
  @Injected(\.authUseCase) var authUseCase

  // These are automatically resolved from bulk registrations
}
```

### With UnifiedDI

```swift
// Bulk registration works seamlessly with UnifiedDI
let modules = UnifiedDI.bulkInterfaces {
  UserInterface.self => (
    repository: { UserRepositoryImpl() },
    useCase: { UserUseCaseImpl(repository: $0) }
  )
}
```

## Error Handling

### Registration Validation

```swift
do {
  let modules = try registerModule.bulkInterfaces {
    UserInterface.self => (
      repository: { UserRepositoryImpl() },
      useCase: { UserUseCaseImpl(repository: $0) },
      fallback: { MockUserRepositoryImpl() }
    )
  }
} catch RegistrationError.duplicateInterface(let interface) {
  print("Interface \(interface) already registered")
} catch RegistrationError.invalidFactory(let error) {
  print("Factory validation failed: \(error)")
}
```

### Runtime Safety

- **Type Validation**: All factory signatures validated at registration
- **Dependency Cycles**: Automatic cycle detection in bulk registrations
- **Missing Dependencies**: Clear error messages for resolution failures

## Next Steps

- [Core APIs](./coreApis.md) - Learn about WeaveDI's core registration APIs
- [Property Wrappers](./injected.md) - Use @Injected with bulk registered dependencies
- [UnifiedDI](./unifiedDI.md) - Integrate bulk registration with UnifiedDI
