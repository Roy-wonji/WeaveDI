import Foundation
import WeaveDI
import LogMacro

// MARK: - Auto Optimization: Stats / Graph / Optimized Types

/// 자동 최적화로 수집된 통계/그래프/최적화 타입 확인 예제
enum AutoOptimizationShowcase {
    static func printOverview() {
        // 샘플 데이터 생성: 간단 타입 등록/해석으로 통계/그래프가 비지 않도록 함
        struct ServiceA: Sendable {}
        struct ServiceB: Sendable {}
        _ = UnifiedDI.register(ServiceA.self) { ServiceA() }
        _ = UnifiedDI.register(ServiceB.self) { ServiceB() }
        for _ in 0..<5 { _ = UnifiedDI.resolve(ServiceA.self) }
        for _ in 0..<3 { _ = UnifiedDI.resolve(ServiceB.self) }

        let stats = UnifiedDI.stats()
        let graph = UnifiedDI.autoGraph()
        let optimized = UnifiedDI.optimizedTypes()

        #logInfo("📊 [AutoDI] Stats: \(stats)")
        #logInfo("🗺️ [AutoDI] Graph:\n\(graph)")
        #logInfo("⚡ [AutoDI] Optimized: \(optimized)")
    }
}
