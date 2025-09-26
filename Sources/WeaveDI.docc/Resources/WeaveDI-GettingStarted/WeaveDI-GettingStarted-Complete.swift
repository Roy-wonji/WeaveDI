import Foundation
import WeaveDI
import SwiftUI

// MARK: - 1. 서비스 정의

protocol GreetingService: Sendable {
    func greet(name: String) -> String
    func farewell(name: String) -> String
}

final class SimpleGreetingService: GreetingService {
    func greet(name: String) -> String {
        return "안녕하세요, \(name)님!"
    }

    func farewell(name: String) -> String {
        return "안녕히 가세요, \(name)님!"
    }
}

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

// MARK: - 2. 서비스 등록 및 부트스트랩

extension DIContainer {
    static func setupDependencies() async {
        // 동기 부트스트랩으로 모든 서비스 등록
        await DIContainer.bootstrap { container in
            // 인사 서비스 등록
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

// MARK: - 3. Property Wrapper로 의존성 주입

final class WelcomeController: Sendable {
    // @Inject로 의존성 주입 (옵셔널)
    @Inject private var greetingService: GreetingService?
    @Inject private var loggingService: LoggingService?

    func welcomeUser(name: String) -> String {
        guard let service = greetingService else {
            return "서비스를 사용할 수 없습니다"
        }

        let message = service.greet(name: name)
        loggingService?.log(message: "사용자 \(name) 환영 처리 완료")
        return message
    }

    func farewellUser(name: String) -> String {
        guard let service = greetingService else {
            return "서비스를 사용할 수 없습니다"
        }

        let message = service.farewell(name: name)
        loggingService?.log(message: "사용자 \(name) 작별 처리 완료")
        return message
    }
}

// MARK: - 4. SwiftUI 앱 통합

@main
struct WeaveDIDemoApp: App {
    init() {
        // 앱 시작 시 의존성 설정
        Task {
            await DIContainer.setupDependencies()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @Inject private var greetingService: GreetingService?
    @Inject private var loggingService: LoggingService?
    @Inject private var configService: ConfigService?

    @State private var userName = ""
    @State private var message = ""
    @State private var isGreeting = true

    var body: some View {
        VStack(spacing: 20) {
            // 앱 정보
            Text(configService?.appName ?? "앱 이름 없음")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("버전: \(configService?.version ?? "알 수 없음")")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // 사용자 입력
            TextField("이름을 입력하세요", text: $userName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            // 액션 선택
            Picker("액션", selection: $isGreeting) {
                Text("인사하기").tag(true)
                Text("작별하기").tag(false)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            // 실행 버튼
            Button(isGreeting ? "인사하기" : "작별하기") {
                processAction()
            }
            .disabled(userName.isEmpty)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)

            // 결과 표시
            Text(message)
                .foregroundColor(.primary)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
    }

    private func processAction() {
        guard let service = greetingService else {
            message = "서비스를 사용할 수 없습니다"
            loggingService?.log(message: "서비스 사용 실패")
            return
        }

        message = isGreeting
            ? service.greet(name: userName)
            : service.farewell(name: userName)

        loggingService?.log(message: "사용자 액션 처리: \(isGreeting ? "인사" : "작별")")
    }
}

// MARK: - 5. UIKit 통합 예제

#if canImport(UIKit)
class MainViewController: UIViewController {
    @Inject private var greetingService: GreetingService?
    @Inject private var loggingService: LoggingService?
    @Inject private var configService: ConfigService?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()

        // 서비스 사용 예제
        testServices()
    }

    private func setupView() {
        view.backgroundColor = .systemBackground

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = configService?.appName ?? "WeaveDI Demo"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center

        let versionLabel = UILabel()
        versionLabel.text = "버전: \(configService?.version ?? "1.0.0")"
        versionLabel.font = .systemFont(ofSize: 16)
        versionLabel.textColor = .secondaryLabel
        versionLabel.textAlignment = .center

        let testButton = UIButton(type: .system)
        testButton.setTitle("서비스 테스트", for: .normal)
        testButton.backgroundColor = .systemBlue
        testButton.setTitleColor(.white, for: .normal)
        testButton.layer.cornerRadius = 8
        testButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        testButton.addTarget(self, action: #selector(testServices), for: .touchUpInside)

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(versionLabel)
        stackView.addArrangedSubview(testButton)

        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func testServices() {
        let message = greetingService?.greet(name: "UIKit 사용자") ?? "서비스 없음"
        loggingService?.log(message: "UIKit에서 서비스 테스트: \(message)")

        let alert = UIAlertController(title: "서비스 테스트", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}
#endif

// MARK: - 6. 비즈니스 로직 예제

final class BusinessLogic: Sendable {
    @Inject private var greetingService: GreetingService?
    @Inject private var loggingService: LoggingService?

    func processWelcome(userName: String) -> String {
        let message = greetingService?.greet(name: userName) ?? "서비스 사용 불가"
        loggingService?.log(message: "사용자 \(userName) 환영 처리 완료")
        return message
    }

    func processFarewell(userName: String) -> String {
        let message = greetingService?.farewell(name: userName) ?? "서비스 사용 불가"
        loggingService?.log(message: "사용자 \(userName) 작별 처리 완료")
        return message
    }
}

// MARK: - 사용 예제

func exampleUsage() async {
    // 1. 의존성 설정
    await DIContainer.setupDependencies()

    // 2. 직접 해결
    let service = UnifiedDI.resolve(GreetingService.self)
    let directMessage = service?.greet(name: "직접 사용자") ?? "서비스 없음"
    print("직접 해결: \(directMessage)")

    // 3. 컨트롤러를 통한 사용
    let controller = WelcomeController()
    let controllerMessage = controller.welcomeUser(name: "컨트롤러 사용자")
    print("컨트롤러 사용: \(controllerMessage)")

    // 4. 비즈니스 로직 사용
    let businessLogic = BusinessLogic()
    let businessMessage = businessLogic.processWelcome(userName: "비즈니스 사용자")
    print("비즈니스 로직: \(businessMessage)")
}