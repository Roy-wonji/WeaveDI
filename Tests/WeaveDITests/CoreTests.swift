//
//  CoreTests.swift
//  DiContainerTests
//
//  Created by Wonja Suh on 9/24/25.
//

import XCTest
@testable import WeaveDI

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

    func testBasicTypeRegistration_기본타입등록() async throws {
        // Given & When
        let service = await UnifiedDI.registerAsync(TestUserService.self) {
            TestUserServiceImpl()
        }

        // Then
        XCTAssertEqual(service.getUser(id: "123"), "user_123")

        let resolved = await UnifiedDI.resolveAsync(TestUserService.self)
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.getUser(id: "456"), "user_456")
    }

    func testKeyPathRegistration_키패스등록() async throws {
        // When
        let service = UnifiedDI.register(\.testUserService) { TestUserServiceImpl() }

        // Then
        XCTAssertEqual(service.getUser(id: "456"), "user_456")

        // Wait for async registration to complete
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        let resolved = await UnifiedDI.resolveAsync(TestUserService.self)
        XCTAssertNotNil(resolved)
    }

    func testConditionalRegistration_조건부등록() async throws {
        // Test true condition
        let service1 = UnifiedDI.Conditional.registerIf(
            TestUserService.self,
            condition: true,
            factory: { TestUserServiceImpl() },
            fallback: { MockUserService() }
        )
        XCTAssertEqual(service1.getUser(id: "123"), "user_123")

        // Test false condition
        UnifiedDI.release(TestUserService.self)

        let service2 = UnifiedDI.Conditional.registerIf(
            TestUserService.self,
            condition: false,
            factory: { TestUserServiceImpl() },
            fallback: { MockUserService() }
        )
        XCTAssertEqual(service2.getUser(id: "123"), "mock_user_123")
    }

    func testBatchRegistration_배치등록() async throws {
        // When - 배치 등록 대신 개별 등록으로 변경
        _ = await UnifiedDI.registerAsync(TestUserService.self) { TestUserServiceImpl() }
        _ = await UnifiedDI.registerAsync(TestNetworkService.self) { TestNetworkServiceImpl() }
        _ = await UnifiedDI.registerAsync(TestDatabaseService.self) { TestDatabaseServiceImpl() }

        // Then
        let userService = await UnifiedDI.resolveAsync(TestUserService.self)
        let networkService = await UnifiedDI.resolveAsync(TestNetworkService.self)
        let dbService = await UnifiedDI.resolveAsync(TestDatabaseService.self)

        XCTAssertNotNil(userService)
        XCTAssertNotNil(networkService)
        XCTAssertNotNil(dbService)

        XCTAssertEqual(userService?.getUser(id: "test"), "user_test")
        XCTAssertEqual(networkService?.fetchData(), "network_data")
        XCTAssertEqual(dbService?.query("SELECT * FROM users"), ["result_SELECT * FROM users"])
    }

    // MARK: - Resolution Tests

    func testOptionalResolution_옵셔널해결() async throws {
        // Test without registration
        let service1 = await UnifiedDI.resolveAsync(TestUserService.self)
        XCTAssertNil(service1)

        // Test with registration
        _ = await UnifiedDI.registerAsync(TestUserService.self) { TestUserServiceImpl() }
        let service2 = await UnifiedDI.resolveAsync(TestUserService.self)
        XCTAssertNotNil(service2)
    }

    func testRequiredResolution_필수해결() async throws {
        // Given
        _ = await UnifiedDI.registerAsync(TestUserService.self) { TestUserServiceImpl() }

        // When
        let service = UnifiedDI.requireResolve(TestUserService.self)

        // Then
        XCTAssertEqual(service.getUser(id: "required"), "user_required")
    }

    func testResolutionWithDefault_기본값포함해결() async throws {
        // Test without registration
        let service1 = UnifiedDI.resolve(TestUserService.self, default: MockUserService())
        XCTAssertEqual(service1.getUser(id: "default"), "mock_user_default")

        // Test with registration
        _ = await UnifiedDI.registerAsync(TestUserService.self) { TestUserServiceImpl() }
        // Wait for async registration
        try await Task.sleep(nanoseconds: 10_000_000)
        let service2 = UnifiedDI.resolve(TestUserService.self, default: MockUserService())
        XCTAssertEqual(service2.getUser(id: "registered"), "user_registered")
    }

    func testThrowingResolution_예외발생해결() async throws {
        // Test without registration - deprecated API 제거로 인한 테스트 제거
        // 기본적으로 UnifiedDI.resolve는 nil을 반환하므로 에러를 던지지 않음

        // Test with registration
        _ = await UnifiedDI.registerAsync(TestUserService.self) { TestUserServiceImpl() }
        let service = await UnifiedDI.resolveAsync(TestUserService.self)
        XCTAssertNotNil(service)
        XCTAssertEqual(service?.getUser(id: "throws"), "user_throws")
    }

    func testResultResolution_결과타입해결() async throws {
        // Result API가 deprecated되어 기본 해결 방식으로 테스트
        // Test without registration
        let service1 = await UnifiedDI.resolveAsync(TestUserService.self)
        XCTAssertNil(service1)

        // Test with registration
        _ = await UnifiedDI.registerAsync(TestUserService.self) { TestUserServiceImpl() }
        let service2 = await UnifiedDI.resolveAsync(TestUserService.self)
        XCTAssertNotNil(service2)
        XCTAssertEqual(service2?.getUser(id: "result"), "user_result")
    }

    // MARK: - Management Tests

    func testRelease_해제() async throws {
        // Given
        _ = await UnifiedDI.registerAsync(TestUserService.self) { TestUserServiceImpl() }
        let beforeRelease = await UnifiedDI.resolveAsync(TestUserService.self)
        XCTAssertNotNil(beforeRelease)

        // When
        UnifiedDI.release(TestUserService.self)

        // Then
        let afterRelease = await UnifiedDI.resolveAsync(TestUserService.self)
        XCTAssertNil(afterRelease)
    }

    func testIsRegistered_등록상태확인() async throws {
        // isRegistered API가 deprecated되어 resolve로 테스트
        // Test not registered
        let notRegistered = await UnifiedDI.resolveAsync(TestUserService.self)
        XCTAssertNil(notRegistered)

        // Test registered
        _ = await UnifiedDI.registerAsync(TestUserService.self) { TestUserServiceImpl() }
        let registered = await UnifiedDI.resolveAsync(TestUserService.self)
        XCTAssertNotNil(registered)

        // Test after release
        UnifiedDI.release(TestUserService.self)
        let afterRelease = await UnifiedDI.resolveAsync(TestUserService.self)
        XCTAssertNil(afterRelease)
    }

    func testContainerStatus_컨테이너상태() async throws {
        // 컨테이너 상태 API가 deprecated되어 기본적인 등록/해결 테스트로 변경

        // Register some dependencies
        _ = await UnifiedDI.registerAsync(TestUserService.self) { TestUserServiceImpl() }
        _ = await UnifiedDI.registerAsync(TestNetworkService.self) { TestNetworkServiceImpl() }

        // Verify registrations
        let userService = await UnifiedDI.resolveAsync(TestUserService.self)
        let networkService = await UnifiedDI.resolveAsync(TestNetworkService.self)
        XCTAssertNotNil(userService)
        XCTAssertNotNil(networkService)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAccess_동시접근() async throws {
        // Register initial service
        _ = await UnifiedDI.registerAsync(TestUserService.self) { TestUserServiceImpl() }

        // Concurrent resolution using TaskGroup
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    let service = await UnifiedDI.resolveAsync(TestUserService.self)
                    XCTAssertNotNil(service)
                }
            }
        }
    }

    func testConcurrentRegistration_동시등록() async throws {
        // Concurrent registration using TaskGroup
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    _ = await UnifiedDI.registerAsync(TestUserService.self) { TestUserServiceImpl() }
                }
            }
        }

        // Verify final state
        let service = await UnifiedDI.resolveAsync(TestUserService.self)
        XCTAssertNotNil(service)
    }

    // MARK: - Performance Tests

    func testResolutionPerformance_해결성능() async throws {
        // Setup
        _ = await UnifiedDI.registerAsync(TestUserService.self) { TestUserServiceImpl() }

        // Measure resolution performance (async measure not supported, use simple timing)
        let startTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<1000 {
            _ = await UnifiedDI.resolveAsync(TestUserService.self)
        }
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        // Loosen threshold to avoid CI flakiness on slow machines
        XCTAssertLessThan(timeElapsed, 2.0)
    }

    func testRegistrationPerformance_등록성능() async throws {
        // Measure registration performance (async measure not supported, use simple timing)
        let startTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = await UnifiedDI.registerAsync(TestUserService.self) { TestUserServiceImpl() }
            UnifiedDI.release(TestUserService.self)
        }
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertLessThan(timeElapsed, 3.0)
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
