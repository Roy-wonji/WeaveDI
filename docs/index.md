---
layout: home

hero:
  name: "WeaveDI"
  text: "Modern Dependency Injection for Swift"
  tagline: High-performance DI framework with Swift Concurrency support
  image:
    src: /logo.svg
    alt: WeaveDI
  actions:
    - theme: brand
      text: Get Started
      link: /guide/quickStart
    - theme: alt
      text: View on GitHub
      link: https://github.com/Roy-wonji/WeaveDI

features:
  - icon: 🚀
    title: Runtime Hot Path Optimization
    details: TypeID + lock-free reads improve performance by 50-80%. Lightning-fast dependency resolution.
    link: /guide/runtimeOptimization
  - icon: 🎭
    title: Actor Hop Optimization
    details: Intelligently optimizes transitions between different Actor contexts to achieve maximum performance.
    link: /guide/diActor
  - icon: 🔒
    title: Complete Type Safety
    details: KeyPath-based registration and strong type inference provide compile-time validation.
    link: /guide/unifiedDi
  - icon: 📝
    title: Intuitive Property Wrappers
    details: "@Inject, @Factory, @SafeInject - simple and powerful dependency injection patterns."
    link: /guide/propertyWrappers
  - icon: 🏗️
    title: Powerful Module System
    details: AppDIContainer, ModuleFactory, Container for scalable dependency management.
    link: /guide/moduleSystem
  - icon: 🧪
    title: Test-Friendly Design
    details: Easy mocking, isolated tests, and reliable bootstrap reset for testing.
    link: /guide/bootstrap
---

## Quick Example

```swift
import WeaveDI

// 1. Bootstrap dependencies at app startup
await DependencyContainer.bootstrap { container in
    container.register(UserServiceProtocol.self) {
        UserService()
    }

    container.register(\.userRepository) {
        UserRepositoryImpl()
    }
}

// 2. Use property wrappers for injection
class ViewController {
    @Inject var userService: UserServiceProtocol?
    @Factory var dataProcessor: DataProcessor

    func loadUserData() async {
        guard let service = userService else { return }
        let userData = await service.fetchUser()
        updateUI(with: userData)
    }
}

// 3. Modern async/await support
let userService = await UnifiedDI.resolve(UserService.self)
let userData = await userService?.fetchUserData()
```

## Performance Metrics

| Scenario | Legacy DI | WeaveDI 3.1.0 | Improvement |
|----------|-----------|---------------|-------------|
| Single dependency resolution | 0.8ms | 0.2ms | **75%** |
| Complex dependency graph | 15.6ms | 3.1ms | **80%** |
| MainActor UI update | 3.1ms | 0.6ms | **81%** |

## Why WeaveDI?

WeaveDI 3.1.0 is designed for modern Swift applications, providing:

- Support for **iOS 15.0+, macOS 14.0+, watchOS 8.0+, tvOS 15.0+**
- **Swift Concurrency** first-class integration
- **Actor model** optimization
- **Zero-cost abstraction** in release builds
- **Comprehensive testing** support

*A framework for Swift developers*
