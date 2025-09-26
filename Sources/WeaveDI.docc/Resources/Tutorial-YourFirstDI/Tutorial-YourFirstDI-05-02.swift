import XCTest
import DiContainer
@testable import DiContainerApp

final class UserServiceTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        // 각 테스트마다 컨테이너를 초기화
        await UnifiedDI.releaseAll()
    }

    override func tearDown() async throws {
        // 테스트 후 정리
        await UnifiedDI.releaseAll()
        try await super.tearDown()
    }

    func testUserService_WithMockNetworkService_ReturnsUsers() async throws {
        // Given: Mock 서비스들을 등록
        _ = UnifiedDI.register(NetworkService.self) {
            MockNetworkService()
        }
        _ = UnifiedDI.register(UserService.self) {
            DefaultUserService()
        }

        // When: UserService를 통해 사용자 목록을 가져옴
        let userService = UnifiedDI.resolve(UserService.self)!
        let users = try await userService.getUsers()

        // Then: 결과 검증
        XCTAssertFalse(users.isEmpty, "사용자 목록이 비어있지 않아야 합니다")
        XCTAssertEqual(users.first?.name, "테스트 사용자", "첫 번째 사용자 이름이 일치해야 합니다")
        XCTAssertEqual(users.first?.email, "test@example.com", "첫 번째 사용자 이메일이 일치해야 합니다")
    }

    func testUserService_WithMockUserService_ReturnsUsers() async throws {
        // Given: MockUserService 직접 사용
        _ = UnifiedDI.register(UserService.self) {
            MockUserService()
        }

        // When
        let userService = UnifiedDI.resolve(UserService.self)!
        let users = try await userService.getUsers()

        // Then
        XCTAssertEqual(users.count, 2, "Mock 사용자는 2명이어야 합니다")
        XCTAssertEqual(users[0].name, "Mock 사용자 1")
        XCTAssertEqual(users[1].name, "Mock 사용자 2")
    }

    func testUserService_GetUserById_ReturnsCorrectUser() async throws {
        // Given
        _ = UnifiedDI.register(UserService.self) {
            MockUserService()
        }

        // When
        let userService = UnifiedDI.resolve(UserService.self)!
        let user = try await userService.getUser(by: "1")

        // Then
        XCTAssertEqual(user.id, 1)
        XCTAssertEqual(user.name, "Mock 사용자 1")
    }

    func testUserService_WithFailingMock_ThrowsError() async {
        // Given: 실패하도록 설정된 Mock
        let mockUserService = MockUserService()
        mockUserService.shouldFailRequest = true

        _ = UnifiedDI.register(UserService.self) {
            mockUserService
        }

        // When & Then
        let userService = UnifiedDI.resolve(UserService.self)!

        do {
            _ = try await userService.getUsers()
            XCTFail("에러가 발생해야 합니다")
        } catch {
            XCTAssertTrue(error is UserServiceError)
        }
    }

    func testDependencyInjection_PropertyWrapper_Works() {
        // Given: 의존성 등록
        _ = UnifiedDI.register(UserService.self) {
            MockUserService()
        }

        // When: Property Wrapper를 통한 주입 테스트
        class TestClass {
            @Inject var userService: UserService?

            func hasService() -> Bool {
                return userService != nil
            }
        }

        let testInstance = TestClass()

        // Then
        XCTAssertTrue(testInstance.hasService(), "Property Wrapper를 통한 주입이 성공해야 합니다")
    }
}