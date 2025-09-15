//
//  AsyncTests.swift
//  DiContainerTests
//
//  Created by Wonja Suh on 3/24/25.
//

import XCTest
@testable import DiContainer

// MARK: - Async Test Services

protocol AsyncTestService: Sendable {
    func performAsyncOperation() async -> String
}

final class AsyncTestServiceImpl: AsyncTestService, @unchecked Sendable {
    func performAsyncOperation() async -> String {
        try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        return "async_operation_completed"
    }
}

final class MockAsyncTestService: AsyncTestService, @unchecked Sendable {
    func performAsyncOperation() async -> String {
        return "mock_async_operation"
    }
}

protocol AsyncDatabaseService: Sendable {
    static func initialize() async -> AsyncDatabaseService
    func query(_ sql: String) async -> [String]
}

final class AsyncDatabaseServiceImpl: AsyncDatabaseService, @unchecked Sendable {
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

    override func setUp() async throws {
        try await super.setUp()
        await DependencyContainer.resetForTesting()
    }

    override func tearDown() async throws {
        await DependencyContainer.resetForTesting()
        try await super.tearDown()
    }

    // MARK: - DIAsync Registration Tests

    func testAsyncRegistration() async {
        // Register async service
        await DIAsync.register(AsyncTestService.self) {
            AsyncTestServiceImpl()
        }

        // Resolve and test
        let service = await DIAsync.resolve(AsyncTestService.self)
        XCTAssertNotNil(service)

        let result = await service?.performAsyncOperation()
        XCTAssertEqual(result, "async_operation_completed")
    }

    func testAsyncRegistrationWithFactory() async {
        // Register with async factory
        await DIAsync.register(AsyncDatabaseService.self) {
            await AsyncDatabaseServiceImpl.initialize()
        }

        // Resolve and test
        let service = await DIAsync.resolve(AsyncDatabaseService.self)
        XCTAssertNotNil(service)

        let result = await service?.query("SELECT * FROM users")
        XCTAssertEqual(result, ["async_result_SELECT * FROM users"])
    }

    func testAsyncKeyPathRegistration() async {
        // Register with KeyPath
        let service = await DIAsync.register(\.asyncTestService) {
            AsyncTestServiceImpl()
        }

        // Test returned service
        let result = await service.performAsyncOperation()
        XCTAssertEqual(result, "async_operation_completed")

        // Test resolution
        let resolved = await DIAsync.resolve(AsyncTestService.self)
        XCTAssertNotNil(resolved)
    }

    func testAsyncGetOrCreate() async {
        // First call should create
        let service1 = await DIAsync.getOrCreate(\.asyncTestService) {
            AsyncTestServiceImpl()
        }

        // Second call should return existing
        let service2 = await DIAsync.getOrCreate(\.asyncTestService) {
            MockAsyncTestService() // This shouldn't be called
        }

        // Both should be the same reference
        let result1 = await service1.performAsyncOperation()
        let result2 = await service2.performAsyncOperation()

        XCTAssertEqual(result1, "async_operation_completed")
        XCTAssertEqual(result2, "async_operation_completed")
    }

    // MARK: - DIAsync Resolution Tests

    func testAsyncResolution() async {
        // Register service
        await DIAsync.register(AsyncTestService.self) {
            AsyncTestServiceImpl()
        }

        // Test optional resolution
        let service = await DIAsync.resolve(AsyncTestService.self)
        XCTAssertNotNil(service)

        // Test required resolution
        let requiredService = await DIAsync.requireResolve(AsyncTestService.self)
        let result = await requiredService.performAsyncOperation()
        XCTAssertEqual(result, "async_operation_completed")
    }

    func testAsyncResolutionWithDefault() async {
        // Test without registration
        let service1 = await DIAsync.resolve(AsyncTestService.self, default: MockAsyncTestService())
        let result1 = await service1.performAsyncOperation()
        XCTAssertEqual(result1, "mock_async_operation")

        // Register and test with registration
        await DIAsync.register(AsyncTestService.self) {
            AsyncTestServiceImpl()
        }

        let service2 = await DIAsync.resolve(AsyncTestService.self, default: MockAsyncTestService())
        let result2 = await service2.performAsyncOperation()
        XCTAssertEqual(result2, "async_operation_completed")
    }

    func testAsyncRequireResolveFailure() async {
        // This would cause fatalError in real implementation
        // We test the registration check instead
        let isRegistered = await DIAsync.isRegistered(AsyncTestService.self)
        XCTAssertFalse(isRegistered)
    }

    // MARK: - DIAsync Conditional Registration Tests

    func testAsyncConditionalRegistration() async {
        // Test true condition
        await DIAsync.registerIf(
            AsyncTestService.self,
            condition: true,
            factory: { AsyncTestServiceImpl() },
            fallback: { MockAsyncTestService() }
        )

        let service1 = await DIAsync.resolve(AsyncTestService.self)
        let result1 = await service1?.performAsyncOperation()
        XCTAssertEqual(result1, "async_operation_completed")

        // Reset and test false condition
        await DIAsync.releaseAll()

        await DIAsync.registerIf(
            AsyncTestService.self,
            condition: false,
            factory: { AsyncTestServiceImpl() },
            fallback: { MockAsyncTestService() }
        )

        let service2 = await DIAsync.resolve(AsyncTestService.self)
        let result2 = await service2?.performAsyncOperation()
        XCTAssertEqual(result2, "mock_async_operation")
    }

    func testAsyncConditionalKeyPathRegistration() async {
        // Test true condition with KeyPath
        let service1 = await DIAsync.registerIf(
            \.asyncTestService,
            condition: true,
            factory: { AsyncTestServiceImpl() },
            fallback: { MockAsyncTestService() }
        )

        let result1 = await service1.performAsyncOperation()
        XCTAssertEqual(result1, "async_operation_completed")

        // Reset and test false condition
        await DIAsync.releaseAll()

        let service2 = await DIAsync.registerIf(
            \.asyncTestService,
            condition: false,
            factory: { AsyncTestServiceImpl() },
            fallback: { MockAsyncTestService() }
        )

        let result2 = await service2.performAsyncOperation()
        XCTAssertEqual(result2, "mock_async_operation")
    }

    // MARK: - DIAsync Batch Registration Tests

    func testAsyncBatchRegistration() async {
        // Register multiple services in batch
        await DIAsync.registerMany {
            DIAsyncRegistration(AsyncTestService.self) { AsyncTestServiceImpl() }
            DIAsyncRegistration(\.asyncDatabaseService) { await AsyncDatabaseServiceImpl.initialize() }
        }

        // Test all services are registered
        let testService = await DIAsync.resolve(AsyncTestService.self)
        let dbService = await DIAsync.resolve(AsyncDatabaseService.self)

        XCTAssertNotNil(testService)
        XCTAssertNotNil(dbService)

        let testResult = await testService?.performAsyncOperation()
        let dbResult = await dbService?.query("SELECT 1")

        XCTAssertEqual(testResult, "async_operation_completed")
        XCTAssertEqual(dbResult, ["async_result_SELECT 1"])
    }

    // MARK: - DIAsync Introspection Tests

    func testAsyncIsRegistered() async {
        // Test not registered
        var isRegistered = await DIAsync.isRegistered(AsyncTestService.self)
        XCTAssertFalse(isRegistered)

        // Register and test
        await DIAsync.register(AsyncTestService.self) {
            AsyncTestServiceImpl()
        }

        isRegistered = await DIAsync.isRegistered(AsyncTestService.self)
        XCTAssertTrue(isRegistered)

        // Test KeyPath version
        let isKeyPathRegistered = await DIAsync.isRegistered(\.asyncTestService)
        XCTAssertTrue(isKeyPathRegistered)
    }

    // MARK: - Mixed Sync/Async Tests

    func testMixedSyncAsyncRegistration() async {
        // Register in sync DI
        DI.register(AsyncTestService.self) { AsyncTestServiceImpl() }

        // Should be resolvable from async DI (fallback to sync)
        let asyncService = await DIAsync.resolve(AsyncTestService.self)
        XCTAssertNotNil(asyncService)

        let result = await asyncService?.performAsyncOperation()
        XCTAssertEqual(result, "async_operation_completed")
    }

    func testAsyncRegistrationWithSyncFallback() async {
        // Register in async DI
        await DIAsync.register(AsyncTestService.self) {
            AsyncTestServiceImpl()
        }

        // Should be resolvable from sync DI
        let syncService = DI.resolve(AsyncTestService.self)
        XCTAssertNotNil(syncService)
    }

    // MARK: - Performance Tests

    func testAsyncRegistrationPerformance() async {
        await measureAsync {
            for _ in 0..<100 {
                await DIAsync.register(AsyncTestService.self) {
                    AsyncTestServiceImpl()
                }
                await DIAsync.releaseAll()
            }
        }
    }

    func testAsyncResolutionPerformance() async {
        // Setup
        await DIAsync.register(AsyncTestService.self) {
            AsyncTestServiceImpl()
        }

        await measureAsync {
            for _ in 0..<1000 {
                let _ = await DIAsync.resolve(AsyncTestService.self)
            }
        }
    }

    func testConcurrentAsyncAccess() async {
        // Register service
        await DIAsync.register(AsyncTestService.self) {
            AsyncTestServiceImpl()
        }

        // Test concurrent access
        await withTaskGroup(of: String?.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    let service = await DIAsync.resolve(AsyncTestService.self)
                    return await service?.performAsyncOperation()
                }
            }

            var results: [String?] = []
            for await result in group {
                results.append(result)
            }

            // All should succeed
            XCTAssertEqual(results.count, 100)
            for result in results {
                XCTAssertEqual(result, "async_operation_completed")
            }
        }
    }

    // MARK: - Error Handling Tests

    func testAsyncErrorHandling() async {
        // Test resolution of non-registered service
        let service = await DIAsync.resolve(AsyncTestService.self)
        XCTAssertNil(service)

        // Test with fallback
        let fallbackService = await DIAsync.resolve(AsyncTestService.self, default: MockAsyncTestService())
        let result = await fallbackService.performAsyncOperation()
        XCTAssertEqual(result, "mock_async_operation")
    }

    // MARK: - Helper Methods

    private func measureAsync(_ operation: () async throws -> Void) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        try? await operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        print("Async operation took: \(duration * 1000)ms")
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