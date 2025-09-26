import Foundation

// MARK: - Mock NetworkService

final class MockNetworkService: NetworkService {
    var shouldFailRequest = false
    var mockData: Data?

    func fetchData(from endpoint: String) async throws -> Data {
        if shouldFailRequest {
            throw NetworkError.invalidResponse
        }

        if let mockData {
            return mockData
        }

        // Mock User 데이터 반환
        let mockUsers = [
            User(
                id: 1,
                name: "테스트 사용자",
                username: "testuser",
                email: "test@example.com",
                phone: "010-1234-5678",
                website: "test.com",
                company: Company(
                    name: "테스트 회사",
                    catchPhrase: "테스트 구호",
                    bs: "테스트 비즈니스"
                ),
                address: Address(
                    street: "테스트 거리",
                    suite: "101호",
                    city: "서울",
                    zipcode: "12345",
                    geo: Geo(lat: "37.5665", lng: "126.9780")
                )
            )
        ]

        return try JSONEncoder().encode(mockUsers)
    }
}

// MARK: - Mock UserService

final class MockUserService: UserService {
    var shouldFailRequest = false
    var mockUsers: [User] = []

    func getUsers() async throws -> [User] {
        if shouldFailRequest {
            throw UserServiceError.userNotFound
        }

        if mockUsers.isEmpty {
            return [
                User(
                    id: 1,
                    name: "Mock 사용자 1",
                    username: "mock1",
                    email: "mock1@example.com",
                    phone: "010-0000-0001",
                    website: "mock1.com",
                    company: Company(
                        name: "Mock 회사 1",
                        catchPhrase: "Mock 구호 1",
                        bs: "Mock 비즈니스 1"
                    ),
                    address: Address(
                        street: "Mock 거리 1",
                        suite: "101호",
                        city: "서울",
                        zipcode: "12345",
                        geo: Geo(lat: "37.5665", lng: "126.9780")
                    )
                ),
                User(
                    id: 2,
                    name: "Mock 사용자 2",
                    username: "mock2",
                    email: "mock2@example.com",
                    phone: "010-0000-0002",
                    website: "mock2.com",
                    company: Company(
                        name: "Mock 회사 2",
                        catchPhrase: "Mock 구호 2",
                        bs: "Mock 비즈니스 2"
                    ),
                    address: Address(
                        street: "Mock 거리 2",
                        suite: "202호",
                        city: "부산",
                        zipcode: "54321",
                        geo: Geo(lat: "35.1796", lng: "129.0756")
                    )
                )
            ]
        }

        return mockUsers
    }

    func getUser(by id: String) async throws -> User {
        let users = try await getUsers()
        guard let user = users.first(where: { "\($0.id)" == id }) else {
            throw UserServiceError.userNotFound
        }
        return user
    }
}