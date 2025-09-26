import WeaveDI
import Foundation

// 중급 03-02: 스코프 해제와 리소스 정리 패턴

struct ScreenCache: Sendable { let key: String }

func exampleScopedCleanup() async {
    let screenId = "home"

    // 1) 스코프 등록 (화면 범위)
    _ = DIAdvanced.Scope.registerScoped(ScreenCache.self, scope: .screen) {
        ScreenCache(key: screenId)
    }

    // 2) 사용
    _ = DI.resolve(ScreenCache.self)

    // 3) 특정 타입만 해제
    let removedType = await DIAdvanced.Scope.releaseScoped(ScreenCache.self, kind: .screen, id: screenId)
    _ = removedType

    // 4) 범위 전체 해제 (화면 종료 시)
    let removedCount = await DIAdvanced.Scope.releaseScope(.screen, id: screenId)
    _ = removedCount
}

