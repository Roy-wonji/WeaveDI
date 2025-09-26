import Foundation
import DiContainer
import LogMacro

// MARK: - 테스트 시나리오 검증 및 통계

/// 테스트 실행 중 의존성 사용 패턴을 분석하고 최적화하는
/// 고급 테스트 분석 시스템을 구현합니다.

// MARK: - 테스트 실행 통계 수집기

/// 테스트 실행 중 DI 관련 통계를 수집하는 시스템
final class TestExecutionStatsCollector: @unchecked Sendable {
    private let queue = DispatchQueue(label: "TestExecutionStats", attributes: .concurrent)

    // 통계 데이터
    private var _testCases: [TestCaseStats] = []
    private var _dependencyUsage: [String: DependencyUsageStats] = [:]
    private var _mockInteractions: [String: MockInteractionStats] = [:]
    private var _currentTestCase: TestCaseStats?

    /// 테스트 케이스 시작을 기록합니다
    func beginTestCase(name: String, category: String = "default") {
        queue.async(flags: .barrier) {
            let testCase = TestCaseStats(
                name: name,
                category: category,
                startTime: Date()
            )

            self._currentTestCase = testCase
            #logInfo("🧪 테스트 케이스 시작: \(name)")
        }
    }

    /// 테스트 케이스 종료를 기록합니다
    func endTestCase(success: Bool) {
        queue.async(flags: .barrier) {
            guard var testCase = self._currentTestCase else { return }

            testCase.endTime = Date()
            testCase.success = success
            testCase.duration = testCase.endTime!.timeIntervalSince(testCase.startTime)

            self._testCases.append(testCase)
            self._currentTestCase = nil

            let status = success ? "성공" : "실패"
            #logInfo("🏁 테스트 케이스 종료: \(testCase.name) (\(status))")
        }
    }

    /// 의존성 사용을 기록합니다
    func recordDependencyUsage<T>(
        _ type: T.Type,
        resolveTime: TimeInterval,
        isMock: Bool,
        testCaseName: String
    ) {
        let typeName = String(describing: type)

        queue.async(flags: .barrier) {
            if self._dependencyUsage[typeName] == nil {
                self._dependencyUsage[typeName] = DependencyUsageStats(typeName: typeName)
            }

            self._dependencyUsage[typeName]?.recordUsage(
                resolveTime: resolveTime,
                isMock: isMock,
                testCase: testCaseName
            )

            #logInfo("📊 의존성 사용 기록: \(typeName) (Mock: \(isMock))")
        }
    }

    /// Mock 상호작용을 기록합니다
    func recordMockInteraction(
        mockType: String,
        method: String,
        parameters: [String: Any],
        testCaseName: String
    ) {
        queue.async(flags: .barrier) {
            if self._mockInteractions[mockType] == nil {
                self._mockInteractions[mockType] = MockInteractionStats(mockType: mockType)
            }

            self._mockInteractions[mockType]?.recordInteraction(
                method: method,
                parameters: parameters,
                testCase: testCaseName
            )

            #logInfo("🎭 Mock 상호작용 기록: \(mockType).\(method)")
        }
    }

    /// 포괄적인 테스트 분석 리포트를 생성합니다
    func generateTestAnalysisReport() -> TestAnalysisReport {
        return queue.sync {
            let successfulTests = _testCases.filter { $0.success == true }
            let failedTests = _testCases.filter { $0.success == false }

            let totalDuration = _testCases.compactMap { $0.duration }.reduce(0, +)
            let averageDuration = _testCases.isEmpty ? 0 : totalDuration / Double(_testCases.count)

            // 카테고리별 분석
            let testsByCategory = Dictionary(grouping: _testCases) { $0.category }

            // 의존성 사용 패턴 분석
            let mostUsedDependencies = Array(_dependencyUsage.values
                .sorted { $0.totalUsageCount > $1.totalUsageCount }
                .prefix(5))

            let slowestDependencies = Array(_dependencyUsage.values
                .sorted { $0.averageResolveTime > $1.averageResolveTime }
                .prefix(5))

            // Mock 사용 분석
            let mockUsageAnalysis = analyzeMockUsage()

            return TestAnalysisReport(
                totalTests: _testCases.count,
                successfulTests: successfulTests.count,
                failedTests: failedTests.count,
                successRate: _testCases.isEmpty ? 0 : Double(successfulTests.count) / Double(_testCases.count),
                totalDuration: totalDuration,
                averageDuration: averageDuration,
                testsByCategory: testsByCategory.mapValues { $0.count },
                mostUsedDependencies: mostUsedDependencies,
                slowestDependencies: slowestDependencies,
                mockUsageAnalysis: mockUsageAnalysis,
                reportGeneratedAt: Date()
            )
        }
    }

    private func analyzeMockUsage() -> MockUsageAnalysis {
        let totalMockInteractions = _mockInteractions.values.map { $0.totalInteractions }.reduce(0, +)
        let mostInteractiveMocks = Array(_mockInteractions.values
            .sorted { $0.totalInteractions > $1.totalInteractions }
            .prefix(3))

        let methodCallDistribution = _mockInteractions.values.flatMap { stats in
            stats.methodCallCounts.map { (method: $0.key, calls: $0.value) }
        }
        let sortedMethodCalls = methodCallDistribution.sorted { $0.calls > $1.calls }

        return MockUsageAnalysis(
            totalMockTypes: _mockInteractions.count,
            totalInteractions: totalMockInteractions,
            mostInteractiveMocks: mostInteractiveMocks,
            topMethodCalls: Array(sortedMethodCalls.prefix(5))
        )
    }
}

// MARK: - 통계 데이터 구조

struct TestCaseStats {
    let name: String
    let category: String
    let startTime: Date
    var endTime: Date?
    var success: Bool?
    var duration: TimeInterval?
}

struct DependencyUsageStats {
    let typeName: String
    private(set) var totalUsageCount: Int = 0
    private(set) var mockUsageCount: Int = 0
    private(set) var realUsageCount: Int = 0
    private(set) var totalResolveTime: TimeInterval = 0.0
    private(set) var usageByTestCase: [String: Int] = [:]

    var averageResolveTime: TimeInterval {
        totalUsageCount > 0 ? totalResolveTime / Double(totalUsageCount) : 0.0
    }

    var mockUsageRate: Double {
        totalUsageCount > 0 ? Double(mockUsageCount) / Double(totalUsageCount) : 0.0
    }

    mutating func recordUsage(resolveTime: TimeInterval, isMock: Bool, testCase: String) {
        totalUsageCount += 1
        totalResolveTime += resolveTime
        usageByTestCase[testCase, default: 0] += 1

        if isMock {
            mockUsageCount += 1
        } else {
            realUsageCount += 1
        }
    }
}

struct MockInteractionStats {
    let mockType: String
    private(set) var totalInteractions: Int = 0
    private(set) var methodCallCounts: [String: Int] = [:]
    private(set) var interactionsByTestCase: [String: Int] = [:]

    mutating func recordInteraction(method: String, parameters: [String: Any], testCase: String) {
        totalInteractions += 1
        methodCallCounts[method, default: 0] += 1
        interactionsByTestCase[testCase, default: 0] += 1
    }
}

struct TestAnalysisReport {
    let totalTests: Int
    let successfulTests: Int
    let failedTests: Int
    let successRate: Double
    let totalDuration: TimeInterval
    let averageDuration: TimeInterval
    let testsByCategory: [String: Int]
    let mostUsedDependencies: [DependencyUsageStats]
    let slowestDependencies: [DependencyUsageStats]
    let mockUsageAnalysis: MockUsageAnalysis
    let reportGeneratedAt: Date
}

struct MockUsageAnalysis {
    let totalMockTypes: Int
    let totalInteractions: Int
    let mostInteractiveMocks: [MockInteractionStats]
    let topMethodCalls: [(method: String, calls: Int)]
}

// MARK: - 테스트 스위트 실행기

/// 여러 테스트 케이스를 체계적으로 실행하고 분석하는 시스템
final class TestSuiteRunner {
    private let statsCollector = TestExecutionStatsCollector()
    private let container: TestDIContainer

    init(container: TestDIContainer) {
        self.container = container
    }

    /// 테스트 스위트를 실행합니다
    func runTestSuite(_ testSuite: TestSuite) async {
        #logInfo("🚀 테스트 스위트 실행 시작: \(testSuite.name)")

        for testCase in testSuite.testCases {
            await runSingleTest(testCase)
        }

        #logInfo("✅ 테스트 스위트 실행 완료: \(testSuite.name)")
    }

    private func runSingleTest(_ testCase: TestCase) async {
        statsCollector.beginTestCase(name: testCase.name, category: testCase.category)

        var success = false
        do {
            // 테스트 설정
            await testCase.setup?(container)

            // 테스트 실행
            await testCase.execute(container, statsCollector)
            success = true

        } catch {
            #logError("❌ 테스트 실패: \(testCase.name) - \(error.localizedDescription)")
            success = false
        }

        // 테스트 정리
        await testCase.tearDown?(container)

        statsCollector.endTestCase(success: success)
    }

    /// 테스트 분석 리포트를 생성합니다
    func generateReport() -> TestAnalysisReport {
        return statsCollector.generateTestAnalysisReport()
    }
}

// MARK: - 테스트 케이스 정의

struct TestSuite {
    let name: String
    let testCases: [TestCase]
}

struct TestCase {
    let name: String
    let category: String
    let setup: ((TestDIContainer) async -> Void)?
    let execute: (TestDIContainer, TestExecutionStatsCollector) async throws -> Void
    let tearDown: ((TestDIContainer) async -> Void)?
}

// MARK: - 실제 비즈니스 로직 (테스트 대상)

protocol OrderProcessor: Sendable {
    func processOrder(_ order: Order) async throws -> ProcessedOrder
}

struct Order: Codable {
    let id: String
    let userId: String
    let items: [OrderItem]
    let totalAmount: Double
}

struct OrderItem: Codable {
    let productId: String
    let quantity: Int
    let price: Double
}

struct ProcessedOrder: Codable {
    let orderId: String
    let status: String
    let processedAt: Date
    let confirmationNumber: String
}

final class DefaultOrderProcessor: OrderProcessor {
    @Inject private var paymentService: PaymentService
    @Inject private var inventoryService: InventoryService
    @Inject private var notificationService: NotificationService

    func processOrder(_ order: Order) async throws -> ProcessedOrder {
        #logInfo("💼 주문 처리 시작: \(order.id)")

        // 1. 재고 확인
        for item in order.items {
            let available = try await inventoryService.checkAvailability(productId: item.productId, quantity: item.quantity)
            guard available else {
                throw OrderProcessingError.insufficientStock(item.productId)
            }
        }

        // 2. 결제 처리
        let paymentResult = try await paymentService.processPayment(amount: order.totalAmount, orderId: order.id)

        // 3. 재고 차감
        for item in order.items {
            try await inventoryService.reserveStock(productId: item.productId, quantity: item.quantity)
        }

        // 4. 알림 발송
        await notificationService.sendOrderConfirmation(orderId: order.id, userId: order.userId)

        return ProcessedOrder(
            orderId: order.id,
            status: "processed",
            processedAt: Date(),
            confirmationNumber: paymentResult.confirmationNumber
        )
    }
}

// 필요한 서비스 프로토콜들
protocol PaymentService: Sendable {
    func processPayment(amount: Double, orderId: String) async throws -> PaymentResult
}

protocol InventoryService: Sendable {
    func checkAvailability(productId: String, quantity: Int) async throws -> Bool
    func reserveStock(productId: String, quantity: Int) async throws
}

protocol NotificationService: Sendable {
    func sendOrderConfirmation(orderId: String, userId: String) async
}

struct PaymentResult {
    let confirmationNumber: String
    let transactionId: String
}

enum OrderProcessingError: Error {
    case insufficientStock(String)
    case paymentFailed(String)
}

// MARK: - 향상된 Mock 서비스들

final class EnhancedMockPaymentService: BaseMock, PaymentService {
    private var shouldFail = false
    private var failureReason = "Payment declined"

    func setShouldFail(_ fail: Bool, reason: String = "Payment declined") {
        shouldFail = fail
        failureReason = reason
    }

    func processPayment(amount: Double, orderId: String) async throws -> PaymentResult {
        trackCall(method: "processPayment", parameters: [
            "amount": amount,
            "orderId": orderId
        ])

        if shouldFail {
            throw OrderProcessingError.paymentFailed(failureReason)
        }

        return PaymentResult(
            confirmationNumber: "CONF-\(orderId)-\(Int.random(in: 1000...9999))",
            transactionId: "TXN-\(UUID().uuidString.prefix(8))"
        )
    }
}

final class EnhancedMockInventoryService: BaseMock, InventoryService {
    private var stockLevels: [String: Int] = [:]
    private var reservedStock: [String: Int] = [:]

    func setStockLevel(productId: String, quantity: Int) {
        stockLevels[productId] = quantity
        #logInfo("📦 재고 설정: \(productId) = \(quantity)")
    }

    func checkAvailability(productId: String, quantity: Int) async throws -> Bool {
        trackCall(method: "checkAvailability", parameters: [
            "productId": productId,
            "quantity": quantity
        ])

        let availableStock = stockLevels[productId, default: 0]
        let reserved = reservedStock[productId, default: 0]
        let actualAvailable = availableStock - reserved

        return actualAvailable >= quantity
    }

    func reserveStock(productId: String, quantity: Int) async throws {
        trackCall(method: "reserveStock", parameters: [
            "productId": productId,
            "quantity": quantity
        ])

        reservedStock[productId, default: 0] += quantity
        #logInfo("🔒 재고 예약: \(productId) +\(quantity)")
    }
}

final class EnhancedMockNotificationService: BaseMock, NotificationService {
    private var sentNotifications: [(orderId: String, userId: String, timestamp: Date)] = []

    func sendOrderConfirmation(orderId: String, userId: String) async {
        trackCall(method: "sendOrderConfirmation", parameters: [
            "orderId": orderId,
            "userId": userId
        ])

        sentNotifications.append((orderId, userId, Date()))
        #logInfo("📧 알림 발송: 주문 \(orderId) → 사용자 \(userId)")
    }

    func getSentNotifications() -> [(orderId: String, userId: String, timestamp: Date)] {
        return sentNotifications
    }
}

// MARK: - 종합 테스트 시나리오 데모

final class ComprehensiveTestDemo {
    private let container = TestDIContainer()
    private let testRunner: TestSuiteRunner

    init() {
        setupTestEnvironment()
        testRunner = TestSuiteRunner(container: container)
    }

    private func setupTestEnvironment() {
        // Mock 서비스들 등록
        container.registerMock(EnhancedMockPaymentService(), for: PaymentService.self)
        container.registerMock(EnhancedMockInventoryService(), for: InventoryService.self)
        container.registerMock(EnhancedMockNotificationService(), for: NotificationService.self)

        // 실제 서비스 등록
        container.registerTestImpl({ DefaultOrderProcessor() }, for: OrderProcessor.self)
    }

    func runComprehensiveTests() async {
        #logInfo("🎬 종합 테스트 시나리오 데모 시작")

        let testSuite = createTestSuite()
        await testRunner.runTestSuite(testSuite)

        let report = testRunner.generateReport()
        displayTestReport(report)

        #logInfo("🎉 종합 테스트 시나리오 데모 완료")
    }

    private func createTestSuite() -> TestSuite {
        return TestSuite(name: "OrderProcessing", testCases: [
            // 성공 시나리오
            TestCase(
                name: "성공적인 주문 처리",
                category: "success",
                setup: { container in
                    let inventory = container.resolve(EnhancedMockInventoryService.self)
                    inventory.setStockLevel(productId: "PROD-001", quantity: 100)
                    inventory.setStockLevel(productId: "PROD-002", quantity: 50)
                },
                execute: { container, stats in
                    let startTime = Date()
                    let processor = container.resolve(OrderProcessor.self)
                    let resolveTime = Date().timeIntervalSince(startTime)

                    stats.recordDependencyUsage(OrderProcessor.self, resolveTime: resolveTime, isMock: false, testCaseName: "성공적인 주문 처리")

                    let order = Order(
                        id: "ORDER-001",
                        userId: "USER-123",
                        items: [
                            OrderItem(productId: "PROD-001", quantity: 2, price: 29.99),
                            OrderItem(productId: "PROD-002", quantity: 1, price: 49.99)
                        ],
                        totalAmount: 109.97
                    )

                    let result = try await processor.processOrder(order)
                    assert(result.status == "processed")

                    // Mock 상호작용 기록
                    let paymentMock = container.resolve(EnhancedMockPaymentService.self)
                    stats.recordMockInteraction(
                        mockType: "PaymentService",
                        method: "processPayment",
                        parameters: ["amount": 109.97],
                        testCaseName: "성공적인 주문 처리"
                    )
                },
                tearDown: nil
            ),

            // 재고 부족 시나리오
            TestCase(
                name: "재고 부족 주문 처리",
                category: "failure",
                setup: { container in
                    let inventory = container.resolve(EnhancedMockInventoryService.self)
                    inventory.setStockLevel(productId: "PROD-003", quantity: 1) // 부족한 재고
                },
                execute: { container, stats in
                    let processor = container.resolve(OrderProcessor.self)
                    stats.recordDependencyUsage(OrderProcessor.self, resolveTime: 0.001, isMock: false, testCaseName: "재고 부족 주문 처리")

                    let order = Order(
                        id: "ORDER-002",
                        userId: "USER-456",
                        items: [OrderItem(productId: "PROD-003", quantity: 5, price: 19.99)], // 재고보다 많이 주문
                        totalAmount: 99.95
                    )

                    do {
                        _ = try await processor.processOrder(order)
                        throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected error but succeeded"])
                    } catch OrderProcessingError.insufficientStock {
                        // 예상된 에러
                    }
                },
                tearDown: nil
            ),

            // 결제 실패 시나리오
            TestCase(
                name: "결제 실패 주문 처리",
                category: "failure",
                setup: { container in
                    let inventory = container.resolve(EnhancedMockInventoryService.self)
                    inventory.setStockLevel(productId: "PROD-004", quantity: 100)

                    let payment = container.resolve(EnhancedMockPaymentService.self)
                    payment.setShouldFail(true, reason: "Insufficient funds")
                },
                execute: { container, stats in
                    let processor = container.resolve(OrderProcessor.self)
                    stats.recordDependencyUsage(OrderProcessor.self, resolveTime: 0.002, isMock: false, testCaseName: "결제 실패 주문 처리")

                    let order = Order(
                        id: "ORDER-003",
                        userId: "USER-789",
                        items: [OrderItem(productId: "PROD-004", quantity: 1, price: 999.99)],
                        totalAmount: 999.99
                    )

                    do {
                        _ = try await processor.processOrder(order)
                        throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected payment failure"])
                    } catch OrderProcessingError.paymentFailed {
                        // 예상된 에러
                        stats.recordMockInteraction(
                            mockType: "PaymentService",
                            method: "processPayment",
                            parameters: ["failed": true],
                            testCaseName: "결제 실패 주문 처리"
                        )
                    }
                },
                tearDown: { container in
                    let payment = container.resolve(EnhancedMockPaymentService.self)
                    payment.setShouldFail(false) // 상태 초기화
                }
            )
        ])
    }

    private func displayTestReport(_ report: TestAnalysisReport) {
        #logInfo("\n📊 종합 테스트 분석 리포트")
        #logInfo("=" * 50)

        #logInfo("🎯 전체 결과:")
        #logInfo("- 총 테스트: \(report.totalTests)개")
        #logInfo("- 성공: \(report.successfulTests)개")
        #logInfo("- 실패: \(report.failedTests)개")
        #logInfo("- 성공률: \(String(format: "%.1f", report.successRate * 100))%")
        #logInfo("- 총 실행 시간: \(String(format: "%.3f", report.totalDuration))초")
        #logInfo("- 평균 실행 시간: \(String(format: "%.3f", report.averageDuration))초")

        #logInfo("\n📂 카테고리별 결과:")
        for (category, count) in report.testsByCategory {
            #logInfo("- \(category): \(count)개")
        }

        #logInfo("\n🔧 의존성 사용 분석:")
        for dep in report.mostUsedDependencies {
            #logInfo("- \(dep.typeName): \(dep.totalUsageCount)회 사용 (Mock 비율: \(String(format: "%.1f", dep.mockUsageRate * 100))%)")
        }

        if !report.slowestDependencies.isEmpty {
            #logInfo("\n⏱️ 느린 의존성:")
            for dep in report.slowestDependencies {
                #logInfo("- \(dep.typeName): 평균 \(String(format: "%.3f", dep.averageResolveTime * 1000))ms")
            }
        }

        #logInfo("\n🎭 Mock 사용 분석:")
        let mockAnalysis = report.mockUsageAnalysis
        #logInfo("- 사용된 Mock 타입: \(mockAnalysis.totalMockTypes)개")
        #logInfo("- 총 Mock 상호작용: \(mockAnalysis.totalInteractions)회")

        if !mockAnalysis.topMethodCalls.isEmpty {
            #logInfo("- 가장 많이 호출된 메서드:")
            for methodCall in mockAnalysis.topMethodCalls {
                #logInfo("  - \(methodCall.method): \(methodCall.calls)회")
            }
        }
    }
}

// MARK: - 테스트 시나리오 검증 데모

enum TestScenariosExample {
    static func demonstrateTestScenarios() async {
        #logInfo("🎬 테스트 시나리오 검증 및 통계 데모 시작")

        let demo = ComprehensiveTestDemo()
        await demo.runComprehensiveTests()

        #logInfo("🎉 테스트 시나리오 검증 및 통계 데모 완료")
    }
}

// MARK: - 유틸리티 함수

private extension String {
    static func * (string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}