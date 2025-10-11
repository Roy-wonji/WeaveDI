//
//  TCAToWeaveDIAutoSyncTests.swift
//  WeaveDI
//
//  Created by Wonji Suh on 2025.
//

import XCTest
@testable import WeaveDI

#if canImport(Dependencies)
import Dependencies

// MARK: - Test Services for TCA → WeaveDI

public protocol TCAToWeaveDITestService: Sendable {
    func getName() -> String
}

public final class LiveTCAToWeaveDIService: TCAToWeaveDITestService {
    public init() {}
    public func getName() -> String { "live_tca_service" }
}

public final class MockTCAToWeaveDIService: TCAToWeaveDITestService, @unchecked Sendable {
    public var mockName: String
    public init(name: String = "mock_tca_service") {
        self.mockName = name
    }
    public func getName() -> String { mockName }
}

// MARK: - TCA DependencyKey

public struct TCAToWeaveDIServiceKey: DependencyKey {
    public static let liveValue: TCAToWeaveDITestService = LiveTCAToWeaveDIService()
    public static let testValue: TCAToWeaveDITestService = MockTCAToWeaveDIService()
}

// MARK: - TCA DependencyValues Extension (사용자 패턴)

public extension DependencyValues {
    var tcaToWeaveDIService: TCAToWeaveDITestService {
        get {
            let value = self[TCAToWeaveDIServiceKey.self]
            // 🎯 TCA → WeaveDI 자동 동기화 (+1줄)
            TCAAutoSyncContainer.autoSyncToWeaveDI(TCAToWeaveDITestService.self, value: value)
            return value
        }
        set {
            self[TCAToWeaveDIServiceKey.self] = newValue
            // 🎯 TCA → WeaveDI 자동 동기화 (+1줄)
            TCAAutoSyncContainer.autoSyncToWeaveDI(TCAToWeaveDITestService.self, value: newValue)
        }
    }
}

// MARK: - InjectedKey for WeaveDI

public struct TCAToWeaveDITestServiceInjectedKey: InjectedKey {
    public static let liveValue: TCAToWeaveDITestService = LiveTCAToWeaveDIService()
}

extension InjectedValues {
    var tcaToWeaveDITestService: TCAToWeaveDITestService {
        get { self[TCAToWeaveDITestServiceInjectedKey.self] }
        set { self[TCAToWeaveDITestServiceInjectedKey.self] = newValue }
    }
}

// MARK: - Test Classes

class TCAToWeaveDIConsumer {
    @Injected(\.tcaToWeaveDITestService) var service: TCAToWeaveDITestService

    init() {}

    func getServiceName() -> String {
        return service.getName()
    }
}

// MARK: - Tests

final class TCAToWeaveDIAutoSyncTests: XCTestCase {

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        UnifiedDI.releaseAll()
        enableBidirectionalTCASync()
    }

    func testTCADependencyValuesAutoSyncToWeaveDI() async throws {
        // Given: TCA DependencyValues에서 서비스 접근 (한 줄 추가된 버전)
        let tcaService = withDependencies { _ in
            // TCA 기본 의존성 사용
        } operation: {
            @Dependency(\.tcaToWeaveDIService) var service
            return service
        }

        // When: TCA에서 접근한 후 WeaveDI에서 해결 시도
        await UnifiedDI.waitForRegistration()
        let weaveDIService = UnifiedDI.resolve(TCAToWeaveDITestService.self)

        // Then: TCA에서 설정한 값이 WeaveDI에도 자동 등록되어야 함
        XCTAssertNotNil(weaveDIService)
        XCTAssertEqual(weaveDIService?.getName(), "mock_tca_service")
        XCTAssertEqual(tcaService.getName(), "mock_tca_service")
    }

    func testTCADependencyValuesSetterAutoSync() async throws {
        // Given: 커스텀 mock 서비스
        let customService = MockTCAToWeaveDIService(name: "custom_tca_mock")

        // When: TCA DependencyValues setter로 설정
         await withDependencies { dependencies in
            dependencies.tcaToWeaveDIService = customService  // 자동 WeaveDI 동기화됨
        } operation: {
            await UnifiedDI.waitForRegistration()
            // Then: WeaveDI에서도 해당 값에 접근 가능해야 함
            let weaveDIService = UnifiedDI.resolve(TCAToWeaveDITestService.self)
            XCTAssertNotNil(weaveDIService)
            XCTAssertEqual(weaveDIService?.getName(), "custom_tca_mock")

            // @Injected로도 접근 가능해야 함
            let consumer = TCAToWeaveDIConsumer()
            let result = consumer.getServiceName()
            XCTAssertEqual(result, "custom_tca_mock")
        }
    }

    func testWeaveDIInjectedAccessAfterTCARegistration() async throws {
        // Given: TCA에서 먼저 서비스 등록
         await withDependencies { dependencies in
            let mockService = MockTCAToWeaveDIService(name: "tca_registered")
            dependencies.tcaToWeaveDIService = mockService
        } operation: {
            await UnifiedDI.waitForRegistration()
            // When: @Injected property wrapper로 접근
            let consumer = TCAToWeaveDIConsumer()
            let result = consumer.getServiceName()

            // Then: TCA에서 등록한 값을 @Injected로 접근 가능해야 함
            XCTAssertEqual(result, "tca_registered")
        }
    }

    func testRealWorldTCAPattern() async throws {
        // Given: 실제 사용자 사용 패턴
        struct MyAppDependencyKey: DependencyKey {
            static let liveValue: TCAToWeaveDITestService = LiveTCAToWeaveDIService()
        }

        // 사용자가 추가하는 DependencyValues extension
        await withDependencies { dependencies in
            // TCA의 기본 subscript 사용
            let value = dependencies[MyAppDependencyKey.self]
            // 수동으로 WeaveDI 동기화 (사용자가 추가)
            TCAAutoSyncContainer.autoSyncToWeaveDI(TCAToWeaveDITestService.self, value: value)
        } operation: {
            await UnifiedDI.waitForRegistration()
            // WeaveDI에서 접근 가능해야 함
            let service = UnifiedDI.resolve(TCAToWeaveDITestService.self)

            // Then: TCA → WeaveDI 동기화가 잘 작동해야 함
            XCTAssertNotNil(service)
            XCTAssertEqual(service?.getName(), "live_tca_service")
        }
    }

    func testBidirectionalSync() async throws {
        // Given: 양방향 동기화 테스트
        let tcaMockService = MockTCAToWeaveDIService(name: "tca_side")

        // When: TCA → WeaveDI
         await withDependencies { dependencies in
            dependencies.tcaToWeaveDIService = tcaMockService
        } operation: {
            await UnifiedDI.waitForRegistration()
            // WeaveDI에서 접근
            let weaveDIService = UnifiedDI.resolve(TCAToWeaveDITestService.self)
            XCTAssertEqual(weaveDIService?.getName(), "tca_side")

            // WeaveDI → TCA 방향도 테스트
            let weaveDIMockService = MockTCAToWeaveDIService(name: "weavedi_side")
            _ = UnifiedDI.register(TCAToWeaveDITestService.self) { weaveDIMockService }
            await UnifiedDI.waitForRegistration()

            // TCA에서도 업데이트된 값 접근 가능해야 함
            let updatedService = UnifiedDI.resolve(TCAToWeaveDITestService.self)
            XCTAssertEqual(updatedService?.getName(), "weavedi_side")
        }
    }
}
#endif
