//
//  PluginSystem.swift
//  DiContainer
//
//  Created by Claude on 2025-09-14.
//

import Foundation
import LogMacro

// MARK: - Plugin System Architecture

/// 확장 가능한 플러그인 시스템의 핵심 인터페이스
///
/// ## 개요
///
/// DiContainer의 플러그인 시스템은 런타임에 기능을 동적으로 추가할 수 있는
/// 확장 가능한 아키텍처를 제공합니다.
///
/// ## 지원하는 플러그인 타입:
/// - **Registration Plugins**: 의존성 등록 로직 확장
/// - **Resolution Plugins**: 의존성 해결 로직 확장
/// - **Lifecycle Plugins**: 컨테이너 생명주기 훅
/// - **Validation Plugins**: 등록/해결 검증 로직
/// - **Monitoring Plugins**: 성능 모니터링 및 로깅
///
/// ## 사용 예시:
///
/// ```swift
/// // 플러그인 등록
/// let loggingPlugin = LoggingPlugin()
/// PluginManager.shared.register(loggingPlugin)
///
/// // 자동 스캔 플러그인
/// let autoScanPlugin = AutoScanPlugin(packages: ["com.myapp"])
/// PluginManager.shared.register(autoScanPlugin)
/// ```

// MARK: - Base Plugin Protocol

/// 모든 플러그인이 구현해야 하는 기본 인터페이스
public protocol Plugin: Sendable {
    /// 플러그인의 고유 식별자
    var identifier: String { get }

    /// 플러그인의 버전
    var version: String { get }

    /// 플러그인에 대한 설명
    var description: String { get }

    /// 플러그인의 우선순위 (낮을수록 먼저 실행)
    var priority: Int { get }

    /// 플러그인 활성화
    func activate() async throws

    /// 플러그인 비활성화
    func deactivate() async throws

    /// 플러그인 상태 확인
    var isActive: Bool { get }
}

// MARK: - Specialized Plugin Protocols

/// 의존성 등록 과정에 개입하는 플러그인
public protocol RegistrationPlugin: Plugin {
    /// 등록 전 훅
    func beforeRegistration<T>(_ type: T.Type, factory: @Sendable @escaping () -> T) async throws

    /// 등록 후 훅
    func afterRegistration<T>(_ type: T.Type, instance: T) async throws

    /// 등록 실패 훅
    func onRegistrationFailure<T>(_ type: T.Type, error: Error) async throws
}

/// 의존성 해결 과정에 개입하는 플러그인
public protocol ResolutionPlugin: Plugin {
    /// 해결 전 훅
    func beforeResolution<T>(_ type: T.Type) async throws

    /// 해결 후 훅
    func afterResolution<T>(_ type: T.Type, instance: T?) async throws

    /// 해결 실패 훅
    func onResolutionFailure<T>(_ type: T.Type, error: Error) async throws
}

/// 컨테이너 생명주기에 개입하는 플러그인
public protocol LifecyclePlugin: Plugin {
    /// 컨테이너 초기화 후 훅
    func onContainerInitialized() async throws

    /// 컨테이너 재설정 전 훅
    func beforeContainerReset() async throws

    /// 컨테이너 재설정 후 훅
    func afterContainerReset() async throws

    /// 컨테이너 해제 전 훅
    func beforeContainerDestroy() async throws
}

/// 검증 로직을 제공하는 플러그인
public protocol ValidationPlugin: Plugin {
    /// 등록 검증
    func validateRegistration<T>(_ type: T.Type, factory: @Sendable @escaping () -> T) async throws -> Bool

    /// 해결 검증
    func validateResolution<T>(_ type: T.Type, instance: T?) async throws -> Bool
}

/// 모니터링 및 메트릭스 플러그인
public protocol MonitoringPlugin: Plugin {
    /// 이벤트 기록
    func recordEvent(_ event: PluginEvent) async

    /// 메트릭스 수집
    func collectMetrics() async -> [String: String]

    /// 상태 리포트 생성
    func generateStatusReport() async -> PluginStatusReport
}

// MARK: - Plugin Events

public struct PluginEvent: Sendable {
    public let timestamp: Date
    public let type: EventType
    public let details: [String: String] // Changed to Sendable type
    public let source: String

    public enum EventType: String, Sendable {
        case registration = "registration"
        case resolution = "resolution"
        case lifecycle = "lifecycle"
        case validation = "validation"
        case error = "error"
    }

    public init(type: EventType, details: [String: String] = [:], source: String = "PluginSystem") {
        self.timestamp = Date()
        self.type = type
        self.details = details
        self.source = source
    }
}

public struct PluginStatusReport: Sendable {
    public let pluginId: String
    public let status: String
    public let metrics: [String: String] // Changed to Sendable type
    public let generatedAt: Date

    public init(pluginId: String, status: String, metrics: [String: String] = [:]) {
        self.pluginId = pluginId
        self.status = status
        self.metrics = metrics
        self.generatedAt = Date()
    }
}

// MARK: - Plugin Manager

/// 플러그인 시스템의 중앙 관리자
@MainActor
public final class PluginManager: ObservableObject {
    public static let shared = PluginManager()

    @Published public private(set) var registeredPlugins: [String: any Plugin] = [:]
    @Published public private(set) var activePlugins: Set<String> = []

    private var pluginHooks: PluginHooks = PluginHooks()

    private init() {}

    // MARK: - Plugin Registration

    /// 플러그인 등록
    public func register(_ plugin: any Plugin) async throws {
        guard registeredPlugins[plugin.identifier] == nil else {
            throw PluginError.pluginAlreadyRegistered(plugin.identifier)
        }

        registeredPlugins[plugin.identifier] = plugin

        // 플러그인 타입별 훅 등록
        registerPluginHooks(plugin)

      #logDebug("🔌 [Plugin] Registered plugin: \(plugin.identifier) v\(plugin.version)")
    }

    /// 플러그인 등록 해제
    public func unregister(_ pluginId: String) async throws {
        guard let plugin = registeredPlugins[pluginId] else {
            throw PluginError.pluginNotFound(pluginId)
        }

        // 활성화된 플러그인이면 먼저 비활성화
        if activePlugins.contains(pluginId) {
            try await deactivate(pluginId)
        }

        registeredPlugins.removeValue(forKey: pluginId)
        unregisterPluginHooks(plugin)

      #logDebug("🔌 [Plugin] Unregistered plugin: \(pluginId)")
    }

    // MARK: - Plugin Activation

    /// 플러그인 활성화
    public func activate(_ pluginId: String) async throws {
        guard let plugin = registeredPlugins[pluginId] else {
            throw PluginError.pluginNotFound(pluginId)
        }

        guard !activePlugins.contains(pluginId) else {
            return // 이미 활성화됨
        }

        try await plugin.activate()
        activePlugins.insert(pluginId)

        print("✅ [Plugin] Activated plugin: \(pluginId)")
    }

    /// 플러그인 비활성화
    public func deactivate(_ pluginId: String) async throws {
        guard let plugin = registeredPlugins[pluginId] else {
            throw PluginError.pluginNotFound(pluginId)
        }

        guard activePlugins.contains(pluginId) else {
            return // 이미 비활성화됨
        }

        try await plugin.deactivate()
        activePlugins.remove(pluginId)

        print("⏹️ [Plugin] Deactivated plugin: \(pluginId)")
    }

    /// 모든 플러그인 활성화
    public func activateAll() async throws {
        let sortedPlugins = registeredPlugins.values.sorted { $0.priority < $1.priority }

        for plugin in sortedPlugins {
            try await activate(plugin.identifier)
        }
    }

    /// 모든 플러그인 비활성화
    public func deactivateAll() async throws {
        let sortedPlugins = registeredPlugins.values.sorted { $0.priority > $1.priority }

        for plugin in sortedPlugins {
            try await deactivate(plugin.identifier)
        }
    }

    // MARK: - Hook Management

    private func registerPluginHooks(_ plugin: any Plugin) {
        if let regPlugin = plugin as? RegistrationPlugin {
            pluginHooks.registrationPlugins.append(regPlugin)
        }

        if let resPlugin = plugin as? ResolutionPlugin {
            pluginHooks.resolutionPlugins.append(resPlugin)
        }

        if let lifecyclePlugin = plugin as? LifecyclePlugin {
            pluginHooks.lifecyclePlugins.append(lifecyclePlugin)
        }

        if let validationPlugin = plugin as? ValidationPlugin {
            pluginHooks.validationPlugins.append(validationPlugin)
        }

        if let monitoringPlugin = plugin as? MonitoringPlugin {
            pluginHooks.monitoringPlugins.append(monitoringPlugin)
        }
    }

    private func unregisterPluginHooks(_ plugin: any Plugin) {
        pluginHooks.registrationPlugins.removeAll { $0.identifier == plugin.identifier }
        pluginHooks.resolutionPlugins.removeAll { $0.identifier == plugin.identifier }
        pluginHooks.lifecyclePlugins.removeAll { $0.identifier == plugin.identifier }
        pluginHooks.validationPlugins.removeAll { $0.identifier == plugin.identifier }
        pluginHooks.monitoringPlugins.removeAll { $0.identifier == plugin.identifier }
    }

    // MARK: - Hook Execution

    /// 등록 전 훅 실행
    public func executeBeforeRegistrationHooks<T>(_ type: T.Type, factory: @Sendable @escaping () -> T) async throws {
        for plugin in pluginHooks.registrationPlugins {
            if activePlugins.contains(plugin.identifier) {
                try await plugin.beforeRegistration(type, factory: factory)
            }
        }
    }

    /// 해결 전 훅 실행
    public func executeBeforeResolutionHooks<T>(_ type: T.Type) async throws {
        for plugin in pluginHooks.resolutionPlugins {
            if activePlugins.contains(plugin.identifier) {
                try await plugin.beforeResolution(type)
            }
        }
    }

    // MARK: - Plugin Discovery

    /// 플러그인 정보 조회
    public func getPluginInfo(_ pluginId: String) -> PluginInfo? {
        guard let plugin = registeredPlugins[pluginId] else { return nil }

        return PluginInfo(
            identifier: plugin.identifier,
            version: plugin.version,
            description: plugin.description,
            priority: plugin.priority,
            isActive: activePlugins.contains(pluginId),
            capabilities: getPluginCapabilities(plugin)
        )
    }

    /// 모든 플러그인 정보 조회
    public func getAllPluginsInfo() -> [PluginInfo] {
        return registeredPlugins.values.compactMap { plugin in
            getPluginInfo(plugin.identifier)
        }
    }

    private func getPluginCapabilities(_ plugin: any Plugin) -> [String] {
        var capabilities: [String] = []

        if plugin is RegistrationPlugin { capabilities.append("Registration") }
        if plugin is ResolutionPlugin { capabilities.append("Resolution") }
        if plugin is LifecyclePlugin { capabilities.append("Lifecycle") }
        if plugin is ValidationPlugin { capabilities.append("Validation") }
        if plugin is MonitoringPlugin { capabilities.append("Monitoring") }

        return capabilities
    }
}

// MARK: - Plugin Hooks Container

private struct PluginHooks {
    var registrationPlugins: [RegistrationPlugin] = []
    var resolutionPlugins: [ResolutionPlugin] = []
    var lifecyclePlugins: [LifecyclePlugin] = []
    var validationPlugins: [ValidationPlugin] = []
    var monitoringPlugins: [MonitoringPlugin] = []
}

// MARK: - Plugin Info

public struct PluginInfo: Sendable, Identifiable {
    public let id: String
    public let identifier: String
    public let version: String
    public let description: String
    public let priority: Int
    public let isActive: Bool
    public let capabilities: [String]

    public init(identifier: String, version: String, description: String, priority: Int, isActive: Bool, capabilities: [String]) {
        self.id = identifier
        self.identifier = identifier
        self.version = version
        self.description = description
        self.priority = priority
        self.isActive = isActive
        self.capabilities = capabilities
    }
}

// MARK: - Plugin Errors

public enum PluginError: Error, LocalizedError {
    case pluginNotFound(String)
    case pluginAlreadyRegistered(String)
    case pluginActivationFailed(String, Error)
    case pluginDeactivationFailed(String, Error)
    case invalidPluginConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case .pluginNotFound(let id):
            return "플러그인을 찾을 수 없습니다: \(id)"
        case .pluginAlreadyRegistered(let id):
            return "플러그인이 이미 등록되었습니다: \(id)"
        case .pluginActivationFailed(let id, let error):
            return "플러그인 활성화 실패 \(id): \(error.localizedDescription)"
        case .pluginDeactivationFailed(let id, let error):
            return "플러그인 비활성화 실패 \(id): \(error.localizedDescription)"
        case .invalidPluginConfiguration(let details):
            return "잘못된 플러그인 구성: \(details)"
        }
    }
}

// MARK: - Base Plugin Implementation

/// 기본 플러그인 구현을 위한 베이스 클래스
open class BasePlugin: @unchecked Sendable, Plugin {
    public let identifier: String
    public let version: String
    public let description: String
    public let priority: Int

    public private(set) var isActive: Bool = false

    public init(identifier: String, version: String, description: String, priority: Int = 100) {
        self.identifier = identifier
        self.version = version
        self.description = description
        self.priority = priority
    }

    open func activate() async throws {
        guard !isActive else { return }
        isActive = true
      #logDebug("🔌 [Plugin] BasePlugin \(identifier) activated")
    }

    open func deactivate() async throws {
        guard isActive else { return }
        isActive = false
      #logDebug("🔌 [Plugin] BasePlugin \(identifier) deactivated")
    }
}
