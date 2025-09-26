import Foundation
import WeaveDI
import LogMacro

// MARK: - Actor Hop: Parallel Resolution + Suggestions

enum ActorHopMetrics {
    static func collect() async {
        // 샘플 타입 등록 (병렬 해석 대상)
        struct SessionStore: Sendable { let id = UUID() }
        _ = UnifiedDI.register(SessionStore.self) { SessionStore() }

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    _ = UnifiedDI.resolve(SessionStore.self)
                }
            }
        }

        let hopStats = await UnifiedDI.actorHopStats
        let suggestions = await UnifiedDI.actorOptimizations

        #logInfo("🎯 [Actor] HopStats: \(hopStats)")
        #logInfo("💡 [Actor] Suggestions: \(suggestions)")
    }
}
