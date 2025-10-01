# Real-World Examples

Practical examples of using WeaveDI in production applications across different domains.

## E-Commerce App

### Project Structure

```
ShopApp/
├── Features/
│   ├── Product/
│   ├── Cart/
│   ├── Checkout/
│   └── User/
├── Core/
│   ├── Networking/
│   ├── Database/
│   ├── Analytics/
│   └── Payment/
└── App/
```

### Dependency Setup

```swift
// App/DI/AppDI.swift
import WeaveDI

final class ShopAppDI {
    static func bootstrap() async {
        await WeaveDI.Container.bootstrap { container in
            // Infrastructure
            registerInfrastructure(in: container)

            // Features
            registerProductFeature(in: container)
            registerCartFeature(in: container)
            registerCheckoutFeature(in: container)
            registerUserFeature(in: container)
        }
    }

    private static func registerInfrastructure(in container: WeaveDI.Container) {
        // API Client
        container.register(APIClient.self, scope: .singleton) {
            URLSessionAPIClient(
                baseURL: Configuration.apiBaseURL,
                timeout: 30
            )
        }

        // Database
        container.register(Database.self, scope: .singleton) {
            RealmDatabase(configuration: .defaultConfiguration)
        }

        // Analytics
        container.register(Analytics.self, scope: .singleton) {
            FirebaseAnalytics()
        }

        // Payment
        container.register(PaymentProcessor.self, scope: .singleton) {
            StripePaymentProcessor(publishableKey: Configuration.stripeKey)
        }
    }

    private static func registerProductFeature(in container: WeaveDI.Container) {
        container.register(ProductRepository.self) {
            ProductRepositoryImpl()
        }

        container.register(ProductService.self) {
            ProductServiceImpl()
        }
    }

    private static func registerCartFeature(in container: WeaveDI.Container) {
        container.register(CartRepository.self) {
            CartRepositoryImpl()
        }

        container.register(CartService.self, scope: .singleton) {
            CartServiceImpl()
        }
    }

    private static func registerCheckoutFeature(in container: WeaveDI.Container) {
        container.register(OrderRepository.self) {
            OrderRepositoryImpl()
        }

        container.register(CheckoutService.self) {
            CheckoutServiceImpl()
        }
    }

    private static func registerUserFeature(in container: WeaveDI.Container) {
        container.register(AuthRepository.self) {
            AuthRepositoryImpl()
        }

        container.register(UserService.self, scope: .singleton) {
            UserServiceImpl()
        }
    }
}
```

### Product Feature

```swift
// Features/Product/ProductListViewModel.swift
import WeaveDI

@MainActor
final class ProductListViewModel: ObservableObject {
    @Injected(\.productService) var productService
    @Injected(\.cartService) var cartService
    @Injected(\.analytics) var analytics

    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var error: Error?

    func loadProducts(category: String) async {
        isLoading = true
        defer { isLoading = false }

        analytics.track(.productListViewed(category: category))

        do {
            products = try await productService.fetchProducts(category: category)
        } catch {
            self.error = error
            analytics.track(.error(error, context: "product_list"))
        }
    }

    func addToCart(_ product: Product) async {
        do {
            try await cartService.addItem(product)
            analytics.track(.productAddedToCart(product: product))
        } catch {
            self.error = error
        }
    }
}

// Features/Product/ProductListView.swift
import SwiftUI

struct ProductListView: View {
    @StateObject private var viewModel = ProductListViewModel()
    let category: String

    var body: some View {
        List(viewModel.products) { product in
            ProductRow(product: product) {
                Task {
                    await viewModel.addToCart(product)
                }
            }
        }
        .task {
            await viewModel.loadProducts(category: category)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}
```

### Cart Feature with Real-time Sync

```swift
// Features/Cart/CartService.swift
import WeaveDI
import Combine

protocol CartService {
    var itemCount: AnyPublisher<Int, Never> { get }
    var items: [CartItem] { get }

    func addItem(_ product: Product) async throws
    func removeItem(_ itemId: String) async throws
    func updateQuantity(_ itemId: String, quantity: Int) async throws
    func clearCart() async throws
}

final class CartServiceImpl: CartService {
    @Injected(\.cartRepository) var repository
    @Injected(\.userService) var userService
    @Injected(\.analytics) var analytics

    private let itemCountSubject = CurrentValueSubject<Int, Never>(0)

    var itemCount: AnyPublisher<Int, Never> {
        itemCountSubject.eraseToAnyPublisher()
    }

    private(set) var items: [CartItem] = [] {
        didSet {
            itemCountSubject.send(items.count)
        }
    }

    init() {
        Task {
            await loadCart()
        }
    }

    func addItem(_ product: Product) async throws {
        guard let userId = userService.currentUserId else {
            throw CartError.notAuthenticated
        }

        let item = CartItem(product: product, quantity: 1)
        try await repository.addItem(item, userId: userId)

        items.append(item)

        analytics.track(.cartItemAdded(product: product))
    }

    func removeItem(_ itemId: String) async throws {
        guard let userId = userService.currentUserId else {
            throw CartError.notAuthenticated
        }

        try await repository.removeItem(itemId, userId: userId)

        items.removeAll { $0.id == itemId }

        analytics.track(.cartItemRemoved(itemId: itemId))
    }

    func updateQuantity(_ itemId: String, quantity: Int) async throws {
        guard let userId = userService.currentUserId else {
            throw CartError.notAuthenticated
        }

        try await repository.updateQuantity(itemId, quantity: quantity, userId: userId)

        if let index = items.firstIndex(where: { $0.id == itemId }) {
            items[index].quantity = quantity
        }
    }

    func clearCart() async throws {
        guard let userId = userService.currentUserId else {
            throw CartError.notAuthenticated
        }

        try await repository.clearCart(userId: userId)
        items.removeAll()
    }

    private func loadCart() async {
        guard let userId = userService.currentUserId else { return }

        do {
            items = try await repository.fetchCart(userId: userId)
        } catch {
            analytics.track(.error(error, context: "cart_load"))
        }
    }
}
```

### Checkout Flow

```swift
// Features/Checkout/CheckoutViewModel.swift
import WeaveDI

@MainActor
final class CheckoutViewModel: ObservableObject {
    @Injected(\.cartService) var cartService
    @Injected(\.checkoutService) var checkoutService
    @Injected(\.paymentProcessor) var paymentProcessor
    @Injected(\.analytics) var analytics

    @Published var shippingAddress: Address?
    @Published var paymentMethod: PaymentMethod?
    @Published var isProcessing = false
    @Published var orderConfirmation: Order?
    @Published var error: CheckoutError?

    var total: Decimal {
        cartService.items.reduce(0) { $0 + $1.total }
    }

    func validateCheckout() -> Bool {
        guard shippingAddress != nil else {
            error = .missingShippingAddress
            return false
        }

        guard paymentMethod != nil else {
            error = .missingPaymentMethod
            return false
        }

        guard !cartService.items.isEmpty else {
            error = .emptyCart
            return false
        }

        return true
    }

    func processCheckout() async {
        guard validateCheckout() else { return }

        isProcessing = true
        defer { isProcessing = false }

        analytics.track(.checkoutStarted(total: total))

        do {
            // 1. Process payment
            let paymentIntent = try await paymentProcessor.createPaymentIntent(
                amount: total,
                currency: "USD"
            )

            // 2. Confirm payment
            try await paymentProcessor.confirmPayment(
                paymentIntent,
                using: paymentMethod!
            )

            // 3. Create order
            let order = try await checkoutService.createOrder(
                items: cartService.items,
                shippingAddress: shippingAddress!,
                paymentMethod: paymentMethod!,
                total: total
            )

            // 4. Clear cart
            try await cartService.clearCart()

            orderConfirmation = order

            analytics.track(.checkoutCompleted(order: order))
        } catch {
            self.error = .paymentFailed(error)
            analytics.track(.checkoutFailed(error: error))
        }
    }
}
```

## Social Media App

### Project Structure

```
SocialApp/
├── Features/
│   ├── Feed/
│   ├── Profile/
│   ├── Messaging/
│   └── Notifications/
├── Core/
│   ├── Networking/
│   ├── ImageCache/
│   ├── Database/
│   └── PushNotifications/
└── App/
```

### Feed Feature with Pagination

```swift
// Features/Feed/FeedViewModel.swift
import WeaveDI

@MainActor
final class FeedViewModel: ObservableObject {
    @Injected(\.feedService) var feedService
    @Injected(\.imageCache) var imageCache
    @Injected(\.analytics) var analytics

    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false

    private var currentPage = 0
    private var hasMorePages = true

    func loadFeed() async {
        guard !isLoading else { return }

        isLoading = true
        currentPage = 0
        hasMorePages = true

        defer { isLoading = false }

        analytics.track(.feedViewed)

        do {
            let result = try await feedService.fetchFeed(page: 0)
            posts = result.posts
            hasMorePages = result.hasMore

            // Prefetch images
            await prefetchImages(for: result.posts)
        } catch {
            analytics.track(.error(error, context: "feed_load"))
        }
    }

    func loadMore() async {
        guard !isLoadingMore, hasMorePages else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        currentPage += 1

        do {
            let result = try await feedService.fetchFeed(page: currentPage)
            posts.append(contentsOf: result.posts)
            hasMorePages = result.hasMore

            await prefetchImages(for: result.posts)
        } catch {
            currentPage -= 1
            analytics.track(.error(error, context: "feed_load_more"))
        }
    }

    func likePost(_ postId: String) async {
        do {
            try await feedService.likePost(postId)

            if let index = posts.firstIndex(where: { $0.id == postId }) {
                posts[index].isLiked = true
                posts[index].likeCount += 1
            }

            analytics.track(.postLiked(postId: postId))
        } catch {
            analytics.track(.error(error, context: "like_post"))
        }
    }

    private func prefetchImages(for posts: [Post]) async {
        await withTaskGroup(of: Void.self) { group in
            for post in posts {
                group.addTask {
                    await self.imageCache.prefetch(post.imageURL)
                }
            }
        }
    }
}
```

### Real-time Messaging

```swift
// Features/Messaging/MessagingService.swift
import WeaveDI
import Combine

protocol MessagingService {
    var newMessages: AnyPublisher<Message, Never> { get }

    func sendMessage(_ text: String, to userId: String) async throws
    func fetchConversations() async throws -> [Conversation]
    func fetchMessages(conversationId: String) async throws -> [Message]
    func markAsRead(_ messageId: String) async throws
}

final class MessagingServiceImpl: MessagingService {
    @Injected(\.apiClient) var apiClient
    @Injected(\.webSocketService) var webSocket
    @Injected(\.database) var database
    @Injected(\.pushNotifications) var pushNotifications

    private let newMessagesSubject = PassthroughSubject<Message, Never>()

    var newMessages: AnyPublisher<Message, Never> {
        newMessagesSubject.eraseToAnyPublisher()
    }

    init() {
        setupWebSocketListener()
    }

    func sendMessage(_ text: String, to userId: String) async throws {
        let message = Message(
            id: UUID().uuidString,
            text: text,
            senderId: userId,
            timestamp: Date()
        )

        // Save locally
        try await database.save(message)

        // Send via WebSocket
        try await webSocket.send(.message(message))

        // Fallback to API if WebSocket fails
        if !webSocket.isConnected {
            try await apiClient.post("/messages", body: message)
        }
    }

    func fetchConversations() async throws -> [Conversation] {
        // Try local cache first
        if let cached = try? await database.fetch(Conversation.self) {
            return cached
        }

        // Fetch from API
        let conversations: [Conversation] = try await apiClient.get("/conversations")

        // Update cache
        try await database.save(conversations)

        return conversations
    }

    func fetchMessages(conversationId: String) async throws -> [Message] {
        let messages: [Message] = try await apiClient.get("/conversations/\(conversationId)/messages")

        // Save to local database
        try await database.save(messages)

        return messages
    }

    func markAsRead(_ messageId: String) async throws {
        try await apiClient.post("/messages/\(messageId)/read", body: EmptyBody())
    }

    private func setupWebSocketListener() {
        webSocket.messages
            .compactMap { event -> Message? in
                if case .message(let message) = event {
                    return message
                }
                return nil
            }
            .sink { [weak self] message in
                self?.handleNewMessage(message)
            }
            .store(in: &cancellables)
    }

    private func handleNewMessage(_ message: Message) {
        // Save to database
        Task {
            try? await database.save(message)
        }

        // Notify subscribers
        newMessagesSubject.send(message)

        // Show push notification if app is in background
        if !UIApplication.shared.isActive {
            pushNotifications.show(
                title: "New Message",
                body: message.text
            )
        }
    }

    private var cancellables = Set<AnyCancellable>()
}
```

## Financial App

### Project Structure

```
FinanceApp/
├── Features/
│   ├── Accounts/
│   ├── Transactions/
│   ├── Budgets/
│   └── Investments/
├── Core/
│   ├── Networking/
│   ├── Encryption/
│   ├── Biometrics/
│   └── Analytics/
└── App/
```

### Secure Transaction Service

```swift
// Features/Transactions/TransactionService.swift
import WeaveDI

protocol TransactionService {
    func fetchTransactions(accountId: String) async throws -> [Transaction]
    func createTransaction(_ transaction: Transaction) async throws -> Transaction
    func categorizeTransaction(_ transactionId: String, category: Category) async throws
}

final class TransactionServiceImpl: TransactionService {
    @Injected(\.apiClient) var apiClient
    @Injected(\.encryption) var encryption
    @Injected(\.biometrics) var biometrics
    @Injected(\.database) var database
    @Injected(\.analytics) var analytics

    func fetchTransactions(accountId: String) async throws -> [Transaction] {
        // Check biometric authentication for sensitive data
        guard try await biometrics.authenticate(reason: "Access your transactions") else {
            throw TransactionError.authenticationFailed
        }

        analytics.track(.transactionsFetched(accountId: accountId))

        // Fetch encrypted data
        let encryptedData: Data = try await apiClient.get("/accounts/\(accountId)/transactions")

        // Decrypt
        let decryptedData = try encryption.decrypt(encryptedData)

        // Parse
        let transactions = try JSONDecoder().decode([Transaction].self, from: decryptedData)

        // Cache locally (encrypted)
        try await database.save(transactions, encrypted: true)

        return transactions
    }

    func createTransaction(_ transaction: Transaction) async throws -> Transaction {
        // Require biometric authentication
        guard try await biometrics.authenticate(reason: "Confirm transaction") else {
            throw TransactionError.authenticationFailed
        }

        analytics.track(.transactionCreated(amount: transaction.amount))

        // Encrypt sensitive data
        let jsonData = try JSONEncoder().encode(transaction)
        let encryptedData = try encryption.encrypt(jsonData)

        // Send to API
        let response: Data = try await apiClient.post(
            "/transactions",
            body: encryptedData
        )

        // Decrypt response
        let decryptedResponse = try encryption.decrypt(response)
        let createdTransaction = try JSONDecoder().decode(Transaction.self, from: decryptedResponse)

        // Save locally
        try await database.save(createdTransaction, encrypted: true)

        return createdTransaction
    }

    func categorizeTransaction(
        _ transactionId: String,
        category: Category
    ) async throws {
        try await apiClient.put(
            "/transactions/\(transactionId)/category",
            body: ["category": category.rawValue]
        )

        // Update local cache
        if var transaction = try? await database.fetch(
            Transaction.self,
            id: transactionId
        ) {
            transaction.category = category
            try await database.save(transaction, encrypted: true)
        }

        analytics.track(.transactionCategorized(category: category))
    }
}
```

### Budget Tracking with Notifications

```swift
// Features/Budgets/BudgetService.swift
import WeaveDI

final class BudgetServiceImpl: BudgetService {
    @Injected(\.apiClient) var apiClient
    @Injected(\.database) var database
    @Injected(\.notifications) var notifications
    @Injected(\.analytics) var analytics

    func trackSpending(transaction: Transaction) async throws {
        // Fetch relevant budgets
        let budgets = try await fetchBudgets(for: transaction.category)

        for budget in budgets {
            let spent = try await calculateSpent(budget: budget)
            let percentage = (spent / budget.limit) * 100

            // Check thresholds
            if percentage >= 100 {
                await notifications.send(
                    .budgetExceeded(budget: budget, spent: spent)
                )
                analytics.track(.budgetExceeded(budget: budget))
            } else if percentage >= 90 {
                await notifications.send(
                    .budgetWarning(budget: budget, percentage: percentage)
                )
                analytics.track(.budgetWarning(budget: budget))
            }

            // Update budget status
            try await updateBudgetStatus(budget.id, spent: spent)
        }
    }

    private func calculateSpent(budget: Budget) async throws -> Decimal {
        let transactions = try await database.fetch(
            Transaction.self,
            where: "category == %@ AND date >= %@ AND date <= %@",
            budget.category,
            budget.startDate,
            budget.endDate
        )

        return transactions.reduce(0) { $0 + $1.amount }
    }
}
```

## Testing Real-World Scenarios

### E-Commerce Checkout Test

```swift
import XCTest
@testable import ShopApp
import WeaveDI

final class CheckoutIntegrationTests: XCTestCase {
    func testCompleteCheckoutFlow() async throws {
        await withInjectedValues { values in
            values.cartService = MockCartService(items: [.testItem])
            values.paymentProcessor = MockPaymentProcessor()
            values.checkoutService = MockCheckoutService()
        } operation: {
            let viewModel = CheckoutViewModel()

            // Setup
            viewModel.shippingAddress = .testAddress
            viewModel.paymentMethod = .testCard

            // Execute checkout
            await viewModel.processCheckout()

            // Verify
            XCTAssertNotNil(viewModel.orderConfirmation)
            XCTAssertNil(viewModel.error)
        }
    }
}
```

## Next Steps

- [Testing Guide](../tutorial/testing) - Learn comprehensive testing strategies
- [Best Practices](./bestPractices) - Follow production-ready patterns
- [Multi-Module Projects](./multiModuleProjects) - Scale your architecture
- [SwiftUI Integration](./swiftuiIntegration) - Build modern UIs
