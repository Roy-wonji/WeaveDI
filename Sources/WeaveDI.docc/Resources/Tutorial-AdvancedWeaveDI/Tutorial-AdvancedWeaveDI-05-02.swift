import Foundation
import WeaveDI
import LogMacro

// MARK: - Top Used Types

enum TopUsedTypesDemo {
    static func printTop() {
        let top = UnifiedDI.getTopUsedTypes()
        #logInfo("🏆 [Perf] top used: \(top)")
    }
}
