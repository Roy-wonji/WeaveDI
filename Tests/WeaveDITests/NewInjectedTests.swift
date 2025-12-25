import XCTest
@testable import WeaveDI

class NewInjectedTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // 테스트마다 깨끗한 상태로 시작
        UnifiedDI.releaseAll()
    }

    func testNewTypeBasedInjection() {
        // 🎯 새로운 방식: 타입 기반 @Injected 테스트

        // 서비스 등록
        let registeredService = WeaveDI.register { MockUserService() }
        XCTAssertNotNil(registeredService)

        // @Injected로 해결
        let testContainer = TestContainer()

        // 실제로 주입된 서비스가 동작하는지 확인
        let result = testContainer.getUserInfo()
        XCTAssertEqual(result, "Mock User")
    }

    func testBuilderPattern() {
        // 🏗️ 빌더 패턴 테스트

        WeaveDI.builder
            .register { MockUserService() }
            .register { MockLogger() }
            .configure()

        let container = TestContainer()
        XCTAssertEqual(container.getUserInfo(), "Mock User")

        // Logger도 확인
        container.logSomething()
    }

    func testEnvironmentBasedRegistration() {
        // 🌍 환경별 등록 테스트

        WeaveDI.registerForEnvironment { env in
            if env.isDebug {
                env.register { MockUserService() as UserServiceProtocol }
            } else {
                env.register { ProductionUserService() as UserServiceProtocol }
            }
        }

        let container = TestContainerWithProtocol()
        let result = container.getUserInfo()

        #if DEBUG
        XCTAssertEqual(result, "Mock User")
        #else
        XCTAssertEqual(result, "Production User")
        #endif
    }
}

// MARK: - Test Helpers

protocol UserServiceProtocol: Sendable {
    func getUser() -> String
}

struct MockUserService: UserServiceProtocol {
    func getUser() -> String {
        return "Mock User"
    }
}

struct ProductionUserService: UserServiceProtocol {
    func getUser() -> String {
        return "Production User"
    }
}

protocol LoggerProtocol: Sendable {
    func log(_ message: String)
}

struct MockLogger: LoggerProtocol {
    func log(_ message: String) {
        print("Mock Log: \(message)")
    }
}

class TestContainer {
    // ✅ 새로운 방식: 타입만으로 간단하게!
    @Injected var userService: MockUserService
    @Injected var logger: MockLogger

    func getUserInfo() -> String {
        return userService.getUser()
    }

    func logSomething() {
        logger.log("테스트 로그")
    }
}

class TestContainerWithProtocol {
    // ✅ 프로토콜로도 동작!
    @Injected var userService: UserServiceProtocol

    func getUserInfo() -> String {
        return userService.getUser()
    }
}