import Foundation
import WeaveDI

// MARK: - 첫 번째 의존성 주입 예제

/// 간단한 서비스 프로토콜
protocol GreetingService {
    func greet(name: String) -> String
}

/// 기본 구현
final class DefaultGreetingService: GreetingService {
    func greet(name: String) -> String {
        return "안녕하세요, \(name)님!"
    }
}

/// 의존성 주입을 사용하는 클래스
final class WelcomeViewController {
    @Inject var greetingService: GreetingService

    func showWelcome(for userName: String) {
        let message = greetingService.greet(name: userName)
        print(message)
    }
}

// MARK: - 설정 및 사용

/// 앱 초기화
final class AppSetup {
    static func configure() {
        // 의존성 등록
        DIContainer.shared.register(GreetingService.self) {
            DefaultGreetingService()
        }
    }
}

// 사용 예제
AppSetup.configure()

let welcomeVC = WelcomeViewController()
welcomeVC.showWelcome(for: "WeaveDI 사용자")
// 출력: "안녕하세요, WeaveDI 사용자님!"