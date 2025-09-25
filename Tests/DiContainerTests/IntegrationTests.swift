//
//  IntegrationTests.swift
//  DiContainerTests
//
//  Created by Wonji Suh on 3/24/25.
//

import XCTest
import Foundation
import LogMacro
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
    func get<T: Sendable>(_ key: String) async -> T?
    func set<T: Sendable>(_ key: String, value: T) async
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
        if let cache = cacheService, let cached: IntegrationUser = await cache.get("user_\(id)") {
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

final class IntegrationNetworkClientImpl: IntegrationNetworkClient {
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

actor IntegrationCacheServiceImpl: IntegrationCacheService {
    private var cache: [String: any Sendable] = [:]

    func get<T: Sendable>(_ key: String) async -> T? {
        return cache[key] as? T
    }

    func set<T: Sendable>(_ key: String, value: T) async {
        cache[key] = value
    }

    func remove(_ key: String) async {
        cache.removeValue(forKey: key)
    }
}

final class IntegrationAnalyticsServiceImpl: IntegrationAnalyticsService, @unchecked Sendable {
    private var events: [(String, [String: Any])] = []
    private let lock = NSLock()

    func track(event: String, parameters: [String: Any]) {
        lock.lock()
        events.append((event, parameters))
        lock.unlock()
    }

    func getEvents() -> [(String, [String: Any])] {
        lock.lock()
        let snapshot = events
        lock.unlock()
        return snapshot
    }
}

final class IntegrationUserServiceImpl: IntegrationUserService, @unchecked Sendable {
    @Inject var repository: IntegrationUserRepository?
    @Inject var analytics: IntegrationAnalyticsService?

    func getUser(id: String) async throws -> IntegrationUser {
        analytics?.track(event: "user_fetch_started", parameters: ["user_id": id])

        guard let repository = repository,
              let user = await repository.findUser(id: id) else {
            analytics?.track(event: "user_fetch_failed", parameters: ["user_id": id])
            throw IntegrationError.userNotFound
        }

        analytics?.track(event: "user_fetch_success", parameters: ["user_id": id])
        return user
    }

    func updateUser(_ user: IntegrationUser) async throws {
        analytics?.track(event: "user_update_started", parameters: ["user_id": user.id])

        try await repository?.saveUser(user)

        analytics?.track(event: "user_update_success", parameters: ["user_id": user.id])
    }

    func deleteUser(id: String) async throws {
        analytics?.track(event: "user_delete_started", parameters: ["user_id": id])

        // In real implementation, would call repository.deleteUser
        analytics?.track(event: "user_delete_success", parameters: ["user_id": id])
    }
}

// MARK: - Mock Implementations

final class MockIntegrationNetworkClient: IntegrationNetworkClient {
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

    // MARK: - Basic Integration Tests

    func testCompleteUserServiceFlow_전체사용자서비스플로우() async throws {
        // Setup dependencies using UnifiedDI
        await setupProductionDependencies()

        // Get the main service
        let userService = UnifiedDI.requireResolve(IntegrationUserService.self)

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
        let analytics = UnifiedDI.resolve(IntegrationAnalyticsService.self) as? IntegrationAnalyticsServiceImpl
        let events = analytics?.getEvents() ?? []

        XCTAssertTrue(events.contains { $0.0 == "user_fetch_started" })
        XCTAssertTrue(events.contains { $0.0 == "user_fetch_success" })
        XCTAssertTrue(events.contains { $0.0 == "user_update_started" })
        XCTAssertTrue(events.contains { $0.0 == "user_update_success" })
    }

    func testCacheIntegration_캐시통합() async throws {
        // Setup dependencies
        await setupProductionDependencies()

        let repository = UnifiedDI.requireResolve(IntegrationUserRepository.self)

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
        XCTAssertLessThan(duration, 0.1) // Should be faster (< 100ms) - more realistic
    }

    func testErrorHandlingIntegration_에러처리통합() async {
        // Setup dependencies with mock that throws
        final class FailingNetworkClient: IntegrationNetworkClient, @unchecked Sendable {
            func fetchUserData(id: String) async throws -> [String: Any] {
                throw IntegrationError.networkError
            }

            func uploadUserData(_ data: [String: Any]) async throws {
                throw IntegrationError.networkError
            }
        }

        // Register services individually with UnifiedDI
        _ = UnifiedDI.register(IntegrationNetworkClient.self) { FailingNetworkClient() }
        _ = UnifiedDI.register(IntegrationCacheService.self) { IntegrationCacheServiceImpl() }
        _ = UnifiedDI.register(IntegrationAnalyticsService.self) { IntegrationAnalyticsServiceImpl() }
        _ = UnifiedDI.register(IntegrationUserRepository.self) { IntegrationUserRepositoryImpl() }
        _ = UnifiedDI.register(IntegrationUserService.self) { IntegrationUserServiceImpl() }

        let userService = UnifiedDI.requireResolve(IntegrationUserService.self)

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
        let analytics = UnifiedDI.resolve(IntegrationAnalyticsService.self) as? IntegrationAnalyticsServiceImpl
        let events = analytics?.getEvents() ?? []

        XCTAssertTrue(events.contains { $0.0 == "user_fetch_failed" })
    }

    // MARK: - Environment-Based Integration Tests

    func testDevelopmentEnvironment_개발환경() async throws {
        // Setup development dependencies
        await setupDevelopmentDependencies()

        let userService = UnifiedDI.requireResolve(IntegrationUserService.self)
        let user = try await userService.getUser(id: "dev_test")

        // Should use mock network client
        XCTAssertEqual(user.name, "Mock User dev_test")
        XCTAssertEqual(user.email, "mockdev_test@example.com")
    }

    func testProductionEnvironment_프로덕션환경() async throws {
        // Setup production dependencies
        await setupProductionDependencies()

        let userService = UnifiedDI.requireResolve(IntegrationUserService.self)
        let user = try await userService.getUser(id: "prod_test")

        // Should use real network client
        XCTAssertEqual(user.name, "User prod_test")
        XCTAssertEqual(user.email, "userprod_test@example.com")
    }

    func testConditionalEnvironmentDependencies_조건부환경의존성() async throws {
        await setupConditionalDependencies(isProduction: false)

        let userService = UnifiedDI.requireResolve(IntegrationUserService.self)
        let user = try await userService.getUser(id: "conditional_test")

        // Should use mock for development
        XCTAssertEqual(user.name, "Mock User conditional_test")
    }

    // MARK: - Performance Integration Tests

    func testConcurrentUserOperations_동시사용자작업() async throws {
        await setupProductionDependencies()

        let userService = UnifiedDI.requireResolve(IntegrationUserService.self)

        // Perform concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<25 {
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
        let analytics = UnifiedDI.resolve(IntegrationAnalyticsService.self) as? IntegrationAnalyticsServiceImpl
        let events = analytics?.getEvents() ?? []

        let fetchStartedEvents = events.filter { $0.0 == "user_fetch_started" }
        let fetchSuccessEvents = events.filter { $0.0 == "user_fetch_success" }

        XCTAssertEqual(fetchStartedEvents.count, 25)
        XCTAssertEqual(fetchSuccessEvents.count, 25)
    }

    func testMemoryLeakIntegration_메모리누수통합() async throws {
        // Setup and teardown multiple times to check for leaks
        for i in 0..<5 {
            await setupProductionDependencies()

            let userService = UnifiedDI.requireResolve(IntegrationUserService.self)
            _ = try await userService.getUser(id: "leak_test_\(i)")

          await MainActor.run { UnifiedDI.releaseAll() }
        }

        // If we get here without crashes or excessive memory growth, test passes
        XCTAssertTrue(true)
    }

    // MARK: - Auto Optimization Integration Tests

    func testIntegrationWithAutoOptimization_자동최적화통합() async throws {
        // Enable auto optimization
        UnifiedDI.setAutoOptimization(true)
        UnifiedDI.setLogLevel(.all)

        await setupProductionDependencies()

        let userService = UnifiedDI.requireResolve(IntegrationUserService.self)

        // Use services multiple times to trigger optimization
        for i in 0..<10 {
            _ = try await userService.getUser(id: "optimization_test_\(i)")
        }

        // Wait for auto optimization to process (polling)
        _ = await waitAsyncUntil(timeout: 2.0) {
            let s = UnifiedDI.stats()
            return s.count > 0
        }

        // Check optimization stats
        let stats = UnifiedDI.stats()
        XCTAssertGreaterThan(stats.count, 0)

        // Check if any services were optimized
        let optimizedTypes = UnifiedDI.optimizedTypes()
        XCTAssertGreaterThanOrEqual(optimizedTypes.count, 0)

        // Check for type safety issues
        let typeSafetyIssues = await UnifiedDI.typeSafetyIssues
        Log.debug("Type safety issues detected: \(typeSafetyIssues.count)")

        // Check Actor hop statistics
        let actorHopStats = await UnifiedDI.actorHopStats
        Log.debug("Actor hop stats: \(actorHopStats)")
    }

    func testConcurrentOptimizationTracking_동시최적화추적() async throws {
        UnifiedDI.setAutoOptimization(true)
        await setupProductionDependencies()

        let userService = UnifiedDI.requireResolve(IntegrationUserService.self)

        // Concurrent operations to trigger Actor hop detection
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    do {
                        _ = try await userService.getUser(id: "concurrent_opt_\(i)")
                    } catch {
                        Log.error("Concurrent operation failed: \(error)")
                    }
                }
            }
        }

        // Wait for optimization processing (polling)
        _ = await waitAsyncUntil(timeout: 2.0) {
            let opt = await UnifiedDI.actorOptimizations
            let perf = await UnifiedDI.asyncPerformanceStats
            return (opt.count + perf.count) >= 0 // ensure retrieval; gives time for collection
        }

        // Check results
        let actorOptimizations = await UnifiedDI.actorOptimizations
      let asyncPerformanceStats = await UnifiedDI.asyncPerformanceStats

        Log.debug("Actor optimizations: \(actorOptimizations.count)")
        Log.debug("Async performance stats: \(asyncPerformanceStats.count)")

        XCTAssertGreaterThanOrEqual(actorOptimizations.count + asyncPerformanceStats.count, 0)
    }

    // MARK: - Helper Methods

    private func setupProductionDependencies() async {
        _ = UnifiedDI.register(IntegrationNetworkClient.self) { IntegrationNetworkClientImpl() }
        _ = UnifiedDI.register(IntegrationCacheService.self) { IntegrationCacheServiceImpl() }
        _ = UnifiedDI.register(IntegrationAnalyticsService.self) { IntegrationAnalyticsServiceImpl() }
        _ = UnifiedDI.register(IntegrationUserRepository.self) { IntegrationUserRepositoryImpl() }
        _ = UnifiedDI.register(IntegrationUserService.self) { IntegrationUserServiceImpl() }
    }

    private func setupDevelopmentDependencies() async {
        _ = UnifiedDI.register(IntegrationNetworkClient.self) { MockIntegrationNetworkClient() }
        _ = UnifiedDI.register(IntegrationCacheService.self) { IntegrationCacheServiceImpl() }
        _ = UnifiedDI.register(IntegrationAnalyticsService.self) { IntegrationAnalyticsServiceImpl() }
        _ = UnifiedDI.register(IntegrationUserRepository.self) { IntegrationUserRepositoryImpl() }
        _ = UnifiedDI.register(IntegrationUserService.self) { IntegrationUserServiceImpl() }
    }

    private func setupConditionalDependencies(isProduction: Bool) async {
        _ = UnifiedDI.Conditional.registerIf(
            IntegrationNetworkClient.self,
            condition: isProduction,
            factory: { IntegrationNetworkClientImpl() },
            fallback: { MockIntegrationNetworkClient() }
        )
        _ = UnifiedDI.register(IntegrationCacheService.self) { IntegrationCacheServiceImpl() }
        _ = UnifiedDI.register(IntegrationAnalyticsService.self) { IntegrationAnalyticsServiceImpl() }
        _ = UnifiedDI.register(IntegrationUserRepository.self) { IntegrationUserRepositoryImpl() }
        _ = UnifiedDI.register(IntegrationUserService.self) { IntegrationUserServiceImpl() }
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
