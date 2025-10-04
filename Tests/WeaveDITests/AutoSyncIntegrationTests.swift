//
//  AutoSyncIntegrationTests.swift
//  WeaveDI
//
//  Created by Wonji Suh on 2025.
//

import XCTest
@testable import WeaveDI

// MARK: - Test Services for Auto Sync

public protocol AutoSyncTestService: Sendable {
    func getValue() -> String
}

public final class LiveAutoSyncService: AutoSyncTestService {
    public init() {}
    public func getValue() -> String { "live_auto_sync" }
}

public final class MockAutoSyncService: AutoSyncTestService, @unchecked Sendable {
    public var mockValue = "mock_auto_sync"
    public init() {}
    public func getValue() -> String { mockValue }
}

// MARK: - Test InjectedKey

public struct AutoSyncServiceKey: InjectedKey {
    public static let liveValue: AutoSyncTestService = LiveAutoSyncService()
    public static let testValue: AutoSyncTestService = MockAutoSyncService()
}

// MARK: - InjectedValues Extension

extension InjectedValues {
    var autoSyncTestService: AutoSyncTestService {
        get { self[AutoSyncServiceKey.self] }
        set { self[AutoSyncServiceKey.self] = newValue }
    }
}

// MARK: - Test Classes

class AutoSyncServiceConsumer {
    @Injected(\.autoSyncTestService) var service

    func callService() -> String {
        return service.getValue()
    }
}

// MARK: - Integration Tests

final class AutoSyncIntegrationTests: XCTestCase {

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        // 각 테스트마다 깨끗한 컨테이너로 시작
        UnifiedDI.releaseAll()
    }

    // MARK: - WeaveDI → TCA 자동 동기화 테스트

    func testInjectedKeyAutoSyncToTCAAndWeaveDI() async throws {
        // Given: 기존 사용자 패턴 (코드 수정 없음!)
        // extension ExchangeRateCacheUseCaseImpl: InjectedKey { ... }
        // extension InjectedValues {
        //   var exchangeRateCacheUseCase: ExchangeRateCacheInterface {
        //     get { self[ExchangeRateCacheUseCaseImpl.self] }  // ← 이 부분이 자동 동기화됨
        //     set { self[ExchangeRateCacheUseCaseImpl.self] = newValue }
        //   }
        // }

        // When: InjectedValues로 접근 (기존 방식 그대로)
        let service = InjectedValues.current.autoSyncTestService

        // Then: 자동으로 WeaveDI에 등록되어야 함
        XCTAssertEqual(service.getValue(), "live_auto_sync")

        // WeaveDI에서도 접근 가능해야 함
        let weaveDIService = UnifiedDI.resolve(AutoSyncTestService.self)
        XCTAssertNotNil(weaveDIService)
        XCTAssertEqual(weaveDIService?.getValue(), "live_auto_sync")
    }

    func testInjectedPropertyWrapperAutoSync() async throws {
        // Given: @Injected를 사용하는 기존 패턴
        let consumer = AutoSyncServiceConsumer()

        // When: @Injected property wrapper로 접근
        let result = consumer.callService()

        // Then: 자동 동기화가 작동해야 함
        XCTAssertEqual(result, "live_auto_sync")

        // WeaveDI에서도 등록되어 있어야 함
        let weaveDIService = UnifiedDI.resolve(AutoSyncTestService.self)
        XCTAssertNotNil(weaveDIService)
        XCTAssertEqual(weaveDIService?.getValue(), "live_auto_sync")
    }

    func testInjectedValuesSetterAutoSync() async throws {
        // Given: 커스텀 mock 서비스
        let mockService = MockAutoSyncService()
        mockService.mockValue = "custom_mock_value"

        // When: InjectedValues setter로 설정 (기존 방식 그대로)
        withInjectedValues { values in
            values.autoSyncTestService = mockService
        } operation: {
            // Then: WeaveDI에도 자동 등록되어야 함
            let weaveDIService = UnifiedDI.resolve(AutoSyncTestService.self)
            XCTAssertNotNil(weaveDIService)
            XCTAssertEqual(weaveDIService?.getValue(), "custom_mock_value")

            // @Injected로도 접근 가능해야 함
            let consumer = AutoSyncServiceConsumer()
            let result = consumer.callService()
            XCTAssertEqual(result, "custom_mock_value")
        }
    }

    func testWeaveDIToInjectedKeySync() async throws {
        // Given: UnifiedDI에 직접 등록
        let customService = MockAutoSyncService()
        customService.mockValue = "weavedi_registered"
        _ = UnifiedDI.register(AutoSyncTestService.self) { customService }

        // When: InjectedValues로 접근
        let service = InjectedValues.current.autoSyncTestService

        // Then: WeaveDI에서 등록한 값이 반환되어야 함
        XCTAssertEqual(service.getValue(), "weavedi_registered")
    }

    // MARK: - 성능 테스트

    func testAutoSyncPerformance() async throws {
        measure {
            for _ in 0..<100 {
                _ = InjectedValues.current.autoSyncTestService
            }
        }
    }

    // MARK: - 실제 사용자 패턴 테스트

    func testRealWorldUsagePattern() async throws {
        // Given: 실제 사용자가 사용하는 패턴
        struct ExchangeRateUseCaseKey: InjectedKey {
            static let liveValue: AutoSyncTestService = LiveAutoSyncService()
            static let testValue: AutoSyncTestService = MockAutoSyncService()
        }

        // When: 기존 코드 그대로 사용
        let service = InjectedValues.current[ExchangeRateUseCaseKey.self]

        // Then: 자동으로 WeaveDI에도 등록되어야 함
        XCTAssertEqual(service.getValue(), "live_auto_sync")

        let weaveDIService = UnifiedDI.resolve(AutoSyncTestService.self)
        XCTAssertNotNil(weaveDIService)
    }

    func testMultipleInjectedKeysAutoSync() async throws {
        // Given: 여러 InjectedKey 동시 사용
        struct ServiceA: InjectedKey {
            static let liveValue: AutoSyncTestService = LiveAutoSyncService()
        }
        struct ServiceB: InjectedKey {
            static let liveValue: AutoSyncTestService = MockAutoSyncService()
        }

        // When: 여러 서비스 접근
        let serviceA = InjectedValues.current[ServiceA.self]
        let serviceB = InjectedValues.current[ServiceB.self]

        // Then: 각각 WeaveDI에 등록되어야 함
        XCTAssertEqual(serviceA.getValue(), "live_auto_sync")
        XCTAssertEqual(serviceB.getValue(), "mock_auto_sync")

        // WeaveDI에서도 접근 가능해야 함
        let weaveDIServiceA = UnifiedDI.resolve(AutoSyncTestService.self)
        XCTAssertNotNil(weaveDIServiceA)
    }
}