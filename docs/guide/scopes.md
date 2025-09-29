# Scopes Guide (Screen / Session / Request)

WeaveDI's scope system provides powerful dependency isolation and caching capabilities by organizing dependencies into context-specific containers. This enables efficient memory management and proper lifecycle control for different types of application state including screen-level, session-level, and request-level dependencies.

## Overview

Scopes solve the fundamental problem of dependency lifecycle management in complex applications. Without scopes, all dependencies would either be global singletons (sharing state inappropriately) or recreated on every access (inefficient). Scopes provide a middle ground where dependencies can be cached and reused within appropriate boundaries while being automatically cleaned up when those boundaries are crossed.

**Key Benefits**:
- **Memory Efficiency**: Dependencies are cached within scope boundaries and cleaned up automatically
- **State Isolation**: Screen-specific or session-specific state doesn't leak between contexts
- **Performance Optimization**: Avoid unnecessary object recreation within the same scope
- **Lifecycle Management**: Automatic cleanup when scopes are cleared

## Why Do We Need Scopes?

Scopes address specific architectural patterns and performance requirements in modern applications:

### 1. Screen-Level State Management
**Problem**: UI components need to share state within a screen but isolate it from other screens.

**Solution**: Screen scopes ensure ViewModels, caches, and screen-specific services are shared within one screen but cleaned up when navigating away.

```swift
// Example: Image cache should be shared within photo gallery screen
// but cleared when user navigates to different screen
```

### 2. User Session Management
**Problem**: User-specific services should be available throughout the user's session but completely cleaned up on logout.

**Solution**: Session scopes automatically manage user-specific dependencies with proper cleanup on session termination.

```swift
// Example: User preferences, notification settings, and personalization data
// should persist during session but be cleared on logout
```

### 3. Request Context Management
**Problem**: In server-side or request-heavy applications, request-specific data should be isolated and cleaned up after request completion.

**Solution**: Request scopes ensure thread-safe isolation of request-specific data with automatic cleanup.

```swift
// Example: HTTP request context, tracing information, and temporary processing data
// should be isolated per request and cleaned up after response is sent
```

## Core Types and APIs

### ScopeKind
Defines the three built-in scope types, each optimized for different use cases:

```swift
enum ScopeKind {
    case screen    // UI navigation boundaries
    case session   // User session boundaries
    case request   // Request/operation boundaries
}
```

**Scope Characteristics**:
- **Screen**: Typically short-lived (seconds to minutes), UI-focused
- **Session**: Medium to long-lived (minutes to hours), user-focused
- **Request**: Very short-lived (milliseconds to seconds), operation-focused

### ScopeContext
Central management system for scope lifecycle and identification:

```swift
class ScopeContext {
    // Set current scope with unique identifier
    func setCurrent(_ kind: ScopeKind, id: String)

    // Clear specific scope and cleanup all associated dependencies
    func clear(_ kind: ScopeKind)

    // Check current scope ID (useful for debugging)
    func currentID(for kind: ScopeKind) -> String?
}
```

**Context Management Patterns**:
- **Hierarchical IDs**: Use meaningful IDs like "ProfileScreen", "UserSession_123", "Request_UUID"
- **Automatic Cleanup**: Always pair `setCurrent` with `clear` for proper memory management
- **Thread Safety**: All ScopeContext operations are thread-safe and actor-compatible

### Registration APIs
Scoped registration methods provide both synchronous and asynchronous dependency creation:

```swift
// Synchronous scoped registration
func registerScoped<T>(
    _ type: T.Type,
    scope: ScopeKind,
    factory: @escaping () -> T
)

// Asynchronous scoped registration
func registerAsyncScoped<T>(
    _ type: T.Type,
    scope: ScopeKind,
    factory: @escaping () async -> T
)
```

## Detailed Usage Examples

### Screen Scope - Complete Navigation Example

Screen scopes are perfect for managing UI-specific dependencies that should be isolated between different screens or view controllers.

**Purpose**: Manage dependencies that should persist during screen lifetime but be cleaned up on navigation.

**Lifecycle**: Created on screen appearance, cached during screen lifetime, destroyed on screen disappearance.

```swift
class HomeViewController: UIViewController {
    @Inject var viewModel: HomeViewModel?
    @Inject var imageCache: ImageCache?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set up screen scope with unique identifier
        ScopeContext.shared.setCurrent(.screen, id: "HomeScreen")

        // Register screen-specific dependencies
        Task {
            await GlobalUnifiedRegistry.registerScoped(HomeViewModel.self, scope: .screen) {
                HomeViewModel(
                    userService: UnifiedDI.resolve(UserService.self)!,
                    analytics: UnifiedDI.resolve(AnalyticsService.self)
                )
            }

            await GlobalUnifiedRegistry.registerScoped(ImageCache.self, scope: .screen) {
                ImageCache(maxSize: 50_000_000) // 50MB cache for this screen
            }

            // Dependencies are now available and cached within this screen
            setupUI()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // Clear screen scope - automatically cleans up HomeViewModel and ImageCache
        ScopeContext.shared.clear(.screen)

        print("✅ Screen dependencies cleaned up")
    }

    private func setupUI() {
        // These will resolve to the same cached instances
        let vm1 = UnifiedDI.resolve(HomeViewModel.self)
        let vm2 = UnifiedDI.resolve(HomeViewModel.self)
        // vm1 === vm2 (same instance)

        let cache1 = UnifiedDI.resolve(ImageCache.self)
        let cache2 = UnifiedDI.resolve(ImageCache.self)
        // cache1 === cache2 (same instance)
    }
}
```

**Advanced Screen Scope Pattern**:

```swift
// Screen scope with child scopes for complex UI
class DetailViewController: UIViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Main screen scope
        ScopeContext.shared.setCurrent(.screen, id: "DetailScreen_\(itemID)")

        Task {
            // Register main screen dependencies
            await GlobalUnifiedRegistry.registerScoped(DetailViewModel.self, scope: .screen) {
                DetailViewModel(itemID: self.itemID)
            }

            // Register child component dependencies with hierarchical IDs
            await GlobalUnifiedRegistry.registerScoped(CommentListViewModel.self, scope: .screen) {
                CommentListViewModel(itemID: self.itemID)
            }

            await GlobalUnifiedRegistry.registerScoped(RelatedItemsViewModel.self, scope: .screen) {
                RelatedItemsViewModel(itemID: self.itemID)
            }
        }
    }
}
```

### Session Scope - User Authentication Example

Session scopes manage user-specific dependencies that should persist across multiple screens within a user session.

**Purpose**: Cache user-specific services and data throughout the user's authenticated session.

**Lifecycle**: Created on successful authentication, persists across app usage, destroyed on logout or session expiration.

```swift
class AuthenticationManager {
    func handleSuccessfulLogin(user: User) async {
        // Set up session scope with user identifier
        ScopeContext.shared.setCurrent(.session, id: "UserSession_\(user.id)")

        // Register session-specific dependencies
        await GlobalUnifiedRegistry.registerScoped(UserSession.self, scope: .session) {
            UserSession(
                user: user,
                preferences: user.preferences,
                permissions: user.permissions
            )
        }

        await GlobalUnifiedRegistry.registerScoped(NotificationManager.self, scope: .session) {
            NotificationManager(
                userID: user.id,
                settings: user.notificationSettings
            )
        }

        await GlobalUnifiedRegistry.registerScoped(PersonalizationService.self, scope: .session) {
            PersonalizationService(
                userID: user.id,
                preferences: user.preferences
            )
        }

        // Session dependencies are now available app-wide
        print("✅ User session established with scoped dependencies")
    }

    func handleLogout() {
        // Clear session scope - automatically cleans up all user-specific dependencies
        ScopeContext.shared.clear(.session)

        print("✅ User session cleared, all user-specific dependencies cleaned up")

        // Navigate to login screen
        navigateToLogin()
    }
}

// Usage across the app - session dependencies are available everywhere
class ProfileViewController: UIViewController {
    @Inject var userSession: UserSession?
    @Inject var personalization: PersonalizationService?

    override func viewDidLoad() {
        super.viewDidLoad()

        // These resolve to the same cached instances established during login
        guard let session = userSession else { return }
        guard let personalizer = personalization else { return }

        // Use session data
        displayUserProfile(session.user)
        applyPersonalization(personalizer.getTheme())
    }
}
```

**Advanced Session Scope with Refresh**:

```swift
class SessionManager {
    func refreshSession() async {
        guard let currentUserID = ScopeContext.shared.currentID(for: .session) else { return }

        // Clear current session
        ScopeContext.shared.clear(.session)

        // Re-establish with refreshed data
        let refreshedUser = try await fetchUpdatedUserData()
        await handleSuccessfulLogin(user: refreshedUser)
    }
}
```

### Request Scope - Server-Side Pattern

Request scopes are ideal for server-side applications or client applications that process many independent operations.

**Purpose**: Isolate dependencies per request/operation to prevent data mixing and enable proper cleanup.

**Lifecycle**: Created at request start, used throughout request processing, destroyed at request completion.

```swift
class APIRequestHandler {
    func handleIncomingRequest(_ httpRequest: HTTPRequest) async -> HTTPResponse {
        // Create unique request scope
        let requestID = UUID().uuidString
        ScopeContext.shared.setCurrent(.request, id: "Request_\(requestID)")

        defer {
            // Ensure cleanup even if request fails
            ScopeContext.shared.clear(.request)
        }

        do {
            // Register request-specific dependencies
            await GlobalUnifiedRegistry.registerAsyncScoped(RequestContext.self, scope: .request) {
                await RequestContext.create(
                    requestID: requestID,
                    userAgent: httpRequest.headers["User-Agent"],
                    traceID: httpRequest.headers["X-Trace-ID"] ?? requestID
                )
            }

            await GlobalUnifiedRegistry.registerAsyncScoped(RequestLogger.self, scope: .request) {
                RequestLogger(requestID: requestID)
            }

            await GlobalUnifiedRegistry.registerAsyncScoped(DatabaseTransaction.self, scope: .request) {
                await DatabaseTransaction.begin()
            }

            // Process request with scoped dependencies
            let response = await processRequest(httpRequest)

            // Commit transaction if successful
            if let transaction = await UnifiedDI.resolveAsync(DatabaseTransaction.self) {
                await transaction.commit()
            }

            return response

        } catch {
            // Rollback transaction on error
            if let transaction = await UnifiedDI.resolveAsync(DatabaseTransaction.self) {
                await transaction.rollback()
            }

            throw error
        }
    }

    private func processRequest(_ request: HTTPRequest) async -> HTTPResponse {
        // These resolve to request-specific cached instances
        let context = await UnifiedDI.resolveAsync(RequestContext.self)!
        let logger = await UnifiedDI.resolveAsync(RequestLogger.self)!

        logger.info("Processing request: \(context.requestID)")

        // Business logic here...
        // All dependencies are isolated to this specific request

        return HTTPResponse.ok()
    }
}
```

**Concurrent Request Handling**:

```swift
class ConcurrentAPIServer {
    func handleMultipleRequests(_ requests: [HTTPRequest]) async {
        // Process multiple requests concurrently, each with isolated scope
        await withTaskGroup(of: HTTPResponse.self) { group in
            for request in requests {
                group.addTask {
                    await self.handleIncomingRequest(request)
                }
            }
        }
        // Each request had its own isolated dependencies
    }
}
```

## Lifecycle Management Patterns

### iOS App Lifecycle Integration

```swift
class AppDelegate: UIResponder, UIApplicationDelegate {
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Set up app-level scope if needed
        ScopeContext.shared.setCurrent(.session, id: "AppSession_\(Date().timeIntervalSince1970)")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Clear temporary scopes to free memory
        ScopeContext.shared.clear(.screen)

        // Keep session scope for when app returns to foreground
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Clear all scopes
        ScopeContext.shared.clear(.session)
        ScopeContext.shared.clear(.screen)
        ScopeContext.shared.clear(.request)
    }
}
```

### SwiftUI Integration

```swift
struct ContentView: View {
    var body: some View {
        NavigationView {
            HomeView()
        }
        .onAppear {
            ScopeContext.shared.setCurrent(.screen, id: "MainNavigation")
        }
        .onDisappear {
            ScopeContext.shared.clear(.screen)
        }
    }
}

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        VStack {
            // UI content
        }
        .task {
            // Set up screen scope
            ScopeContext.shared.setCurrent(.screen, id: "HomeView")

            // Register scoped dependencies
            await GlobalUnifiedRegistry.registerScoped(HomeScreenCache.self, scope: .screen) {
                HomeScreenCache()
            }
        }
    }
}
```

## Advanced Patterns

### Hierarchical Scopes

```swift
// Parent scope for major sections
ScopeContext.shared.setCurrent(.session, id: "ShoppingSession")

// Child scope for specific flow
ScopeContext.shared.setCurrent(.screen, id: "CheckoutFlow")

// When clearing, clear child scopes first
ScopeContext.shared.clear(.screen)  // Clear checkout flow
// Session continues until user logs out
```

### Conditional Scope Registration

```swift
func registerDependencies() async {
    let scopeID = ScopeContext.shared.currentID(for: .screen)

    if scopeID?.contains("Admin") == true {
        // Admin-specific dependencies
        await GlobalUnifiedRegistry.registerScoped(AdminService.self, scope: .screen) {
            AdminService()
        }
    } else {
        // Regular user dependencies
        await GlobalUnifiedRegistry.registerScoped(UserService.self, scope: .screen) {
            UserService()
        }
    }
}
```

### Scope Transition Handling

```swift
class NavigationManager {
    func navigateToScreen(_ screenID: String) async {
        // Clear current screen scope
        ScopeContext.shared.clear(.screen)

        // Set new screen scope
        ScopeContext.shared.setCurrent(.screen, id: screenID)

        // Register new screen dependencies
        await registerDependenciesForScreen(screenID)
    }
}
```

## Performance Considerations

### Memory Management
- **Scope Size**: Keep scope boundaries appropriate to avoid excessive memory usage
- **Cleanup Timing**: Clear scopes promptly when contexts end
- **Cache Limits**: Consider memory limits when caching large objects in scopes

### Concurrency Performance
- **Thread Safety**: All scope operations are thread-safe
- **Actor Integration**: Works seamlessly with Swift's actor model
- **Parallel Access**: Multiple threads can safely access scoped dependencies

### Debugging and Monitoring

```swift
// Check current scope status
func debugScopes() {
    let screenID = ScopeContext.shared.currentID(for: .screen)
    let sessionID = ScopeContext.shared.currentID(for: .session)
    let requestID = ScopeContext.shared.currentID(for: .request)

    print("Current Scopes:")
    print("  Screen: \(screenID ?? "none")")
    print("  Session: \(sessionID ?? "none")")
    print("  Request: \(requestID ?? "none")")
}

// Monitor scope lifecycle
class ScopeMonitor {
    static func logScopeChange(_ kind: ScopeKind, _ action: String, id: String?) {
        print("🔍 Scope \(action): \(kind) - \(id ?? "nil")")
    }
}
```

## Troubleshooting Guide

### Common Issues and Solutions

#### "Scope is not applied"
**Symptoms**: Dependencies not being cached, new instances created every time
**Cause**: Scope ID not set before registration
**Solution**:
```swift
// ❌ Wrong order
await GlobalUnifiedRegistry.registerScoped(MyService.self, scope: .screen) { MyService() }
ScopeContext.shared.setCurrent(.screen, id: "MyScreen") // Too late!

// ✅ Correct order
ScopeContext.shared.setCurrent(.screen, id: "MyScreen")
await GlobalUnifiedRegistry.registerScoped(MyService.self, scope: .screen) { MyService() }
```

#### "Memory leak detected"
**Symptoms**: Memory usage growing over time, objects not being released
**Cause**: Forgot to call `clear()` when scope ends
**Solution**:
```swift
// ✅ Always pair setCurrent with clear
override func viewWillAppear(_ animated: Bool) {
    ScopeContext.shared.setCurrent(.screen, id: "MyScreen")
    // Register dependencies...
}

override func viewDidDisappear(_ animated: Bool) {
    ScopeContext.shared.clear(.screen) // Essential cleanup!
}
```

#### "Concurrency issues"
**Symptoms**: Race conditions, unexpected behavior in multi-threaded code
**Solution**: WeaveDI scopes are inherently thread-safe, but ensure proper async/await usage:
```swift
// ✅ Proper async registration
await GlobalUnifiedRegistry.registerAsyncScoped(AsyncService.self, scope: .request) {
    await AsyncService.create()
}

// ✅ Proper async resolution
let service = await UnifiedDI.resolveAsync(AsyncService.self)
```

#### "Dependencies not found"
**Symptoms**: Resolution returns nil even after registration
**Cause**: Scope cleared between registration and resolution
**Solution**: Verify scope lifecycle matches dependency usage:
```swift
func checkScopeStatus() {
    if ScopeContext.shared.currentID(for: .screen) == nil {
        print("⚠️ Screen scope not set - dependencies will not be cached")
    }
}
```

## Best Practices Summary

### 1. Scope Lifecycle Management
- Always pair `setCurrent` with `clear`
- Use meaningful, unique scope IDs
- Clear scopes promptly when contexts end

### 2. Dependency Design
- Group related dependencies in the same scope
- Avoid cross-scope dependencies when possible
- Design dependencies to be scope-aware

### 3. Performance Optimization
- Monitor memory usage in long-lived scopes
- Use request scopes for short-lived operations
- Clear unused scopes proactively

### 4. Error Handling
- Use defer blocks to ensure cleanup
- Handle scope transitions gracefully
- Provide fallback behavior when scopes are not available

> **Important**: If scope ID is not set, scope registration behaves as one-time creation (no caching). This can lead to unexpected behavior where you expect caching but get new instances every time.

## See Also

- [Core APIs](../api/coreApis.md) - Detailed registration and resolution methods
- [Property Wrappers](./propertyWrappers.md) - Using scoped dependencies with @Inject
- [Bootstrap Guide](./bootstrap.md) - Setting up scoped dependencies at app startup