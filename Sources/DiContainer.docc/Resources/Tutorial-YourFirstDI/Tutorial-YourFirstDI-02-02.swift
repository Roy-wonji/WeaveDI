import Foundation
import DiContainer

// MARK: - UserService Protocol

protocol UserService: Sendable {
    func getUsers() async throws -> [User]
    func getUser(by id: String) async throws -> User
}

// MARK: - UserService Implementation

final class DefaultUserService: UserService {
    @Inject private var networkService: NetworkService?

    private let baseURL = "https://jsonplaceholder.typicode.com"

    func getUsers() async throws -> [User] {
        guard let networkService else {
            throw UserServiceError.networkServiceUnavailable
        }

        let data = try await networkService.fetchData(from: "\(baseURL)/users")
        let users = try JSONDecoder().decode([User].self, from: data)
        return users
    }

    func getUser(by id: String) async throws -> User {
        guard let networkService else {
            throw UserServiceError.networkServiceUnavailable
        }

        let data = try await networkService.fetchData(from: "\(baseURL)/users/\(id)")
        let user = try JSONDecoder().decode(User.self, from: data)
        return user
    }
}

// MARK: - UserService Errors

enum UserServiceError: Error, LocalizedError {
    case networkServiceUnavailable
    case userNotFound

    var errorDescription: String? {
        switch self {
        case .networkServiceUnavailable:
            return "네트워크 서비스를 사용할 수 없습니다"
        case .userNotFound:
            return "사용자를 찾을 수 없습니다"
        }
    }
}