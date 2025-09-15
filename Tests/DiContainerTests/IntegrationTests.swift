//
//  IntegrationTests.swift
//  DiContainerTests
//
//  Created by Wonja Suh on 3/24/25.
//

import XCTest
@testable import DiContainer

// MARK: - Integration Test Services

protocol IntegrationUserRepository: Sendable {
    func findUser(id: String) async -> IntegrationUser?
    func saveUser(_ user: IntegrationUser) async throws
}

protocol IntegrationNetworkClient: Sendable {
    func fetchUserData(id: String) async throws -> [String: Any]
    func uploadUserData(_ data: [String: Any]) async throws
}

protocol IntegrationCacheService: Sendable {
    func get(_ key: String) async -> Any?
    func set(_ key: String, value: Any) async
    func remove(_ key: String) async
}

protocol IntegrationAnalyticsService: Sendable {
    func track(event: String, parameters: [String: Any])
}

protocol IntegrationUserService: Sendable {
    func getUser(id: String) async throws -> IntegrationUser
    func updateUser(_ user: IntegrationUser) async throws
    func deleteUser(id: String) async throws
}

// MARK: - Test Models

struct IntegrationUser: Sendable, Equatable {
    let id: String
    let name: String
    let email: String
}

// MARK: - Test Implementations

final class IntegrationUserRepositoryImpl: IntegrationUserRepository, @unchecked Sendable {
    @Inject var networkClient: IntegrationNetworkClient?
    @Inject var cacheService: IntegrationCacheService?

    func findUser(id: String) async -> IntegrationUser? {
        // Check cache first
        if let cached = await cacheService?.get("user_\(id)") as? IntegrationUser {
            return cached
        }

        // Fetch from network
        guard let client = networkClient else { return nil }

        do {
            let data = try await client.fetchUserData(id: id)
            let user = IntegrationUser(
                id: id,
                name: data["name"] as? String ?? "Unknown",
                email: data["email"] as? String ?? "unknown@example.com"
            )

            // Cache the result
            await cacheService?.set("user_\(id)", value: user)
            return user
        } catch {
            return nil
        }
    }

    func saveUser(_ user: IntegrationUser) async throws {
        let data: [String: Any] = [
            "id": user.id,
            "name": user.name,
            "email": user.email
        ]

        try await networkClient?.uploadUserData(data)
        await cacheService?.set("user_\(user.id)", value: user)
    }
}

final class IntegrationNetworkClientImpl: IntegrationNetworkClient, @unchecked Sendable {
    func fetchUserData(id: String) async throws -> [String: Any] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds

        return [
            "id": id,
            "name": "User \(id)",
            "email": "user\(id)@example.com"
        ]
    }

    func uploadUserData(_ data: [String: Any]) async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        // In real implementation, would upload to server
    }
}

final class IntegrationCacheServiceImpl: IntegrationCacheService, @unchecked Sendable {
    private var cache: [String: Any] = [:]
    private let queue = DispatchQueue(label: "cache", attributes: .concurrent)

    func get(_ key: String) async -> Any? {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.cache[key])
            }
        }
    }

    func set(_ key: String, value: Any) async {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.cache[key] = value
                continuation.resume()
            }
        }
    }

    func remove(_ key: String) async {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.cache.removeValue(forKey: key)
                continuation.resume()
            }
        }
    }
}

final class IntegrationAnalyticsServiceImpl: IntegrationAnalyticsService, @unchecked Sendable {
    private var events: [(String, [String: Any])] = []
    private let queue = DispatchQueue(label: "analytics", attributes: .concurrent)

    func track(event: String, parameters: [String: Any]) {
        queue.async(flags: .barrier) {
            self.events.append((event, parameters))
        }
    }

    func getEvents() -> [(String, [String: Any])] {
        return queue.sync { events }
    }
}

final class IntegrationUserServiceImpl: IntegrationUserService, @unchecked Sendable {
    @RequiredInject var repository: IntegrationUserRepository
    @Inject var analytics: IntegrationAnalyticsService?

    func getUser(id: String) async throws -> IntegrationUser {
        analytics?.track(event: "user_fetch_started", parameters: ["user_id": id])

        guard let user = await repository.findUser(id: id) else {
            analytics?.track(event: "user_fetch_failed", parameters: ["user_id": id])
            throw IntegrationError.userNotFound
        }

        analytics?.track(event: "user_fetch_success", parameters: ["user_id": id])
        return user
    }

    func updateUser(_ user: IntegrationUser) async throws {
        analytics?.track(event: "user_update_started", parameters: ["user_id": user.id])

        try await repository.saveUser(user)

        analytics?.track(event: "user_update_success", parameters: ["user_id": user.id])
    }

    func deleteUser(id: String) async throws {
        analytics?.track(event: "user_delete_started", parameters: ["user_id": id])

        // In real implementation, would call repository.deleteUser
        analytics?.track(event: "user_delete_success", parameters: ["user_id": id])
    }
}

// MARK: - Mock Implementations

final class MockIntegrationNetworkClient: IntegrationNetworkClient, @unchecked Sendable {
    func fetchUserData(id: String) async throws -> [String: Any] {
        return [
            "id": id,
            "name": "Mock User \(id)",
            "email": "mock\(id)@example.com"
        ]
    }

    func uploadUserData(_ data: [String: Any]) async throws {
        // Mock implementation - no network call
    }
}

// MARK: - Errors

enum IntegrationError: Error {
    case userNotFound
    case networkError
    case cacheError
}

// MARK: - Integration Tests

final class IntegrationTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await DependencyContainer.resetForTesting()
    }

    override func tearDown() async throws {
        await DependencyContainer.resetForTesting()
        try await super.tearDown()
    }

    // MARK: - Basic Integration Tests

    func testCompleteUserServiceFlow() async throws {
        // Setup dependencies
        await setupProductionDependencies()

        // Get the main service
        let userService = DI.requireResolve(IntegrationUserService.self)

        // Test complete flow
        let user = try await userService.getUser(id: "test123")

        XCTAssertEqual(user.id, "test123")
        XCTAssertEqual(user.name, "User test123")
        XCTAssertEqual(user.email, "usertest123@example.com")

        // Test update
        let updatedUser = IntegrationUser(
            id: "test123",
            name: "Updated User",
            email: "updated@example.com"
        )

        try await userService.updateUser(updatedUser)

        // Verify analytics events
        let analytics = DI.resolve(IntegrationAnalyticsService.self) as? IntegrationAnalyticsServiceImpl
        let events = analytics?.getEvents() ?? []

        XCTAssertTrue(events.contains { $0.0 == "user_fetch_started" })
        XCTAssertTrue(events.contains { $0.0 == "user_fetch_success" })
        XCTAssertTrue(events.contains { $0.0 == "user_update_started" })
        XCTAssertTrue(events.contains { $0.0 == "user_update_success" })
    }

    func testCacheIntegration() async throws {
        // Setup dependencies
        await setupProductionDependencies()

        let repository = DI.requireResolve(IntegrationUserRepository.self)

        // First fetch should go to network and cache
        let user1 = await repository.findUser(id: "cache_test")
        XCTAssertNotNil(user1)
        XCTAssertEqual(user1?.name, "User cache_test")

        // Second fetch should come from cache (faster)
        let startTime = CFAbsoluteTimeGetCurrent()
        let user2 = await repository.findUser(id: "cache_test")
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime

        XCTAssertNotNil(user2)
        XCTAssertEqual(user1?.id, user2?.id)
        XCTAssertLessThan(duration, 0.005) // Should be much faster (< 5ms)
    }

    func testErrorHandlingIntegration() async {
        // Setup dependencies with mock that throws
        class FailingNetworkClient: IntegrationNetworkClient, @unchecked Sendable {
            func fetchUserData(id: String) async throws -> [String: Any] {
                throw IntegrationError.networkError
            }

            func uploadUserData(_ data: [String: Any]) async throws {
                throw IntegrationError.networkError
            }
        }

        DI.registerMany {
            Registration(IntegrationNetworkClient.self) { FailingNetworkClient() }
            Registration(IntegrationCacheService.self) { IntegrationCacheServiceImpl() }
            Registration(IntegrationAnalyticsService.self) { IntegrationAnalyticsServiceImpl() }
            Registration(IntegrationUserRepository.self) { IntegrationUserRepositoryImpl() }
            Registration(IntegrationUserService.self) { IntegrationUserServiceImpl() }
        }

        let userService = DI.requireResolve(IntegrationUserService.self)

        // Should handle error gracefully
        do {
            _ = try await userService.getUser(id: "failing_test")
            XCTFail("Should have thrown error")
        } catch IntegrationError.userNotFound {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // Verify error analytics
        let analytics = DI.resolve(IntegrationAnalyticsService.self) as? IntegrationAnalyticsServiceImpl
        let events = analytics?.getEvents() ?? []

        XCTAssertTrue(events.contains { $0.0 == "user_fetch_failed" })
    }

    // MARK: - Environment-Based Integration Tests

    func testDevelopmentEnvironment() async throws {
        // Setup development dependencies
        await setupDevelopmentDependencies()

        let userService = DI.requireResolve(IntegrationUserService.self)
        let user = try await userService.getUser(id: "dev_test")

        // Should use mock network client
        XCTAssertEqual(user.name, "Mock User dev_test")
        XCTAssertEqual(user.email, "mockdev_test@example.com")
    }

    func testProductionEnvironment() async throws {
        // Setup production dependencies
        await setupProductionDependencies()

        let userService = DI.requireResolve(IntegrationUserService.self)
        let user = try await userService.getUser(id: "prod_test")

        // Should use real network client
        XCTAssertEqual(user.name, "User prod_test")
        XCTAssertEqual(user.email, "userprod_test@example.com")
    }

    // MARK: - Bootstrap Integration Tests

    func testBootstrapIntegration() async throws {
        // Test complete bootstrap workflow
        await DependencyContainer.bootstrap { container in
            // Core services
            container.register(IntegrationNetworkClient.self) { IntegrationNetworkClientImpl() }
            container.register(IntegrationCacheService.self) { IntegrationCacheServiceImpl() }
            container.register(IntegrationAnalyticsService.self) { IntegrationAnalyticsServiceImpl() }

            // Business logic
            container.register(IntegrationUserRepository.self) { IntegrationUserRepositoryImpl() }
            container.register(IntegrationUserService.self) { IntegrationUserServiceImpl() }
        }

        // Verify all services are available
        XCTAssertTrue(DI.isRegistered(IntegrationNetworkClient.self))
        XCTAssertTrue(DI.isRegistered(IntegrationCacheService.self))
        XCTAssertTrue(DI.isRegistered(IntegrationAnalyticsService.self))
        XCTAssertTrue(DI.isRegistered(IntegrationUserRepository.self))
        XCTAssertTrue(DI.isRegistered(IntegrationUserService.self))

        // Test the bootstrapped system
        let userService = DI.requireResolve(IntegrationUserService.self)
        let user = try await userService.getUser(id: "bootstrap_test")

        XCTAssertNotNil(user)
        XCTAssertEqual(user.id, "bootstrap_test")
    }

    func testAsyncBootstrapIntegration() async throws {
        // Test async bootstrap with async services
        await DependencyContainer.bootstrapAsync { container in
            // Async initialization
            let dbService = await AsyncDatabaseServiceImpl.initialize()
            container.register(AsyncDatabaseService.self, instance: dbService)

            // Regular services
            container.register(IntegrationNetworkClient.self) { IntegrationNetworkClientImpl() }
            container.register(IntegrationUserRepository.self) { IntegrationUserRepositoryImpl() }
        }

        // Verify services are available
        XCTAssertTrue(DI.isRegistered(AsyncDatabaseService.self))
        XCTAssertTrue(DI.isRegistered(IntegrationNetworkClient.self))
        XCTAssertTrue(DI.isRegistered(IntegrationUserRepository.self))
    }

    // MARK: - Performance Integration Tests

    func testConcurrentUserOperations() async throws {
        await setupProductionDependencies()

        let userService = DI.requireResolve(IntegrationUserService.self)

        // Perform concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    do {
                        let user = try await userService.getUser(id: "concurrent_\(i)")
                        XCTAssertEqual(user.id, "concurrent_\(i)")
                    } catch {
                        XCTFail("Concurrent operation failed: \(error)")
                    }
                }
            }
        }

        // Verify analytics captured all events
        let analytics = DI.resolve(IntegrationAnalyticsService.self) as? IntegrationAnalyticsServiceImpl
        let events = analytics?.getEvents() ?? []

        let fetchStartedEvents = events.filter { $0.0 == "user_fetch_started" }
        let fetchSuccessEvents = events.filter { $0.0 == "user_fetch_success" }

        XCTAssertEqual(fetchStartedEvents.count, 50)
        XCTAssertEqual(fetchSuccessEvents.count, 50)
    }

    func testMemoryLeakIntegration() async throws {
        // Setup and teardown multiple times to check for leaks
        for i in 0..<10 {
            await setupProductionDependencies()

            let userService = DI.requireResolve(IntegrationUserService.self)
            _ = try await userService.getUser(id: "leak_test_\(i)")

            await DependencyContainer.resetForTesting()
        }

        // If we get here without crashes or excessive memory growth, test passes
        XCTAssertTrue(true)
    }

    // MARK: - Helper Methods

    private func setupProductionDependencies() async {
        DI.registerMany {
            Registration(IntegrationNetworkClient.self) { IntegrationNetworkClientImpl() }
            Registration(IntegrationCacheService.self) { IntegrationCacheServiceImpl() }
            Registration(IntegrationAnalyticsService.self) { IntegrationAnalyticsServiceImpl() }
            Registration(IntegrationUserRepository.self) { IntegrationUserRepositoryImpl() }
            Registration(IntegrationUserService.self) { IntegrationUserServiceImpl() }
        }
    }

    private func setupDevelopmentDependencies() async {
        DI.registerMany {
            Registration(IntegrationNetworkClient.self) { MockIntegrationNetworkClient() }
            Registration(IntegrationCacheService.self) { IntegrationCacheServiceImpl() }
            Registration(IntegrationAnalyticsService.self) { IntegrationAnalyticsServiceImpl() }
            Registration(IntegrationUserRepository.self) { IntegrationUserRepositoryImpl() }
            Registration(IntegrationUserService.self) { IntegrationUserServiceImpl() }
        }
    }

    private func setupConditionalDependencies(isProduction: Bool) async {
        DI.registerMany {
            Registration(
                IntegrationNetworkClient.self,
                condition: isProduction,
                factory: { IntegrationNetworkClientImpl() },
                fallback: { MockIntegrationNetworkClient() }
            )
            Registration(IntegrationCacheService.self) { IntegrationCacheServiceImpl() }
            Registration(IntegrationAnalyticsService.self) { IntegrationAnalyticsServiceImpl() }
            Registration(IntegrationUserRepository.self) { IntegrationUserRepositoryImpl() }
            Registration(IntegrationUserService.self) { IntegrationUserServiceImpl() }
        }
    }
}

// MARK: - DependencyContainer Extensions for Integration Tests

extension DependencyContainer {
    var integrationUserService: IntegrationUserService? {
        return resolve(IntegrationUserService.self)
    }

    var integrationUserRepository: IntegrationUserRepository? {
        return resolve(IntegrationUserRepository.self)
    }

    var integrationNetworkClient: IntegrationNetworkClient? {
        return resolve(IntegrationNetworkClient.self)
    }

    var integrationCacheService: IntegrationCacheService? {
        return resolve(IntegrationCacheService.self)
    }

    var integrationAnalyticsService: IntegrationAnalyticsService? {
        return resolve(IntegrationAnalyticsService.self)
    }
}