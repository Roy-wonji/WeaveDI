# Quick Start Guide

Get up and running with WeaveDI in 5 minutes.

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.2.0")
]
```

### Xcode

1. File → Add Package Dependencies
2. Enter: `https://github.com/Roy-wonji/WeaveDI.git`
3. Add Package

## Basic Usage

### 1. Import

```swift
import WeaveDI
```

### 2. Define Services

```swift
protocol UserService {
    func fetchUser(id: String) async -> User?
}

class UserServiceImpl: UserService {
    func fetchUser(id: String) async -> User? {
        // Implementation
        return User(id: id, name: "John")
    }
}
```

### 3. Register Dependencies

```swift
// Register at app startup
let userService = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}
```

### 4. Use Property Wrappers

```swift
class UserViewController {
    @Inject var userService: UserService?

    func loadUser() async {
        guard let service = userService else { return }
        let user = await service.fetchUser(id: "123")
        // Update UI
    }
}
```

## Property Wrappers

### @Inject - Optional Dependencies

```swift
class ViewController {
    @Inject var userService: UserService?

    func viewDidLoad() {
        userService?.fetchUser(id: "current")
    }
}
```

### @Factory - New Instance Each Time

```swift
class DocumentProcessor {
    @Factory var pdfGenerator: PDFGenerator

    func createDocument() {
        let generator = pdfGenerator // New instance
        generator.generate()
    }
}
```

### @SafeInject - Error Handling

```swift
class DataManager {
    @SafeInject var database: Database?

    func save(_ data: Data) throws {
        guard let db = database else {
            throw DIError.dependencyNotFound
        }
        try db.save(data)
    }
}
```

## Advanced Features

### Runtime Optimization

```swift
// Enable optimization for better performance
UnifiedRegistry.shared.enableOptimization()
```

### Bootstrap Pattern

```swift
await DIContainer.bootstrap { container in
    container.register(UserService.self) { UserServiceImpl() }
    container.register(DatabaseService.self) { DatabaseServiceImpl() }
}
```

## Next Steps

- [Property Wrappers](/guide/property-wrappers) - Detailed injection patterns
- [Core APIs](/api/core-apis) - Complete API reference
- [Runtime Optimization](/guide/runtime-optimization) - Performance tuning