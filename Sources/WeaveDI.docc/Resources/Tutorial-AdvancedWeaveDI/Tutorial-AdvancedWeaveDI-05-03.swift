import Foundation
import WeaveDI
import LogMacro

// MARK: - 모니터링/최적화 리셋

enum MonitoringResetDemo {
    static func resetAll() async {
        await UnifiedDI.resetMonitoring()
        #logInfo("🧼 [Perf] monitoring reset")
    }
}
