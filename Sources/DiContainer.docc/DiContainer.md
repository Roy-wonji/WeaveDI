# DiContainer

A high-performance Swift dependency injection framework designed for modern Swift concurrency.

## Overview

DiContainer is a comprehensive dependency injection solution that provides type-safe, performant, and Swift Concurrency-native dependency management for iOS, macOS, watchOS, and tvOS applications.

### Key Features

- **🚀 High Performance**: Actor Hop optimization reduces initialization overhead by up to 10x
- **⚡ Swift Concurrency Native**: Built from the ground up for async/await and Actor isolation
- **🔒 Type Safe**: Compile-time type safety with KeyPath-based registration
- **📝 Property Wrappers**: Modern `@Factory`, `@Inject`, and `@RequiredInject` support
- **🏗️ Module System**: Organize dependencies with reusable modules
- **🔌 Plugin Architecture**: Extensible plugin system for custom behaviors
- **🧪 Test-Friendly**: Built-in support for dependency mocking and test isolation

### Quick Start

```swift
import DiContainer

// 1. Bootstrap your dependencies (once at app startup)
await DependencyContainer.bootstrap { container in
    container.register(UserService.self) { UserServiceImpl() }
    container.register(NetworkService.self) { URLSessionNetworkService() }
}

// 2. Use dependency injection in your code
class UserViewController: UIViewController {
    @Inject var userService: UserService

    override func viewDidLoad() {
        super.viewDidLoad()

        Task {
            let user = try await userService.getCurrentUser()
            updateUI(with: user)
        }
    }
}
```

## Topics

### Getting Started

- <doc:QuickStart>
- <doc:Migration-Guide>
- <doc:Best-Practices>

### Core APIs

- ``DI``
- ``DependencyContainer``
- ``Module``
- ``Container``

### Property Wrappers

- ``Factory``
- ``Inject``
- ``RequiredInject``

### Advanced Features

- <doc:Bootstrap-System>
- <doc:Actor-Hop-Optimization>
- <doc:Module-System>
- <doc:Plugin-Architecture>
- <doc:Auto-Resolution>

### Testing

- <doc:Testing-Guide>
- <doc:Mock-Registration>

### Performance

- <doc:Performance-Guide>
- <doc:Benchmarks>