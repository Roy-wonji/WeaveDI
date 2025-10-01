# SwiftUI Integration

Learn how to effectively use WeaveDI with SwiftUI views, property wrappers, and previews.

## Using DI in SwiftUI Views

### Basic View Injection

```swift
struct UserProfileView: View {
    @Injected(\.userService) var userService
    @Injected(\.imageLoader) var imageLoader

    @State private var user: User?
    @State private var isLoading = false

    var body: some View {
        VStack {
            if let user = user {
                AsyncImage(url: user.avatarURL)
                Text(user.name)
                Text(user.email)
            } else if isLoading {
                ProgressView()
            }
        }
        .task {
            await loadUser()
        }
    }

    private func loadUser() async {
        isLoading = true
        defer { isLoading = false }

        do {
            user = try await userService.fetchCurrentUser()
        } catch {
            print("Failed to load user: \(error)")
        }
    }
}
```

## Integration with ObservableObject

### ViewModel with DI

```swift
@MainActor
final class UserProfileViewModel: ObservableObject {
    @Injected(\.userService) var userService
    @Injected(\.authService) var authService

    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadUser() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            user = try await userService.fetchCurrentUser()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() async {
        do {
            try await authService.logout()
            user = nil
        } catch {
            errorMessage = "Failed to logout"
        }
    }
}

// Use in View
struct UserProfileView: View {
    @StateObject private var viewModel = UserProfileViewModel()

    var body: some View {
        VStack {
            if let user = viewModel.user {
                Text(user.name)
                Button("Logout") {
                    Task { await viewModel.logout() }
                }
            } else if viewModel.isLoading {
                ProgressView()
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
        }
        .task {
            await viewModel.loadUser()
        }
    }
}
```

## SwiftUI Previews with DI

### Basic Preview Configuration

```swift
struct UserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        // Method 1: Using withInjectedValues
        UserProfileView()
            .task {
                await withInjectedValues { values in
                    values.userService = MockUserService()
                    values.authService = MockAuthService()
                } operation: {}
            }
    }
}
```

### Advanced Preview with Custom Dependencies

```swift
struct UserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview 1: Loading state
            PreviewWithDependencies(
                userService: LoadingUserService()
            ) {
                UserProfileView()
            }
            .previewDisplayName("Loading")

            // Preview 2: Success state
            PreviewWithDependencies(
                userService: MockUserService(user: .preview)
            ) {
                UserProfileView()
            }
            .previewDisplayName("Success")

            // Preview 3: Error state
            PreviewWithDependencies(
                userService: ErrorUserService()
            ) {
                UserProfileView()
            }
            .previewDisplayName("Error")
        }
    }
}

// Helper for Preview DI
struct PreviewWithDependencies<Content: View>: View {
    let userService: UserService
    let content: Content

    init(
        userService: UserService,
        @ViewBuilder content: () -> Content
    ) {
        self.userService = userService
        self.content = content()
    }

    var body: some View {
        content
            .task {
                await withInjectedValues { values in
                    values.userService = userService
                } operation: {}
            }
    }
}
```

## Environment vs @Injected

### When to Use Environment

**Use SwiftUI Environment when:**
- You need to pass values down the view hierarchy
- The value is UI-specific (colors, fonts, layout)
- You want to override values for specific view subtrees

```swift
// Environment approach
struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.light
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            ThemedButton()
        }
        .environment(\.theme, .dark)
    }
}

struct ThemedButton: View {
    @Environment(\.theme) var theme

    var body: some View {
        Button("Press Me") {}
            .foregroundColor(theme.primaryColor)
    }
}
```

### When to Use @Injected

**Use @Injected when:**
- You need business logic services
- The dependency is app-wide (not view-specific)
- You want compile-time type safety with KeyPath
- You need to test with different implementations

```swift
// @Injected approach
struct OrderListView: View {
    @Injected(\.orderService) var orderService
    @State private var orders: [Order] = []

    var body: some View {
        List(orders) { order in
            OrderRow(order: order)
        }
        .task {
            orders = try await orderService.fetchOrders()
        }
    }
}
```

### Comparison Table

| Feature | Environment | @Injected |
|---------|------------|-----------|
| Scope | View hierarchy | App-wide |
| Type Safety | Runtime | Compile-time (KeyPath) |
| Override | Per view subtree | Global or scoped |
| Use Case | UI configuration | Business logic |
| Testing | Pass via `.environment()` | `withInjectedValues` |
| Performance | View-specific | Singleton/Scoped |

## Combining @Injected with @State and @Binding

### Parent-Child Data Flow

```swift
// Parent View
struct OrderManagementView: View {
    @Injected(\.orderService) var orderService
    @State private var orders: [Order] = []
    @State private var selectedOrder: Order?

    var body: some View {
        NavigationView {
            List(orders) { order in
                Button(order.title) {
                    selectedOrder = order
                }
            }
            .sheet(item: $selectedOrder) { order in
                OrderDetailView(order: order)
            }
            .task {
                await loadOrders()
            }
        }
    }

    private func loadOrders() async {
        do {
            orders = try await orderService.fetchOrders()
        } catch {
            print("Failed to load orders")
        }
    }
}

// Child View
struct OrderDetailView: View {
    @Injected(\.orderService) var orderService
    let order: Order

    @State private var isProcessing = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            Text(order.title)
            Text("Total: \(order.total)")

            Button("Process Order") {
                Task { await processOrder() }
            }
            .disabled(isProcessing)
        }
    }

    private func processOrder() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await orderService.processOrder(order)
            dismiss()
        } catch {
            print("Failed to process order")
        }
    }
}
```

## Advanced Patterns

### View Modifier for DI

```swift
struct WithMockData: ViewModifier {
    func body(content: Content) -> some View {
        content
            .task {
                await withInjectedValues { values in
                    values.userService = MockUserService()
                    values.orderService = MockOrderService()
                } operation: {}
            }
    }
}

extension View {
    func withMockData() -> some View {
        modifier(WithMockData())
    }
}

// Usage in Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .withMockData()
    }
}
```

### DI Container View

```swift
struct DIContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        setupDependencies()
    }

    private func setupDependencies() {
        // Setup production dependencies
        Task {
            await withInjectedValues { values in
                values.userService = ProductionUserService()
                values.orderService = ProductionOrderService()
            } operation: {}
        }
    }

    var body: some View {
        content
    }
}

// Usage
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            DIContainer {
                ContentView()
            }
        }
    }
}
```

### Observable Macro Integration (iOS 17+)

```swift
import Observation

@Observable
final class UserProfileViewModel {
    @Injected(\.userService) var userService

    var user: User?
    var isLoading = false
    var errorMessage: String?

    @MainActor
    func loadUser() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            user = try await userService.fetchCurrentUser()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// View (iOS 17+)
struct UserProfileView: View {
    @State private var viewModel = UserProfileViewModel()

    var body: some View {
        VStack {
            if let user = viewModel.user {
                Text(user.name)
            } else if viewModel.isLoading {
                ProgressView()
            }
        }
        .task {
            await viewModel.loadUser()
        }
    }
}
```

## Testing SwiftUI Views

### Unit Testing ViewModels

```swift
import XCTest
@testable import MyApp

final class UserProfileViewModelTests: XCTestCase {
    func testLoadUser() async throws {
        await withInjectedValues { values in
            values.userService = MockUserService(user: .testUser)
        } operation: {
            let viewModel = UserProfileViewModel()

            await viewModel.loadUser()

            XCTAssertNotNil(viewModel.user)
            XCTAssertEqual(viewModel.user?.name, "Test User")
            XCTAssertFalse(viewModel.isLoading)
        }
    }

    func testLoadUserError() async throws {
        await withInjectedValues { values in
            values.userService = ErrorUserService()
        } operation: {
            let viewModel = UserProfileViewModel()

            await viewModel.loadUser()

            XCTAssertNil(viewModel.user)
            XCTAssertNotNil(viewModel.errorMessage)
        }
    }
}
```

### Snapshot Testing with Dependencies

```swift
import SnapshotTesting
@testable import MyApp

final class UserProfileViewSnapshotTests: XCTestCase {
    func testUserProfileViewSuccess() async {
        await withInjectedValues { values in
            values.userService = MockUserService(user: .preview)
        } operation: {
            let view = UserProfileView()
            assertSnapshot(matching: view, as: .image)
        }
    }

    func testUserProfileViewLoading() async {
        await withInjectedValues { values in
            values.userService = LoadingUserService()
        } operation: {
            let view = UserProfileView()
            assertSnapshot(matching: view, as: .image)
        }
    }
}
```

## Best Practices

### ✅ Do's

```swift
// ✅ Use @Injected for business logic
struct ProductListView: View {
    @Injected(\.productService) var productService
}

// ✅ Use @StateObject for ViewModels
struct ProductListView: View {
    @StateObject private var viewModel = ProductListViewModel()
}

// ✅ Configure dependencies in previews
struct ProductListView_Previews: PreviewProvider {
    static var previews: some View {
        ProductListView()
            .task {
                await withInjectedValues { values in
                    values.productService = MockProductService()
                } operation: {}
            }
    }
}

// ✅ Keep Views focused on presentation
struct ProductRow: View {
    let product: Product

    var body: some View {
        HStack {
            Text(product.name)
            Spacer()
            Text("$\(product.price)")
        }
    }
}
```

### ❌ Don'ts

```swift
// ❌ Don't inject heavy services directly into small views
struct ProductPriceLabel: View {
    @Injected(\.productService) var productService  // Too granular
    let productId: String
}

// ❌ Don't create dependencies in View body
struct ProductListView: View {
    var body: some View {
        let service = ProductService()  // Wrong!
        // ...
    }
}

// ❌ Don't mix Environment and @Injected for same dependency
struct ProductView: View {
    @Environment(\.productService) var envService
    @Injected(\.productService) var injectedService  // Confusing
}
```

## Migration from Environment to @Injected

### Before (Environment)

```swift
// Old Environment approach
struct ProductServiceKey: EnvironmentKey {
    static let defaultValue: ProductService = ProductServiceImpl()
}

extension EnvironmentValues {
    var productService: ProductService {
        get { self[ProductServiceKey.self] }
        set { self[ProductServiceKey.self] = newValue }
    }
}

struct ProductListView: View {
    @Environment(\.productService) var productService
}

// Set in parent
ContentView()
    .environment(\.productService, MockProductService())
```

### After (@Injected)

```swift
// New @Injected approach
struct ProductServiceKey: InjectedKey {
    static var liveValue: ProductService = ProductServiceImpl()
    static var testValue: ProductService = MockProductService()
}

extension InjectedValues {
    var productService: ProductService {
        get { self[ProductServiceKey.self] }
        set { self[ProductServiceKey.self] = newValue }
    }
}

struct ProductListView: View {
    @Injected(\.productService) var productService
}

// Test configuration
await withInjectedValues { values in
    values.productService = MockProductService()
} operation: {
    // Test code
}
```

## Next Steps

- [Testing Guide](../tutorial/testing) - Learn how to test SwiftUI views with DI
- [TCA Integration](./tcaIntegration) - Using WeaveDI with The Composable Architecture
- [Best Practices](./bestPractices) - General DI best practices
- [Practical Guide](./practicalGuide) - Real-world usage patterns
