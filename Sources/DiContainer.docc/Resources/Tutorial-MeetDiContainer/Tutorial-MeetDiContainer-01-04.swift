import SwiftUI
import DiContainer

@main
struct CounterApp: App {

    init() {
        setupDependencies()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func setupDependencies() {
        #logInfo("🚀 DiContainer 설정 시작...")

        // CounterService 등록
        _ = UnifiedDI.register(CounterService.self) {
            DefaultCounterService()
        }

        #logInfo("✅ 의존성 등록 완료!")
        #logInfo("📦 등록된 서비스:")
        #logInfo("   • CounterService")
    }
}