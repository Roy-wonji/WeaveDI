import Foundation

// MARK: - NetworkService Protocol

protocol NetworkService: Sendable {
    var isConnected: Bool { get }
    func checkConnection() async -> Bool
    func uploadData(_ data: String) async throws -> String
}

// MARK: - NetworkService Implementation

final class DefaultNetworkService: NetworkService {
    private var _isConnected = false

    var isConnected: Bool {
        return _isConnected
    }

    func checkConnection() async -> Bool {
        print("🌐 [NetworkService] 네트워크 연결 확인 중...")

        // 실제로는 네트워크 상태를 확인하지만, 여기서는 시뮬레이션
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1초 대기

        // 랜덤하게 연결 상태 결정 (실패 시뮬레이션)
        _isConnected = Bool.random()

        print("🌐 [NetworkService] 연결 상태: \(_isConnected ? "연결됨" : "연결 실패")")
        return _isConnected
    }

    func uploadData(_ data: String) async throws -> String {
        guard isConnected else {
            throw NetworkError.notConnected
        }

        print("🌐 [NetworkService] 데이터 업로드 중: \(data)")
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5초 대기

        let result = "업로드 성공: \(data) (\(Date().timeIntervalSince1970))"
        print("🌐 [NetworkService] \(result)")
        return result
    }
}

// MARK: - Network Errors

enum NetworkError: Error, LocalizedError {
    case notConnected
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "네트워크에 연결되지 않았습니다"
        case .uploadFailed:
            return "데이터 업로드에 실패했습니다"
        }
    }
}