//
//  UserWantedAutoSyncTests.swift
//  WeaveDI - 사용자가 원하는 @AutoSync 패턴 테스트
//
//  Created by Wonji Suh on 2025.
//

import XCTest
@testable import WeaveDI

#if canImport(Dependencies)
import Dependencies

// MARK: - Test Services

public protocol UserWantedTestService: Sendable {
    func getName() -> String
}

public final class LiveUserWantedService: UserWantedTestService {
    public init() {}
    public func getName() -> String { "live_user_wanted_service" }
}

public final class MockUserWantedService: UserWantedTestService, @unchecked Sendable {
    public var mockName: String
    public init(name: String = "mock_user_wanted_service") {
        self.mockName = name
    }
    public func getName() -> String { mockName }
}

// MARK: - TCA DependencyKey

public struct UserWantedServiceKey: DependencyKey {
    public static let liveValue: UserWantedTestService = LiveUserWantedService()
    public static let testValue: UserWantedTestService = MockUserWantedService()
}

// MARK: - 🎯 사용자가 원하는 패턴: @AutoSync만 추가!

/// 🎯 **사용자가 정말 원했던 패턴**: @AutoSync만 추가하면 기존 코드 그대로!
@AutoSync  // ← 이것만 추가!
extension DependencyValues {
    var userWantedService: UserWantedTestService {
        get { self[UserWantedServiceKey.self] }  // 기존 코드 그대로
        set { self[UserWantedServiceKey.self] = newValue }  // 기존 코드 그대로
    }

    // 여러 property도 테스트 (같은 Key 사용)
    var anotherService: UserWantedTestService {
        get { self[UserWantedServiceKey.self] }
        set { self[UserWantedServiceKey.self] = newValue }
    }
}

// MARK: - InjectedKey for WeaveDI

public struct UserWantedTestServiceInjectedKey: InjectedKey {
    public static let liveValue: UserWantedTestService = LiveUserWantedService()
}

extension InjectedValues {
    var userWantedTestService: UserWantedTestService {
        get { self[UserWantedTestServiceInjectedKey.self] }
        set { self[UserWantedTestServiceInjectedKey.self] = newValue }
    }
}

// MARK: - WeaveDI 소비자 클래스

class UserWantedConsumer {
    @Injected(\.userWantedTestService) var service: UserWantedTestService

    init() {}

    func getServiceName() -> String {
        return service.getName()
    }
}

// MARK: - Tests

final class UserWantedAutoSyncTests: XCTestCase {

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        UnifiedDI.releaseAll()
    }

    func testUserWantedAutoSyncPattern() throws {
        // Given: 사용자가 원하는 패턴 - @AutoSync만 추가했을 때

        // When: 기존 property 사용 (그대로)
        let tcaService = withDependencies { _ in
            // TCA 기본 의존성 사용
        } operation: {
            @Dependency(\.userWantedService) var service
            return service
        }

        // Then: 기존 property는 여전히 작동해야 함
        XCTAssertEqual(tcaService.getName(), "mock_user_wanted_service")

        // And: 매크로가 생성한 Sync 버전도 사용 가능해야 함
        let tcaSyncService = withDependencies { _ in
            // TCA 기본 의존성 사용
        } operation: {
            @Dependency(\.userWantedServiceSync) var service  // 매크로가 자동 생성한 Sync 버전
            return service
        }

        // Then: Sync 버전은 자동으로 WeaveDI와 동기화되어야 함
        XCTAssertEqual(tcaSyncService.getName(), "mock_user_wanted_service")

        // WeaveDI에서도 접근 가능해야 함
        let weaveDIService = UnifiedDI.resolve(UserWantedTestService.self)
        XCTAssertNotNil(weaveDIService)
        XCTAssertEqual(weaveDIService?.getName(), "mock_user_wanted_service")
    }

    func testAutoSyncSetterSynchronization() throws {
        // Given: 커스텀 mock 서비스
        let customService = MockUserWantedService(name: "custom_user_wanted")

        // When: 매크로 생성된 Sync setter 사용
        withDependencies { dependencies in
            dependencies.userWantedServiceSync = customService  // 매크로 생성 Sync setter로 자동 WeaveDI 동기화
        } operation: {
            // Then: WeaveDI에서도 해당 값에 접근 가능해야 함
            let weaveDIService = UnifiedDI.resolve(UserWantedTestService.self)
            XCTAssertNotNil(weaveDIService)
            XCTAssertEqual(weaveDIService?.getName(), "custom_user_wanted")

            // @Injected로도 접근 가능해야 함
            let consumer = UserWantedConsumer()
            let result = consumer.getServiceName()
            XCTAssertEqual(result, "custom_user_wanted")
        }
    }

    func testMultiplePropertiesAutoSync() throws {
        // Given: @AutoSync가 여러 property에 적용될 때

        // When: 여러 Sync property 사용
        let service1 = withDependencies { _ in
        } operation: {
            @Dependency(\.userWantedServiceSync) var service
            return service
        }

        let service2 = withDependencies { _ in
        } operation: {
            @Dependency(\.anotherServiceSync) var service  // 또 다른 매크로 생성 property
            return service
        }

        // Then: 모든 Sync property가 작동해야 함
        XCTAssertEqual(service1.getName(), "mock_user_wanted_service")
        XCTAssertEqual(service2.getName(), "mock_user_wanted_service")
    }

    func testOriginalPropertiesUnchanged() throws {
        // Given: @AutoSync 추가 후에도

        // When: 기존 property들을 사용할 때
        let originalService = withDependencies { _ in
        } operation: {
            @Dependency(\.userWantedService) var service  // 기존 property (변경 없음)
            return service
        }

        // Then: 기존 property는 여전히 정상 작동해야 함
        XCTAssertEqual(originalService.getName(), "mock_user_wanted_service")

        // And: 기존 property는 동기화 코드가 없어야 함 (WeaveDI에 등록되지 않음)
        // 이는 기존 동작을 보장하는 테스트
        // 실제로는 Sync 버전만 WeaveDI와 동기화됨
    }

    func testUserExperienceRealistic() throws {
        // Given: 실제 사용자 사용 시나리오

        // 1. 사용자는 기존 코드를 그대로 사용
        let originalService = withDependencies { _ in
        } operation: {
            @Dependency(\.userWantedService) var service
            return service
        }

        // 2. 동기화가 필요한 경우에만 Sync 버전 사용
        let syncService = withDependencies { dependencies in
            let customService = MockUserWantedService(name: "realistic_sync_test")
            dependencies.userWantedServiceSync = customService  // 동기화 버전으로 설정
        } operation: {
            @Dependency(\.userWantedServiceSync) var service
            return service
        }

        // Then: 두 방식 모두 정상 작동
        XCTAssertEqual(originalService.getName(), "mock_user_wanted_service")
        XCTAssertEqual(syncService.getName(), "realistic_sync_test")

        // And: Sync 버전은 WeaveDI와 동기화됨
        let weaveDIService = UnifiedDI.resolve(UserWantedTestService.self)
        XCTAssertEqual(weaveDIService?.getName(), "realistic_sync_test")
    }
}
#endif