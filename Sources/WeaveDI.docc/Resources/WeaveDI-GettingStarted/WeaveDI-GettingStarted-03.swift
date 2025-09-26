import Foundation
import WeaveDI
import SwiftUI

// MARK: - 앱 초기화 및 부트스트랩

// MARK: - SwiftUI App 설정

@main
struct WeaveDIDemoApp: App {
    init() {
        // 앱 시작 시 서비스 등록 및 부트스트랩
        Task {
            await setupDependencies()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func setupDependencies() async {
        // 동기 부트스트랩
        await DIContainer.bootstrap { container in
            // 기본 서비스들 등록
            container.register(GreetingService.self) {
                SimpleGreetingService()
            }

            // 로깅 서비스 등록
            container.register(LoggingService.self) {
                ConsoleLoggingService()
            }

            // 설정 서비스 등록
            container.register(ConfigService.self) {
                DefaultConfigService()
            }
        }
    }
}

// MARK: - 추가 서비스들

protocol LoggingService: Sendable {
    func log(message: String)
}

final class ConsoleLoggingService: LoggingService {
    func log(message: String) {
        print("📝 Log: \(message)")
    }
}

protocol ConfigService: Sendable {
    var appName: String { get }
    var version: String { get }
}

final class DefaultConfigService: ConfigService {
    let appName = "WeaveDI Demo"
    let version = "1.0.0"
}

// MARK: - UIKit AppDelegate 설정

#if canImport(UIKit)
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 앱 시작 시 의존성 설정
        Task {
            await setupDependencies()
            await setupUI()
        }
        return true
    }

    private func setupDependencies() async {
        await DIContainer.bootstrap { container in
            container.register(GreetingService.self) {
                SimpleGreetingService()
            }

            container.register(LoggingService.self) {
                ConsoleLoggingService()
            }
        }
    }

    @MainActor
    private func setupUI() {
        window = UIWindow(frame: UIScreen.main.bounds)
        let viewController = MainViewController()
        window?.rootViewController = viewController
        window?.makeKeyAndVisible()
    }
}

class MainViewController: UIViewController {
    @Inject private var greetingService: GreetingService?
    @Inject private var loggingService: LoggingService?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()

        // 서비스 사용 예제
        let message = greetingService?.greet(name: "UIKit 사용자") ?? "서비스 없음"
        loggingService?.log(message: message)
    }

    private func setupView() {
        view.backgroundColor = .systemBackground

        let label = UILabel()
        label.text = "WeaveDI UIKit Demo"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
#endif

// MARK: - SwiftUI 메인 뷰

struct ContentView: View {
    @Inject private var greetingService: GreetingService?
    @Inject private var loggingService: LoggingService?
    @Inject private var configService: ConfigService?

    var body: some View {
        VStack(spacing: 20) {
            Text(configService?.appName ?? "앱 이름 없음")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("버전: \(configService?.version ?? "알 수 없음")")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("인사 테스트") {
                testGreeting()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)

            WelcomeView()
        }
        .padding()
    }

    private func testGreeting() {
        let message = greetingService?.greet(name: "SwiftUI 사용자") ?? "서비스 없음"
        loggingService?.log(message: message)
    }
}

// MARK: - 비즈니스 로직 예제

final class BusinessLogic: Sendable {
    @Inject private var greetingService: GreetingService?
    @Inject private var loggingService: LoggingService?

    func processWelcome(userName: String) -> String {
        let message = greetingService?.greet(name: userName) ?? "서비스 사용 불가"
        loggingService?.log(message: "사용자 \(userName) 처리 완료")
        return message
    }

    func processFarewell(userName: String) -> String {
        let message = greetingService?.farewell(name: userName) ?? "서비스 사용 불가"
        loggingService?.log(message: "사용자 \(userName) 작별 처리 완료")
        return message
    }
}