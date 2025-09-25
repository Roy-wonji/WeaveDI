import Foundation
import DiContainer
import LogMacro

// MARK: - 테스트 시나리오: 스냅샷/통계 확인

enum TestScenariosDemo {
    static func verifyStats() {
        let stats = UnifiedDI.stats()
        #logInfo("📊 [Test] usage stats: \(stats)")
    }
}
