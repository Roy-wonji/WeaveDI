import SwiftUI
import WeaveDI

@main
struct CounterApp: App {

    init() {
        Task {
            await setupAppDIContainer()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    /// AppDIContainer를 활용한 체계적인 의존성 설정
    private func setupAppDIContainer() async {
        print("🚀 AppDIContainer 설정 시작...")

        // AppDIContainer의 의존성 등록 메서드 사용
        let appContainer = AppDIContainer.shared

        await appContainer.registerDependencies { container in
            print("📦 Clean Architecture 계층별 의존성 등록 중...")

            // 🏗️ Repository Layer (Data Layer)
            container.register(CounterRepository.self) {
                UserDefaultsCounterRepository()
            }

            // 🔧 Service Layer
            container.register(CounterService.self) {
                DefaultCounterService()
            }

            container.register(LoggingService.self) {
                DefaultLoggingService()
            }

            container.register(NetworkService.self) {
                DefaultNetworkService()
            }

            // 🎯 UseCase Layer (Business Logic)
            container.register(CounterUseCase.self) {
                DefaultCounterUseCase()
            }

            print("✅ 모든 의존성 등록 완료!")
        }

        print("🏛️ Clean Architecture 구조:")
        print("   ┌─────────────────┐")
        print("   │  Presentation   │ ← ContentView")
        print("   └─────────────────┘")
        print("           │")
        print("   ┌─────────────────┐")
        print("   │   Use Cases     │ ← CounterUseCase")
        print("   └─────────────────┘")
        print("           │")
        print("   ┌─────────────────┐")
        print("   │  Repositories   │ ← CounterRepository")
        print("   └─────────────────┘")
        print("           │")
        print("   ┌─────────────────┐")
        print("   │   Services      │ ← CounterService, LoggingService")
        print("   └─────────────────┘")
        print("")
        print("🎯 Property Wrapper 역할:")
        print("   • @Inject → 계층간 의존성 주입")
        print("   • @Factory → 매번 새로운 로거 생성")
        print("   • @SafeInject → 안전한 네트워크 처리")
    }
}