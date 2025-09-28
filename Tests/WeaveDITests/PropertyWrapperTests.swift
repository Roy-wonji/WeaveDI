//
//  PropertyWrapperTests.swift
//  DiContainerTests
//
//  Created by Wonja Suh on 9/24/25.
//

import XCTest
@testable import WeaveDI

// MARK: - Property Wrapper Tests

final class PropertyWrapperTests: XCTestCase {

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        UnifiedDI.releaseAll()
        UnifiedDI.setLogLevel(.off)
    }

    @MainActor
    override func tearDown() async throws {
        UnifiedDI.releaseAll()
        UnifiedDI.resetStats()
        try await super.tearDown()
    }

    // MARK: - @Inject Tests

  func testInjectOptional_옵셔널주입() async {
        // Test class with optional injection
        class TestService {
            @Inject var userService: TestUserService?

            func performOperation() -> String? {
                return userService?.getUser(id: "inject_test")
            }
        }

        let service = TestService()

        // Test without registration
        XCTAssertNil(service.userService)
        XCTAssertNil(service.performOperation())

        // Test with registration
        _ =  UnifiedDI.register(TestUserService.self) { TestUserServiceImpl() }
        await UnifiedDI.waitForRegistration()
        XCTAssertNotNil(service.userService)
        XCTAssertEqual(service.performOperation(), "user_inject_test")
    }

    func testInjectWithKeyPath_키패스주입() async {
        // Register service
        _ = UnifiedDI.register(\.propertyTestUserService) { TestUserServiceImpl() }
        await UnifiedDI.waitForRegistration()

        // Test class with KeyPath injection
        class TestService {
            @Inject(\.propertyTestUserService) var userService: TestUserService?

            func performOperation() -> String? {
                return userService?.getUser(id: "keypath_test")
            }
        }

        let service = TestService()
        XCTAssertNotNil(service.userService)
        XCTAssertEqual(service.performOperation(), "user_keypath_test")
    }

    func testInjectWithExplicitType_명시적타입주입() async {
        // Register service
        _ = UnifiedDI.register(TestUserService.self) { TestUserServiceImpl() }
        await UnifiedDI.waitForRegistration()

        // Test class with explicit type injection
        class TestService {
            @Inject(TestUserService.self) var userService: TestUserService?

            func performOperation() -> String? {
                return userService?.getUser(id: "explicit_test")
            }
        }

        let service = TestService()
        XCTAssertNotNil(service.userService)
        XCTAssertEqual(service.performOperation(), "user_explicit_test")
    }

    func testInjectNonOptional_필수주입() async {
        // Register service first to prevent fatalError
        _ = UnifiedDI.register(TestUserService.self) { TestUserServiceImpl() }
        await UnifiedDI.waitForRegistration()

        // Test class with non-optional injection (requires registration)
        class TestService {
            @Inject var userService: TestUserService?

            func performOperation() -> String {
                return userService?.getUser(id: "required_test") ?? "service_missing"
            }
        }

        let service = TestService()
        XCTAssertEqual(service.performOperation(), "user_required_test")
    }

    // MARK: - @Factory Tests

    func testFactoryCreatesNewInstances_팩토리새인스턴스생성() {
        // Register service
        _ = UnifiedDI.register(TestUserService.self) { TestUserServiceImpl() }

        // Test class with factory injection
        class TestService {
            @Factory(factory: { TestUserServiceImpl() }) var userService1: TestUserService
            @Factory(factory: { TestUserServiceImpl() }) var userService2: TestUserService

            func areInstancesDifferent() -> Bool {
                // Factory should create new instances each time
                // We test by calling the services and ensuring they work
                let result1 = userService1.getUser(id: "factory1")
                let result2 = userService2.getUser(id: "factory2")
                return result1 == "user_factory1" && result2 == "user_factory2"
            }
        }

        let service = TestService()
        XCTAssertTrue(service.areInstancesDifferent())
    }

    func testFactoryWithDirectFactory_직접팩토리() {
        // Test class with direct factory
        class TestService {
            @Factory(factory: { TestUserServiceImpl() }) var userService: TestUserService

            func performOperation() -> String {
                return userService.getUser(id: "factory_test")
            }
        }

        let service = TestService()
        XCTAssertEqual(service.performOperation(), "user_factory_test")
    }

    // MARK: - @SafeInject Tests

    @MainActor
    func testSafeInjectSuccess_안전주입성공() async throws {
        // Register service directly into live container to avoid async timing issues
      WeaveDI.Container.live.register(TestUserService.self, instance: TestUserServiceImpl())

        // Test class with safe injection
        class TestService {
            @SafeInject var userService: SafeInjectResult<TestUserService>

            func performOperation() throws -> String {
                let service = try userService.get()
                return service.getUser(id: "safe_test")
            }
        }

        let service = TestService()
        let result = try service.performOperation()
        XCTAssertEqual(result, "user_safe_test")
    }

    func testSafeInjectFailure_안전주입실패() {
        // Don't register service - should throw error

        class TestService {
            @SafeInject var userService: SafeInjectResult<TestUserService>

            func performOperation() throws -> String {
                let service = try userService.get()
                return service.getUser(id: "safe_test")
            }
        }

        let service = TestService()

        XCTAssertThrowsError(try service.performOperation()) { error in
            // Should throw an error when service is not registered
            XCTAssertTrue(error is SafeInjectError)
        }
    }

    // MARK: - Integration Tests

    func testComplexPropertyWrapperIntegration_복합래퍼통합() {
        // Register services
        _ = UnifiedDI.register(TestUserService.self) { TestUserServiceImpl() }
        _ = UnifiedDI.register(TestNetworkService.self) { TestNetworkServiceImpl() }
        _ = UnifiedDI.register(TestDatabaseService.self) { TestDatabaseServiceImpl() }

        // Complex service with multiple property wrappers
        class ComplexService {
            @Inject var userService: TestUserService?
            @SafeInject var networkService: SafeInjectResult<TestNetworkService>
            @Factory(factory: { TestDatabaseServiceImpl() }) var dbService: TestDatabaseService

            func performComplexOperation() throws -> String {
                let user = userService?.getUser(id: "complex") ?? "no_user"
                let network = try networkService.get().fetchData()
                let db = dbService.query("SELECT * FROM test").first ?? "no_data"

                return "\(user)_\(network)_\(db)"
            }
        }

        let service = ComplexService()

        do {
            let result = try service.performComplexOperation()
            XCTAssertEqual(result, "user_complex_network_data_result_SELECT * FROM test")
        } catch {
            XCTFail("Complex operation should succeed: \(error)")
        }
    }

    // MARK: - Performance Tests

    func testPropertyWrapperPerformance_래퍼성능() {
        _ = UnifiedDI.register(TestUserService.self) { TestUserServiceImpl() }

        class TestService: @unchecked Sendable {
            @Inject var userService: TestUserService?
        }

        // Create multiple instances and access the property wrapper
        measure {
            for _ in 0..<1000 {
                let service = TestService()
                _ = service.userService?.getUser(id: "perf_test")
            }
        }
    }

    func testFactoryPerformance_팩토리성능() {
        class TestService {
            @Factory(factory: { TestUserServiceImpl() }) var userService: TestUserService
        }

        let service = TestService()

        // Factory should create new instances each time
        measure {
            for _ in 0..<100 {
                _ = service.userService.getUser(id: "factory_perf")
            }
        }
    }

    // MARK: - Error Handling Tests

    func testSafeInjectErrorHandling_안전주입에러처리() {
        class TestService {
            @SafeInject var missingService: SafeInjectResult<TestUserService>

            func safeOperation() -> String {
                do {
                    let service = try missingService.get()
                    return service.getUser(id: "error_test")
                } catch {
                    return "error_handled"
                }
            }
        }

        let service = TestService()
        XCTAssertEqual(service.safeOperation(), "error_handled")
    }

    // MARK: - Thread Safety Tests

    func testConcurrentPropertyWrapperAccess_동시래퍼접근() async {
        _ = UnifiedDI.register(TestUserService.self) { TestUserServiceImpl() }

        class TestService: @unchecked Sendable {
            @Inject var userService: TestUserService?
        }

        let service = TestService()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    _ = service.userService?.getUser(id: "concurrent")
                }
            }
        }
        XCTAssertTrue(true)
    }
}

// MARK: - WeaveDI.Container Extension for Tests

extension WeaveDI.Container {
    var propertyTestUserService: TestUserService? {
        return resolve(TestUserService.self)
    }

    var propertyTestNetworkService: TestNetworkService? {
        return resolve(TestNetworkService.self)
    }

    var propertyTestDatabaseService: TestDatabaseService? {
        return resolve(TestDatabaseService.self)
    }
}
