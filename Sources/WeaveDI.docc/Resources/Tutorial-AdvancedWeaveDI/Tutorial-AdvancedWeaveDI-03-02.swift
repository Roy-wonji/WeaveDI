import Foundation
import WeaveDI
import LogMacro

// MARK: - Sendable 충족/검증

final class NonSendableCache { let id = UUID() }
struct WrappedCache: Sendable { let id: String }

enum SendableGuide {
    static func migrate() {
        // 비-Sendable 타입을 포장하여 Sendable로 노출하는 패턴
        let wrapped = WrappedCache(id: "cache-1")
        #logInfo("🔒 [Sendable] wrapped=\(wrapped.id)")
    }
}
