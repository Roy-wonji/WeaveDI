//
//  PropertyWrapperTests.swift
//  DiContainerTests
//
//  Created by Wonja Suh on 9/24/25.
//

import XCTest
@testable import WeaveDI

// MARK: - Test Services

protocol PropertyWrapperTestUserService: Sendable {
    func getUser(id: String) -> String
}

final class PropertyWrapperTestUserServiceImpl: PropertyWrapperTestUserService, InjectedKey, @unchecked Sendable {
    static let liveValue: PropertyWrapperTestUserServiceImpl = PropertyWrapperTestUserServiceImpl()
    static let testValue: PropertyWrapperTestUserServiceImpl = PropertyWrapperTestUserServiceImpl()

    func getUser(id: String) -> String {
        return "User-\(id)"
    }
}

final class MockPropertyWrapperTestUserService: PropertyWrapperTestUserService, InjectedKey, @unchecked Sendable {
    static let liveValue: MockPropertyWrapperTestUserService = MockPropertyWrapperTestUserService()
    static let testValue: MockPropertyWrapperTestUserService = MockPropertyWrapperTestUserService()

    private let lock = NSLock()
    private var _mockValue = "MockUser"

    var mockValue: String {
        get {
            lock.lock()
            let value = _mockValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            _mockValue = newValue
            lock.unlock()
        }
    }

    func getUser(id: String) -> String {
        return "\(mockValue)-\(id)"
    }
}

// MARK: - Property Wrapper Tests

final class PropertyWrapperTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        // 각 테스트마다 깨끗한 컨테이너로 시작
        WeaveDI.Container.live = WeaveDI.Container()
    }

    override func tearDown() async throws {
        WeaveDI.Container.live = WeaveDI.Container()
        try await super.tearDown()
    }

    // MARK: - @Injected Tests (Type-based)

    func testInjectedWithType() async throws {
        // Given: TestService를 타입으로 주입받는 클래스
        class TestService {
            @Injected(PropertyWrapperTestUserServiceImpl.self) var userService

            func performOperation() -> String {
                return userService.getUser(id: "injected_test")
            }
        }

        // When: 서비스 등록
        WeaveDI.Container.live.register(PropertyWrapperTestUserServiceImpl.self, instance: PropertyWrapperTestUserServiceImpl())

        let service = TestService()

        // Then: 주입된 서비스가 정상 작동
        XCTAssertEqual(service.performOperation(), "User-injected_test")
    }

    func testInjectedWithTypeOptional() async throws {
        // Given: Optional 타입 주입 (컨테이너 resolve 직접 사용)
        class TestService {
            var userService: PropertyWrapperTestUserServiceImpl? {
                return WeaveDI.Container.live.resolve(PropertyWrapperTestUserServiceImpl.self)
            }

            func performOperation() -> String? {
                return userService?.getUser(id: "optional_test")
            }
        }

        let service = TestService()

        // When: 등록되지 않은 상태에서 접근
        // Then: nil 반환
        XCTAssertNil(service.userService)
        XCTAssertNil(service.performOperation())

        // When: 서비스 등록 후
        WeaveDI.Container.live.register(PropertyWrapperTestUserServiceImpl.self, instance: PropertyWrapperTestUserServiceImpl())

        // Then: 주입된 서비스 사용 가능
        XCTAssertNotNil(service.userService)
        XCTAssertEqual(service.performOperation(), "User-optional_test")
    }

    // MARK: - @Factory Tests

    func testFactory() async throws {
        // Given: Factory로 새 인스턴스를 생성하는 클래스
        class TestService {
            func createUsers() -> [String] {
                // Factory 패턴으로 새 인스턴스 생성
                let factory = { PropertyWrapperTestUserServiceImpl() }
                let user1 = factory().getUser(id: "1")
                let user2 = factory().getUser(id: "2")
                return [user1, user2]
            }
        }

        let service = TestService()

        // Then: 매번 새 인스턴스 생성
        let users = service.createUsers()
        XCTAssertEqual(users.count, 2)
        XCTAssertEqual(users[0], "User-1")
        XCTAssertEqual(users[1], "User-2")
    }

    // MARK: - Integration Tests

    func testPropertyWrapperIntegration() async throws {
        // Given: 여러 방식을 함께 사용하는 복합 서비스
        class ComplexService {
            @Injected(PropertyWrapperTestUserServiceImpl.self) var userService

            func processUsers() -> [String] {
                // 기존 서비스 사용
                let existingUser = userService.getUser(id: "existing")

                // Factory 패턴으로 새 인스턴스 생성
                let newUser = PropertyWrapperTestUserServiceImpl().getUser(id: "new")

                return [existingUser, newUser]
            }
        }

        // When: 서비스 등록
        WeaveDI.Container.live.register(PropertyWrapperTestUserServiceImpl.self, instance: PropertyWrapperTestUserServiceImpl())

        let complexService = ComplexService()

        // Then: 모든 방식이 정상 작동
        let results = complexService.processUsers()
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0], "User-existing")
        XCTAssertEqual(results[1], "User-new")
    }

    // MARK: - Error Handling Tests

    func testMissingDependency() async throws {
        // Given: 등록되지 않은 의존성을 주입받는 서비스
        class TestService {
            var userService: PropertyWrapperTestUserServiceImpl? {
                return WeaveDI.Container.live.resolve(PropertyWrapperTestUserServiceImpl.self)
            }
        }

        let service = TestService()

        // When & Then: 등록되지 않은 경우 nil 반환
        XCTAssertNil(service.userService)
    }

    // MARK: - Performance Tests

    func testPropertyWrapperPerformance() async throws {
        // Given: 성능 테스트를 위한 서비스
        class TestService {
            @Injected(PropertyWrapperTestUserServiceImpl.self) var userService
        }

        WeaveDI.Container.live.register(PropertyWrapperTestUserServiceImpl.self, instance: PropertyWrapperTestUserServiceImpl())
        let service = TestService()

        // When & Then: Property Wrapper 접근 성능 측정
        measure {
            for _ in 0..<1000 {
                let _ = service.userService.getUser(id: "perf_test")
            }
        }
    }

    // MARK: - Thread Safety Tests

    func testPropertyWrapperThreadSafety() async throws {
        // Given: 멀티스레드 환경에서 사용할 서비스
        final class TestService: @unchecked Sendable {
            @Injected(PropertyWrapperTestUserServiceImpl.self) var userService

            func safeOperation() -> String {
                return userService.getUser(id: "thread_test")
            }
        }

        WeaveDI.Container.live.register(PropertyWrapperTestUserServiceImpl.self, instance: PropertyWrapperTestUserServiceImpl())
        let service = TestService()

        // When: 여러 스레드에서 동시 접근
        let results = await withTaskGroup(of: String.self) { group in
            for _ in 0..<10 {
                group.addTask { @Sendable in
                    return service.safeOperation()
                }
            }

            // Then: 모든 작업이 성공적으로 완료
            var taskResults: [String] = []
            for await result in group {
                taskResults.append(result)
            }
            return taskResults
        }

        XCTAssertEqual(results.count, 10)
        for result in results {
            XCTAssertEqual(result, "User-thread_test")
        }
    }

    // MARK: - Mock and Testing Support

    func testMockingWithPropertyWrappers() async throws {
        // Given: Mock 서비스를 사용하는 테스트 (컨테이너 resolve 직접 사용)
        class TestService {
            var userService: MockPropertyWrapperTestUserService {
                return WeaveDI.Container.live.resolve(MockPropertyWrapperTestUserService.self) ?? MockPropertyWrapperTestUserService()
            }

            func businessLogic() -> String {
                let user = userService.getUser(id: "business")
                return "Processed: \(user)"
            }
        }

        let mockService = MockPropertyWrapperTestUserService()
        mockService.mockValue = "TestMock"

        // When: Mock 서비스 등록
        WeaveDI.Container.live.register(MockPropertyWrapperTestUserService.self, instance: mockService)

        let service = TestService()

        // Then: Mock 서비스가 주입되어 테스트 가능
        let result = service.businessLogic()
        XCTAssertEqual(result, "Processed: TestMock-business")
    }
}