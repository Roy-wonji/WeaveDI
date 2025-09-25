import Foundation
import DiContainer
import LogMacro

// MARK: - Actor Hop: Parallel Resolution + Suggestions

enum ActorHopMetrics {
    static func collect() async {
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
