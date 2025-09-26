import Foundation
import DiContainer
import LogMacro

// MARK: - Type Safety & Sendable Checks

enum TypeSafetyInspector {
    static func run() async {
        let issues = await UnifiedDI.typeSafetyIssues
        for (typeName, issue) in issues {
            #logWarning("🔒 [TypeSafety] Issue: \(typeName) -> \(issue)")
        }

        // Sendable 예시 등록
        struct SafeCache: Sendable { let id: String }
        _ = UnifiedDI.register(SafeCache.self) { SafeCache(id: "ok") }
    }
}
