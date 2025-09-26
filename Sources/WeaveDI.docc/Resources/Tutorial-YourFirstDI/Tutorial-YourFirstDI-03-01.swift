import SwiftUI
import WeaveDI

@main
struct WeaveDIApp: App {

    init() {
        setupDependencies()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func setupDependencies() {
        // NetworkService 등록
        _ = UnifiedDI.register(NetworkService.self) {
            DefaultNetworkService()
        }

        // UserService 등록
        _ = UnifiedDI.register(UserService.self) {
            DefaultUserService()
        }

        print("✅ 모든 의존성이 성공적으로 등록되었습니다!")
    }
}