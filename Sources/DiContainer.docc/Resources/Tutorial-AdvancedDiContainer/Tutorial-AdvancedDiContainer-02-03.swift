import Foundation
import DiContainer
import LogMacro

// MARK: - Actor Hop: 대량 병렬 시뮬레이션

enum ActorHopStressTest {
    static func runParallelTasks() async {
        // 스트레스 대상 타입 등록
        struct ExpensiveService: Sendable {}
        _ = UnifiedDI.register(ExpensiveService.self) { ExpensiveService() }

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask { _ = UnifiedDI.resolve(ExpensiveService.self) }
            }
        }
        #logInfo("🏁 [Actor] stress test done")
    }
}
