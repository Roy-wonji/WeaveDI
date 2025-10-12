import Foundation
import LogMacro

/// DI 로깅 채널 - 로그 타입별 분류
public enum DILogChannel: String, CaseIterable, Sendable {
    case registration = "REG"      // 의존성 등록
    case resolution = "RES"        // 의존성 해결
    case optimization = "OPT"      // 성능 최적화
    case health = "HEALTH"         // 헬스체크
    case diagnostics = "DIAG"      // 진단
    case general = "GEN"           // 일반
    case error = "ERROR"           // 에러
    case performance = "PERF"      // 성능 측정
}

/// DI 로그 레벨
public enum DILogSeverity: String, CaseIterable, Comparable, Sendable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"

    public static func < (lhs: DILogSeverity, rhs: DILogSeverity) -> Bool {
        let order: [DILogSeverity] = [.debug, .info, .warning, .error]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

/// DI 로그 레벨 필터 설정
public enum DILogLevel: String, CaseIterable, Sendable {
    case all = "ALL"               // 모든 로그
    case registration = "REG"      // 등록 관련만
    case optimization = "OPT"      // 최적화 관련만
    case health = "HEALTH"         // 헬스체크만
    case errorsOnly = "ERROR"      // 에러만
    case off = "OFF"               // 로그 끄기
}

/// 향상된 DI 로거 - 환경 플래그 및 레벨별 제어 지원
public struct DILogger {

    /// 현재 로그 레벨 (환경 플래그로 제어) - Thread-safe
    private static let currentLogLevel: DILogLevel = {
        #if DEBUG && DI_MONITORING_ENABLED
        return .all
        #elseif DEBUG
        return .errorsOnly
        #else
        return .off
        #endif
    }()

    /// 현재 로그 심각도 임계값 - Thread-safe
    private static let severityThreshold: DILogSeverity = {
        #if DEBUG && DI_MONITORING_ENABLED
        return .debug
        #elseif DEBUG
        return .warning
        #else
        return .error
        #endif
    }()

    /// 동적 로그 레벨 설정을 위한 스레드 안전 저장소
    private static let runtimeConfigLock = NSLock()
    private static nonisolated(unsafe) var _runtimeLogLevel: DILogLevel?
    private static nonisolated(unsafe) var _runtimeSeverityThreshold: DILogSeverity?

    /// 로그 레벨 동적 설정
    public static func configure(level: DILogLevel, severityThreshold: DILogSeverity = .info) {
        runtimeConfigLock.lock()
        defer { runtimeConfigLock.unlock() }
        _runtimeLogLevel = level
        _runtimeSeverityThreshold = severityThreshold
    }

    /// 현재 설정된 로그 레벨 가져오기
    public static func getCurrentLogLevel() -> DILogLevel {
        runtimeConfigLock.lock()
        defer { runtimeConfigLock.unlock() }
        return _runtimeLogLevel ?? currentLogLevel
    }

    /// 현재 설정된 심각도 임계값 가져오기
    public static func getCurrentSeverityThreshold() -> DILogSeverity {
        runtimeConfigLock.lock()
        defer { runtimeConfigLock.unlock() }
        return _runtimeSeverityThreshold ?? severityThreshold
    }

    /// 설정 초기화 (기본값으로 복원)
    public static func resetToDefaults() {
        runtimeConfigLock.lock()
        defer { runtimeConfigLock.unlock() }
        _runtimeLogLevel = nil
        _runtimeSeverityThreshold = nil
    }

    /// 특정 채널과 심각도에서 로그를 출력할지 결정
    private static func shouldEmit(channel: DILogChannel, severity: DILogSeverity) -> Bool {
        // 런타임 설정 또는 기본 설정 사용
        runtimeConfigLock.lock()
        let logLevel = _runtimeLogLevel ?? currentLogLevel
        let threshold = _runtimeSeverityThreshold ?? severityThreshold
        runtimeConfigLock.unlock()

        // 심각도 체크
        guard severity >= threshold else { return false }

        // 레벨별 채널 필터링
        switch logLevel {
        case .all:
            return true
        case .registration:
            return channel == .registration || channel == .error
        case .optimization:
            return channel == .optimization || channel == .performance || channel == .error
        case .health:
            return channel == .health || channel == .diagnostics || channel == .error
        case .errorsOnly:
            return channel == .error || severity == .error
        case .off:
            return false
        }
    }

    /// 내부 로그 출력 함수
    private static func emit(
        _ severity: DILogSeverity,
        channel: DILogChannel,
        _ message: Any,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        _ arguments: [Any]
    ) {
        #if DEBUG || DI_MONITORING_ENABLED
        guard shouldEmit(channel: channel, severity: severity) else { return }

        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(timestamp)] [\(severity.rawValue)] [\(channel.rawValue)] \(fileName):\(line) \(function) - \(message)"

        switch severity {
        case .debug:
            Log.debug(logMessage)
        case .info:
            Log.info(logMessage)
        case .warning:
            // LogMacro에서 warning을 지원하지 않을 수 있으므로 info로 처리
            Log.info("⚠️ " + logMessage)
        case .error:
            Log.error(logMessage)
        }
        #endif
    }

    // MARK: - Public Logging Methods

    public static func debug(
        channel: DILogChannel = .general,
        _ message: Any,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        _ arguments: Any...
    ) {
        emit(.debug, channel: channel, message, file: file, function: function, line: line, arguments)
    }

    public static func info(
        channel: DILogChannel = .general,
        _ message: Any,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        _ arguments: Any...
    ) {
        emit(.info, channel: channel, message, file: file, function: function, line: line, arguments)
    }

    public static func warning(
        channel: DILogChannel = .general,
        _ message: Any,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        _ arguments: Any...
    ) {
        emit(.warning, channel: channel, message, file: file, function: function, line: line, arguments)
    }

    public static func error(
        channels: [DILogChannel] = [.error],
        _ message: Any,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        _ arguments: Any...
    ) {
        for channel in channels {
            emit(.error, channel: channel, message, file: file, function: function, line: line, arguments)
        }
    }

    // MARK: - Specialized Logging Methods

    /// 의존성 등록 로그
    public static func logRegistration<T>(
        type: T.Type,
        success: Bool,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let message = success ?
            "Successfully registered \(String(describing: type))" :
            "Failed to register \(String(describing: type))"
        let severity: DILogSeverity = success ? .info : .error

        emit(severity, channel: .registration, message, file: file, function: function, line: line, [])
    }

    /// 의존성 해결 로그
    public static func logResolution<T>(
        type: T.Type,
        success: Bool,
        duration: TimeInterval? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var message = success ?
            "Successfully resolved \(String(describing: type))" :
            "Failed to resolve \(String(describing: type))"

        if let duration = duration {
            message += " (took \(String(format: "%.2f", duration * 1000))ms)"
        }

        let severity: DILogSeverity = success ? .info : .error
        let channel: DILogChannel = duration != nil ? .performance : .resolution

        emit(severity, channel: channel, message, file: file, function: function, line: line, [])
    }

    /// 성능 측정 로그
    public static func logPerformance(
        operation: String,
        duration: TimeInterval,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let message = "\(operation) completed in \(String(format: "%.2f", duration * 1000))ms"
        emit(.info, channel: .performance, message, file: file, function: function, line: line, [])
    }

    /// 헬스체크 로그
    public static func logHealth(
        component: String,
        status: Bool,
        details: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var message = "\(component) health check: \(status ? "PASS" : "FAIL")"
        if let details = details {
            message += " - \(details)"
        }

        let severity: DILogSeverity = status ? .info : .warning
        emit(severity, channel: .health, message, file: file, function: function, line: line, [])
    }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
