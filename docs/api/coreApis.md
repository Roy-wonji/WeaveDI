# Core API Guide

Learn about the essential APIs and usage patterns of WeaveDI 2.0.

> Notice: Synchronous API → async API Transition (Important)
>
> - Synchronous resolution APIs of UnifiedRegistry have been removed. Use async APIs (`resolveAsync`, `resolveAnyAsync`, `resolveAnyAsyncBox`, `resolveAsync(keyPath:)`) for all resolutions.
> - Synchronous APIs for dependency graph visualization have also been removed. Use async APIs (`generateDOTGraphAsync`, `generateMermaidGraphAsync`, `generateASCIIGraphAsync`, `generateJSONGraphAsync`).
> - Please transition existing code to async versions by adding `await`.

## Overview

WeaveDI 2.0 is designed around three core patterns:
1. **Registration** - Register dependencies in the container
2. **Injection** - Automatic injection through property wrappers
3. **Resolution** - Manual dependency resolution

## Registration API

### UnifiedDI Quick Reference

```swift
// Basic registration
UnifiedDI.register(Service.self) { ServiceImpl() }

// Conditional registration
UnifiedDI.registerIf(Analytics.self, condition: isProd,
                     factory: { FirebaseAnalytics() },
                     fallback: { NoOpAnalytics() })

// Scoped registration (sync/async)
UnifiedDI.registerScoped(UserService.self, scope: .session) { UserServiceImpl() }
UnifiedDI.registerAsyncScoped(ProfileCache.self, scope: .screen) { await ProfileCache.make() }

// Release (all/scope/specific type-scope)
UnifiedDI.release(Service.self)
UnifiedDI.releaseScope(.session, id: userID)
UnifiedDI.releaseScoped(UserService.self, kind: .session, id: userID)
```

### DI (Simplified) Quick Reference

```swift
// Basic registration
DI.register(Service.self) { ServiceImpl() }

// Conditional registration
DI.registerIf(Service.self, condition: flag,
              factory: { RealService() },
              fallback: { MockService() })

// Scoped registration (sync/async)
DI.registerScoped(UserService.self, scope: .request) { UserServiceImpl() }
DI.registerAsyncScoped(RequestContext.self, scope: .request) { await RequestContext.create() }

// Release (all/scope/specific type-scope)
DI.release(Service.self)
DI.releaseScope(.request, id: requestID)
DI.releaseScoped(UserService.self, kind: .request, id: requestID)
```

## Injection API

### @Inject Property Wrapper

The most common method for dependency injection:

```swift
class UserViewModel {
    // Optional injection - nil if not registered
    @Inject var userService: UserService?

    // Required type - uses default value if not registered
    @Inject var userService: UserService = UserServiceImpl()

    func loadUser() async {
        guard let service = userService else { return }
        let user = try await service.getCurrentUser()
        // ...
    }
}
```

### @RequiredInject Property Wrapper

Used for dependencies that must be registered:

```swift
class UserViewController: UIViewController {
    // fatalError occurs if not registered
    @RequiredInject var userService: UserService

    override func viewDidLoad() {
        super.viewDidLoad()
        // userService is always available
        loadUserData()
    }
}
```

## Resolution API

### DI Global Resolver

Simple dependency resolution:

```swift
// Optional resolution
let userService: UserService? = DI.resolve(UserService.self)

// Resolution with default value
let userService = DI.resolve(UserService.self) ?? UserServiceImpl()

// Required resolution (fatalError if not registered)
let userService: UserService = DI.requireResolve(UserService.self)

// Error handling with Result type
let result = DI.resolveResult(UserService.self)
switch result {
case .success(let service):
    // Use service
case .failure(let error):
    Log.error("Resolution failed: \(error)")
}
```

### UnifiedDI Unified Resolver

Performance-optimized resolution method:

```swift
// Synchronous resolution
let userService: UserService? = UnifiedDI.resolve(UserService.self)

// Asynchronous resolution (Actor Hop optimized)
let userService: UserService? = await UnifiedDI.resolveAsync(UserService.self)

// Type-safe resolution through KeyPath
extension WeaveDI.Container {
    var userService: UserService? {
        resolve(UserService.self)
    }
}

let service = UnifiedDI.resolve(\.userService)
```

## Best Practices

1. **Use UnifiedDI**: Recommended for most scenarios
2. **Enable Optimization**: Use optimization mode for performance-critical apps
3. **Leverage Property Wrappers**: Use property wrappers for clean code
4. **Error Handling**: Graceful error handling with SafeInject

## Related Documentation

- [Property Wrappers](/guide/propertyWrappers) - Detailed property wrapper guide
- [Runtime Optimization](/guide/runtimeOptimization) - Performance optimization
- [UnifiedDI](/guide/unifiedDi) - Advanced UnifiedDI features