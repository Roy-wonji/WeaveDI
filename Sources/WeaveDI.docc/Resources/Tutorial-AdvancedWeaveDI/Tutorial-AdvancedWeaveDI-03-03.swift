import Foundation
import WeaveDI
import LogMacro

// MARK: - 필수 해석/기본값 패턴

protocol Logger: Sendable { func info(_ m: String) }
struct ConsoleLogger: Logger { func info(_ m: String) { print(m) } }

enum ResolutionPatterns {
    static func requireOrDefault() {
        // 기본값 포함 해결 (항상 성공)
        let logger = UnifiedDI.resolve(Logger.self, default: ConsoleLogger())
        logger.info("hello")
    }
}
