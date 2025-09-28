# Unified DI System - UnifiedDI vs DI

WeaveDI 2.0 provides two main API entry points: `UnifiedDI` and `DI`. Understand the role and usage scenarios of each to make the optimal choice for your project.

## 🎯 API Selection Guide

### UnifiedDI (Recommended)
**"Comprehensive API with all features"**

```swift
// Support for all registration methods
UnifiedDI.register(Service.self) { ServiceImpl() }
UnifiedDI.registerIf(Service.self, condition: isProduction,
                     factory: { ProdService() },
                     fallback: { MockService() })

// Various resolution strategies
let service = UnifiedDI.resolve(Service.self)                    // Optional
let required = UnifiedDI.requireResolve(Service.self)           // Required
let safe = try UnifiedDI.resolveThrows(Service.self)           // Throws
let withDefault = UnifiedDI.resolve(Service.self, default: MockService())

// Performance tracking
let tracked = UnifiedDI.resolveWithTracking(Service.self)

// Batch registration
UnifiedDI.registerMany {
    Registration(NetworkService.self) { NetworkServiceImpl() }
    Registration(UserService.self) { sharedUserService }
    Registration(AnalyticsService.self, condition: analytics) {
        GoogleAnalytics()
    } fallback: {
        NoOpAnalytics()
    }
}
```

#### Scope-based Registration/Resolution (Screen/Session/Request)
```swift
// Set scope ID (e.g., start session scope on login success)
ScopeContext.shared.setCurrent(.session, id: user.id)

// Scope registration (sync/async)
UnifiedDI.registerScoped(UserService.self, scope: .session) { UserServiceImpl() }
UnifiedDI.registerAsyncScoped(ProfileCache.self, scope: .screen) { await ProfileCache.make() }

// Resolve same way as before (uses scope cache if current scope ID exists)
let userService = UnifiedDI.resolve(UserService.self)

// Release scope (all/specific type)
UnifiedDI.releaseScope(.session, id: user.id)
UnifiedDI.releaseScoped(UserService.self, kind: .session, id: user.id)
```

#### Async Singletons (Single creation)
```swift
await GlobalUnifiedRegistry.registerAsyncSingleton(RemoteConfig.self) { await RemoteConfig.fetch() }

// Use anywhere
let config: RemoteConfig? = await UnifiedDI.resolveAsync(RemoteConfig.self)
```

#### Automatic Graph Collection (Optional)
```swift
// Enable automatic recording (records edges from parent context → target type during resolution)
CircularDependencyDetector.shared.setAutoRecordingEnabled(true)

// For more accurate graphs, wrap with begin/end in 'owning type' context
try? CircularDependencyDetector.shared.beginResolution(HomeViewModel.self)
defer { CircularDependencyDetector.shared.endResolution(HomeViewModel.self) }

let service = UnifiedDI.resolve(UserService.self)
```

**Usage Scenarios:**
- Complex app architectures
- When advanced DI features are needed
- When performance optimization is critical
- A/B testing or conditional registration needs
- Large team development

### DI (Simplified)
**"Concise API with core features only"**

```swift
// Provides only 3 basic patterns
DI.register(Service.self) { ServiceImpl() }  // Registration
@Inject var service: Service?                 // Injection
let service = DI.resolve(Service.self)        // Resolution
```

**Usage Scenarios:**
- Simple projects
- Learning DI concepts
- Minimal setup requirements
- Prototype development
- Small team development

## 🔄 Migration Strategy

### Legacy DI → UnifiedDI
```swift
// Before (Legacy)
DI.register(Service.self) { ServiceImpl() }
let service = DI.resolve(Service.self)

// After (UnifiedDI)
UnifiedDI.register(Service.self) { ServiceImpl() }
let service = UnifiedDI.resolve(Service.self)
```

### Gradual Migration
```swift
// Step 1: Keep existing code while using UnifiedDI for new code
class LegacyViewController {
    @Inject var service: OldService?  // Keep existing code
}

class NewViewController {
    private let newService = UnifiedDI.resolve(NewService.self, default: DefaultNewService())
}

// Step 2: Unify with batch registration
await WeaveDI.Container.bootstrap { container in
    // Existing services
    container.register(OldService.self) { OldServiceImpl() }

    // New services - register in UnifiedDI style
    UnifiedDI.register(NewService.self) { NewServiceImpl() }
}

// Step 3: Fully integrate with UnifiedDI
UnifiedDI.registerMany {
    Registration(OldService.self) { OldServiceImpl() }
    Registration(NewService.self) { NewServiceImpl() }
}
```

## 🏗️ Production Patterns

### Environment-based Configuration
```swift
#if DEBUG
UnifiedDI.registerMany {
    Registration(APIService.self) { MockAPIService() }
    Registration(AnalyticsService.self) { DebugAnalytics() }
    Registration(LoggerService.self, default: ConsoleLogger(level: .debug))
}
#else
UnifiedDI.registerMany {
    Registration(APIService.self) { ProductionAPIService() }
    Registration(AnalyticsService.self) { FirebaseAnalytics() }
    Registration(LoggerService.self, default: CloudLogger(level: .info))
}
#endif
```

### Module Separation
```swift
enum NetworkModule {
    static func register() {
        UnifiedDI.registerMany {
            Registration(HTTPClient.self) { URLSessionHTTPClient() }
            Registration(APIService.self) { APIServiceImpl() }
            Registration(NetworkReachability.self) { NetworkReachability.shared }
        }
    }
}

enum DataModule {
    static func register() {
        UnifiedDI.registerMany {
            Registration(DatabaseService.self) { CoreDataService() }
            Registration(CacheService.self) { NSCacheService() }
            Registration(KeychainService.self) { KeychainService.shared }
        }
    }
}

// In app initialization
await WeaveDI.Container.bootstrap { container in
    NetworkModule.register()
    DataModule.register()
}
```

## 📊 Performance Characteristics Comparison

| Feature | UnifiedDI | DI (Simplified) |
|---------|-----------|-----------------|
| Basic registration/resolution | ✅ Optimized | ✅ Optimized |
| Conditional registration | ✅ Supported | ❌ Not supported |
| Performance tracking | ✅ Built-in | ❌ Not supported |
| Batch registration | ✅ Result Builder DSL | ❌ Not supported |
| KeyPath registration | ✅ Supported | ❌ Not supported |
| Scopes (.screen/.session/.request) | ✅ Register/resolve/release support | ❌ Not supported |
| Async singletons (single initialization guarantee) | ✅ Supported (GlobalUnifiedRegistry) | ❌ Not supported |
| Automatic graph collection option | ✅ Supported (CircularDependencyDetector) | ❌ Not supported |
| Error strategies | ✅ Various (throws, default, etc.) | ✅ Basic only |
| Learning curve | Medium | Low |
| Memory overhead | Low | Very low |

## 🎯 Conclusion and Recommendations

### ✅ Choose UnifiedDI
- Production app development
- Team development environments
- Complex dependency graphs
- When performance optimization is critical
- When test-friendly architecture is needed

### ✅ Choose DI (Simplified)
- Prototype development
- Learning purposes
- Very simple projects
- When minimal dependency management is needed

### 💡 Best Practice
We recommend using **UnifiedDI** in most cases. It provides more features while allowing you to use only what you need, making it highly scalable.

```swift
// Recommended pattern: Start with UnifiedDI and expand features as needed
@main
struct MyApp: App {
    init() {
        Task {
            await setupDependencies()
        }
    }

    private func setupDependencies() async {
        // Use UnifiedDI's powerful batch registration
        UnifiedDI.registerMany {
            // Basic services
            Registration(NetworkService.self) { NetworkServiceImpl() }
            Registration(UserService.self) { UserServiceImpl() }

            // Environment-specific conditional registration
            Registration(AnalyticsService.self,
                        condition: !isDebug,
                        factory: { GoogleAnalytics() },
                        fallback: { NoOpAnalytics() })
        }

        // Enable performance optimization
        await UnifiedDI.enablePerformanceOptimization()
    }
}
```

## 🔬 Note: If "Compile-time Absolute Guarantee/Ultra-low Overhead" is the Goal

This framework focuses on runtime DI (flexibility/tools/concurrency optimization). If Needle-style **compile-time guarantees** and **ultra-low overhead** are top priorities:

- Switch to code generation-based static binding instead of registry/runtime lookup
- Component (Dependencies/Provides) declarations → generate wire code at build time
- Remove property wrappers/dictionaries/casting from production hot paths, replace with constructor injection/direct references

This approach can provide significant benefits depending on the team/domain. The current repo could also consider a gradual transition strategy (debug=runtime DI, release=code generation DI).

---

📖 **Documentation**: [한국어](../ko.lproj/UnifiedDI) | [English](UnifiedDI)
