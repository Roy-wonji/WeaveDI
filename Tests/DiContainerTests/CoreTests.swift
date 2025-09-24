//
//  CoreTests.swift
//  DiContainerTests
//
//  Created by Wonja Suh on 9/24/25.
//

import XCTest
@testable import DiContainer

// MARK: - Test Services

protocol TestUserService: Sendable {
    func getUser(id: String) -> String
}

final class TestUserServiceImpl: TestUserService, @unchecked Sendable {
    func getUser(id: String) -> String {
        return "user_\(id)"
    }
}

final class MockUserService: TestUserService, @unchecked Sendable {
    func getUser(id: String) -> String {
        return "mock_user_\(id)"
    }
}

protocol TestNetworkService: Sendable {
    func fetchData() -> String
}

final class TestNetworkServiceImpl: TestNetworkService, @unchecked Sendable {
    func fetchData() -> String {
        return "network_data"
    }
}

protocol TestDatabaseService: Sendable {
    func query(_ sql: String) -> [String]
}

final class TestDatabaseServiceImpl: TestDatabaseService, @unchecked Sendable {
    func query(_ sql: String) -> [String] {
        return ["result_\(sql)"]
    }
}

// MARK: - Core DI Tests

final class CoreTests: XCTestCase {

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        UnifiedDI.releaseAll()

        // 테스트를 위한 자동 로깅 비활성화
        UnifiedDI.setLogLevel(.off)
    }

    @MainActor
    override func tearDown() async throws {
        // UnifiedDI 방식으로 변경
        UnifiedDI.releaseAll()
        UnifiedDI.resetStats()

        try await super.tearDown()
    }

    // MARK: - Basic Registration Tests

    func testBasicTypeRegistration_기본타입등록() {
        // Given & When
        let service = UnifiedDI.register(TestUserService.self) {
            TestUserServiceImpl()
        }

        // Then
        XCTAssertEqual(service.getUser(id: "123"), "user_123")

        let resolved = UnifiedDI.resolve(TestUserService.self)
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.getUser(id: "456"), "user_456")
    }

    func testKeyPathRegistration_키패스등록() {
        // When
        let service = UnifiedDI.register(\.testUserService) { TestUserServiceImpl() }

        // Then
        XCTAssertEqual(service.getUser(id: "456"), "user_456")

        let resolved = UnifiedDI.resolve(TestUserService.self)
        XCTAssertNotNil(resolved)
    }

    func testConditionalRegistration_조건부등록() {
        // Test true condition
        UnifiedDI.Conditional.registerIf(
            TestUserService.self,
            condition: true,
            factory: { TestUserServiceImpl() },
            fallback: { MockUserService() }
        )

        let service1 = UnifiedDI.resolve(TestUserService.self)
        XCTAssertEqual(service1?.getUser(id: "123"), "user_123")

        // Test false condition
        UnifiedDI.release(TestUserService.self)

        UnifiedDI.Conditional.registerIf(
            TestUserService.self,
            condition: false,
            factory: { TestUserServiceImpl() },
            fallback: { MockUserService() }
        )

        let service2 = UnifiedDI.resolve(TestUserService.self)
        XCTAssertEqual(service2?.getUser(id: "123"), "mock_user_123")
    }

    func testBatchRegistration_배치등록() {
        // When - 배치 등록 대신 개별 등록으로 변경
        _ = UnifiedDI.register(TestUserService.self) { TestUserServiceImpl() }
        _ = UnifiedDI.register(TestNetworkService.self) { TestNetworkServiceImpl() }
        _ = UnifiedDI.register(TestDatabaseService.self) { TestDatabaseServiceImpl() }

        // Then
        let userService = UnifiedDI.resolve(TestUserService.self)
        let networkService = UnifiedDI.resolve(TestNetworkService.self)
        let dbService = UnifiedDI.resolve(TestDatabaseService.self)

        XCTAssertNotNil(userService)
        XCTAssertNotNil(networkService)
        XCTAssertNotNil(dbService)

        XCTAssertEqual(userService?.getUser(id: "test"), "user_test")
        XCTAssertEqual(networkService?.fetchData(), "network_data")
        XCTAssertEqual(dbService?.query("SELECT * FROM users"), ["result_SELECT * FROM users"])
    }

    // MARK: - Resolution Tests

    func testOptionalResolution_옵셔널해결() {
        // Test without registration
        let service1 = UnifiedDI.resolve(TestUserService.self)
        XCTAssertNil(service1)

        // Test with registration
        _ = UnifiedDI.register(TestUserService.self) { TestUserServiceImpl() }
        let service2 = UnifiedDI.resolve(TestUserService.self)
        XCTAssertNotNil(service2)
    }

    func testRequiredResolution_필수해결() {
        // Given
        _ = UnifiedDI.register(TestUserService.self) { TestUserServiceImpl() }

        // When
        let service = UnifiedDI.requireResolve(TestUserService.self)

        // Then
        XCTAssertEqual(service.getUser(id: "required"), "user_required")
    }

    func testResolutionWithDefault_기본값포함해결() {
        // Test without registration
        let service1 = UnifiedDI.resolve(TestUserService.self, default: MockUserService())
        XCTAssertEqual(service1.getUser(id: "default"), "mock_user_default")

        // Test with registration
        _ = UnifiedDI.register(TestUserService.self) { TestUserServiceImpl() }
        let service2 = UnifiedDI.resolve(TestUserService.self, default: MockUserService())
        XCTAssertEqual(service2.getUser(id: "registered"), "user_registered")
    }

    func testThrowingResolution_예외발생해결() throws {
        // Test without registration - deprecated API 제거로 인한 테스트 제거
        // 기본적으로 UnifiedDI.resolve는 nil을 반환하므로 에러를 던지지 않음

        // Test with registration
        _ = UnifiedDI.register(TestUserService.self) { TestUserServiceImpl() }
        let service = UnifiedDI.resolve(TestUserService.self)
        XCTAssertNotNil(service)
        XCTAssertEqual(service?.getUser(id: "throws"), "user_throws")
    }

    func testResultResolution_결과타입해결() {
        // Result API가 deprecated되어 기본 해결 방식으로 테스트
        // Test without registration
        let service1 = UnifiedDI.resolve(TestUserService.self)
        XCTAssertNil(service1)

        // Test with registration
        _ = UnifiedDI.register(TestUserService.self) { TestUserServiceImpl() }
        let service2 = UnifiedDI.resolve(TestUserService.self)
        XCTAssertNotNil(service2)
        XCTAssertEqual(service2?.getUser(id: "result"), "user_result")
    }

    // MARK: - Management Tests

    func testRelease_해제() {
        // Given
        _ = UnifiedDI.register(TestUserService.self) { TestUserServiceImpl() }
        XCTAssertNotNil(UnifiedDI.resolve(TestUserService.self))

        // When
        UnifiedDI.release(TestUserService.self)

        // Then
        XCTAssertNil(UnifiedDI.resolve(TestUserService.self))
    }

    func testIsRegistered_등록상태확인() {
        // isRegistered API가 deprecated되어 resolve로 테스트
        // Test not registered
        XCTAssertNil(UnifiedDI.resolve(TestUserService.self))

        // Test registered
        _ = UnifiedDI.register(TestUserService.self) { TestUserServiceImpl() }
        XCTAssertNotNil(UnifiedDI.resolve(TestUserService.self))

        // Test after release
        UnifiedDI.release(TestUserService.self)
        XCTAssertNil(UnifiedDI.resolve(TestUserService.self))
    }

    func testContainerStatus_컨테이너상태() async {
        // 컨테이너 상태 API가 deprecated되어 기본적인 등록/해결 테스트로 변경

        // Register some dependencies
        _ = UnifiedDI.register(TestUserService.self) { TestUserServiceImpl() }
        _ = UnifiedDI.register(TestNetworkService.self) { TestNetworkServiceImpl() }

        // Verify registrations
        XCTAssertNotNil(UnifiedDI.resolve(TestUserService.self))
        XCTAssertNotNil(UnifiedDI.resolve(TestNetworkService.self))
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAccess_동시접근() {
        let expectation = XCTestExpectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 100

        // Register initial service
        _ = UnifiedDI.register(TestUserService.self) { TestUserServiceImpl() }

        // Concurrent resolution
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            let service = UnifiedDI.resolve(TestUserService.self)
            XCTAssertNotNil(service)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testConcurrentRegistration_동시등록() {
        let expectation = XCTestExpectation(description: "Concurrent registration")
        expectation.expectedFulfillmentCount = 50

        DispatchQueue.concurrentPerform(iterations: 50) { index in
            _ = UnifiedDI.register(TestUserService.self) { TestUserServiceImpl() }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        // Verify final state
        let service = UnifiedDI.resolve(TestUserService.self)
        XCTAssertNotNil(service)
    }

    // MARK: - Performance Tests

    func testResolutionPerformance_해결성능() {
        // Setup
        _ = UnifiedDI.register(TestUserService.self) { TestUserServiceImpl() }

        // Measure resolution performance
        measure {
            for _ in 0..<1000 {
                _ = UnifiedDI.resolve(TestUserService.self)
            }
        }
    }

    func testRegistrationPerformance_등록성능() {
        measure {
            for _ in 0..<100 {
                _ = UnifiedDI.register(TestUserService.self) { TestUserServiceImpl() }
                UnifiedDI.release(TestUserService.self)
            }
        }
    }
}

// MARK: - DependencyContainer Extension for Tests

extension DependencyContainer {
    var testUserService: TestUserService? {
        return resolve(TestUserService.self)
    }

    var testNetworkService: TestNetworkService? {
        return resolve(TestNetworkService.self)
    }

    var testDatabaseService: TestDatabaseService? {
        return resolve(TestDatabaseService.self)
    }
}