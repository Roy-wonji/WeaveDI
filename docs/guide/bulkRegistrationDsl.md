# Bulk Registration & DSL

Configure multiple dependencies efficiently using WeaveDI's bulk registration system and Domain Specific Language (DSL) patterns. This approach reduces boilerplate code and makes dependency registration more readable and maintainable.

## Overview

Bulk registration allows you to register multiple related dependencies in a single operation, following common patterns like Repository-UseCase architectures. The DSL provides a fluent, expressive syntax that makes dependency configuration more intuitive.

**Benefits**:
- **Reduced Boilerplate**: Register multiple related services with minimal code
- **Pattern Consistency**: Enforces common architectural patterns
- **Type Safety**: Compile-time checking of dependency relationships
- **Readability**: Clear, expressive syntax that documents dependencies

## Interface Pattern Batch Registration

The Interface Pattern is perfect for Repository-UseCase architectures where you have a common pattern of dependencies that need to be registered together.

**Purpose**: Automatically register Repository, UseCase, and fallback implementations for a given interface in one operation.

**How it works**:
- **Repository Factory**: Creates the primary data access implementation
- **UseCase Factory**: Creates the business logic layer, automatically injected with the repository
- **Fallback**: Provides a default implementation when the primary repository fails

```swift
let entries = registerModule.registerInterfacePattern(
  BookListInterface.self,
  repositoryFactory: { BookListRepositoryImpl() },
  useCaseFactory: { BookListUseCaseImpl(repository: $0) }, // $0 is the repository instance
  repositoryFallback: { DefaultBookListRepositoryImpl() }
)
```

**What this creates**:
- `BookListRepository` → `BookListRepositoryImpl` (primary)
- `BookListRepository` → `DefaultBookListRepositoryImpl` (fallback)
- `BookListUseCase` → `BookListUseCaseImpl` (with injected repository)
- `BookListInterface` → Complete configured service

**Use Cases**:
- **MVVM Architecture**: Repository-ViewModel patterns
- **Clean Architecture**: Repository-UseCase-Presenter layers
- **Service Layers**: API-Service-Cache combinations

## Bulk DSL

The Bulk DSL provides a more expressive, readable way to configure multiple interface patterns using operator overloading and closure syntax.

**Purpose**: Use a fluent DSL syntax to configure multiple interfaces with their dependencies in a single, readable block.

**Benefits of DSL**:
- **Expressive Syntax**: The `=>` operator clearly shows relationships
- **Grouped Configuration**: Related dependencies are visually grouped
- **Type Inference**: Swift's type system provides safety
- **Reduced Errors**: Less chance of misconfiguration

```swift
let modules = registerModule.bulkInterfaces {
  // Clean, readable syntax showing the relationship between interface and implementations
  BookListInterface.self => (
    repository: { BookListRepositoryImpl() },      // Primary repository
    useCase: { BookListUseCaseImpl(repository: $0) }, // UseCase with auto-injected repo
    fallback: { DefaultBookListRepositoryImpl() }   // Fallback when primary fails
  )

  // You can register multiple interfaces in the same block
  UserInterface.self => (
    repository: { UserRepositoryImpl() },
    useCase: { UserUseCaseImpl(repository: $0) },
    fallback: { OfflineUserRepositoryImpl() }
  )
}
```

**Advanced DSL Patterns**:

```swift
let modules = registerModule.bulkInterfaces {
  // With additional dependencies
  WeatherInterface.self => (
    repository: { WeatherRepositoryImpl() },
    useCase: {
      WeatherUseCaseImpl(
        repository: $0,
        logger: UnifiedDI.resolve(LoggerProtocol.self)!
      )
    },
    fallback: { CachedWeatherRepositoryImpl() }
  )

  // With conditional registration
  AnalyticsInterface.self => (
    repository: {
      #if DEBUG
      MockAnalyticsRepositoryImpl()
      #else
      FirebaseAnalyticsRepositoryImpl()
      #endif
    },
    useCase: { AnalyticsUseCaseImpl(repository: $0) },
    fallback: { NoOpAnalyticsRepositoryImpl() }
  )
}
```

## Easy Scope Registration

Easy Scope provides a simplified way to register multiple services within a specific scope without the complexity of interface patterns.

**Purpose**: Register multiple independent services quickly and efficiently with consistent scoping.

**When to use**:
- **Simple Services**: Services that don't follow Repository-UseCase patterns
- **Utility Services**: Loggers, formatters, validators
- **Third-party Integrations**: External SDK wrappers
- **Configuration Services**: Settings, preferences, constants

```swift
let modules = registerModule.easyScopes {
  // Register multiple services in one block
  register(UserService.self) { UserServiceImpl() }
  register(NetworkService.self) { NetworkServiceImpl() }
  register(LoggerProtocol.self) { ConsoleLogger() }
  register(CacheService.self) { MemoryCacheService() }
}
```

**Advanced Easy Scope Examples**:

```swift
let modules = registerModule.easyScopes {
  // With dependencies between services
  register(LoggerProtocol.self) { ConsoleLogger() }

  register(NetworkService.self) {
    NetworkServiceImpl(
      logger: UnifiedDI.resolve(LoggerProtocol.self)!
    )
  }

  register(UserService.self) {
    UserServiceImpl(
      network: UnifiedDI.resolve(NetworkService.self)!,
      logger: UnifiedDI.resolve(LoggerProtocol.self)!
    )
  }

  // With scoped registration
  registerScoped(SessionService.self, scope: .session) {
    SessionServiceImpl()
  }
}
```

## Combining Patterns

You can combine different bulk registration patterns for maximum flexibility:

```swift
await WeaveDI.Container.bootstrap { container in
  // First register core services with Easy Scope
  let coreServices = registerModule.easyScopes {
    register(LoggerProtocol.self) { ConsoleLogger() }
    register(ConfigService.self) { AppConfigService() }
  }

  // Then register business interfaces with Bulk DSL
  let businessServices = registerModule.bulkInterfaces {
    UserInterface.self => (
      repository: { UserRepositoryImpl() },
      useCase: { UserUseCaseImpl(repository: $0) },
      fallback: { OfflineUserRepositoryImpl() }
    )

    BookInterface.self => (
      repository: { BookRepositoryImpl() },
      useCase: { BookUseCaseImpl(repository: $0) },
      fallback: { CachedBookRepositoryImpl() }
    )
  }

  // Finally register complex patterns individually if needed
  let complexEntries = registerModule.registerInterfacePattern(
    ComplexInterface.self,
    repositoryFactory: { ComplexRepositoryImpl() },
    useCaseFactory: { ComplexUseCaseImpl(repository: $0) },
    repositoryFallback: { SimpleComplexRepositoryImpl() }
  )
}
```

## Best Practices

### 1. Choose the Right Pattern

```swift
// ✅ Use Interface Pattern for Repository-UseCase architectures
let userEntries = registerModule.registerInterfacePattern(
  UserInterface.self,
  repositoryFactory: { UserRepositoryImpl() },
  useCaseFactory: { UserUseCaseImpl(repository: $0) },
  repositoryFallback: { OfflineUserRepositoryImpl() }
)

// ✅ Use Bulk DSL for multiple interface patterns
let modules = registerModule.bulkInterfaces {
  UserInterface.self => (repository: ..., useCase: ..., fallback: ...)
  BookInterface.self => (repository: ..., useCase: ..., fallback: ...)
}

// ✅ Use Easy Scope for simple services
let utilities = registerModule.easyScopes {
  register(LoggerProtocol.self) { ConsoleLogger() }
  register(DateFormatter.self) { ISO8601DateFormatter() }
}
```

### 2. Maintain Consistency

```swift
// ✅ Group related services together
let dataServices = registerModule.bulkInterfaces {
  UserInterface.self => (/* configuration */),
  ProfileInterface.self => (/* configuration */),
  SettingsInterface.self => (/* configuration */)
}

let networkServices = registerModule.easyScopes {
  register(HTTPClient.self) { URLSessionHTTPClient() }
  register(APIService.self) { RestAPIService() }
}
```

### 3. Use Meaningful Names

```swift
// ✅ Clear, descriptive variable names
let coreBusinessLogic = registerModule.bulkInterfaces { /* ... */ }
let infrastructureServices = registerModule.easyScopes { /* ... */ }
let externalIntegrations = registerModule.registerInterfacePattern(/* ... */)
```

## See Also

- [Module System](./moduleSystem.md) - Organizing bulk registrations into modules
- [Bootstrap Guide](./bootstrap.md) - Using bulk registration in app startup
- [Core APIs](../api/coreApis.md) - Individual registration methods