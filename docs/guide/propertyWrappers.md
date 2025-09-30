# Property Wrapper Guide

Complete guide to implementing declarative and type-safe dependency injection using WeaveDI's powerful Property Wrappers. This guide covers Swift 5/6 compatibility, advanced patterns, and real-world usage scenarios.

## Overview

WeaveDI leverages Swift's Property Wrapper feature to make dependency injection more declarative and intuitive. Through Property Wrappers like `@Inject`, `@Factory`, and `@SafeInject`, you can solve complex dependency management with simple annotations.

### Swift Version Compatibility

| Swift Version | Property Wrapper Features | WeaveDI Support |
|---------------|---------------------------|------------------|
| **Swift 6.0+** | Full strict concurrency, Sendable compliance | ✅ Complete support with actor safety |
| **Swift 5.9+** | Advanced property wrappers, async/await | ✅ Full feature support |
| **Swift 5.8+** | Basic property wrappers | ✅ Core functionality |
| **Swift 5.7+** | Property wrapper basics | ⚠️ Limited features |

### Key Benefits

- **🔒 Type Safety**: Compile-time dependency verification
- **📝 Declarative**: Clean, readable injection syntax
- **⚡ Performance**: Optimized resolution with lazy loading
- **🧪 Testable**: Easy mock injection for testing
- **🔄 Thread Safe**: Safe across actors and async contexts

## @Inject - Universal Dependency Injection

### Basic Usage

`@Inject` is the most commonly used Property Wrapper, supporting both type-based and KeyPath-based injection.

#### Swift 6 Enhanced Safety

```swift
import WeaveDI

// Swift 6: Sendable-compliant services
protocol UserService: Sendable {
    func getUser(id: String) async throws -> User
}

@MainActor
class UserViewController {
    @Inject private var userService: UserService?
    @Inject private var logger: Logger?

    func loadUser() async {
        // Safe actor-isolated access
        guard let service = userService else {
            logger?.error("UserService not available")
            return
        }

        do {
            let user = try await service.getUser(id: "current")
            // Update UI on main actor
            await updateUI(with: user)
        } catch {
            logger?.error("Failed to load user: \(error)")
        }
    }

    @MainActor
    private func updateUI(with user: User) {
        // UI updates happen safely on main actor
    }
}
```

#### Basic Type-Based Injection

```swift
import WeaveDI

class UserService {
    // Type-based injection - optional
    @Inject var repository: UserRepositoryProtocol?
    @Inject var logger: LoggerProtocol?

    // Type-based injection - required (force unwrapping)
    @Inject var networkService: NetworkServiceProtocol!

    func getUser(id: String) async throws -> User {
        logger?.info("Starting user lookup: \(id)")

        guard let repository = repository else {
            throw ServiceError.repositoryNotAvailable
        }

        let user = try await repository.findUser(by: id)
        logger?.info("User lookup completed: \(user.name)")
        return user
    }
}
```

### KeyPath-based Injection

```swift
// WeaveDI.Container extension
extension WeaveDI.Container {
    var userRepository: UserRepositoryProtocol? {
        resolve(UserRepositoryProtocol.self)
    }

    var database: DatabaseServiceProtocol? {
        resolve(DatabaseServiceProtocol.self)
    }

    var logger: LoggerProtocol? {
        resolve(LoggerProtocol.self)
    }
}

// Using KeyPath-based injection
class DatabaseManager {
    @Inject(\.database) var database: DatabaseServiceProtocol?
    @Inject(\.logger) var logger: LoggerProtocol!

    func performMigration() async throws {
        logger.info("Starting database migration")

        guard let database = database else {
            logger.error("Database service is unavailable")
            throw DatabaseError.serviceUnavailable
        }

        try await database.runMigrations()
        logger.info("Database migration completed")
    }
}
```

## @Factory - Factory Instance Injection

### Basic Concept

`@Factory` is a Property Wrapper that injects factory instances managed by `FactoryValues`. It is primarily used in modularized architectures.

```swift
// FactoryValues extension
extension FactoryValues {
    var repositoryFactory: RepositoryModuleFactory {
        get { self[RepositoryModuleFactory.self] ?? RepositoryModuleFactory() }
        set { self[RepositoryModuleFactory.self] = newValue }
    }

    var useCaseFactory: UseCaseModuleFactory {
        get { self[UseCaseModuleFactory.self] ?? UseCaseModuleFactory() }
        set { self[UseCaseModuleFactory.self] = newValue }
    }
}
```

## @RequiredInject - Required Dependency Injection

### Basic Usage

`@RequiredInject` is a strict Property Wrapper that triggers a `fatalError` if dependency resolution fails.

```swift
class CriticalService {
    // Essential dependencies - app terminates if resolution fails
    @RequiredInject var database: DatabaseServiceProtocol
    @RequiredInject var securityService: SecurityServiceProtocol

    // KeyPath-based required dependency
    @RequiredInject(\.logger) var logger: LoggerProtocol

    func performCriticalOperation() async throws {
        // database and securityService are always guaranteed to be valid
        try await securityService.validateAccess()
        let result = try await database.executeCriticalQuery()
        logger.info("Critical operation completed: \(result)")
    }
}
```

## Advanced Usage Patterns

### Usage with Actor

```swift
@MainActor
class UIService {
    @Inject var userService: UserServiceProtocol?
    @Inject var imageLoader: ImageLoaderProtocol!

    func updateUserProfile(_ user: User) async {
        // Safely executed in MainActor context
        let profileImage = await imageLoader.loadImage(from: user.profileImageURL)
        // UI updates...
    }
}

actor DataProcessor {
    @Inject var databaseService: DatabaseServiceProtocol?
    @Inject var analyticsService: AnalyticsServiceProtocol!

    func processUserData(_ data: UserData) async throws {
        // Safely executed in Actor context
        try await databaseService?.store(data)
        await analyticsService.track(event: "data_processed")
    }
}
```

### SwiftUI Integration

```swift
import SwiftUI
import WeaveDI

struct UserProfileView: View {
    @StateObject private var viewModel = UserProfileViewModel()

    var body: some View {
        VStack {
            AsyncImage(url: viewModel.user?.profileImageURL)
            Text(viewModel.user?.name ?? "Loading...")

            Button("Refresh") {
                Task {
                    await viewModel.loadUserData()
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadUserData()
            }
        }
    }
}

@MainActor
class UserProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Inject var userService: UserServiceProtocol?
    @Inject var logger: LoggerProtocol!

    func loadUserData() async {
        isLoading = true
        errorMessage = nil

        do {
            guard let userService = userService else {
                throw ServiceError.serviceUnavailable("UserService")
            }

            let loadedUser = try await userService.getCurrentUser()
            self.user = loadedUser
            logger.info("User data loaded successfully")
        } catch {
            self.errorMessage = error.localizedDescription
            logger.error("User data loading failed: \(error)")
        }

        isLoading = false
    }
}
```

## Testing Usage

### Mock Injection

```swift
// Mock service for testing
class MockUserService: UserServiceProtocol {
    var mockUser: User?
    var shouldThrowError = false

    func getCurrentUser() async throws -> User {
        if shouldThrowError {
            throw ServiceError.networkError
        }
        return mockUser ?? User.mockUser
    }
}

class UserServiceTests: XCTestCase {
    var mockUserService: MockUserService!

    override func setUp() async throws {
        await super.setUp()

        // Register mock service
        mockUserService = MockUserService()
        DI.register(UserServiceProtocol.self, instance: mockUserService)
    }

    func testUserLoading() async throws {
        // Given
        let expectedUser = User(id: "test", name: "Test User")
        mockUserService.mockUser = expectedUser

        // Test target class (Mock is automatically injected)
        let viewModel = UserProfileViewModel()

        // When
        await viewModel.loadUserData()

        // Then
        XCTAssertEqual(viewModel.user?.id, expectedUser.id)
        XCTAssertEqual(viewModel.user?.name, expectedUser.name)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
}
```

Dependency injection through Property Wrappers is one of WeaveDI's most powerful features. It is declarative, type-safe, and naturally integrates with Swift's language features, greatly enhancing the developer experience.