import Foundation
import DiContainer
import LogMacro

// MARK: - 운영 패턴 2: 로깅/모니터링

enum OpsLoggingDemo {
    static func demo() async {
        // 로그 레벨 설정 (운영 중 이슈만)
        UnifiedDI.setLogLevel(.errors)

        // 간단한 이벤트 로깅
        #logInfo("ℹ️ [Ops] start")
        #logWarning("⚠️ [Ops] suspicious latency")
        #logError("⛔ [Ops] error sample")
    }
}
