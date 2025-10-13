//
//  DependencyValuesIntegrationTests.swift
//  WeaveDI
//
//  Created by Wonji Suh on 2025.
//

import XCTest
import WeaveDI

// MARK: - Test Services

protocol TestService: Sendable {
    func getValue() -> String
}

final class LiveTestService: TestService {
    func getValue() -> String { "live" }
}

final class MockTestService: TestService, @unchecked Sendable {
    var mockValue = "mock"
    func getValue() -> String { mockValue }
}

protocol AsyncTestService: Sendable {
    func performOperation() async -> String
}

final class LiveAsyncTestService: AsyncTestService {
    func performOperation() async -> String {
        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
        return "async_live_result"
    }
}

final class MockAsyncTestService: AsyncTestService, @unchecked Sendable {
    var mockResult = "async_mock_result"

    func performOperation() async -> String {
        return mockResult
    }
}

// MARK: - Test Keys

struct TestServiceKey: InjectedKey {
    static let liveValue: TestService = LiveTestService()
    static let testValue: TestService = MockTestService()
}

struct ExchangeRateServiceKey: InjectedKey {
    static let liveValue: ExchangeRateService = LiveExchangeRateService()
    static let testValue: ExchangeRateService = MockExchangeRateService()
}

struct AsyncTestServiceKey: InjectedKey {
    static let liveValue: AsyncTestService = LiveAsyncTestService()
    static let testValue: AsyncTestService = MockAsyncTestService()
}

// MARK: - InjectedValues Extensions

extension InjectedValues {
    var testService: TestService {
        get { self[TestServiceKey.self] }
        set { self[TestServiceKey.self] = newValue }
    }

    var exchangeRateService: ExchangeRateService {
        get { self[ExchangeRateServiceKey.self] }
        set { self[ExchangeRateServiceKey.self] = newValue }
    }

    var asyncTestService: AsyncTestService {
        get { self[AsyncTestServiceKey.self] }
        set { self[AsyncTestServiceKey.self] = newValue }
    }
}

// MARK: - Test Classes

class TestServiceConsumer {
    @Injected(\.testService) var service

    func callService() throws -> String {
        return service.getValue()
    }
}

class AsyncServiceConsumer {
    @Injected(\.asyncTestService) var service

    func performAsyncOperation() async -> String {
        return await service.performOperation()
    }
}

class KeyPathBasedService {
    @Injected(\.testService) var service

    func accessService() -> String? {
        return service.getValue()
    }
}

// MARK: - Exchange Rate Services

protocol ExchangeRateService: Sendable {
    func getRate(from: Currency, to: Currency) async throws -> ExchangeRate
}

final class LiveExchangeRateService: ExchangeRateService {
    func getRate(from: Currency, to: Currency) async throws -> ExchangeRate {
        // 실제 API 호출 시뮬레이션
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        return ExchangeRate(from: from, to: to, rate: 1.2345, timestamp: Date())
    }
}

final class MockExchangeRateService: ExchangeRateService, @unchecked Sendable {
    var mockRate: Double = 1.0

    func getRate(from: Currency, to: Currency) async throws -> ExchangeRate {
        return ExchangeRate(from: from, to: to, rate: mockRate, timestamp: Date())
    }
}

enum Currency: String, Sendable {
    case USD, EUR, KRW, JPY
}

struct ExchangeRate: Sendable, Equatable {
    let from: Currency
    let to: Currency
    let rate: Double
    let timestamp: Date

    static func == (lhs: ExchangeRate, rhs: ExchangeRate) -> Bool {
        lhs.from == rhs.from &&
        lhs.to == rhs.to &&
        abs(lhs.rate - rhs.rate) < 0.0001
    }
}

class ExchangeController {
    @Injected(\.exchangeRateService) var exchangeService

    func getCurrentRate(from: Currency, to: Currency) async throws -> ExchangeRate {
        return try await exchangeService.getRate(from: from, to: to)
    }
}

enum TestError: Error {
    case serviceNotFound
}

// MARK: - Test Cases

final class DependencyValuesIntegrationTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        // 각 테스트마다 깨끗한 컨테이너로 시작
        WeaveDI.Container.live = WeaveDI.Container()
    }

    // MARK: - Basic InjectedKey Usage Tests

    func testBasicInjectedKeyUsage() async throws {
        // When: InjectedKey를 통해 서비스 접근
        let service = InjectedValues.current[TestServiceKey.self]

        // Then: 기본값이 반환됨
        XCTAssertEqual(service.getValue(), "mock")
    }

    func testInjectedKeyWithOverride() async throws {
        let mockService = MockTestService()
        mockService.mockValue = "custom_mock"

        // When: withInjectedValues로 값 오버라이드
        let result = withInjectedValues {
            $0[TestServiceKey.self] = mockService
        } operation: {
            let service = InjectedValues.current[TestServiceKey.self]
            return service.getValue()
        }

        // Then: 오버라이드된 값이 반환됨
        XCTAssertEqual(result, "custom_mock")
    }

    func testInjectedWithKeyPath() async throws {
        let mockService = MockTestService()
        mockService.mockValue = "keypath_test"

        // When: KeyPath 기반으로 값 설정하고 @Injected로 접근
        let result = withInjectedValues {
            $0.testService = mockService
        } operation: {
            let consumer = TestServiceConsumer()
            return try! consumer.callService()
        }

        // Then: KeyPath를 통해 설정한 값이 @Injected로 접근됨
        XCTAssertEqual(result, "keypath_test")
    }

    // MARK: - Async Integration Tests

    func testAsyncServiceIntegration() async throws {
        let mockAsyncService = MockAsyncTestService()
        mockAsyncService.mockResult = "async_integration_test"

        // When: 비동기 서비스 테스트
        let result = await withInjectedValues {
            $0.asyncTestService = mockAsyncService
        } operation: {
            let consumer = AsyncServiceConsumer()
            return await consumer.performAsyncOperation()
        }

        // Then: 비동기 서비스가 정상 작동
        XCTAssertEqual(result, "async_integration_test")
    }

    // MARK: - Real-world Example: Exchange Rate Service

    func testExchangeRateServiceIntegration() async throws {
        let mockService = MockExchangeRateService()
        mockService.mockRate = 1300.0

        // When: 환율 서비스를 사용하는 컨트롤러 테스트
        let rate = await withInjectedValues {
            $0.exchangeRateService = mockService
        } operation: {
            let controller = ExchangeController()
            return try! await controller.getCurrentRate(from: .USD, to: .KRW)
        }

        // Then: 올바른 환율이 반환됨
        XCTAssertEqual(rate.rate, 1300.0)
        XCTAssertEqual(rate.from, .USD)
        XCTAssertEqual(rate.to, .KRW)
    }

    func testNestedInjectedValues() async throws {
        let outerMock = MockTestService()
        outerMock.mockValue = "outer"

        let innerMock = MockTestService()
        innerMock.mockValue = "inner"

        // When: 중첩된 withInjectedValues 테스트
        let results = withInjectedValues {
            $0.testService = outerMock
        } operation: {
            let outerResult = InjectedValues.current.testService.getValue()

            let innerResult = withInjectedValues {
                $0.testService = innerMock
            } operation: {
                return InjectedValues.current.testService.getValue()
            }

            let afterInnerResult = InjectedValues.current.testService.getValue()
            return (outerResult, innerResult, afterInnerResult)
        }

        // Then: 중첩된 스코프가 올바르게 작동
        XCTAssertEqual(results.0, "outer")  // 외부 스코프
        XCTAssertEqual(results.1, "inner")  // 내부 스코프
        XCTAssertEqual(results.2, "outer")  // 내부 스코프 종료 후 외부 스코프 복원
    }

    // MARK: - Performance Tests

    func testInjectedValuesPerformance() async throws {
        measure {
            for _ in 0..<1000 {
                let _ = InjectedValues.current[TestServiceKey.self]
            }
        }
    }

    func testWithInjectedValuesPerformance() async throws {
        let mockService = MockTestService()

        await measureAsync {
            for _ in 0..<100 {
                withInjectedValues {
                    $0.testService = mockService
                } operation: {
                    let _ = InjectedValues.current.testService.getValue()
                }
            }
        }
    }

    // MARK: - Error Handling Tests

    func testMissingDependencyHandling() async throws {
        // Given: 정의되지 않은 키 타입
        struct UndefinedServiceKey: InjectedKey {
            static let liveValue: TestService = LiveTestService()
            static let testValue: TestService = MockTestService()
        }

        // When: 정의되지 않은 키로 접근
        let service = InjectedValues.current[UndefinedServiceKey.self]

        // Then: liveValue가 반환됨 (기본 동작)
        XCTAssertEqual(service.getValue(), "mock")
    }
}

// MARK: - Helper Extensions

extension XCTestCase {
    func measureAsync(block: @escaping @Sendable () async -> Void) async {
        await withCheckedContinuation { continuation in
            measure {
                let group = DispatchGroup()
                group.enter()
                Task { @Sendable in
                    await block()
                    group.leave()
                }
                group.wait()
            }
            continuation.resume()
        }
    }
}
