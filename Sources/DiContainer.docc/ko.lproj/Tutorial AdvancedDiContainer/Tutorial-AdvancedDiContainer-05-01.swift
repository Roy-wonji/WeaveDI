import Foundation
import DiContainer
import LogMacro

// MARK: - 요약/모듈 보기

enum AdvancedSummary {
    static func show() async {
        let text = await UnifiedDI.summary()
        #logInfo("📄 [Summary]\n\(text)")
        await UnifiedDI.showModules()
    }
}
