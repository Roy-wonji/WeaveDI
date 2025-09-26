import Foundation
import WeaveDI
import LogMacro

// MARK: - Actor Hop: 제안 활용 (예시 가이드)

@MainActor
final class MainActorService: Sendable { func work() {} }

enum ActorSuggestionGuide {
    static func apply() async {
        let suggestions = await UnifiedDI.actorOptimizations
        #logInfo("💡 [Actor] suggestions count=\(suggestions.count)")
        // 실제 앱에서는 해당 타입을 MainActor로 보내거나, 호출 위치를 조정하는 식으로 반영합니다.
        let _ = MainActorService()
    }
}
