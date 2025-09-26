import SwiftUI
import WeaveDI

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
        print("🚀 WeaveDI 설정 시작...")

        // 🔄 @Inject용: 싱글톤 등록
        _ = UnifiedDI.register(CounterService.self) {
            DefaultCounterService()
        }

        // 🏭 @Factory용: 팩토리 등록
        _ = UnifiedDI.register(LoggingService.self) {
            DefaultLoggingService()
        }

        // 🛡️ @SafeInject용: 네트워크 서비스 등록 (실패 시뮬레이션)
        // 의도적으로 등록하지 않아서 SafeInject의 에러 처리 확인
        // _ = UnifiedDI.register(NetworkService.self) {
        //     DefaultNetworkService()
        // }

        print("✅ 의존성 등록 완료!")
        print("📦 등록된 서비스:")
        print("   • CounterService (싱글톤)")
        print("   • LoggingService (팩토리)")
        print("   ⚠️ NetworkService (등록하지 않음 - SafeInject 테스트용)")
        print("")
        print("🎯 Property Wrapper 차이점:")
        print("   • @Inject → fatalError 시 앱 크래시")
        print("   • @Factory → 매번 새 인스턴스 생성")
        print("   • @SafeInject → 에러를 안전하게 처리")
        print("")
        print("💡 NetworkService가 없어도 SafeInject로 안전하게 처리됩니다!")
    }
}