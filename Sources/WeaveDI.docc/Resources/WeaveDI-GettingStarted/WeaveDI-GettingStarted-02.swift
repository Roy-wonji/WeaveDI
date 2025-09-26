import Foundation
import WeaveDI
import SwiftUI

// MARK: - Property Wrapper로 의존성 주입

final class WelcomeController: Sendable {
    // @Inject로 의존성 주입 (옵셔널)
    @Inject private var greetingService: GreetingService?

    func welcomeUser(name: String) -> String {
        guard let service = greetingService else {
            return "서비스를 사용할 수 없습니다"
        }
        return service.greet(name: name)
    }

    func farewellUser(name: String) -> String {
        guard let service = greetingService else {
            return "서비스를 사용할 수 없습니다"
        }
        return service.farewell(name: name)
    }
}

// MARK: - 비즈니스 로직 분리

final class UserManager: Sendable {
    @Inject private var greetingService: GreetingService?

    func processUser(name: String, action: UserAction) -> String {
        guard let service = greetingService else {
            return "서비스 초기화 실패"
        }

        switch action {
        case .greet:
            return service.greet(name: name)
        case .farewell:
            return service.farewell(name: name)
        }
    }
}

enum UserAction {
    case greet
    case farewell
}

// MARK: - SwiftUI에서 사용하는 예제

struct WelcomeView: View {
    @Inject private var greetingService: GreetingService?
    @State private var userName = ""
    @State private var message = ""
    @State private var isGreeting = true

    var body: some View {
        VStack(spacing: 20) {
            TextField("이름을 입력하세요", text: $userName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Picker("액션", selection: $isGreeting) {
                Text("인사하기").tag(true)
                Text("작별하기").tag(false)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            Button(isGreeting ? "인사하기" : "작별하기") {
                processAction()
            }
            .disabled(userName.isEmpty)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)

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
            return
        }

        message = isGreeting
            ? service.greet(name: userName)
            : service.farewell(name: userName)
    }
}