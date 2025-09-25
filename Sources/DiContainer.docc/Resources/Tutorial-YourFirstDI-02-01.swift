import Foundation

// MARK: - NetworkService Protocol

protocol NetworkService: Sendable {
    func fetchData(from endpoint: String) async throws -> Data
}

// MARK: - NetworkService Implementation

final class DefaultNetworkService: NetworkService {
    func fetchData(from endpoint: String) async throws -> Data {
        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NetworkError.invalidResponse
        }

        return data
    }
}

// MARK: - Network Errors

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다"
        case .invalidResponse:
            return "서버 응답이 올바르지 않습니다"
        case .noData:
            return "데이터가 없습니다"
        }
    }
}