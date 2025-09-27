# Property Wrappers

WeaveDI의 강력한 프로퍼티 래퍼를 활용한 타입 안전한 의존성 주입

## Overview

WeaveDI는 Swift의 프로퍼티 래퍼 기능을 활용하여 의존성 주입을 더욱 직관적이고 안전하게 만들어줍니다. 세 가지 핵심 프로퍼티 래퍼가 서로 다른 사용 시나리오를 커버하며, 모든 래퍼는 컴파일 타임 안전성을 제공합니다.

### 프로퍼티 래퍼 종류

| 래퍼 | 용도 | 반환 타입 | 사용 시점 |
|------|------|----------|----------|
| `@Inject` | 선택적 의존성 | `Optional` | 없어도 동작하는 서비스 |
| `@Factory` | 팩토리 인스턴스 | `Non-Optional` | 매번 새 인스턴스 필요 |
| `@SafeInject` | 필수 의존성 | `Optional` + 에러 처리 | 반드시 있어야 하는 서비스 |

### 프로퍼티 래퍼의 장점

- **선언적 문법**: 의존성을 프로퍼티처럼 선언만 하면 자동 주입
- **지연 로딩**: 실제 사용 시점에 의존성 해결하여 앱 시작 시간 단축
- **타입 안전성**: Swift 타입 시스템과 완벽 통합으로 컴파일 타임 검증
- **메모리 효율성**: 자동 메모리 관리와 약한 참조 지원

## @Inject

The most commonly used property wrapper for optional dependency injection.

### Basic Usage

```swift
class UserViewController {
    @Inject var userService: UserService?
    @Inject var analytics: AnalyticsService?

    func viewDidLoad() {
        guard let service = userService else {
            // Handle missing dependency gracefully
            return
        }

        Task {
            let user = await service.fetchCurrentUser()
            updateUI(with: user)
        }
    }
}
```

### When to Use @Inject

- Optional dependencies that may not be available
- Services that can gracefully degrade when missing
- Testing scenarios where you want to mock dependencies

## @Factory

Creates a new instance every time the property is accessed.

### Basic Usage

```swift
class DocumentProcessor {
    @Factory var pdfGenerator: PDFGenerator
    @Factory var emailSender: EmailSender

    func processDocument(_ document: Document) {
        // Each access creates a new instance
        let generator1 = pdfGenerator  // New instance
        let generator2 = pdfGenerator  // Another new instance

        generator1.configure(for: document)
        let pdf = generator1.generate()

        emailSender.send(pdf, to: document.recipient)
    }
}
```

### When to Use @Factory

- Stateful objects that shouldn't be shared
- Objects with per-operation configuration
- Utilities that need fresh state each time

## @SafeInject

Provides required dependency injection with explicit error handling.

### Basic Usage

```swift
class PaymentProcessor {
    @SafeInject var paymentGateway: PaymentGateway?
    @SafeInject var fraudDetection: FraudDetectionService?

    func processPayment(_ payment: Payment) throws {
        guard let gateway = paymentGateway else {
            throw PaymentError.gatewayUnavailable
        }

        guard let fraud = fraudDetection else {
            throw PaymentError.securityUnavailable
        }

        try fraud.validate(payment)
        try gateway.process(payment)
    }
}
```

### When to Use @SafeInject

- Critical dependencies that must be available
- Services where failure should be explicit
- Production code that requires robust error handling

## Advanced Patterns

### Combining Property Wrappers

```swift
class ShoppingCartService {
    @Inject var userService: UserService?          // Optional
    @SafeInject var paymentService: PaymentService? // Required
    @Factory var orderValidator: OrderValidator     // New instance each time

    func checkout(_ cart: Cart) throws {
        guard let user = userService?.currentUser else {
            throw CheckoutError.userNotFound
        }

        guard let payment = paymentService else {
            throw CheckoutError.paymentUnavailable
        }

        let validator = orderValidator
        try validator.validate(cart, for: user)
        try payment.process(cart.total)
    }
}
```

### Testing with Property Wrappers

```swift
class UserViewControllerTests: XCTestCase {
    var sut: UserViewController!

    override func setUp() {
        super.setUp()

        // Register test dependencies
        UnifiedDI.register(UserService.self) {
            MockUserService()
        }

        sut = UserViewController()
    }

    func testUserDataLoading() async {
        // The @Inject property will automatically use MockUserService
        await sut.loadUserData()

        XCTAssertTrue(sut.isDataLoaded)
    }
}
```

## Performance Considerations

### Optimization with Property Wrappers

Property wrappers automatically benefit from runtime optimization:

```swift
// Enable optimization for all property wrappers
UnifiedRegistry.shared.enableOptimization()

class HighPerformanceService {
    @Inject var dataService: DataService?  // Optimized resolution
    @Factory var processor: DataProcessor  // Optimized creation
}
```

### Lazy Resolution

Property wrappers resolve dependencies lazily:

```swift
class LazyService {
    @Inject var expensiveService: ExpensiveService?

    func doWork() {
        // expensiveService is only resolved when first accessed
        expensiveService?.performExpensiveOperation()
    }
}
```

## Error Handling Best Practices

### Graceful Degradation with @Inject

```swift
class AnalyticsManager {
    @Inject var analytics: AnalyticsService?

    func trackEvent(_ event: String) {
        // Gracefully handle missing analytics
        analytics?.track(event) ?? logLocally(event)
    }

    private func logLocally(_ event: String) {
        print("📊 Analytics unavailable, logging locally: \(event)")
    }
}
```

### Explicit Error Handling with @SafeInject

```swift
class CriticalService {
    @SafeInject var database: Database?

    func saveUserData(_ data: UserData) throws {
        guard let db = database else {
            throw ServiceError.databaseUnavailable
        }

        try db.save(data)
    }
}
```

## See Also

- [Core APIs](/guide/core-apis) - Core API reference
- [Quick Start](/quick-start) - Getting started guide
- [Runtime Optimization](/guide/runtime-optimization) - Performance optimization