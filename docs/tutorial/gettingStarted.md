# Getting Started with WeaveDI

Build your first iOS app with WeaveDI step by step. This tutorial uses actual WeaveDI APIs based on the real source code.

## 🎯 What You'll Build

A simple user profile app that demonstrates:
- Basic dependency registration and resolution
- Property wrapper injection
- Swift Concurrency with WeaveDI
- Testing with dependency injection

## 📱 Project Setup

### 1. Create New iOS Project

```bash
# Create a new iOS project in Xcode
# File → New → Project → iOS → App
# Name: UserProfileApp
```

### 2. Add WeaveDI Package

```swift
// In Package.swift or Xcode Package Manager
dependencies: [
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.1.0")
]
```

### 3. Import WeaveDI

```swift
import WeaveDI
```

## 🏗️ Step 1: Define Your Models

First, let's define our data models:

```swift
// Models/User.swift
import Foundation

struct User: Codable, Sendable {
    let id: String
    let name: String
    let email: String
    let avatarURL: URL?

    init(id: String, name: String, email: String, avatarURL: URL? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.avatarURL = avatarURL
    }
}

enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError
}
```

## 🔧 Step 2: Create Service Protocols

Define the contracts for your services:

```swift
// Services/UserService.swift
import Foundation

/// Protocol for user-related operations
protocol UserService: Sendable {
    func fetchUser(id: String) async throws -> User
    func updateUser(_ user: User) async throws
    func deleteUser(id: String) async throws
}

/// Protocol for network operations
protocol NetworkService: Sendable {
    func fetchData(from url: URL) async throws -> Data
    func postData(_ data: Data, to url: URL) async throws -> Data
}

/// Protocol for local storage
protocol CacheService: Sendable {
    func getUser(id: String) -> User?
    func setUser(_ user: User, id: String)
    func removeUser(id: String)
    func clearAll()
}
```

## 🛠️ Step 3: Implement Services (Real WeaveDI Patterns)

Now let's implement these services using actual WeaveDI patterns:

```swift
// Services/UserServiceImpl.swift
import Foundation
import WeaveDI

/// Real implementation using WeaveDI dependency injection
class UserServiceImpl: UserService {
    // Using actual @Inject from WeaveDI source code
    @Inject var networkService: NetworkService?
    @Inject var cacheService: CacheService?

    func fetchUser(id: String) async throws -> User {
        print("🔍 Fetching user: \(id)")

        // Step 1: Check cache first (performance optimization)
        if let cachedUser = cacheService?.getUser(id: id) {
            print("✅ Found user in cache: \(cachedUser.name)")
            return cachedUser
        }

        // Step 2: Fetch from network
        guard let network = networkService else {
            throw NetworkError.noData
        }

        let url = URL(string: "https://api.example.com/users/\(id)")!
        let data = try await network.fetchData(from: url)

        // Step 3: Parse and cache
        let user = try JSONDecoder().decode(User.self, from: data)
        cacheService?.setUser(user, id: id)

        print("🌐 Fetched user from network: \(user.name)")
        return user
    }

    func updateUser(_ user: User) async throws {
        guard let network = networkService else {
            throw NetworkError.noData
        }

        let url = URL(string: "https://api.example.com/users/\(user.id)")!
        let userData = try JSONEncoder().encode(user)

        _ = try await network.postData(userData, to: url)

        // Update cache
        cacheService?.setUser(user, id: user.id)
        print("✅ User updated: \(user.name)")
    }

    func deleteUser(id: String) async throws {
        // Implementation for delete
        cacheService?.removeUser(id: id)
        print("🗑️ User deleted: \(id)")
    }
}
```

```swift
// Services/NetworkServiceImpl.swift
import Foundation

class NetworkServiceImpl: NetworkService {
    private let session = URLSession.shared

    func fetchData(from url: URL) async throws -> Data {
        print("🌐 Fetching data from: \(url)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // For demo purposes, return mock data
        let mockUser = User(
            id: UUID().uuidString,
            name: "John Doe",
            email: "john@example.com",
            avatarURL: URL(string: "https://avatar.example.com/john.jpg")
        )

        return try JSONEncoder().encode(mockUser)
    }

    func postData(_ data: Data, to url: URL) async throws -> Data {
        print("📤 Posting data to: \(url)")

        // Simulate network request
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        return Data() // Success response
    }
}
```

```swift
// Services/CacheServiceImpl.swift
import Foundation

class CacheServiceImpl: CacheService {
    private var cache: [String: User] = [:]
    private let queue = DispatchQueue(label: "cache.queue", attributes: .concurrent)

    func getUser(id: String) -> User? {
        return queue.sync {
            cache[id]
        }
    }

    func setUser(_ user: User, id: String) {
        queue.async(flags: .barrier) {
            self.cache[id] = user
        }
        print("💾 Cached user: \(user.name)")
    }

    func removeUser(id: String) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: id)
        }
    }

    func clearAll() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
        print("🧹 Cache cleared")
    }
}
```

## 📱 Step 4: Create ViewModel (Using Real WeaveDI APIs)

```swift
// ViewModels/UserProfileViewModel.swift
import Foundation
import SwiftUI
import WeaveDI

@MainActor
class UserProfileViewModel: ObservableObject {
    // Using actual WeaveDI property wrappers from source code
    @Inject var userService: UserService?

    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Load user profile using WeaveDI injected service
    func loadUser(id: String) async {
        print("📱 ViewModel: Loading user \(id)")

        isLoading = true
        errorMessage = nil

        do {
            guard let service = userService else {
                throw NetworkError.noData
            }

            // Using the injected service
            let loadedUser = try await service.fetchUser(id: id)
            self.user = loadedUser

        } catch {
            self.errorMessage = error.localizedDescription
            print("❌ Error loading user: \(error)")
        }

        isLoading = false
    }

    /// Update user profile
    func updateUser(_ updatedUser: User) async {
        guard let service = userService else { return }

        do {
            try await service.updateUser(updatedUser)
            self.user = updatedUser
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    /// Refresh current user
    func refresh() async {
        guard let currentUser = user else { return }
        await loadUser(id: currentUser.id)
    }
}
```

## 🎨 Step 5: Create SwiftUI Views

```swift
// Views/UserProfileView.swift
import SwiftUI

struct UserProfileView: View {
    @StateObject private var viewModel = UserProfileViewModel()
    let userId: String

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView("Loading user...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let user = viewModel.user {
                    UserDetailView(user: user) {
                        Task {
                            await viewModel.refresh()
                        }
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage) {
                        Task {
                            await viewModel.loadUser(id: userId)
                        }
                    }
                } else {
                    Text("No user data")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("User Profile")
            .task {
                await viewModel.loadUser(id: userId)
            }
        }
    }
}

struct UserDetailView: View {
    let user: User
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            AsyncImage(url: user.avatarURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())

            Text(user.name)
                .font(.title2)
                .fontWeight(.bold)

            Text(user.email)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Refresh", action: onRefresh)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Error")
                .font(.title2)
                .fontWeight(.bold)

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

## ⚙️ Step 6: Bootstrap Dependencies (Real WeaveDI Bootstrap)

This is where the magic happens using actual WeaveDI APIs:

```swift
// App/UserProfileApp.swift
import SwiftUI
import WeaveDI

@main
struct UserProfileApp: App {

    init() {
        // Configure dependencies when app starts
        Task {
            await configureDependencies()
        }
    }

    var body: some Scene {
        WindowGroup {
            UserProfileView(userId: "user123")
        }
    }

    /// Configure all app dependencies using actual WeaveDI bootstrap
    private func configureDependencies() async {
        print("🚀 Configuring app dependencies...")

        // Using actual DependencyContainer.bootstrap from WeaveDI source
        await DependencyContainer.bootstrap { container in

            // Register network service
            container.register(NetworkService.self) {
                NetworkServiceImpl()
            }

            // Register cache service
            container.register(CacheService.self) {
                CacheServiceImpl()
            }

            // Register user service (depends on network & cache)
            container.register(UserService.self) {
                UserServiceImpl()
            }
        }

        print("✅ Dependencies configured successfully")
    }
}
```

## 🧪 Step 7: Add Tests (Real WeaveDI Testing Patterns)

```swift
// Tests/UserServiceTests.swift
import XCTest
@testable import UserProfileApp
import WeaveDI

final class UserServiceTests: XCTestCase {

    override func setUp() async throws {
        await super.setUp()

        // Clean slate for each test using actual WeaveDI APIs
        await DependencyContainer.bootstrap { container in
            // Register mock services for testing
            container.register(NetworkService.self) {
                MockNetworkService()
            }

            container.register(CacheService.self) {
                MockCacheService()
            }

            container.register(UserService.self) {
                UserServiceImpl()
            }
        }
    }

    func testFetchUser_Success() async throws {
        // Given
        let userService: UserService = UnifiedDI.resolve(UserService.self)!

        // When
        let user = try await userService.fetchUser(id: "test123")

        // Then
        XCTAssertEqual(user.id, "test123")
        XCTAssertFalse(user.name.isEmpty)
    }

    func testFetchUser_CacheHit() async throws {
        // Given
        let userService: UserService = UnifiedDI.resolve(UserService.self)!
        let cacheService: CacheService = UnifiedDI.resolve(CacheService.self)!

        let cachedUser = User(id: "cached123", name: "Cached User", email: "cached@example.com")
        cacheService.setUser(cachedUser, id: "cached123")

        // When
        let user = try await userService.fetchUser(id: "cached123")

        // Then
        XCTAssertEqual(user.name, "Cached User")
    }
}

// Mock services for testing
class MockNetworkService: NetworkService {
    func fetchData(from url: URL) async throws -> Data {
        let mockUser = User(id: "test123", name: "Test User", email: "test@example.com")
        return try JSONEncoder().encode(mockUser)
    }

    func postData(_ data: Data, to url: URL) async throws -> Data {
        return Data()
    }
}

class MockCacheService: CacheService {
    private var cache: [String: User] = [:]

    func getUser(id: String) -> User? { cache[id] }
    func setUser(_ user: User, id: String) { cache[id] = user }
    func removeUser(id: String) { cache.removeValue(forKey: id) }
    func clearAll() { cache.removeAll() }
}
```

## 🎯 Key Takeaways

You've just built a complete iOS app with WeaveDI! Here's what you learned:

### ✅ Real WeaveDI Features Used:
1. **@Inject Property Wrapper** - Automatic dependency injection
2. **DependencyContainer.bootstrap** - Safe app initialization
3. **UnifiedDI.resolve()** - Clean dependency resolution
4. **Swift Concurrency Support** - Native async/await integration
5. **Test-Friendly Design** - Easy mocking and isolation

### 🚀 Performance Benefits:
- **Lazy Loading**: Dependencies created only when needed
- **Type Safety**: Compile-time verification
- **Actor Safety**: Thread-safe operations
- **Memory Efficient**: Optimal resource usage

### 📈 Next Steps:
- [Property Wrappers Deep Dive](/tutorial/propertyWrappers)
- [Swift Concurrency Integration](/tutorial/concurrencyIntegration)
- [Testing Strategies](/tutorial/testing)

## 🔗 Complete Source Code

The complete project is available on GitHub: [UserProfileApp Example](https://github.com/Roy-wonji/WeaveDI/tree/main/Examples/UserProfileApp)

---

**Congratulations!** You've successfully built your first app with WeaveDI using real production patterns. Your app now has clean architecture, type-safe dependency injection, and excellent testability.