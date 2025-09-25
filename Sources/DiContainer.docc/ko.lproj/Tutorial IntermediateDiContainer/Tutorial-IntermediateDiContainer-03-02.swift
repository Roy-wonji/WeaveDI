import Foundation
import DiContainer
import LogMacro

// MARK: - Scoped Cleanup (세션/요청 정리)

enum ScopedCleanupDemo {
    @MainActor
    static func run() async {
        // 현재 세션/요청 ID가 있다고 가정
        let sessionId = "user-123"
        let requestId = "req-456"

        // 스코프 컨텍스트 초기화/정리
        ScopeContext.shared.setCurrent(.session, id: sessionId)
        ScopeContext.shared.setCurrent(.request, id: requestId)

        // 세션/요청 스코프 해제 (리소스 정리)
        let releasedSession = await DIAdvanced.Scope.releaseScope(.session, id: sessionId)
        let releasedRequest = await DIAdvanced.Scope.releaseScope(.request, id: requestId)

        #logInfo("🧹 [Scope] released session: \(releasedSession), request: \(releasedRequest)")

        // 컨텍스트 클리어
        ScopeContext.shared.clear(.session)
        ScopeContext.shared.clear(.request)
    }
}
