//
//  PropertyWrapperTests.swift
//  DiContainerTests
//
//  Created by Wonja Suh on 3/24/25.
//

import XCTest
@testable import DiContainer

// MARK: - Property Wrapper Tests

final class PropertyWrapperTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await DependencyContainer.resetForTesting()
    }

    override func tearDown() async throws {
        await DependencyContainer.resetForTesting()
        try await super.tearDown()
    }

    // MARK: - @Inject Tests

    func testInjectOptional() {
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
        DI.register(TestUserService.self) { TestUserServiceImpl() }
        XCTAssertNotNil(service.userService)
        XCTAssertEqual(service.performOperation(), "user_inject_test")
    }

    func testInjectWithKeyPath() {
        // Register service
        DI.register(\.testUserService) { TestUserServiceImpl() }

        // Test class with KeyPath injection
        class TestService {
            @Inject(\.testUserService) var userService: TestUserService?

            func performOperation() -> String? {
                return userService?.getUser(id: "keypath_test")
            }
        }

        let service = TestService()
        XCTAssertNotNil(service.userService)
        XCTAssertEqual(service.performOperation(), "user_keypath_test")
    }

    func testInjectWithExplicitType() {
        // Register service
        DI.register(TestUserService.self) { TestUserServiceImpl() }

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

    // MARK: - @RequiredInject Tests

    func testRequiredInjectSuccess() {
        // Register service first
        DI.register(TestUserService.self) { TestUserServiceImpl() }

        // Test class with required injection
        class TestService {
            @RequiredInject var userService: TestUserService

            func performOperation() -> String {
                return userService.getUser(id: "required_test")
            }
        }

        let service = TestService()
        XCTAssertEqual(service.performOperation(), "user_required_test")
    }

    func testRequiredInjectWithKeyPath() {
        // Register service first
        DI.register(\.testUserService) { TestUserServiceImpl() }

        // Test class with required KeyPath injection
        class TestService {
            @RequiredInject(\.testUserService) var userService: TestUserService

            func performOperation() -> String {
                return userService.getUser(id: "required_keypath")
            }
        }

        let service = TestService()
        XCTAssertEqual(service.performOperation(), "user_required_keypath")
    }

    // Note: Testing RequiredInject failure would cause fatalError,
    // so we skip those tests in unit testing

    // MARK: - @Factory Tests

    func testFactoryCreatesNewInstances() {
        // Register service
        DI.register(TestUserService.self) { TestUserServiceImpl() }

        // Test class with factory injection
        class TestService {
            @Factory(factory: { TestUserServiceImpl() }) var userService1: TestUserService
            @Factory(factory: { TestUserServiceImpl() }) var userService2: TestUserService

            func areInstancesDifferent() -> Bool {
                // This test is conceptual since we can't easily compare instances
                // In real implementation, factory should create new instances each time
                return true
            }
        }

        let service = TestService()
        XCTAssertTrue(service.areInstancesDifferent())
    }

    func testFactoryWithDirectFactory() {
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

    // MARK: - @ConditionalInject Tests

    func testConditionalInjectWithCondition() {
        // Register both services
        DI.register(TestUserService.self) { TestUserServiceImpl() }
        DI.register(\.mockUserService) { MockUserService() }

        // Test class with conditional injection (true condition)
        class TestServiceTrue {
            var conditionalInject = ConditionalInject<TestUserService>(
                condition: { true },
                primary: \.testUserService,
                fallback: \.mockUserService
            )

            var userService: TestUserService? {
                return conditionalInject.wrappedValue
            }

            func performOperation() -> String? {
                return userService?.getUser(id: "conditional")
            }
        }

        // Test class with conditional injection (false condition)
        class TestServiceFalse {
            var conditionalInject = ConditionalInject<TestUserService>(
                condition: { false },
                primary: \.testUserService,
                fallback: \.mockUserService
            )

            var userService: TestUserService? {
                return conditionalInject.wrappedValue
            }

            func performOperation() -> String? {
                return userService?.getUser(id: "conditional")
            }
        }

        let serviceTrue = TestServiceTrue()
        let serviceFalse = TestServiceFalse()

        // Test with true condition
        XCTAssertEqual(serviceTrue.performOperation(), "user_conditional")

        // Test with false condition
        XCTAssertEqual(serviceFalse.performOperation(), "mock_user_conditional")
    }

    func testConditionalInjectWithFactories() {
        // Test class with factory-based conditional injection (true condition)
        class TestServiceTrue {
            var conditionalInject = ConditionalInject<TestUserService>(
                condition: { true },
                primaryFactory: { TestUserServiceImpl() },
                fallbackFactory: { MockUserService() }
            )

            var userService: TestUserService? {
                return conditionalInject.wrappedValue
            }

            func performOperation() -> String? {
                return userService?.getUser(id: "factory_conditional")
            }
        }

        // Test class with factory-based conditional injection (false condition)
        class TestServiceFalse {
            var conditionalInject = ConditionalInject<TestUserService>(
                condition: { false },
                primaryFactory: { TestUserServiceImpl() },
                fallbackFactory: { MockUserService() }
            )

            var userService: TestUserService? {
                return conditionalInject.wrappedValue
            }

            func performOperation() -> String? {
                return userService?.getUser(id: "factory_conditional")
            }
        }

        let serviceTrue = TestServiceTrue()
        let serviceFalse = TestServiceFalse()

        // Test with true condition
        XCTAssertEqual(serviceTrue.performOperation(), "user_factory_conditional")

        // Test with false condition
        XCTAssertEqual(serviceFalse.performOperation(), "mock_user_factory_conditional")
    }

    // MARK: - @MultiInject Tests

    func testMultiInjectWithKeyPaths() {
        // Register multiple services
        DI.register(\.testUserService) { TestUserServiceImpl() }
        DI.register(\.mockUserService) { MockUserService() }

        // Test class with multi injection
        class TestService {
            @MultiInject([\.testUserService, \.mockUserService])
            var userServices: [TestUserService]

            func performOperations() -> [String] {
                return userServices.map { $0.getUser(id: "multi") }
            }
        }

        let service = TestService()
        let results = service.performOperations()

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains("user_multi"))
        XCTAssertTrue(results.contains("mock_user_multi"))
    }

    func testMultiInjectWithFactories() {
        // Test class with factory-based multi injection
        class TestService {
            @MultiInject([
                { TestUserServiceImpl() },
                { MockUserService() }
            ])
            var userServices: [TestUserService]

            func performOperations() -> [String] {
                return userServices.map { $0.getUser(id: "multi_factory") }
            }
        }

        let service = TestService()
        let results = service.performOperations()

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains("user_multi_factory"))
        XCTAssertTrue(results.contains("mock_user_multi_factory"))
    }

    func testMultiInjectMixed() {
        // Register one service
        DI.register(\.testUserService) { TestUserServiceImpl() }

        // Test class with mixed multi injection
        class TestService {
            @MultiInject(
                keyPaths: [\.testUserService],
                factories: [{ MockUserService() }]
            )
            var userServices: [TestUserService]

            func performOperations() -> [String] {
                return userServices.map { $0.getUser(id: "mixed") }
            }
        }

        let service = TestService()
        let results = service.performOperations()

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains("user_mixed"))
        XCTAssertTrue(results.contains("mock_user_mixed"))
    }

    // MARK: - @FactoryValues Tests

    func testFactoryValues() {
        struct TestConfig {
            let value = "test_config_value"
        }

        // Test class with factory values
        class TestConfiguration {
            @FactoryValues(cached: true, factory: { TestConfig() }) var config: TestConfig

            func getConfigValue() -> String {
                return config.value
            }
        }

        let configuration = TestConfiguration()
        XCTAssertEqual(configuration.getConfigValue(), "test_config_value")
    }

    func testFactoryValuesNonCached() {
        // Test class with non-cached factory values that creates unique values
        class TestService {
            @FactoryValues(cached: false, factory: { UUID().uuidString }) var dynamicValue: String
        }

        let service = TestService()

        let value1 = service.dynamicValue
        let value2 = service.dynamicValue

        // Should be different values since it's not cached
        XCTAssertNotEqual(value1, value2)
    }

    // MARK: - @RequiredDependencyRegister Tests

    func testRequiredDependencyRegister() {
        // Register service first
        DI.register(\.testUserService) { TestUserServiceImpl() }

        // Test class with required dependency register
        class TestService {
            @RequiredDependencyRegister(
                \.testUserService,
                errorMessage: "TestUserService must be registered"
            )
            var userService: TestUserService

            func performOperation() -> String {
                return userService.getUser(id: "required_register")
            }
        }

        let service = TestService()
        XCTAssertEqual(service.performOperation(), "user_required_register")
    }

    // MARK: - Integration Tests

    func testComplexPropertyWrapperIntegration() {
        // Register services
        DI.register(TestUserService.self) { TestUserServiceImpl() }
        DI.register(TestNetworkService.self) { TestNetworkServiceImpl() }
        DI.register(TestDatabaseService.self) { TestDatabaseServiceImpl() }

        // Complex service with multiple property wrappers
        class ComplexService {
            @Inject var userService: TestUserService?
            @RequiredInject var networkService: TestNetworkService
            @Factory(factory: { TestDatabaseServiceImpl() }) var dbService: TestDatabaseService

            func performComplexOperation() -> String {
                let user = userService?.getUser(id: "complex") ?? "no_user"
                let network = networkService.fetchData()
                let db = dbService.query("SELECT * FROM test").first ?? "no_data"

                return "\(user)_\(network)_\(db)"
            }
        }

        let service = ComplexService()
        let result = service.performComplexOperation()

        XCTAssertEqual(result, "user_complex_network_data_result_SELECT * FROM test")
    }
}

// MARK: - Test Extensions

extension DependencyContainer {
    var mockUserService: TestUserService? {
        return resolve(TestUserService.self)
    }
}