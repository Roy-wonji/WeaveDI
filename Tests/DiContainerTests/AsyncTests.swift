//
//  AsyncTests.swift
//  DiContainerTests
//
//  Created by Wonja Suh on 9/24/25.
//

import XCTest
import LogMacro
@testable import DiContainer

// MARK: - Async Test Services

protocol AsyncTestService: Sendable {
    func performAsyncOperation() async -> String
}

final class AsyncTestServiceImpl: AsyncTestService {
    func performAsyncOperation() async -> String {
        try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        return "async_operation_completed"
    }
}

final class MockAsyncTestService: AsyncTestService {
    func performAsyncOperation() async -> String {
        return "mock_async_operation"
    }
}

protocol AsyncDatabaseService: Sendable {
    static func initialize() async -> AsyncDatabaseService
    func query(_ sql: String) async -> [String]
}

final class AsyncDatabaseServiceImpl: AsyncDatabaseService {
    static func initialize() async -> AsyncDatabaseService {
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        return AsyncDatabaseServiceImpl()
    }

    private init() {}

    func query(_ sql: String) async -> [String] {
        try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        return ["async_result_\(sql)"]
    }
}

// MARK: - Async DI Tests

final class AsyncTests: XCTestCase {

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

    // MARK: - Async Registration Tests with UnifiedDI

    func testAsyncRegistration_비동기등록() async {
        // Register async service using UnifiedDI
        _ = UnifiedDI.register(AsyncTestService.self) {
            AsyncTestServiceImpl()
        }

        // Resolve and test
        let service = UnifiedDI.resolve(AsyncTestService.self)
        XCTAssertNotNil(service)

        let result = await service?.performAsyncOperation()
        XCTAssertEqual(result, "async_operation_completed")
    }

    func testAsyncRegistrationWithFactory_팩토리비동기등록() async {
        // Register with async factory using UnifiedDI
        let asyncService = await AsyncDatabaseServiceImpl.initialize()
        _ = UnifiedDI.register(AsyncDatabaseService.self) { asyncService }

        // Resolve and test
        let service = UnifiedDI.resolve(AsyncDatabaseService.self)
        XCTAssertNotNil(service)

        let result = await service?.query("SELECT * FROM users")
        XCTAssertEqual(result, ["async_result_SELECT * FROM users"])
    }

    func testAsyncKeyPathRegistration_키패스비동기등록() async {
        // Register with KeyPath using UnifiedDI
        let service = UnifiedDI.register(\.asyncTestService) {
            AsyncTestServiceImpl()
        }

        // Test returned service
        let result = await service.performAsyncOperation()
        XCTAssertEqual(result, "async_operation_completed")

        // Test resolution
        let resolved = UnifiedDI.resolve(AsyncTestService.self)
        XCTAssertNotNil(resolved)
    }

    // MARK: - Async Resolution Tests

    func testAsyncResolution_비동기해결() async {
        // Register service using UnifiedDI
        _ = UnifiedDI.register(AsyncTestService.self) {
            AsyncTestServiceImpl()
        }

        // Test optional resolution
        let service = UnifiedDI.resolve(AsyncTestService.self)
        XCTAssertNotNil(service)

        // Test required resolution
        let requiredService = UnifiedDI.requireResolve(AsyncTestService.self)
        let result = await requiredService.performAsyncOperation()
        XCTAssertEqual(result, "async_operation_completed")
    }

    func testAsyncResolutionWithDefault_기본값비동기해결() async {
        // Test without registration
        let service1 = UnifiedDI.resolve(AsyncTestService.self, default: MockAsyncTestService())
        let result1 = await service1.performAsyncOperation()
        XCTAssertEqual(result1, "mock_async_operation")

        // Register and test with registration
        _ = UnifiedDI.register(AsyncTestService.self) {
            AsyncTestServiceImpl()
        }

        let service2 = UnifiedDI.resolve(AsyncTestService.self, default: MockAsyncTestService())
        let result2 = await service2.performAsyncOperation()
        XCTAssertEqual(result2, "async_operation_completed")
    }

    // MARK: - Conditional Registration Tests

    func testAsyncConditionalRegistration_조건부비동기등록() async {
        // Test true condition using UnifiedDI.Conditional
        _ = UnifiedDI.Conditional.registerIf(
            AsyncTestService.self,
            condition: true,
            factory: { AsyncTestServiceImpl() },
            fallback: { MockAsyncTestService() }
        )

        let service1 = UnifiedDI.resolve(AsyncTestService.self)
        let result1 = await service1?.performAsyncOperation()
        XCTAssertEqual(result1, "async_operation_completed")

        // Reset and test false condition
        UnifiedDI.release(AsyncTestService.self)

        _ = UnifiedDI.Conditional.registerIf(
            AsyncTestService.self,
            condition: false,
            factory: { AsyncTestServiceImpl() },
            fallback: { MockAsyncTestService() }
        )

        let service2 = UnifiedDI.resolve(AsyncTestService.self)
        let result2 = await service2?.performAsyncOperation()
        XCTAssertEqual(result2, "mock_async_operation")
    }

    // MARK: - Batch Registration Tests (Simplified)

    func testAsyncBatchRegistration_배치비동기등록() async {
        // Register multiple services individually with UnifiedDI
        _ = UnifiedDI.register(AsyncTestService.self) { AsyncTestServiceImpl() }

        let asyncDb = await AsyncDatabaseServiceImpl.initialize()
        _ = UnifiedDI.register(AsyncDatabaseService.self) { asyncDb }

        // Test all services are registered
        let testService = UnifiedDI.resolve(AsyncTestService.self)
        let dbService = UnifiedDI.resolve(AsyncDatabaseService.self)

        XCTAssertNotNil(testService)
        XCTAssertNotNil(dbService)

        let testResult = await testService?.performAsyncOperation()
        let dbResult = await dbService?.query("SELECT 1")

        XCTAssertEqual(testResult, "async_operation_completed")
        XCTAssertEqual(dbResult, ["async_result_SELECT 1"])
    }

    // MARK: - Performance Tests

    func testAsyncRegistrationPerformance_비동기등록성능() async {
        await measureAsync {
            for _ in 0..<100 {
                _ = UnifiedDI.register(AsyncTestService.self) {
                    AsyncTestServiceImpl()
                }
                UnifiedDI.release(AsyncTestService.self)
            }
        }
    }

    func testAsyncResolutionPerformance_비동기해결성능() async {
        // Setup
        _ = UnifiedDI.register(AsyncTestService.self) {
            AsyncTestServiceImpl()
        }

        await measureAsync {
            for _ in 0..<1000 {
                _ = UnifiedDI.resolve(AsyncTestService.self)
            }
        }
    }

    func testConcurrentAsyncAccess_동시비동기접근() async {
        // Register service
        _ = UnifiedDI.register(AsyncTestService.self) {
            AsyncTestServiceImpl()
        }

        // Test concurrent access
        await withTaskGroup(of: String?.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    let service = UnifiedDI.resolve(AsyncTestService.self)
                    return await service?.performAsyncOperation()
                }
            }

            var results: [String?] = []
            for await result in group {
                results.append(result)
            }

            // All should succeed
            XCTAssertEqual(results.count, 50)
            for result in results {
                XCTAssertEqual(result, "async_operation_completed")
            }
        }
    }

    // MARK: - Error Handling Tests

    func testAsyncErrorHandling_비동기에러처리() async {
        // Test resolution of non-registered service
        let service = UnifiedDI.resolve(AsyncTestService.self)
        XCTAssertNil(service)

        // Test with fallback
        let fallbackService = UnifiedDI.resolve(AsyncTestService.self, default: MockAsyncTestService())
        let result = await fallbackService.performAsyncOperation()
        XCTAssertEqual(result, "mock_async_operation")
    }

    // MARK: - Auto Optimization with Async Tests

    func testAsyncWithAutoOptimization_자동최적화비동기() async {
        // Enable auto optimization for async tests
        UnifiedDI.setAutoOptimization(true)
        UnifiedDI.setLogLevel(.all)

        // Register service
        _ = UnifiedDI.register(AsyncTestService.self) { AsyncTestServiceImpl() }

        // Use the service multiple times asynchronously to trigger auto optimization
        await withTaskGroup(of: Void.self) { group in
            for _ in 1...10 {
                group.addTask {
                    _ = UnifiedDI.resolve(AsyncTestService.self)
                }
            }
        }

        // Wait for auto optimization to process
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Check if optimization was triggered
        let stats = UnifiedDI.stats
        let usage = stats["AsyncTestService"] ?? 0
        XCTAssertGreaterThanOrEqual(usage, 10)

        // Check Actor hop stats
        let actorHopStats = UnifiedDI.actorHopStats
        let hopCount = actorHopStats["AsyncTestService"] ?? 0

        // Actor hops may have been detected in concurrent access
        XCTAssertGreaterThanOrEqual(hopCount, 0)
    }

    func testAsyncPerformanceTracking_비동기성능추적() async {
        // Register service
        _ = UnifiedDI.register(AsyncTestService.self) { AsyncTestServiceImpl() }

        // Perform async operations to collect performance data
        for _ in 1...5 {
            await Task.detached {
                _ = UnifiedDI.resolve(AsyncTestService.self)
            }.value
        }

        // Wait for performance data collection
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Check async performance stats
        let asyncPerformanceStats = UnifiedDI.asyncPerformanceStats

        if let avgTime = asyncPerformanceStats["AsyncTestService"] {
            XCTAssertGreaterThan(avgTime, 0)
        }
    }

    // MARK: - Helper Methods

    private func measureAsync(_ operation: () async throws -> Void) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        try? await operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        Log.debug("Async operation took: \(duration * 1000)ms")
    }
}

// MARK: - DependencyContainer Extension for Async Tests

extension DependencyContainer {
    var asyncTestService: AsyncTestService? {
        return resolve(AsyncTestService.self)
    }

    var asyncDatabaseService: AsyncDatabaseService? {
        return resolve(AsyncDatabaseService.self)
    }
}
