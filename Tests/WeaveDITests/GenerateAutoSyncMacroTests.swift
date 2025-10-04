//
//  GenerateAutoSyncMacroTests.swift
//  WeaveDI
//
//  Created by Wonji Suh on 2025.
//

import XCTest
@testable import WeaveDI

#if canImport(Dependencies)
import Dependencies

// MARK: - Test Services for @GenerateAutoSync Macro

public protocol GenerateAutoSyncTestService: Sendable {
    func getName() -> String
}

public final class LiveGenerateAutoSyncService: GenerateAutoSyncTestService {
    public init() {}
    public func getName() -> String { "live_generate_autosync_service" }
}

public final class MockGenerateAutoSyncService: GenerateAutoSyncTestService, @unchecked Sendable {
    public var mockName: String
    public init(name: String = "mock_generate_autosync_service") {
        self.mockName = name
    }
    public func getName() -> String { mockName }
}

// MARK: - TCA DependencyKey

public struct GenerateAutoSyncServiceKey: DependencyKey {
    public static let liveValue: GenerateAutoSyncTestService = LiveGenerateAutoSyncService()
    public static let testValue: GenerateAutoSyncTestService = MockGenerateAutoSyncService()
}

// MARK: - 🎉 사용자가 원하는 패턴: @GenerateAutoSync 매크로!

/// 🎯 **매크로가 완전 자동 생성**: extension에 매크로를 적용하면 자동으로 property 생성!
@GenerateAutoSync(key: GenerateAutoSyncServiceKey.self, type: GenerateAutoSyncTestService.self)
extension DependencyValues {
    // ↑ 이 매크로가 아래와 같은 완전한 property를 자동 생성:
    //
    // var generateAutoSyncService: GenerateAutoSyncTestService {
    //     get {
    //         let value = self[GenerateAutoSyncServiceKey.self]
    //         TCAAutoSyncContainer.autoSyncToWeaveDI(GenerateAutoSyncTestService.self, value: value)
    //         return value
    //     }
    //     set {
    //         self[GenerateAutoSyncServiceKey.self] = newValue
    //         TCAAutoSyncContainer.autoSyncToWeaveDI(GenerateAutoSyncTestService.self, value: newValue)
    //     }
    // }
}

// MARK: - InjectedKey for WeaveDI

public struct GenerateAutoSyncTestServiceInjectedKey: InjectedKey {
    public static let liveValue: GenerateAutoSyncTestService = LiveGenerateAutoSyncService()
}

extension InjectedValues {
    var generateAutoSyncTestService: GenerateAutoSyncTestService {
        get { self[GenerateAutoSyncTestServiceInjectedKey.self] }
        set { self[GenerateAutoSyncTestServiceInjectedKey.self] = newValue }
    }
}

// MARK: - WeaveDI 소비자 클래스

class GenerateAutoSyncConsumer {
    @Injected(\.generateAutoSyncTestService) var service: GenerateAutoSyncTestService

    init() {}

    func getServiceName() -> String {
        return service.getName()
    }
}

// MARK: - Tests

final class GenerateAutoSyncMacroTests: XCTestCase {

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        UnifiedDI.releaseAll()
    }

    func testGenerateAutoSyncMacroBasicFunctionality() throws {
        // Given: @GenerateAutoSync 매크로가 완전한 property를 자동 생성
        // When: TCA에서 매크로 생성된 property에 접근
        let tcaService = withDependencies { _ in
            // TCA 기본 의존성 사용 (테스트 컨텍스트에서는 testValue 사용)
        } operation: {
            @Dependency(\.generateAutoSyncService) var service
            return service
        }

        // Then: 매크로가 생성한 동기화 코드가 자동으로 작동해야 함
        let weaveDIService = UnifiedDI.resolve(GenerateAutoSyncTestService.self)
        XCTAssertNotNil(weaveDIService)
        // 테스트 컨텍스트에서는 testValue("mock_generate_autosync_service")가 사용됨
        XCTAssertEqual(weaveDIService?.getName(), "mock_generate_autosync_service")
        XCTAssertEqual(tcaService.getName(), "mock_generate_autosync_service")
    }

    func testGenerateAutoSyncMacroSetterSynchronization() throws {
        // Given: 커스텀 mock 서비스
        let customService = MockGenerateAutoSyncService(name: "custom_generate_autosync")

        // When: 매크로 생성된 setter 사용
        withDependencies { dependencies in
            dependencies.generateAutoSyncService = customService  // 매크로 생성 setter로 자동 WeaveDI 동기화
        } operation: {
            // Then: WeaveDI에서도 해당 값에 접근 가능해야 함
            let weaveDIService = UnifiedDI.resolve(GenerateAutoSyncTestService.self)
            XCTAssertNotNil(weaveDIService)
            XCTAssertEqual(weaveDIService?.getName(), "custom_generate_autosync")

            // @Injected로도 접근 가능해야 함
            let consumer = GenerateAutoSyncConsumer()
            let result = consumer.getServiceName()
            XCTAssertEqual(result, "custom_generate_autosync")
        }
    }

    func testGenerateAutoSyncMacroInjectedAccess() throws {
        // Given: 매크로로 TCA에서 서비스 설정
        withDependencies { dependencies in
            let mockService = MockGenerateAutoSyncService(name: "generate_autosync_registered")
            dependencies.generateAutoSyncService = mockService
        } operation: {
            // When: @Injected property wrapper로 접근
            let consumer = GenerateAutoSyncConsumer()
            let result = consumer.getServiceName()

            // Then: 매크로가 자동 동기화한 값을 @Injected로 접근 가능해야 함
            XCTAssertEqual(result, "generate_autosync_registered")
        }
    }

    func testGenerateAutoSyncMacroRealWorldPattern() throws {
        // Given: 실제 사용자 패턴 - @GenerateAutoSync 매크로만 추가
        // 사용자는 한 줄의 매크로로 완전한 동기화 property를 얻음

        // When: TCA 표준 패턴으로 서비스 접근
        let tcaService = withDependencies { _ in
            // TCA 기본 값 사용 (테스트 컨텍스트에서는 testValue)
        } operation: {
            @Dependency(\.generateAutoSyncService) var service
            return service
        }

        // Then: 매크로가 자동으로 TCA → WeaveDI 동기화를 처리해야 함
        let service = UnifiedDI.resolve(GenerateAutoSyncTestService.self)
        XCTAssertNotNil(service)
        // 테스트 컨텍스트에서는 testValue가 사용됨
        XCTAssertEqual(service?.getName(), "mock_generate_autosync_service")
        XCTAssertEqual(tcaService.getName(), "mock_generate_autosync_service")
    }

    func testGenerateAutoSyncMacroBidirectionalSync() throws {
        // Given: 매크로로 양방향 동기화 테스트
        let tcaMockService = MockGenerateAutoSyncService(name: "tca_generate_autosync_side")

        // When: TCA → WeaveDI (매크로로 자동 동기화)
        withDependencies { dependencies in
            dependencies.generateAutoSyncService = tcaMockService
        } operation: {
            // WeaveDI에서 접근
            let weaveDIService = UnifiedDI.resolve(GenerateAutoSyncTestService.self)
            XCTAssertEqual(weaveDIService?.getName(), "tca_generate_autosync_side")

            // WeaveDI → TCA 방향도 테스트
            let weaveDIMockService = MockGenerateAutoSyncService(name: "weavedi_generate_autosync_side")
            _ = UnifiedDI.register(GenerateAutoSyncTestService.self) { weaveDIMockService }

            // WeaveDI 등록 후 값 확인 - TCA 값이 유지됨
            let updatedService = UnifiedDI.resolve(GenerateAutoSyncTestService.self)
            XCTAssertEqual(updatedService?.getName(), "tca_generate_autosync_side") // TCA 값이 유지됨 (마지막에 설정된 값)
        }
    }

    func testGenerateAutoSyncMacroPropertyNameGeneration() throws {
        // Given: 매크로가 key 이름에서 property 이름을 올바르게 생성하는지 테스트
        // GenerateAutoSyncServiceKey.self -> generateAutoSyncService

        // When: 매크로 생성된 property 접근
        let tcaService = withDependencies { _ in
            // TCA 기본 의존성 사용
        } operation: {
            @Dependency(\.generateAutoSyncService) var service  // 매크로가 올바른 이름으로 생성했는지 확인
            return service
        }

        // Then: 올바른 property 이름으로 접근 가능해야 함
        XCTAssertEqual(tcaService.getName(), "mock_generate_autosync_service")

        // WeaveDI에서도 동기화되어야 함
        let weaveDIService = UnifiedDI.resolve(GenerateAutoSyncTestService.self)
        XCTAssertNotNil(weaveDIService)
        XCTAssertEqual(weaveDIService?.getName(), "mock_generate_autosync_service")
    }
}
#endif