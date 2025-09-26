import Foundation
import WeaveDI
import LogMacro

// MARK: - Performance Configuration (Debounce / Log Level)

enum PerformanceTuning {
    static func configure() {
        UnifiedDI.configureOptimization(debounceMs: 100, threshold: 10, realTimeUpdate: false)
        UnifiedDI.setLogLevel(.optimization)
        #logInfo("⚙️ [Perf] Optimization configured (debounce=100ms, threshold=10, realtime=false)")
    }
}
