//
//  CoreTests.swift
//  DiContainerTests
//
//  Created by Wonja Suh on 3/24/25.
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

    override func setUp() async throws {
        try await super.setUp()
        await DependencyContainer.resetForTesting()
    }

    override func tearDown() async throws {
        await DependencyContainer.resetForTesting()
        try await super.tearDown()
    }

    // MARK: - Basic Registration Tests

    func testBasicTypeRegistration() {
        // Given
        let service = TestUserServiceImpl()

        // When
        DI.register(TestUserService.self) { service }

        // Then
        let resolved = DI.resolve(TestUserService.self)
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.getUser(id: "123"), "user_123")
    }

    func testKeyPathRegistration() {
        // When
        let service = DI.register(\.testUserService) { TestUserServiceImpl() }

        // Then
        XCTAssertEqual(service.getUser(id: "456"), "user_456")

        let resolved = DI.resolve(TestUserService.self)
        XCTAssertNotNil(resolved)
    }

    func testConditionalRegistration() {
        // Test true condition
        DI.registerIf(
            TestUserService.self,
            condition: true,
            factory: { TestUserServiceImpl() },
            fallback: { MockUserService() }
        )

        let service1 = DI.resolve(TestUserService.self)
        XCTAssertEqual(service1?.getUser(id: "123"), "user_123")

        // Test false condition
        DI.release(TestUserService.self)

        DI.registerIf(
            TestUserService.self,
            condition: false,
            factory: { TestUserServiceImpl() },
            fallback: { MockUserService() }
        )

        let service2 = DI.resolve(TestUserService.self)
        XCTAssertEqual(service2?.getUser(id: "123"), "mock_user_123")
    }

    func testBatchRegistration() {
        // When
        DI.registerMany {
            Registration(TestUserService.self) { TestUserServiceImpl() }
            Registration(TestNetworkService.self) { TestNetworkServiceImpl() }
            Registration(TestDatabaseService.self) { TestDatabaseServiceImpl() }
        }

        // Then
        let userService = DI.resolve(TestUserService.self)
        let networkService = DI.resolve(TestNetworkService.self)
        let dbService = DI.resolve(TestDatabaseService.self)

        XCTAssertNotNil(userService)
        XCTAssertNotNil(networkService)
        XCTAssertNotNil(dbService)

        XCTAssertEqual(userService?.getUser(id: "test"), "user_test")
        XCTAssertEqual(networkService?.fetchData(), "network_data")
        XCTAssertEqual(dbService?.query("SELECT * FROM users"), ["result_SELECT * FROM users"])
    }

    // MARK: - Resolution Tests

    func testOptionalResolution() {
        // Test without registration
        let service1 = DI.resolve(TestUserService.self)
        XCTAssertNil(service1)

        // Test with registration
        DI.register(TestUserService.self) { TestUserServiceImpl() }
        let service2 = DI.resolve(TestUserService.self)
        XCTAssertNotNil(service2)
    }

    func testRequiredResolution() {
        // Given
        DI.register(TestUserService.self) { TestUserServiceImpl() }

        // When
        let service = DI.requireResolve(TestUserService.self)

        // Then
        XCTAssertEqual(service.getUser(id: "required"), "user_required")
    }

    func testResolutionWithDefault() {
        // Test without registration
        let service1 = DI.resolve(TestUserService.self, default: MockUserService())
        XCTAssertEqual(service1.getUser(id: "default"), "mock_user_default")

        // Test with registration
        DI.register(TestUserService.self) { TestUserServiceImpl() }
        let service2 = DI.resolve(TestUserService.self, default: MockUserService())
        XCTAssertEqual(service2.getUser(id: "registered"), "user_registered")
    }

    func testThrowingResolution() throws {
        // Test without registration
        XCTAssertThrowsError(try DI.resolveThrows(TestUserService.self)) { error in
            XCTAssertTrue(error is DIError)
        }

        // Test with registration
        DI.register(TestUserService.self) { TestUserServiceImpl() }
        let service = try DI.resolveThrows(TestUserService.self)
        XCTAssertEqual(service.getUser(id: "throws"), "user_throws")
    }

    func testResultResolution() {
        // Test without registration
        let result1 = DI.resolveResult(TestUserService.self)
        switch result1 {
        case .failure(let error):
            XCTAssertTrue(error is DIError)
        case .success:
            XCTFail("Should have failed")
        }

        // Test with registration
        DI.register(TestUserService.self) { TestUserServiceImpl() }
        let result2 = DI.resolveResult(TestUserService.self)
        switch result2 {
        case .success(let service):
            XCTAssertEqual(service.getUser(id: "result"), "user_result")
        case .failure:
            XCTFail("Should have succeeded")
        }
    }

    // MARK: - Management Tests

    func testRelease() {
        // Given
        DI.register(TestUserService.self) { TestUserServiceImpl() }
        XCTAssertNotNil(DI.resolve(TestUserService.self))

        // When
        DI.release(TestUserService.self)

        // Then
        XCTAssertNil(DI.resolve(TestUserService.self))
    }

    func testIsRegistered() {
        // Test not registered
        XCTAssertFalse(DI.isRegistered(TestUserService.self))

        // Test registered
        DI.register(TestUserService.self) { TestUserServiceImpl() }
        XCTAssertTrue(DI.isRegistered(TestUserService.self))

        // Test after release
        DI.release(TestUserService.self)
        XCTAssertFalse(DI.isRegistered(TestUserService.self))
    }

    func testContainerStatus() async {
        // Test initial status
        let status1 = await DI.getContainerStatus()
        XCTAssertTrue(status1.isBootstrapped)

        // Register some dependencies
        DI.register(TestUserService.self) { TestUserServiceImpl() }
        DI.register(TestNetworkService.self) { TestNetworkServiceImpl() }

        let status2 = await DI.getContainerStatus()
        XCTAssertTrue(status2.isBootstrapped)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAccess() {
        let expectation = XCTestExpectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 100

        // Register initial service
        DI.register(TestUserService.self) { TestUserServiceImpl() }

        // Concurrent resolution
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            let service = DI.resolve(TestUserService.self)
            XCTAssertNotNil(service)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testConcurrentRegistration() {
        let expectation = XCTestExpectation(description: "Concurrent registration")
        expectation.expectedFulfillmentCount = 50

        DispatchQueue.concurrentPerform(iterations: 50) { index in
            DI.register(TestUserService.self) { TestUserServiceImpl() }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        // Verify final state
        let service = DI.resolve(TestUserService.self)
        XCTAssertNotNil(service)
    }

    // MARK: - Performance Tests

    func testResolutionPerformance() {
        // Setup
        DI.register(TestUserService.self) { TestUserServiceImpl() }

        // Measure resolution performance
        measure {
            for _ in 0..<1000 {
                _ = DI.resolve(TestUserService.self)
            }
        }
    }

    func testRegistrationPerformance() {
        measure {
            for _ in 0..<100 {
                DI.register(TestUserService.self) { TestUserServiceImpl() }
                DI.release(TestUserService.self)
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