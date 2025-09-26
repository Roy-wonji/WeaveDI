import WeaveDI
import Foundation

// 중급 05-01: 테스트용 사전 등록/Mock 패턴 (사용 예)

protocol UserRepository: Sendable { func user(id: String) -> String }
struct MockUserRepository: UserRepository, Sendable { func user(id: String) -> String { "mock-\(id)" } }

// 테스트 setUp()에서 호출한다고 가정한 예시
func testSetup_registerMocks() async {
    await DIContainer.bootstrap { c in
        _ = c.register(UserRepository.self) { MockUserRepository() }
    }

    let repo = DI.resolve(UserRepository.self)
    _ = repo?.user(id: "1") // "mock-1"
}

