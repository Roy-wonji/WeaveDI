import WeaveDI
import Foundation

// 중급 02-01: 환경별 설정 (DEV/PROD 분기 등록 + resolve 예시)

protocol APIClient: Sendable { var baseURL: String { get } }
struct DevAPI: APIClient, Sendable { let baseURL = "https://dev.example.com" }
struct ProdAPI: APIClient, Sendable { let baseURL = "https://api.example.com" }

func exampleEnvironmentConfig(isProd: Bool) async {
    // 1) 앱 시작 시 부트스트랩으로 일괄 등록
    await DIContainer.bootstrap { c in
        if isProd {
            _ = c.register(APIClient.self) { ProdAPI() }
        } else {
            _ = c.register(APIClient.self) { DevAPI() }
        }
    }

    // 2) 해석 및 사용
    let client = DI.resolve(APIClient.self)
    _ = client?.baseURL // 실행 환경에 맞는 baseURL
}

