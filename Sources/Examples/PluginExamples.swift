//
//  PluginExamples.swift
//  DiContainer
//
//  Created by Claude on 2025-09-14.
//

import Foundation

// MARK: - Concrete Plugin Implementations

/// 로깅 플러그인: 모든 DI 활동을 로그로 기록
public final class LoggingPlugin: BasePlugin, RegistrationPlugin, ResolutionPlugin, LifecyclePlugin {

    private let logLevel: LogLevel
    private var registrationCount: Int = 0
    private var resolutionCount: Int = 0

    public enum LogLevel: Int, Sendable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
    }

    public init(logLevel: LogLevel = .info) {
        self.logLevel = logLevel
        super.init(
            identifier: "com.dicontainer.logging",
            version: "1.0.0",
            description: "DI 활동을 로그로 기록하는 플러그인",
            priority: 10 // 높은 우선순위로 먼저 실행
        )
    }

    // MARK: - RegistrationPlugin

    public func beforeRegistration<T>(_ type: T.Type, factory: @Sendable @escaping () -> T) async throws {
        if logLevel.rawValue <= LogLevel.debug.rawValue {
            print("🔧 [LoggingPlugin] Before registration: \(type)")
        }
    }

    public func afterRegistration<T>(_ type: T.Type, instance: T) async throws {
        registrationCount += 1
        if logLevel.rawValue <= LogLevel.info.rawValue {
            print("✅ [LoggingPlugin] Registered: \(type) (#\(registrationCount))")
        }
    }

    public func onRegistrationFailure<T>(_ type: T.Type, error: Error) async throws {
        print("❌ [LoggingPlugin] Registration failed for \(type): \(error)")
    }

    // MARK: - ResolutionPlugin

    public func beforeResolution<T>(_ type: T.Type) async throws {
        if logLevel.rawValue <= LogLevel.debug.rawValue {
            print("🔍 [LoggingPlugin] Before resolution: \(type)")
        }
    }

    public func afterResolution<T>(_ type: T.Type, instance: T?) async throws {
        resolutionCount += 1
        if let _ = instance {
            if logLevel.rawValue <= LogLevel.info.rawValue {
                print("✅ [LoggingPlugin] Resolved: \(type) (#\(resolutionCount))")
            }
        } else {
            print("⚠️ [LoggingPlugin] Failed to resolve: \(type)")
        }
    }

    public func onResolutionFailure<T>(_ type: T.Type, error: Error) async throws {
        print("❌ [LoggingPlugin] Resolution failed for \(type): \(error)")
    }

    // MARK: - LifecyclePlugin

    public func onContainerInitialized() async throws {
        print("🚀 [LoggingPlugin] DI Container initialized")
    }

    public func beforeContainerReset() async throws {
        print("🔄 [LoggingPlugin] Container reset starting... (Registered: \(registrationCount), Resolved: \(resolutionCount))")
    }

    public func afterContainerReset() async throws {
        registrationCount = 0
        resolutionCount = 0
        print("🔄 [LoggingPlugin] Container reset completed")
    }

    public func beforeContainerDestroy() async throws {
        print("🗑️ [LoggingPlugin] Container destruction starting...")
    }
}

// MARK: - Performance Monitoring Plugin

/// 성능 모니터링 플러그인: DI 성능 메트릭스를 추적
public final class PerformanceMonitoringPlugin: BasePlugin, ResolutionPlugin, MonitoringPlugin {

    private var resolutionTimes: [String: [TimeInterval]] = [:]
    private var resolutionCounts: [String: Int] = [:]
    private let maxSamples: Int

    public init(maxSamples: Int = 100) {
        self.maxSamples = maxSamples
        super.init(
            identifier: "com.dicontainer.performance",
            version: "1.0.0",
            description: "DI 성능을 모니터링하는 플러그인",
            priority: 20
        )
    }

    // MARK: - ResolutionPlugin

    private var resolutionStartTimes: [String: CFAbsoluteTime] = [:]

    public func beforeResolution<T>(_ type: T.Type) async throws {
        let typeName = String(describing: type)
        resolutionStartTimes[typeName] = CFAbsoluteTimeGetCurrent()
    }

    public func afterResolution<T>(_ type: T.Type, instance: T?) async throws {
        let typeName = String(describing: type)

        guard let startTime = resolutionStartTimes[typeName] else { return }

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime

        // 성능 데이터 기록
        recordResolutionTime(for: typeName, duration: duration)

        resolutionStartTimes.removeValue(forKey: typeName)
    }

    public func onResolutionFailure<T>(_ type: T.Type, error: Error) async throws {
        let typeName = String(describing: type)
        resolutionStartTimes.removeValue(forKey: typeName)
    }

    private func recordResolutionTime(for typeName: String, duration: TimeInterval) {
        // 해결 횟수 증가
        resolutionCounts[typeName, default: 0] += 1

        // 시간 샘플 추가
        if resolutionTimes[typeName] == nil {
            resolutionTimes[typeName] = []
        }

        resolutionTimes[typeName]?.append(duration)

        // 샘플 개수 제한
        if let times = resolutionTimes[typeName], times.count > maxSamples {
            resolutionTimes[typeName] = Array(times.suffix(maxSamples))
        }
    }

    // MARK: - MonitoringPlugin

    public func recordEvent(_ event: PluginEvent) async {
        if event.type == .resolution {
            // 해결 이벤트 처리
        }
    }

    public func collectMetrics() async -> [String: String] {
        var metrics: [String: String] = [:]

        for (typeName, times) in resolutionTimes {
            let count = resolutionCounts[typeName] ?? 0
            let avgTime = times.isEmpty ? 0 : times.reduce(0, +) / Double(times.count)
            let maxTime = times.max() ?? 0
            let minTime = times.min() ?? 0

            metrics["\(typeName)_count"] = String(count)
            metrics["\(typeName)_averageTime"] = String(format: "%.6f", avgTime)
            metrics["\(typeName)_maxTime"] = String(format: "%.6f", maxTime)
            metrics["\(typeName)_minTime"] = String(format: "%.6f", minTime)
            metrics["\(typeName)_samples"] = String(times.count)
        }

        return metrics
    }

    public func generateStatusReport() async -> PluginStatusReport {
        let metrics = await collectMetrics()
        let totalResolutions = resolutionCounts.values.reduce(0, +)

        var statusMetrics: [String: String] = [
            "totalResolutions": String(totalResolutions),
            "trackedTypes": String(resolutionTimes.keys.count),
            "status": "active"
        ]

        // 성능 데이터 추가
        statusMetrics.merge(metrics) { (_, new) in new }

        return PluginStatusReport(
            pluginId: identifier,
            status: "active",
            metrics: statusMetrics
        )
    }
}

// MARK: - Validation Plugin

/// 검증 플러그인: 의존성 등록/해결을 검증
public final class DependencyValidationPlugin: BasePlugin, ValidationPlugin {

    private let rules: [ValidationRule]

    public init(rules: [ValidationRule] = []) {
        self.rules = rules
        super.init(
            identifier: "com.dicontainer.validation",
            version: "1.0.0",
            description: "의존성 등록/해결을 검증하는 플러그인",
            priority: 5 // 가장 높은 우선순위
        )
    }

    public func validateRegistration<T>(_ type: T.Type, factory: @Sendable @escaping () -> T) async throws -> Bool {
        for rule in rules {
            let isValid = await rule.validateRegistration(type)
            if !isValid {
                print("❌ [ValidationPlugin] Registration validation failed for \(type): \(rule.name)")
                return false
            }
        }
        return true
    }

    public func validateResolution<T>(_ type: T.Type, instance: T?) async throws -> Bool {
        guard let instance = instance else {
            print("❌ [ValidationPlugin] Resolution validation failed: instance is nil for \(type)")
            return false
        }

        for rule in rules {
            let isValid = await rule.validateResolution(type, instance: instance)
            if !isValid {
                print("❌ [ValidationPlugin] Resolution validation failed for \(type): \(rule.name)")
                return false
            }
        }
        return true
    }
}

// MARK: - Validation Rules

public protocol ValidationRule: Sendable {
    var name: String { get }
    func validateRegistration<T>(_ type: T.Type) async -> Bool
    func validateResolution<T>(_ type: T.Type, instance: T) async -> Bool
}

/// 싱글톤 검증 규칙
public struct SingletonValidationRule: ValidationRule {
    public let name = "SingletonValidation"
    private let singletonTypes: Set<String>

    public init(singletonTypes: [String]) {
        self.singletonTypes = Set(singletonTypes)
    }

    public func validateRegistration<T>(_ type: T.Type) async -> Bool {
        // 모든 등록은 허용
        return true
    }

    public func validateResolution<T>(_ type: T.Type, instance: T) async -> Bool {
        let typeName = String(describing: type)

        // 싱글톤 타입인 경우 인스턴스가 동일한지 확인 (간단한 예시)
        if singletonTypes.contains(typeName) {
            // 실제 구현에서는 인스턴스 참조를 추적해야 함
            return true
        }

        return true
    }
}

// MARK: - Auto-Discovery Plugin

/// 자동 탐지 플러그인: 특정 패키지에서 자동으로 의존성을 탐지하고 등록
public final class AutoDiscoveryPlugin: BasePlugin, RegistrationPlugin {

    private let packagePrefixes: [String]
    private let excludedTypes: Set<String>

    public init(packagePrefixes: [String], excludedTypes: [String] = []) {
        self.packagePrefixes = packagePrefixes
        self.excludedTypes = Set(excludedTypes)
        super.init(
            identifier: "com.dicontainer.autodiscovery",
            version: "1.0.0",
            description: "자동으로 의존성을 탐지하고 등록하는 플러그인",
            priority: 50
        )
    }

    @MainActor
    override public func activate() async throws {
        try await super.activate()

        // 자동 탐지 수행
        await performAutoDiscovery()
    }

    private func performAutoDiscovery() async {
        print("🔍 [AutoDiscoveryPlugin] Starting auto-discovery for packages: \(packagePrefixes)")

        // 실제 구현에서는 런타임 리플렉션이나 컴파일 타임 코드 생성을 사용
        // 여기서는 간단한 예시만 제공

        let discoveredTypes = [
            "UserService",
            "NetworkService",
            "DatabaseService"
        ]

        for typeName in discoveredTypes {
            if !excludedTypes.contains(typeName) {
                print("📦 [AutoDiscoveryPlugin] Discovered type: \(typeName)")
                // 실제로는 타입을 등록해야 함
            }
        }
    }

    // MARK: - RegistrationPlugin

    public func beforeRegistration<T>(_ type: T.Type, factory: @Sendable @escaping () -> T) async throws {
        // 자동 탐지된 타입인지 확인
        let typeName = String(describing: type)
        print("🔍 [AutoDiscoveryPlugin] Checking registration for: \(typeName)")
    }

    public func afterRegistration<T>(_ type: T.Type, instance: T) async throws {
        // 등록 완료 처리
    }

    public func onRegistrationFailure<T>(_ type: T.Type, error: Error) async throws {
        print("❌ [AutoDiscoveryPlugin] Auto-discovered type registration failed: \(type)")
    }
}

// MARK: - Configuration Plugin

/// 설정 기반 플러그인: 설정 파일을 기반으로 의존성을 관리
public final class ConfigurationPlugin: BasePlugin, RegistrationPlugin, LifecyclePlugin {

    private let configurationPath: String
    private var configuration: [String: String] = [:]

    public init(configurationPath: String) {
        self.configurationPath = configurationPath
        super.init(
            identifier: "com.dicontainer.configuration",
            version: "1.0.0",
            description: "설정 파일 기반으로 의존성을 관리하는 플러그인",
            priority: 30
        )
    }

    @MainActor
    override public func activate() async throws {
        try await super.activate()
        try await loadConfiguration()
    }

    private func loadConfiguration() async throws {
        // 실제 구현에서는 JSON, YAML 등의 설정 파일을 로드
        print("📄 [ConfigurationPlugin] Loading configuration from: \(configurationPath)")

        // 예시 설정 (간단화)
        configuration = [
            "UserService_type": "singleton",
            "UserService_implementation": "DefaultUserService",
            "NetworkService_type": "factory",
            "NetworkService_implementation": "URLSessionNetworkService"
        ]
    }

    // MARK: - RegistrationPlugin

    public func beforeRegistration<T>(_ type: T.Type, factory: @Sendable @escaping () -> T) async throws {
        let typeName = String(describing: type)

        let config = getConfigurationFor(typeName)
        if !config.isEmpty {
            print("⚙️ [ConfigurationPlugin] Applying configuration for \(typeName): \(config)")
        }
    }

    public func afterRegistration<T>(_ type: T.Type, instance: T) async throws {
        // 등록 후 설정 적용
    }

    public func onRegistrationFailure<T>(_ type: T.Type, error: Error) async throws {
        print("❌ [ConfigurationPlugin] Configuration-based registration failed for \(type)")
    }

    // MARK: - LifecyclePlugin

    public func onContainerInitialized() async throws {
        print("📄 [ConfigurationPlugin] Container initialized with configuration")
    }

    public func beforeContainerReset() async throws {
        print("📄 [ConfigurationPlugin] Saving state before container reset")
    }

    public func afterContainerReset() async throws {
        try await loadConfiguration()
    }

    public func beforeContainerDestroy() async throws {
        print("📄 [ConfigurationPlugin] Cleaning up configuration resources")
    }

    private func getConfigurationFor(_ typeName: String) -> [String: String] {
        var config: [String: String] = [:]
        let prefix = "\(typeName)_"

        for (key, value) in configuration {
            if key.hasPrefix(prefix) {
                let configKey = String(key.dropFirst(prefix.count))
                config[configKey] = value
            }
        }

        return config
    }
}

// MARK: - Plugin Usage Examples

/// 플러그인 시스템 사용 예시
public final class PluginSystemExample {

    @MainActor
    public static func setupBasicPlugins() async throws {
        let pluginManager = PluginManager.shared

        // 로깅 플러그인 등록 및 활성화
        let loggingPlugin = LoggingPlugin(logLevel: .info)
        try await pluginManager.register(loggingPlugin)
        try await pluginManager.activate(loggingPlugin.identifier)

        // 성능 모니터링 플러그인
        let performancePlugin = PerformanceMonitoringPlugin(maxSamples: 50)
        try await pluginManager.register(performancePlugin)
        try await pluginManager.activate(performancePlugin.identifier)

        // 검증 플러그인
        let validationRules = [
            SingletonValidationRule(singletonTypes: ["UserService", "DatabaseService"])
        ]
        let validationPlugin = DependencyValidationPlugin(rules: validationRules)
        try await pluginManager.register(validationPlugin)
        try await pluginManager.activate(validationPlugin.identifier)

        print("✅ Basic plugins setup completed")
    }

    @MainActor
    public static func setupAdvancedPlugins() async throws {
        let pluginManager = PluginManager.shared

        // 자동 탐지 플러그인
        let autoDiscoveryPlugin = AutoDiscoveryPlugin(
            packagePrefixes: ["com.myapp.services"],
            excludedTypes: ["TestService", "MockService"]
        )
        try await pluginManager.register(autoDiscoveryPlugin)
        try await pluginManager.activate(autoDiscoveryPlugin.identifier)

        // 설정 기반 플러그인
        let configPlugin = ConfigurationPlugin(configurationPath: "di-config.json")
        try await pluginManager.register(configPlugin)
        try await pluginManager.activate(configPlugin.identifier)

        print("✅ Advanced plugins setup completed")
    }

    @MainActor
    public static func printPluginStatus() async {
        let pluginManager = PluginManager.shared
        let allPlugins = pluginManager.getAllPluginsInfo()

        print("\n📊 Plugin Status Report:")
        print("========================")

        for plugin in allPlugins {
            let status = plugin.isActive ? "✅ Active" : "⏸️ Inactive"
            print("🔌 \(plugin.identifier) v\(plugin.version) - \(status)")
            print("   📝 \(plugin.description)")
            print("   🎯 Priority: \(plugin.priority)")
            print("   🛠️ Capabilities: \(plugin.capabilities.joined(separator: ", "))")
            print("")
        }

        // 성능 플러그인 리포트
        if let perfPlugin = pluginManager.registeredPlugins["com.dicontainer.performance"] as? PerformanceMonitoringPlugin {
            let report = await perfPlugin.generateStatusReport()
            print("📈 Performance Report:")
            print(report.metrics)
        }
    }
}