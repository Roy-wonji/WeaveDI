import Foundation
import LogMacro

/// 간단한 모듈 생명주기 관리자
public actor SimpleLifecycleManager {

    public static let shared = SimpleLifecycleManager()

    /// 모듈 상태
    public enum ModuleState: String, Sendable {
        case stopped = "stopped"
        case running = "running"
        case error = "error"
    }

    /// 모듈 상태 정보
    public struct ModuleStatus: Sendable {
        public let moduleId: String
        public let state: ModuleState
        public let startTime: Date?
        public let errorMessage: String?

        public init(moduleId: String, state: ModuleState, startTime: Date? = nil, errorMessage: String? = nil) {
            self.moduleId = moduleId
            self.state = state
            self.startTime = startTime
            self.errorMessage = errorMessage
        }
    }

    /// 시스템 건강 상태
    public struct SystemHealth: Sendable {
        public enum Status: String, Sendable {
            case healthy = "healthy"
            case degraded = "degraded"
            case unhealthy = "unhealthy"
        }

        public let status: Status
        public let totalModules: Int
        public let runningModules: Int
        public let errorModules: Int
        public let uptime: TimeInterval

        public init(status: Status, totalModules: Int, runningModules: Int, errorModules: Int, uptime: TimeInterval) {
            self.status = status
            self.totalModules = totalModules
            self.runningModules = runningModules
            self.errorModules = errorModules
            self.uptime = uptime
        }
    }

    private var moduleStates: [String: ModuleStatus] = [:]
    private let coreModules = [
        "OptimizationConfig",
        "PerformanceMonitor",
        "ErrorHandlingSystem",
        "InterModuleCommunicationOptimizer",
        "GraphOptimizer",
        "DiffTracker"
    ]

    private init() {
        // 기본 모듈 상태 초기화
        for moduleId in coreModules {
            moduleStates[moduleId] = ModuleStatus(moduleId: moduleId, state: .stopped)
        }
    }

    /// 특정 모듈 시작
    public func startModule(_ moduleId: String) throws {
        guard moduleStates[moduleId] != nil else {
            throw LifecycleError.moduleNotRegistered(moduleId)
        }

        moduleStates[moduleId] = ModuleStatus(
            moduleId: moduleId,
            state: .running,
            startTime: Date()
        )

        #logInfo("✅ 모듈 시작됨: \(moduleId)")
    }

    /// 특정 모듈 중지
    public func stopModule(_ moduleId: String) throws {
        guard moduleStates[moduleId] != nil else {
            throw LifecycleError.moduleNotRegistered(moduleId)
        }

        moduleStates[moduleId] = ModuleStatus(moduleId: moduleId, state: .stopped)
        #logInfo("🛑 모듈 중지됨: \(moduleId)")
    }

    /// 특정 모듈 재시작
    public func restartModule(_ moduleId: String) throws {
        try stopModule(moduleId)
        try startModule(moduleId)
        #logInfo("♻️ 모듈 재시작됨: \(moduleId)")
    }

    /// 모든 모듈 상태 조회
    public func getAllModuleStates() -> [String: ModuleStatus] {
        return moduleStates
    }

    /// 시스템 건강 상태 조회
    public func getSystemHealth() -> SystemHealth {
        let total = moduleStates.count
        let running = moduleStates.values.filter { $0.state == .running }.count
        let errors = moduleStates.values.filter { $0.state == .error }.count

        let status: SystemHealth.Status
        if errors > 0 {
            status = .unhealthy
        } else if running == total {
            status = .healthy
        } else {
            status = .degraded
        }

        let startTimes = moduleStates.values.compactMap { $0.startTime }
        let uptime = startTimes.isEmpty ? 0 : Date().timeIntervalSince(startTimes.min()!)

        return SystemHealth(
            status: status,
            totalModules: total,
            runningModules: running,
            errorModules: errors,
            uptime: uptime
        )
    }

    /// 활성 모듈 목록 조회
    public func getActiveModules() -> [String] {
        return moduleStates.compactMap { key, value in
            value.state == .running ? key : nil
        }
    }

    /// 에러 모듈 목록 조회
    public func getErrorModules() -> [String: String] {
        return moduleStates.compactMap { key, value in
            if value.state == .error, let errorMessage = value.errorMessage {
                return (key, errorMessage)
            }
            return nil
        }.reduce(into: [String: String]()) { result, pair in
            result[pair.0] = pair.1
        }
    }
}

/// 생명주기 관련 에러
public enum LifecycleError: Error, Sendable {
    case moduleNotRegistered(String)
    case invalidStateTransition(String)

    public var localizedDescription: String {
        switch self {
        case .moduleNotRegistered(let moduleId):
            return "Module '\(moduleId)' is not registered"
        case .invalidStateTransition(let moduleId):
            return "Invalid state transition for module '\(moduleId)'"
        }
    }
}