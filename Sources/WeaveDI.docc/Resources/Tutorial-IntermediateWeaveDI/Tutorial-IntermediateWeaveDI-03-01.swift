import WeaveDI
import Foundation

// 중급 03-01: 스코프 기반 사용 예 (화면/세션 단위)

struct UserSession: Sendable { let id: String }

// 화면/세션 등의 범위를 가지는 의존성은 스코프로 관리합니다.
// - 등록: DIAdvanced.Scope.registerScoped
// - 해제: DIAdvanced.Scope.releaseScope / releaseScoped
// - 해석: 일반 resolve처럼 사용
func exampleScopedUsage() async {
    let userID = "u123"

    // 1) 스코프 등록 (세션 범위)
    _ = DIAdvanced.Scope.registerScoped(UserSession.self, kind: .session, id: userID) {
        UserSession(id: userID)
    }

    // 2) 해석 (일반 resolve와 동일하게 사용)
    let session = DIContainer.live.resolve(UserSession.self)
    _ = session?.id

    // 3) 스코프 해제 (세션 종료 시)
    let removed = await DIAdvanced.Scope.releaseScope(.session, id: userID)
    _ = removed  // 제거된 개수
}

