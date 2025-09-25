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
        print("🚀 DiContainer 설정 시작...")

        // 🔄 @Inject용: 싱글톤 등록 (같은 인스턴스 재사용)
        _ = UnifiedDI.register(CounterService.self) {
            DefaultCounterService()
        }

        // 🏭 @Factory용: 팩토리 등록 (매번 새 인스턴스)
        _ = UnifiedDI.register(LoggingService.self) {
            DefaultLoggingService()
        }

        print("✅ 의존성 등록 완료!")
        print("📦 등록된 서비스:")
        print("   • CounterService (싱글톤)")
        print("   • LoggingService (팩토리)")
        print("")
        print("🎯 차이점:")
        print("   • @Inject → 같은 CounterService 인스턴스 재사용")
        print("   • @Factory → 매번 새로운 LoggingService 생성")
    }
}