import Foundation
import DiContainer
import LogMacro

// MARK: - Complex Domain Model Architecture

/// 복잡한 전자상거래 도메인 모델
/// 여러 계층의 의존성 관계를 보여주는 예제

// MARK: - Domain Entities

struct User: Sendable {
    let id: String
    let email: String
    let preferences: UserPreferences
    let subscriptions: [Subscription]
}

struct UserPreferences: Sendable {
    let theme: String
    let language: String
    let notifications: NotificationSettings
}

struct NotificationSettings: Sendable {
    let emailEnabled: Bool
    let pushEnabled: Bool
    let categories: [String]
}

struct Product: Sendable {
    let id: String
    let name: String
    let price: Decimal
    let category: ProductCategory
    let inventory: InventoryInfo
}

struct ProductCategory: Sendable {
    let id: String
    let name: String
    let parentId: String?
}

struct InventoryInfo: Sendable {
    let available: Int
    let reserved: Int
    let threshold: Int
}

struct Order: Sendable {
    let id: String
    let userId: String
    let items: [OrderItem]
    let shipping: ShippingInfo
    let payment: PaymentInfo
    let status: OrderStatus
}

struct OrderItem: Sendable {
    let productId: String
    let quantity: Int
    let unitPrice: Decimal
}

struct ShippingInfo: Sendable {
    let address: Address
    let method: ShippingMethod
    let estimatedDelivery: Date
}

struct Address: Sendable {
    let street: String
    let city: String
    let country: String
    let postalCode: String
}

enum ShippingMethod: String, Sendable {
    case standard = "standard"
    case express = "express"
    case overnight = "overnight"
}

struct PaymentInfo: Sendable {
    let method: PaymentMethod
    let amount: Decimal
    let currency: String
}

enum PaymentMethod: String, Sendable {
    case creditCard = "credit_card"
    case paypal = "paypal"
    case applePay = "apple_pay"
}

enum OrderStatus: String, Sendable {
    case pending = "pending"
    case confirmed = "confirmed"
    case processing = "processing"
    case shipped = "shipped"
    case delivered = "delivered"
    case cancelled = "cancelled"
}

struct Subscription: Sendable {
    let id: String
    let type: SubscriptionType
    let startDate: Date
    let endDate: Date?
    let isActive: Bool
}

enum SubscriptionType: String, Sendable {
    case free = "free"
    case premium = "premium"
    case enterprise = "enterprise"
}

// MARK: - Repository Layer Protocols

protocol UserRepository: Sendable {
    func findUser(by id: String) async throws -> User?
    func save(user: User) async throws
    func findUsers(with preferences: UserPreferences) async throws -> [User]
}

protocol ProductRepository: Sendable {
    func findProduct(by id: String) async throws -> Product?
    func findProducts(in category: ProductCategory) async throws -> [Product]
    func updateInventory(productId: String, quantity: Int) async throws
}

protocol OrderRepository: Sendable {
    func findOrder(by id: String) async throws -> Order?
    func findOrders(for userId: String) async throws -> [Order]
    func save(order: Order) async throws
    func updateStatus(orderId: String, status: OrderStatus) async throws
}

protocol InventoryRepository: Sendable {
    func checkAvailability(productId: String, quantity: Int) async throws -> Bool
    func reserve(productId: String, quantity: Int) async throws
    func release(productId: String, quantity: Int) async throws
}

protocol NotificationRepository: Sendable {
    func sendNotification(userId: String, message: String, type: String) async throws
    func getNotificationSettings(userId: String) async throws -> NotificationSettings
}

// MARK: - Service Layer Protocols

protocol UserService: Sendable {
    func getUser(id: String) async throws -> User
    func updatePreferences(userId: String, preferences: UserPreferences) async throws
    func checkSubscription(userId: String, type: SubscriptionType) async throws -> Bool
}

protocol ProductService: Sendable {
    func getProduct(id: String) async throws -> Product
    func searchProducts(category: String, filters: [String: Any]) async throws -> [Product]
    func checkAvailability(productId: String, quantity: Int) async throws -> Bool
}

protocol OrderService: Sendable {
    func createOrder(userId: String, items: [OrderItem], shipping: ShippingInfo) async throws -> Order
    func processPayment(orderId: String, paymentInfo: PaymentInfo) async throws
    func updateOrderStatus(orderId: String, status: OrderStatus) async throws
    func getOrderHistory(userId: String) async throws -> [Order]
}

protocol PaymentService: Sendable {
    func processPayment(amount: Decimal, method: PaymentMethod) async throws -> String
    func refundPayment(transactionId: String, amount: Decimal) async throws
    func validatePaymentMethod(method: PaymentMethod, details: [String: Any]) async throws -> Bool
}

protocol ShippingService: Sendable {
    func calculateShippingCost(address: Address, method: ShippingMethod) async throws -> Decimal
    func scheduleDelivery(orderId: String, address: Address, method: ShippingMethod) async throws -> Date
    func trackShipment(orderId: String) async throws -> String
}

protocol NotificationService: Sendable {
    func sendOrderConfirmation(userId: String, order: Order) async throws
    func sendShippingNotification(userId: String, order: Order, trackingNumber: String) async throws
    func sendPromotionNotification(userId: String, message: String) async throws
}

// MARK: - Complex Use Cases

protocol OrderProcessingUseCase: Sendable {
    func processOrder(userId: String, items: [OrderItem], shipping: ShippingInfo, payment: PaymentInfo) async throws -> Order
}

protocol InventoryManagementUseCase: Sendable {
    func reserveItems(items: [OrderItem]) async throws
    func releaseItems(items: [OrderItem]) async throws
    func updateStock(productId: String, quantity: Int) async throws
}

protocol UserAnalyticsUseCase: Sendable {
    func trackUserActivity(userId: String, action: String, metadata: [String: Any]) async throws
    func generateUserInsights(userId: String) async throws -> [String: Any]
    func getRecommendations(userId: String) async throws -> [Product]
}

// MARK: - Implementation Examples

/// 복잡한 의존성 체인을 가진 OrderProcessingUseCase 구현
final class DefaultOrderProcessingUseCase: OrderProcessingUseCase {
    @Inject private var userService: UserService
    @Inject private var productService: ProductService
    @Inject private var orderService: OrderService
    @Inject private var paymentService: PaymentService
    @Inject private var shippingService: ShippingService
    @Inject private var notificationService: NotificationService
    @Inject private var inventoryUseCase: InventoryManagementUseCase
    @Inject private var analyticsUseCase: UserAnalyticsUseCase

    func processOrder(
        userId: String,
        items: [OrderItem],
        shipping: ShippingInfo,
        payment: PaymentInfo
    ) async throws -> Order {
        #logInfo("🛒 [OrderProcessing] 주문 처리 시작 - 사용자: \(userId)")

        // 1. 사용자 검증
        let user = try await userService.getUser(id: userId)
        #logInfo("✅ [OrderProcessing] 사용자 검증 완료: \(user.email)")

        // 2. 상품 가용성 확인
        for item in items {
            let isAvailable = try await productService.checkAvailability(
                productId: item.productId,
                quantity: item.quantity
            )
            guard isAvailable else {
                throw OrderProcessingError.insufficientInventory(productId: item.productId)
            }
        }
        #logInfo("✅ [OrderProcessing] 재고 확인 완료")

        // 3. 재고 예약
        try await inventoryUseCase.reserveItems(items: items)
        #logInfo("📦 [OrderProcessing] 재고 예약 완료")

        do {
            // 4. 배송비 계산
            let shippingCost = try await shippingService.calculateShippingCost(
                address: shipping.address,
                method: shipping.method
            )

            // 5. 총 금액 계산
            let itemsTotal = items.reduce(0) { $0 + $1.unitPrice * Decimal($1.quantity) }
            let totalAmount = itemsTotal + shippingCost

            // 6. 결제 처리
            let paymentInfo = PaymentInfo(
                method: payment.method,
                amount: totalAmount,
                currency: payment.currency
            )

            let transactionId = try await paymentService.processPayment(
                amount: totalAmount,
                method: payment.method
            )
            #logInfo("💳 [OrderProcessing] 결제 완료: \(transactionId)")

            // 7. 주문 생성
            let order = try await orderService.createOrder(
                userId: userId,
                items: items,
                shipping: shipping
            )

            // 8. 배송 스케줄링
            let estimatedDelivery = try await shippingService.scheduleDelivery(
                orderId: order.id,
                address: shipping.address,
                method: shipping.method
            )
            #logInfo("🚚 [OrderProcessing] 배송 스케줄 완료: \(estimatedDelivery)")

            // 9. 알림 발송
            try await notificationService.sendOrderConfirmation(userId: userId, order: order)

            // 10. 사용자 활동 추적
            try await analyticsUseCase.trackUserActivity(
                userId: userId,
                action: "order_created",
                metadata: [
                    "order_id": order.id,
                    "total_amount": totalAmount,
                    "items_count": items.count
                ]
            )

            #logInfo("🎉 [OrderProcessing] 주문 처리 완료: \(order.id)")
            return order

        } catch {
            // 실패 시 예약된 재고 해제
            try await inventoryUseCase.releaseItems(items: items)
            #logError("❌ [OrderProcessing] 주문 처리 실패, 재고 해제됨: \(error)")
            throw error
        }
    }
}

/// 재고 관리 UseCase 구현 (또 다른 복잡한 의존성 체인)
final class DefaultInventoryManagementUseCase: InventoryManagementUseCase {
    @Inject private var inventoryRepository: InventoryRepository
    @Inject private var productRepository: ProductRepository
    @Inject private var notificationService: NotificationService

    func reserveItems(items: [OrderItem]) async throws {
        #logInfo("📦 [Inventory] 재고 예약 시작: \(items.count)개 아이템")

        for item in items {
            let isAvailable = try await inventoryRepository.checkAvailability(
                productId: item.productId,
                quantity: item.quantity
            )

            guard isAvailable else {
                throw InventoryError.insufficientStock(productId: item.productId)
            }

            try await inventoryRepository.reserve(
                productId: item.productId,
                quantity: item.quantity
            )

            // 재고 임계값 확인
            if let product = try await productRepository.findProduct(by: item.productId) {
                let remainingStock = product.inventory.available - item.quantity
                if remainingStock <= product.inventory.threshold {
                    try await notificationService.sendPromotionNotification(
                        userId: "admin",
                        message: "재고 부족 알림: \(product.name) - 남은 수량: \(remainingStock)"
                    )
                }
            }
        }

        #logInfo("✅ [Inventory] 재고 예약 완료")
    }

    func releaseItems(items: [OrderItem]) async throws {
        #logInfo("🔄 [Inventory] 재고 해제 시작: \(items.count)개 아이템")

        for item in items {
            try await inventoryRepository.release(
                productId: item.productId,
                quantity: item.quantity
            )
        }

        #logInfo("✅ [Inventory] 재고 해제 완료")
    }

    func updateStock(productId: String, quantity: Int) async throws {
        #logInfo("📈 [Inventory] 재고 업데이트: \(productId), 수량: \(quantity)")

        try await productRepository.updateInventory(
            productId: productId,
            quantity: quantity
        )

        #logInfo("✅ [Inventory] 재고 업데이트 완료")
    }
}

// MARK: - Error Types

enum OrderProcessingError: Error, LocalizedError {
    case insufficientInventory(productId: String)
    case paymentFailed(reason: String)
    case shippingNotAvailable
    case userNotFound(userId: String)

    var errorDescription: String? {
        switch self {
        case .insufficientInventory(let productId):
            return "재고 부족: \(productId)"
        case .paymentFailed(let reason):
            return "결제 실패: \(reason)"
        case .shippingNotAvailable:
            return "배송 불가 지역"
        case .userNotFound(let userId):
            return "사용자를 찾을 수 없음: \(userId)"
        }
    }
}

enum InventoryError: Error, LocalizedError {
    case insufficientStock(productId: String)
    case reservationFailed(productId: String)
    case releaseError(productId: String)

    var errorDescription: String? {
        switch self {
        case .insufficientStock(let productId):
            return "재고 부족: \(productId)"
        case .reservationFailed(let productId):
            return "재고 예약 실패: \(productId)"
        case .releaseError(let productId):
            return "재고 해제 실패: \(productId)"
        }
    }
}

// MARK: - Dependency Registration Example

extension DIContainer {
    /// 복잡한 도메인 모델의 의존성 등록 예제
    func registerComplexDomainDependencies() async {
        #logInfo("🔧 [DIContainer] 복잡한 도메인 의존성 등록 시작")

        // UseCase 등록 (가장 상위 레벨)
        register(OrderProcessingUseCase.self) {
            DefaultOrderProcessingUseCase()
        }

        register(InventoryManagementUseCase.self) {
            DefaultInventoryManagementUseCase()
        }

        // 이 예제는 복잡한 의존성 체인을 보여줍니다:
        // OrderProcessingUseCase -> 8개의 다른 서비스들
        // 각 서비스들 -> Repository 계층
        // Repository 계층 -> 데이터 소스들

        #logInfo("✅ [DIContainer] 복잡한 도메인 의존성 등록 완료")
    }
}