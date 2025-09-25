import Foundation
import DiContainer
import LogMacro

// MARK: - Auto Optimization: Stats / Graph / Optimized Types

/// 자동 최적화로 수집된 통계/그래프/최적화 타입 확인 예제
enum AutoOptimizationShowcase {
    static func printOverview() {
        let stats = UnifiedDI.stats()
        let graph = UnifiedDI.autoGraph()
        let optimized = UnifiedDI.optimizedTypes()

        #logInfo("📊 [AutoDI] Stats: \(stats)")
        #logInfo("🗺️ [AutoDI] Graph:\n\(graph)")
        #logInfo("⚡ [AutoDI] Optimized: \(optimized)")
    }
}
