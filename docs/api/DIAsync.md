---
title: DIAsync
lang: en-US
---

# DIAsync

Concurrency-first DI API using actor-based registry.
Provides async register/resolve without relying on GCD.

```swift
public enum DIAsync {
  // Shared async registry
  private static let registry = AsyncTypeRegistry()
}
```

  /// Register an async factory (transient)
  /// Register via KeyPath and return the created instance
  /// Get or create via KeyPath-style registration (idempotent)
  /// Resolve an instance (async). Falls back to sync container if not found.
  /// Resolve or return default
  /// Require resolve (fatalError on failure)
  /// Check if a type is registered in async or sync registry
  /// Check if a KeyPath-identified dependency is registered
  /// Release all async registrations (testing purpose)

```swift
public struct DIAsyncRegistrationBuilder {
  public static func buildBlock(_ components: DIAsyncRegistration...) -> [DIAsyncRegistration] {
    components
  }
}
```

