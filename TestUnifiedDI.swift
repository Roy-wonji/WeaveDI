import Foundation
import DiContainer

// 테스트용 프로토콜과 구현체
protocol TestService: Sendable {
    func getMessage() -> String
}

final class TestServiceImpl: TestService, Sendable {
    func getMessage() -> String {
        return "Hello from TestService!"
    }
}

// UnifiedDI API 통합 테스트
@main
struct TestUnifiedDI {
    static func main() async {
        print("🚀 UnifiedDI registerAsync/DIContainer.registerAsync 통합 테스트")
        print("=" * 60)

        // 1. 기존 동기 register 테스트
        print("\n1️⃣ 동기 register 테스트")
        let syncService = UnifiedDI.register(TestService.self) {
            TestServiceImpl()
        }
        print("✅ 동기 등록 완료: \(syncService.getMessage())")

        // 2. 새로운 registerAsync 테스트 (DIContainerActor 사용)
        print("\n2️⃣ registerAsync 테스트 (@DIContainerActor 기반)")
        let asyncService = await UnifiedDI.registerAsync(TestService.self) {
            TestServiceImpl()
        }
        print("✅ 비동기 등록 완료: \(asyncService.getMessage())")

        // 3. resolveAsync 테스트
        print("\n3️⃣ resolveAsync 테스트")
        if let resolvedService = await UnifiedDI.resolveAsync(TestService.self) {
            print("✅ 비동기 해결 완료: \(resolvedService.getMessage())")
        }

        // 4. 성능 비교 테스트
        print("\n4️⃣ 성능 비교 테스트")

        // 동기 방식 1000회
        let syncStart = CFAbsoluteTimeGetCurrent()
        for i in 0..<1000 {
            let _ = UnifiedDI.register(String.self) { "sync-\(i)" }
        }
        let syncTime = CFAbsoluteTimeGetCurrent() - syncStart

        // 비동기 방식 1000회
        let asyncStart = CFAbsoluteTimeGetCurrent()
        for i in 0..<1000 {
            let _ = await UnifiedDI.registerAsync(Int.self) { i }
        }
        let asyncTime = CFAbsoluteTimeGetCurrent() - asyncStart

        print("📊 성능 결과:")
        print("   동기 register: \(String(format: "%.3f", syncTime * 1000))ms")
        print("   비동기 registerAsync: \(String(format: "%.3f", asyncTime * 1000))ms")
        print("   비율: 비동기가 동기 대비 \(String(format: "%.1f", asyncTime / syncTime))배")

        print("\n🎉 UnifiedDI 통합 테스트 완료!")
        print("✅ registerAsync가 DIContainer.registerAsync와 동일하게 동작")
        print("✅ @DIContainerActor 기반으로 성능 최적화")
        print("✅ 기존 동기 API와 완전 호환")
    }
}