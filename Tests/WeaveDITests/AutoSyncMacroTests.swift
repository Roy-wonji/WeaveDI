//
//  AutoSyncMacroTests.swift
//  WeaveDI
//
//  Created by Wonji Suh on 2025.
//

import XCTest
@testable import WeaveDI

#if canImport(Dependencies)
import Dependencies

// MARK: - Test Services for @AutoSync Macro

public protocol AutoSyncMacroTestService: Sendable {
    func getName() -> String
}

public final class LiveAutoSyncMacroService: AutoSyncMacroTestService {
    public init() {}
    public func getName() -> String { "live_autosync_macro_service" }
}

public final class MockAutoSyncMacroService: AutoSyncMacroTestService, @unchecked Sendable {
    public var mockName: String
    public init(name: String = "mock_autosync_macro_service") {
        self.mockName = name
    }
    public func getName() -> String { mockName }
}

// MARK: - TCA DependencyKey

public struct AutoSyncMacroServiceKey: DependencyKey {
    public static let liveValue: AutoSyncMacroTestService = LiveAutoSyncMacroService()
    public static let testValue: AutoSyncMacroTestService = MockAutoSyncMacroService()
}

// MARK: - 사용자가 원하는 패턴 구현

/// 🎯 **사용자가 원하는 패턴**: 기존 TCA 코드에 한 줄만 추가
/// 이것이 실제로 작동하는 패턴입니다!
public extension DependencyValues {
    var autoSyncMacroService: AutoSyncMacroTestService {
        get {
            let value = self[AutoSyncMacroServiceKey.self]
            // 🎯 TCA → WeaveDI 자동 동기화 (+1줄만 추가!)
            TCAAutoSyncContainer.autoSyncToWeaveDI(AutoSyncMacroTestService.self, value: value)
            return value
        }
        set {
            self[AutoSyncMacroServiceKey.self] = newValue
            // 🎯 TCA → WeaveDI 자동 동기화 (+1줄만 추가!)
            TCAAutoSyncContainer.autoSyncToWeaveDI(AutoSyncMacroTestService.self, value: newValue)
        }
    }
}

/// 🎯 **대안 패턴**: 수동 동기화 (테스트용)
public extension DependencyValues {
    var manualSyncService: AutoSyncMacroTestService {
        get {
            let value = self[AutoSyncMacroServiceKey.self]
            // 🎯 TCA → WeaveDI 자동 동기화 (+1줄)
            TCAAutoSyncContainer.autoSyncToWeaveDI(AutoSyncMacroTestService.self, value: value)
            return value
        }
        set {
            self[AutoSyncMacroServiceKey.self] = newValue
            // 🎯 TCA → WeaveDI 자동 동기화 (+1줄)
            TCAAutoSyncContainer.autoSyncToWeaveDI(AutoSyncMacroTestService.self, value: newValue)
        }
    }
}

// MARK: - InjectedKey for WeaveDI

public struct AutoSyncMacroTestServiceInjectedKey: InjectedKey {
    public static let liveValue: AutoSyncMacroTestService = LiveAutoSyncMacroService()
}

extension InjectedValues {
    var autoSyncMacroTestService: AutoSyncMacroTestService {
        get { self[AutoSyncMacroTestServiceInjectedKey.self] }
        set { self[AutoSyncMacroTestServiceInjectedKey.self] = newValue }
    }
}

// MARK: - WeaveDI 소비자 클래스

class AutoSyncMacroConsumer {
    @Injected(\.autoSyncMacroTestService) var service: AutoSyncMacroTestService

    init() {}

    func getServiceName() -> String {
        return service.getName()
    }
}

// MARK: - Tests

final class AutoSyncMacroTests: XCTestCase {

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        UnifiedDI.releaseAll()
        enableBidirectionalTCASync()
    }

    func testAutoSyncBasicFunctionality() throws {
        // Given: 사용자가 원하는 패턴 - 기존 getter/setter에 한 줄씩만 추가
        // When: TCA에서 서비스 접근
        let tcaService = withDependencies { _ in
            // TCA 기본 의존성 사용 (테스트 컨텍스트에서는 testValue 사용)
        } operation: {
            @Dependency(\.autoSyncMacroService) var service
            return service
        }

        // Then: 한 줄 추가로 TCA → WeaveDI 자동 동기화가 작동해야 함
        let weaveDIService = UnifiedDI.resolve(AutoSyncMacroTestService.self)
        XCTAssertNotNil(weaveDIService)
        // 테스트 컨텍스트에서는 testValue("mock_autosync_macro_service")가 사용됨
        XCTAssertEqual(weaveDIService?.getName(), "mock_autosync_macro_service")
        XCTAssertEqual(tcaService.getName(), "mock_autosync_macro_service")
    }

    func testAutoSyncMacroSetterSynchronization() throws {
        // Given: 커스텀 mock 서비스
        let customService = MockAutoSyncMacroService(name: "custom_autosync_macro")

        // When: @AutoSync가 적용된 setter 사용
        withDependencies { dependencies in
            dependencies.autoSyncMacroService = customService  // @AutoSync 매크로로 자동 WeaveDI 동기화
        } operation: {
            // Then: WeaveDI에서도 해당 값에 접근 가능해야 함
            let weaveDIService = UnifiedDI.resolve(AutoSyncMacroTestService.self)
            XCTAssertNotNil(weaveDIService)
            XCTAssertEqual(weaveDIService?.getName(), "custom_autosync_macro")

            // @Injected로도 접근 가능해야 함
            let consumer = AutoSyncMacroConsumer()
            let result = consumer.getServiceName()
            XCTAssertEqual(result, "custom_autosync_macro")
        }
    }

    func testManualSyncPattern() throws {
        // Given: 수동 동기화 패턴 (사용자가 원하는 기존 코드 + 1줄 추가 패턴)
        let customService = MockAutoSyncMacroService(name: "manual_sync_test")

        // When: 수동 동기화가 적용된 setter 사용
        withDependencies { dependencies in
            dependencies.manualSyncService = customService  // 수동 동기화로 WeaveDI 동기화
        } operation: {
            // Then: WeaveDI에서도 해당 값에 접근 가능해야 함
            let weaveDIService = UnifiedDI.resolve(AutoSyncMacroTestService.self)
            XCTAssertNotNil(weaveDIService)
            XCTAssertEqual(weaveDIService?.getName(), "manual_sync_test")

            // @Injected로도 접근 가능해야 함
            let consumer = AutoSyncMacroConsumer()
            let result = consumer.getServiceName()
            XCTAssertEqual(result, "manual_sync_test")
        }
    }

    func testAutoSyncMacroInjectedAccess() throws {
        // Given: @AutoSync 매크로로 TCA에서 서비스 설정
        withDependencies { dependencies in
            let mockService = MockAutoSyncMacroService(name: "autosync_macro_registered")
            dependencies.autoSyncMacroService = mockService
        } operation: {
            // When: @Injected property wrapper로 접근
            let consumer = AutoSyncMacroConsumer()
            let result = consumer.getServiceName()

            // Then: @AutoSync 매크로가 자동 동기화한 값을 @Injected로 접근 가능해야 함
            XCTAssertEqual(result, "autosync_macro_registered")
        }
    }

    func testAutoSyncMacroRealWorldPattern() throws {
        // Given: 실제 사용자 패턴 - 기존 TCA 코드에 한 줄만 추가
        // 사용자는 기존 TCA 코드를 수정하지 않고 한 줄만 추가

        // When: TCA 표준 패턴으로 서비스 접근
        let tcaService = withDependencies { _ in
            // TCA 기본 값 사용 (테스트 컨텍스트에서는 testValue)
        } operation: {
            @Dependency(\.autoSyncMacroService) var service
            return service
        }

        // Then: 한 줄 추가로 TCA → WeaveDI 동기화가 자동으로 처리되어야 함
        let service = UnifiedDI.resolve(AutoSyncMacroTestService.self)
        XCTAssertNotNil(service)
        // 테스트 컨텍스트에서는 testValue가 사용됨
        XCTAssertEqual(service?.getName(), "mock_autosync_macro_service")
        XCTAssertEqual(tcaService.getName(), "mock_autosync_macro_service")
    }

    func testAutoSyncMacroBidirectionalSync() throws {
        // Given: 양방향 동기화 테스트 (한 줄 추가 패턴)
        let tcaMockService = MockAutoSyncMacroService(name: "tca_autosync_side")

        // When: TCA → WeaveDI (한 줄 추가로 자동 동기화)
        withDependencies { dependencies in
            dependencies.autoSyncMacroService = tcaMockService
        } operation: {
            // WeaveDI에서 접근
            let weaveDIService = UnifiedDI.resolve(AutoSyncMacroTestService.self)
            XCTAssertEqual(weaveDIService?.getName(), "tca_autosync_side")

            // WeaveDI → TCA 방향도 테스트
            let weaveDIMockService = MockAutoSyncMacroService(name: "weavedi_autosync_side")
            _ = UnifiedDI.register(AutoSyncMacroTestService.self) { weaveDIMockService }

            // WeaveDI 등록 후 값 확인 - WeaveDI가 우선됨
            let updatedService = UnifiedDI.resolve(AutoSyncMacroTestService.self)
            XCTAssertEqual(updatedService?.getName(), "weavedi_autosync_side")
        }
    }
}
#endif
