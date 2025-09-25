import Foundation
import DiContainer
import LogMacro

// MARK: - Graph Changes (최근 변경 추적)

enum GraphChangeReader {
    static func show(limit: Int = 5) async {
        let changes = await UnifiedDI.getGraphChanges(limit: limit)
        for (ts, diff) in changes {
            #logInfo("🕒 [Graph] \(ts): \(diff)")
        }
    }
}
