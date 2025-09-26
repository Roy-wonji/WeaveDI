# Quick Start Guide

Get up and running with WeaveDI in minutes

## Overview

This guide will walk you through the essential steps to integrate WeaveDI into your project and start using dependency injection effectively.

## Installation

Add WeaveDI to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.2.0")
]
```

## Basic Setup

### 1. Import WeaveDI

```swift
import WeaveDI
```

### 2. Define Your Services

```swift
protocol UserService {
    func fetchUser() async -> User
}

class UserServiceImpl: UserService {
    func fetchUser() async -> User {
        // Implementation
    }
}
```

### 3. Register Dependencies

```swift
// At app startup
let userService = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}
```

### 4. Use Property Wrappers

```swift
class ViewController {
    @Inject var userService: UserService?

    func loadData() async {
        let user = await userService?.fetchUser()
        // Use the user data
    }
}
```

## Advanced Features

### Enable Runtime Optimization

For high-performance applications:

```swift
// Enable hot-path optimization
UnifiedRegistry.shared.enableOptimization()

// Your existing code automatically gets 50-80% performance improvement
let service = await UnifiedDI.resolve(UserService.self)
```

### Bootstrap Pattern

For complex apps:

```swift
await DIContainer.bootstrap { container in
    container.register(UserService.self) { UserServiceImpl() }
    container.register(APIService.self) { APIServiceImpl() }
}
```

## Next Steps

- Learn about <doc:PropertyWrappers>
- Explore <doc:RuntimeOptimization>
- Check out <doc:CoreAPIs>

---

📖 **Documentation**: [한국어](../ko.lproj/QuickStart) | [English](QuickStart)