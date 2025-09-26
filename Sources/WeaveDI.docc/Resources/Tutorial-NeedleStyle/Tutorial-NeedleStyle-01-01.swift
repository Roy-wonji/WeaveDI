// WeaveDI vs Needle 비교

/*
 🏆 WeaveDI가 Needle보다 우수한 점들:

 ✅ 컴파일타임 안전성: 동등 (매크로 vs 코드 생성)
 🚀 런타임 성능: WeaveDI 우승 (제로 코스트 + Actor 최적화)
 🎯 Swift 6 지원: WeaveDI 독점 (완벽 네이티브)
 🛠️ 코드 생성: WeaveDI 우승 (선택적 vs 필수)
 📚 학습 곡선: WeaveDI 우승 (점진적 vs 가파름)
 🔄 마이그레이션: WeaveDI 우승 (점진적 vs All-or-nothing)
*/

import WeaveDI

// Needle의 복잡한 Component 정의
/*
// Needle 방식 (복잡함)
import NeedleFoundation

class AppComponent: Component<EmptyDependency> {
    var userService: UserServiceProtocol {
        return UserServiceImpl(networkService: networkService)
    }

    var networkService: NetworkServiceProtocol {
        return NetworkServiceImpl(logger: logger)
    }

    var logger: LoggerProtocol {
        return ConsoleLogger()
    }
}
*/

// WeaveDI 방식 (간단함)
extension UnifiedDI {
    static func setupApp() {
        // 훨씬 간단하고 직관적!
        _ = register(LoggerProtocol.self) { ConsoleLogger() }
        _ = register(NetworkServiceProtocol.self) { NetworkServiceImpl() }
        _ = register(UserServiceProtocol.self) { UserServiceImpl() }

        // Needle 수준 성능 활성화
        enableStaticOptimization()

        // 컴파일타임 검증 (Needle과 동등한 안전성)
        validateNeedleStyle(
            component: AppComponent.self,
            dependencies: [LoggerProtocol.self, NetworkServiceProtocol.self, UserServiceProtocol.self]
        )
    }
}

// 프로토콜 정의
protocol LoggerProtocol: Sendable {
    func log(_ message: String)
}

protocol NetworkServiceProtocol: Sendable {
    func request(url: String) async -> String
}

protocol UserServiceProtocol: Sendable {
    func getUser(id: String) async -> User?
}

// 구현체
class ConsoleLogger: LoggerProtocol {
    func log(_ message: String) {
        print("📝 \(message)")
    }
}

class NetworkServiceImpl: NetworkServiceProtocol {
    func request(url: String) async -> String {
        return "Response from \(url)"
    }
}

class UserServiceImpl: UserServiceProtocol {
    func getUser(id: String) async -> User? {
        return User(id: id, name: "Sample User")
    }
}

struct User: Sendable {
    let id: String
    let name: String
}

// 임시 타입 (Needle 호환성을 위해)
struct AppComponent {}