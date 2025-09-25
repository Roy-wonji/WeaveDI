import Foundation
import DiContainer
import LogMacro

// MARK: - Optimized Check (특정 타입 최적화 여부)

struct ExpensiveService: Sendable {}

enum OptimizedCheckDemo {
    static func check() {
        let ok = UnifiedDI.isOptimized(ExpensiveService.self)
        #logInfo("⚡ [Optimized] ExpensiveService optimized? \(ok)")
    }
}
