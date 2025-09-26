import Foundation
import WeaveDI
import LogMacro

// MARK: - Auto Optimization 토글/로그 레벨 조회

enum PerfSwitches {
    static func toggle() async {
        UnifiedDI.setAutoOptimization(true)
        let level = await UnifiedDI.getLogLevel()
        #logInfo("📶 [Perf] log level=\(level)")
    }
}
