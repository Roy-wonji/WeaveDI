# WeaveDI Roadmap

This document outlines the future development plans, upcoming features, and long-term vision for WeaveDI. We're committed to making WeaveDI the most powerful, efficient, and developer-friendly dependency injection framework for Swift.

## Version History & Current Status

### Current Version: 3.4.0 ✅ (Released 2025-12-27)

**v3.4.0 New Features:**
- 🆕 **DiModuleFactory Added** - Systematic management of common DI dependencies (Logger, Config, etc.)
- 🔄 **ModuleFactoryManager Extended** - Simplified dependency registration with DiModuleFactory integration
- ⚙️ **AppDIManager Enhanced** - Automatic DiModuleFactory registration in default factories
- 🎯 **Type-Safe Dependency Management** - Safer DI with compile-time type verification
- 🏗️ **WeaveDI.builder Pattern** - New fluent API for intuitive dependency registration
- ⚡ **v3.4.0 Highlight** - Next-generation DependencyBuilder and enhanced @Dependency support
- 📦 **Module Structure Improvements** - Clear role separation with WeaveDICore, WeaveDIAppDI, etc.
- 🔧 **TCA Conflict Resolution** - Perfect compatibility with The Composable Architecture

**v3.3.0 Previous Features:**
- ✅ **Environment Flags Performance Optimization** - Achieved 0% overhead in production
- ✅ **TCA Bridge Policy Configuration** - Dynamic dependency priority control
- ✅ **Modern Batch Registration DSL** - Result Builder-based declarative registration
- ✅ **ComponentDiagnostics System** - Automatic dependency analysis and issue detection
- ✅ **Advanced Performance Monitoring** - Memory-efficient tracking and optimization suggestions
- ✅ **Complete Warning Resolution** - Enhanced type safety improvements

**Previous Features (v3.2.x):**
- ✅ Swift 6.0 full compatibility with strict concurrency
- ✅ Actor-aware dependency injection with `@DIContainerActor`
- ✅ **@Injected Property Wrapper** - TCA-style dependency injection
- ✅ **AppDI Simplification** - Streamlined app initialization with `AppDIManager`
- ✅ Runtime optimization with TypeID and lock-free reading
- ✅ TCA (The Composable Architecture) integration
- ✅ Multi-scope dependency management
- ✅ Comprehensive testing utilities
- ✅ Bilingual documentation (English & Korean)

**Removed Features:**
- ❌ `@Inject` - Removed in 3.2.0 (use `@Injected`)
- ❌ `@SafeInject` - Removed in 3.2.0 (use `@Injected`)

**Performance Metrics (v3.3.0):**
- ⚡ 50-80% faster dependency resolution vs v2.x
- 🧠 2-3x better memory efficiency in multi-threaded scenarios
- 🚀 Complete zero-cost abstractions in production environments
- 📊 Real-time performance insights in development environments

### Latest Development Highlights (December 2025)

#### 🏗️ WeaveDI.builder Pattern

New fluent API for much more intuitive dependency registration:

```swift
// Traditional approach
UnifiedDI.register(UserService.self) { UserServiceImpl() }
UnifiedDI.register(Logger.self) { ConsoleLogger() }

// New builder pattern
WeaveDI.builder
    .register { UserServiceImpl() }    // Automatic type inference
    .register { ConsoleLogger() }      // Automatic type inference
    .configure()
```

#### ⚡ v3.4.0 Feature Highlights

Experience the new DependencyBuilder and @Dependency enhancements available in v3.4.0:

```swift
@DependencyConfiguration
var dependencies {
    UserService()     // Automatic type inference
    NetworkClient()   // Simple registration
    Logger()          // No keypath registration
}

// Enhanced @Dependency
@Dependency var userService: UserService  // Works without keypath
```

#### 📦 Major Module Structure Overhaul

More clear and maintainable module structure:

- **WeaveDICore**: Core DI engine
- **WeaveDIAppDI**: App-level dependency management
- **WeaveDITCA**: Dedicated The Composable Architecture integration
- **WeaveDIMacros**: Swift macro support
- **WeaveDIOptimizations**: Performance optimization dedicated

#### 🔧 Perfect TCA Compatibility Achievement

```swift
// TCA and WeaveDI now work perfectly together
struct AppFeature: Reducer {
    @Dependency(\.userService) var userService: UserService  // TCA

    struct State {
        @Injected var logger: Logger  // WeaveDI - no conflicts!
    }
}
```

#### Enhancements
- 🚀 **Enhanced @Factory**: Support for complex factory patterns with parameters
- 🔍 **Better Error Messages**: More descriptive runtime error reporting
- 🧪 **Testing Improvements**: Simplified mock injection patterns
- ⚙️ **Build-Time Validation**: Compile-time dependency verification

#### Code Examples (Preview)

```swift
// WeaveDI Inspector Integration
#if DEBUG
import WeaveDIInspector

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .weaveDIInspector() // Visual dependency graph overlay
        }
    }
}
#endif

// Enhanced @Factory with parameters (planned)
@Factory(.parameters(userId: String.self, theme: Theme.self))
var userProfileService: UserProfileService
```

### Version 3.4.0 📋 (Q2 2026)

**Focus: Advanced Architecture Patterns**

#### Major Features
- 🏗️ **Module System 2.0**: Enhanced modular architecture support
- 🔄 **Dependency Scopes**: Request, session, and custom scope management
- 🎭 **Interface Segregation**: Automatic protocol-based dependency injection
- 🌐 **Distributed Dependencies**: Support for remote service injection

#### New Architectural Patterns

```swift
// Module System 2.0
@Module
struct UserModule {
    @Provides
    func userService() -> UserService {
        UserServiceImpl()
    }

    @Provides @Singleton
    func userRepository(@Injected networkService: NetworkService) -> UserRepository {
        CoreDataUserRepository(networkService: networkService)
    }
}

// Advanced Scopes
@RequestScoped
class RequestHandler {
    @Injected var requestId: RequestID  // Unique per request
    @Injected var userContext: UserContext  // Scoped to request
}

// Distributed Dependencies
@RemoteService("user-service")
var remoteUserService: UserService?  // Injected from microservice
```

### Version 3.4.0 🎯 (Q3 2025)

**Focus: Enterprise & Production Features**

#### Enterprise Features
- 🏢 **Enterprise Container**: Multi-tenant dependency isolation
- 📈 **Metrics & Monitoring**: Production-grade performance metrics
- 🔐 **Security**: Dependency access control and validation
- 🔄 **Hot Reloading**: Runtime dependency updates without restart

#### Production Optimizations

```swift
// Enterprise Container
@Enterprise
class MultiTenantApp {
    @TenantIsolated
    @Injected var tenantService: TenantService?  // Isolated per tenant

    @Shared
    @Injected var sharedCache: CacheService?  // Shared across tenants
}

// Hot Reloading (Development)
#if DEBUG
WeaveDI.enableHotReloading { newDependencies in
    // Update dependencies without app restart
    print("🔄 Reloaded \(newDependencies.count) dependencies")
}
#endif

// Production Metrics
ProductionMetrics.configure {
    reportDependencyResolutionTimes(threshold: .milliseconds(10))
    alertOnMissingDependencies()
    trackMemoryUsage(interval: .minutes(5))
}
```

## Long-term Vision (2025-2026)

### Version 4.0.0 🌟 (Q4 2025)

**Revolutionary Features:**

#### 🤖 AI-Powered Dependency Management
- **Automatic Dependency Discovery**: AI suggests missing dependencies
- **Performance Optimization**: ML-powered optimization recommendations
- **Code Generation**: Auto-generate boilerplate DI code
- **Testing**: AI-generated test scenarios and mocks

#### 🔮 Predictive Performance
- **Usage Prediction**: Pre-load dependencies based on usage patterns
- **Memory Optimization**: Predictive garbage collection for dependencies
- **Load Balancing**: Automatic load distribution across multiple containers

#### 🌈 Next-Gen Developer Experience
- **Visual Programming**: Drag-and-drop dependency graph builder
- **Real-time Collaboration**: Team-based dependency management
- **Integrated Debugging**: Step-through dependency resolution

### Future Explorations (2026+)

#### Cross-Platform Expansion
- 🖥️ **macOS**: Native macOS app support with AppKit integration
- ⌚ **watchOS**: Optimized for watch complications and background tasks
- 📺 **tvOS**: Focus on memory-efficient TV app architectures
- 🐧 **Swift on Server**: Linux server-side Swift support

#### Advanced Language Features
- 🎭 **Swift Macros 2.0**: Next-generation macro system integration
- 🔗 **Property Wrappers 3.0**: Enhanced property wrapper capabilities
- ⚡ **Concurrency Evolution**: Integration with future Swift concurrency features

## Community & Ecosystem

### Planned Integrations

#### UI Frameworks
- ✅ **SwiftUI**: Full integration (Current)
- ✅ **TCA**: Comprehensive support (v3.1.0)
- 🔄 **UIKit**: Enhanced integration (v3.2.0)
- 📋 **Vapor**: Server-side Swift support (v3.3.0)

#### Testing Frameworks
- ✅ **XCTest**: Native support (Current)
- 📋 **Quick/Nimble**: First-class integration (v3.2.0)
- 📋 **SwiftTesting**: New Swift testing framework support (v3.3.0)

#### Build Tools & CI/CD
- 🔧 **Xcode Cloud**: Enhanced integration
- 📋 **GitHub Actions**: Pre-built workflows for WeaveDI projects
- 📋 **Fastlane**: Automatic dependency validation in deployment
- 🔧 **SwiftPM**: Advanced package management features

### Community Features

#### Documentation & Learning
- 📚 **Interactive Tutorials**: Step-by-step learning paths
- 🎥 **Video Courses**: Comprehensive WeaveDI mastery courses
- 📖 **Best Practices Guide**: Real-world architecture patterns
- 🌍 **Multilingual Docs**: Support for more languages

#### Developer Tools
- 🔧 **Xcode Extensions**: Enhanced IDE integration
- 📱 **WeaveDI Studio**: Standalone dependency management tool
- 🌐 **Web Dashboard**: Cloud-based project analytics
- 📊 **Dependency Analyzer**: Static analysis and reporting

## Technical Roadmap

### Performance Improvements

#### Current Benchmarks (v3.1.0)
```
Dependency Resolution:
- Simple resolve: ~0.01ms (50-80% faster than v2.x)
- Complex graph: ~0.05ms (20-40% improvement)
- Concurrent access: 2-3x faster (lock-free reading)

Memory Usage:
- Memory footprint: 60% smaller than v2.x
- Garbage collection: 40% less frequent
- Peak memory: 30% reduction in large apps
```

#### Target Benchmarks (v4.0.0)
```
Dependency Resolution:
- Simple resolve: ~0.005ms (2x faster than v3.1.0)
- Complex graph: ~0.02ms (2.5x improvement)
- Predictive loading: Near-zero resolution time

Memory Usage:
- Memory footprint: 80% smaller than v2.x
- Zero-copy dependency sharing
- Predictive memory management
```

### Swift Language Evolution

#### Swift 6.x Features
- ✅ **Strict Concurrency**: Full compliance (v3.1.0)
- 📋 **Enhanced Macros**: Advanced macro capabilities (v3.2.0)
- 📋 **Typed Throws**: Better error handling (v3.3.0)
- 🔮 **Region-based Memory**: Memory safety improvements (v4.0.0)

#### Future Swift Features
- 🔮 **Ownership System**: Zero-copy dependency injection
- 🔮 **Effect System**: Functional effects integration
- 🔮 **Distributed Actors**: Native remote dependency support

## Breaking Changes & Migration

### Version 3.x → 4.0.0 Migration

#### Deprecated APIs (Will be removed in v4.0.0)
```swift
// ❌ Deprecated in v3.2.0, removed in v4.0.0
UnifiedDI.register(SomeService.self) { SomeServiceImpl() }

// ✅ New syntax in v4.0.0
@Provides
func someService() -> SomeService { SomeServiceImpl() }
```

#### Migration Timeline
- **v3.2.0**: Deprecation warnings introduced
- **v3.3.0**: Migration tools provided
- **v3.4.0**: Final warnings before v4.0.0
- **v4.0.0**: Clean slate with breaking changes

## Request Features & Feedback

We value community input in shaping WeaveDI's future. Here's how you can contribute:

### How to Request Features

1. 📋 **GitHub Issues**: Create feature request with detailed use cases
2. 💬 **Discussions**: Join ongoing architecture discussions
3. 🗳️ **Feature Voting**: Vote on community-proposed features
4. 🎯 **RFC Process**: Submit formal Request for Comments

### Priority Decision Process

**High Priority:**
- Developer experience improvements
- Performance optimizations
- Swift evolution compatibility
- Critical bug fixes

**Medium Priority:**
- New architecture patterns
- Advanced tooling features
- Community-requested integrations
- Documentation enhancements

**Low Priority:**
- Experimental features
- Niche use cases
- Platform-specific optimizations
- Legacy compatibility

## Get Involved

### Contribution Opportunities

#### Code Contributions
- 🐛 **Bug Fixes**: Help improve stability
- ⚡ **Performance**: Optimize critical paths
- 🆕 **Features**: Implement roadmap items
- 🧪 **Tests**: Expand test coverage

#### Documentation & Community
- 📚 **Documentation**: Improve guides and tutorials
- 🌍 **Translations**: Help translate docs to more languages
- 🎥 **Content Creation**: Create tutorials and examples
- 💬 **Community Support**: Help other developers

#### Testing & Feedback
- 🧪 **Beta Testing**: Test pre-release versions
- 📊 **Performance Testing**: Help benchmark improvements
- 🐛 **Bug Reports**: Report issues with detailed reproduction
- 💡 **Feature Feedback**: Share thoughts on proposed features

### How to Contribute

1. **Fork the Repository**: [WeaveDI GitHub](https://github.com/Roy-wonji/WeaveDI)
2. **Read Contributing Guide**: Follow our contribution guidelines
3. **Join Discussions**: Participate in feature planning
4. **Submit PRs**: Contribute code improvements

## Timeline Summary

| Version | Release Date | Focus | Key Features |
|---------|-------------|-------|--------------|
| **v3.2.0** | ✅ Oct 1, 2025 | TCA-Style DI | @Injected, AppDI Simplification |
| **v3.1.0** | Sep 27, 2025 | Performance | Runtime optimization, Lock-free |
| **v3.3.0** | Q1 2026 | Developer Tools | Inspector, Enhanced Profiler |
| **v3.4.0** | Q2 2026 | Architecture | Module system 2.0, Scopes |
| **v4.0.0** | Q4 2026 | Breaking Changes | Remove @Injected, @SafeInject |

---

**Join us in building the future of dependency injection in Swift!**

For questions, suggestions, or discussions about this roadmap:
- 📧 Email: [suhwj81@gmail.com](mailto:suhwj81@gmail.com)
- 🐙 GitHub: [Roy-wonji/WeaveDI](https://github.com/Roy-wonji/WeaveDI)
- 💬 Discussions: [GitHub Discussions](https://github.com/Roy-wonji/WeaveDI/discussions)
