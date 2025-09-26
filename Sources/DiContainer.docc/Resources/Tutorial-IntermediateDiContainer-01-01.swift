import Foundation
import DiContainer
import LogMacro

// MARK: - 복잡한 전자상거래 도메인 모델

/// 실제 전자상거래 서비스에서 사용될 법한 복잡한 도메인 구조를 구현합니다.
/// 이 예제를 통해 다계층 의존성 관계를 이해하고 실무에 적용할 수 있습니다.

// MARK: - 도메인 엔티티들

struct User: Sendable {
    let id: String
    let email: String
    let name: String
    let membershipLevel: MembershipLevel
}

enum MembershipLevel: String, Sendable {
    case bronze = "bronze"
    case silver = "silver"
    case gold = "gold"
    case platinum = "platinum"
}

struct Product: Sendable {
    let id: String
    let name: String
    let price: Decimal
    let category: ProductCategory
    let inventory: Int
}

struct ProductCategory: Sendable {
    let id: String
    let name: String
    let parentId: String?
}

struct Order: Sendable {
    let id: String
    let userId: String
    let items: [OrderItem]
    let totalAmount: Decimal
    let status: OrderStatus
    let createdAt: Date
}

struct OrderItem: Sendable {
    let productId: String
    let quantity: Int
    let unitPrice: Decimal
}

enum OrderStatus: String, Sendable {
    case pending = "pending"
    case confirmed = "confirmed"
    case processing = "processing"
    case shipped = "shipped"
    case delivered = "delivered"
    case cancelled = "cancelled"
}

// MARK: - Repository 계층 (데이터 접근)

protocol UserRepository: Sendable {
    func findUser(by id: String) async throws -> User?
    func save(_ user: User) async throws
    func findUsersByMembership(_ level: MembershipLevel) async throws -> [User]
}

protocol ProductRepository: Sendable {
    func findProduct(by id: String) async throws -> Product?
    func findProductsByCategory(_ categoryId: String) async throws -> [Product]
    func updateInventory(_ productId: String, quantity: Int) async throws
}

protocol OrderRepository: Sendable {
    func save(_ order: Order) async throws -> Order
    func findOrder(by id: String) async throws -> Order?
    func findOrdersByUser(_ userId: String) async throws -> [Order]
    func updateOrderStatus(_ orderId: String, status: OrderStatus) async throws
}

// MARK: - Service 계층 (비즈니스 로직)

protocol UserService: Sendable {
    func getUser(id: String) async throws -> User
    func validateUser(_ userId: String) async throws -> Bool
    func getUserDiscount(_ userId: String) async throws -> Decimal
}

protocol ProductService: Sendable {
    func getProduct(id: String) async throws -> Product
    func checkProductAvailability(_ productId: String, quantity: Int) async throws -> Bool
    func reserveProduct(_ productId: String, quantity: Int) async throws
}

protocol OrderService: Sendable {
    func createOrder(userId: String, items: [OrderItem]) async throws -> Order
    func processOrder(_ orderId: String) async throws
    func getOrderHistory(userId: String) async throws -> [Order]
}

protocol NotificationService: Sendable {
    func sendOrderConfirmation(_ order: Order) async throws
    func sendShippingNotification(_ order: Order) async throws
}

// MARK: - UseCase 계층 (애플리케이션 로직)

/// 복잡한 주문 처리 UseCase
/// 여러 서비스들을 조합하여 비즈니스 프로세스를 구현합니다.
protocol OrderProcessingUseCase: Sendable {
    func processNewOrder(userId: String, items: [OrderItem]) async throws -> Order
}

// MARK: - 구현체

final class DefaultOrderProcessingUseCase: OrderProcessingUseCase {
    @Inject private var userService: UserService
    @Inject private var productService: ProductService
    @Inject private var orderService: OrderService
    @Inject private var notificationService: NotificationService

    func processNewOrder(userId: String, items: [OrderItem]) async throws -> Order {
        #logInfo("🛒 주문 처리 시작: \(userId)")

        // 1. 사용자 검증
        let isValidUser = try await userService.validateUser(userId)
        guard isValidUser else {
            throw OrderProcessingError.invalidUser(userId)
        }

        // 2. 상품들 가용성 확인
        for item in items {
            let isAvailable = try await productService.checkProductAvailability(
                item.productId,
                quantity: item.quantity
            )
            guard isAvailable else {
                throw OrderProcessingError.productUnavailable(item.productId)
            }
        }

        // 3. 상품들 예약
        for item in items {
            try await productService.reserveProduct(item.productId, quantity: item.quantity)
        }

        do {
            // 4. 주문 생성
            let order = try await orderService.createOrder(userId: userId, items: items)

            // 5. 주문 처리
            try await orderService.processOrder(order.id)

            // 6. 알림 발송
            try await notificationService.sendOrderConfirmation(order)

            #logInfo("✅ 주문 처리 완료: \(order.id)")
            return order

        } catch {
            #logError("❌ 주문 처리 실패: \(error)")
            // 실패시 예약된 상품들을 롤백해야 함
            throw error
        }
    }
}

final class DefaultUserService: UserService {
    @Inject private var userRepository: UserRepository

    func getUser(id: String) async throws -> User {
        guard let user = try await userRepository.findUser(by: id) else {
            throw UserServiceError.userNotFound(id)
        }
        return user
    }

    func validateUser(_ userId: String) async throws -> Bool {
        do {
            _ = try await getUser(id: userId)
            return true
        } catch {
            return false
        }
    }

    func getUserDiscount(_ userId: String) async throws -> Decimal {
        let user = try await getUser(id: userId)

        // 멤버십 레벨에 따른 할인률
        switch user.membershipLevel {
        case .bronze:
            return 0.05  // 5%
        case .silver:
            return 0.10  // 10%
        case .gold:
            return 0.15  // 15%
        case .platinum:
            return 0.20  // 20%
        }
    }
}

final class DefaultProductService: ProductService {
    @Inject private var productRepository: ProductRepository

    func getProduct(id: String) async throws -> Product {
        guard let product = try await productRepository.findProduct(by: id) else {
            throw ProductServiceError.productNotFound(id)
        }
        return product
    }

    func checkProductAvailability(_ productId: String, quantity: Int) async throws -> Bool {
        let product = try await getProduct(id: productId)
        return product.inventory >= quantity
    }

    func reserveProduct(_ productId: String, quantity: Int) async throws {
        let product = try await getProduct(id: productId)
        guard product.inventory >= quantity else {
            throw ProductServiceError.insufficientInventory(productId)
        }

        let newInventory = product.inventory - quantity
        try await productRepository.updateInventory(productId, quantity: newInventory)
    }
}

// MARK: - 에러 정의

enum OrderProcessingError: Error, LocalizedError {
    case invalidUser(String)
    case productUnavailable(String)
    case orderCreationFailed

    var errorDescription: String? {
        switch self {
        case .invalidUser(let userId):
            return "유효하지 않은 사용자: \(userId)"
        case .productUnavailable(let productId):
            return "상품을 사용할 수 없음: \(productId)"
        case .orderCreationFailed:
            return "주문 생성에 실패했습니다"
        }
    }
}

enum UserServiceError: Error {
    case userNotFound(String)
}

enum ProductServiceError: Error {
    case productNotFound(String)
    case insufficientInventory(String)
}

// MARK: - DI 컨테이너 설정

extension DIContainer {
    /// 복잡한 전자상거래 도메인의 의존성을 등록하는 예제
    func registerEcommerceDomain() async {
        #logInfo("🔧 전자상거래 도메인 의존성 등록 시작")

        // UseCase 계층
        register(OrderProcessingUseCase.self) {
            DefaultOrderProcessingUseCase()
        }

        // Service 계층
        register(UserService.self) {
            DefaultUserService()
        }

        register(ProductService.self) {
            DefaultProductService()
        }

        // 이 예제는 Repository와 기타 서비스들의 구현체는
        // 다음 단계에서 mock이나 실제 구현으로 등록될 예정입니다.

        #logInfo("✅ 전자상거래 도메인 의존성 등록 완료")
        #logInfo("📊 등록된 의존성 개수: \(registry.registrationCount)")
    }
}

// MARK: - 사용 예제

enum EcommerceUsageExample {
    static func demonstrateComplexDependencies() async {
        #logInfo("🎬 복잡한 의존성 체인 데모 시작")

        let container = DIContainer()
        await container.registerEcommerceDomain()

        // UseCase를 통한 주문 처리
        let orderUseCase: OrderProcessingUseCase = container.resolve()

        let sampleItems = [
            OrderItem(productId: "prod-001", quantity: 2, unitPrice: 29.99),
            OrderItem(productId: "prod-002", quantity: 1, unitPrice: 149.99)
        ]

        do {
            let order = try await orderUseCase.processNewOrder(
                userId: "user-123",
                items: sampleItems
            )
            #logInfo("🎉 주문 성공: \(order.id)")
        } catch {
            #logError("💥 주문 실패: \(error)")
        }

        #logInfo("📈 현재 성능 통계: \(container.performanceStats())")
    }
}