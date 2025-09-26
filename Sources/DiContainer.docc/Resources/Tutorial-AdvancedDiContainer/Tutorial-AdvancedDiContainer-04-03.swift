import Foundation
import DiContainer
import LogMacro

// MARK: - 상위 사용 타입/제안 요약

enum PerfInsights {
    static func topUsed() -> [String] { UnifiedDI.getTopUsedTypes() }
    static func suggestions() -> [String] { UnifiedDI.getOptimizationTips() }
}
