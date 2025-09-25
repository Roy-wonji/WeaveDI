import Foundation
import LogMacro

// MARK: - LoggingService Protocol

protocol LoggingService: Sendable {
    var sessionId: String { get }
    func logAction(_ action: String)
    func logInfo(_ message: String)
}

// MARK: - LoggingService Implementation

final class DefaultLoggingService: LoggingService {
    let sessionId: String

    init() {
        // 매번 새로운 세션 ID 생성 (Factory 패턴의 핵심!)
        self.sessionId = UUID().uuidString.prefix(8).uppercased().description
        #logInfo("📝 [LoggingService] 새 세션 시작: \(sessionId)")
    }

    func logAction(_ action: String) {
        #logInfo("📝 [\(sessionId)] ACTION: \(action)")
    }

    func logInfo(_ message: String) {
        #logInfo("📝 [\(sessionId)] INFO: \(message)")
    }
}