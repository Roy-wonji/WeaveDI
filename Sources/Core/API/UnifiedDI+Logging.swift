import Foundation

// MARK: - Logging & Monitoring Configuration

public extension UnifiedDI {
  static func setLogLevel(_ level: LogLevel) {
    let optimizerLogLevel: AutoDIOptimizer.LogLevel

    switch level {
      case .all:
        DILogger.configure(level: .all, severityThreshold: .debug)
        optimizerLogLevel = .all
        WeaveDIConfiguration.enableRegistryHealthLogging = true
        configureRuntimeToggles(
          verbose: true,
          autoMonitor: true,
          autoFix: true,
          optimizerTracking: true
        )
      case .errors:
        DILogger.configure(level: .errorsOnly, severityThreshold: .error)
        optimizerLogLevel = .errors
        WeaveDIConfiguration.enableRegistryHealthLogging = false
        configureRuntimeToggles(
          verbose: false,
          autoMonitor: false,
          autoFix: true,
          optimizerTracking: true
        )
      case .warnings:
        DILogger.configure(level: .errorsOnly, severityThreshold: .warning)
        optimizerLogLevel = .errors
        WeaveDIConfiguration.enableRegistryHealthLogging = false
        configureRuntimeToggles(
          verbose: false,
          autoMonitor: false,
          autoFix: true,
          optimizerTracking: true
        )
      case .performance:
        DILogger.configure(level: .optimization, severityThreshold: .info)
        optimizerLogLevel = .optimization
        WeaveDIConfiguration.enableRegistryHealthLogging = false
        configureRuntimeToggles(
          verbose: false,
          autoMonitor: false,
          autoFix: true,
          optimizerTracking: true
        )
      case .registration:
        DILogger.configure(level: .registration, severityThreshold: .info)
        optimizerLogLevel = .registration
        WeaveDIConfiguration.enableRegistryHealthLogging = false
        configureRuntimeToggles(
          verbose: true,
          autoMonitor: false,
          autoFix: true,
          optimizerTracking: true
        )
      case .health:
        DILogger.configure(level: .health, severityThreshold: .info)
        optimizerLogLevel = .errors
        WeaveDIConfiguration.enableRegistryHealthLogging = true
        configureRuntimeToggles(
          verbose: false,
          autoMonitor: true,
          autoFix: true,
          optimizerTracking: true
        )
      case .off:
        DILogger.configure(level: .off)
        optimizerLogLevel = .off
        WeaveDIConfiguration.enableRegistryHealthLogging = false
        configureRuntimeToggles(
          verbose: false,
          autoMonitor: false,
          autoFix: false,
          optimizerTracking: false
        )
    }

    Task { @DIActor in
      AutoDIOptimizer.shared.setLogLevel(optimizerLogLevel, configureLogger: false)
    }
  }

  static func setLogSeverity(_ severity: LogSeverity) {
    switch severity {
      case .debug:
        DILogger.configure(level: .all, severityThreshold: .debug)
      case .info:
        DILogger.configure(level: .all, severityThreshold: .info)
      case .warning:
        DILogger.configure(level: .errorsOnly, severityThreshold: .warning)
      case .error:
        DILogger.configure(level: .errorsOnly, severityThreshold: .error)
    }
  }

  static func getLogConfiguration() -> (level: DILogLevel, severity: DILogSeverity) {
    return (
      level: DILogger.getCurrentLogLevel(),
      severity: DILogger.getCurrentSeverityThreshold()
    )
  }

  static func resetLogConfiguration() {
    DILogger.resetToDefaults()
  }

  @MainActor
  static func startDevelopmentMonitoring() {
    setLogLevel(.all)
    DIMonitor.startDevelopmentMonitoring()
  }

  @MainActor
  static func startProductionMonitoring() {
    setLogLevel(.errors)
    DIMonitor.startProductionMonitoring()
  }

  @MainActor
  static func stopMonitoring() {
    DIMonitor.stop()
  }

  static func performHealthCheck() async -> DIHealthStatus {
    return await DIHealthCheck.shared.performHealthCheck()
  }

  static func generateMonitoringReport() async -> DIMonitorReport {
    return await DIMonitor.shared.generateReport()
  }
}

public extension UnifiedDI {
  enum LogLevel {
    case all
    case errors
    case warnings
    case performance
    case registration
    case health
    case off
  }

  enum LogSeverity {
    case debug
    case info
    case warning
    case error
  }
}

private extension UnifiedDI {
  static func configureRuntimeToggles(
    verbose: Bool,
    autoMonitor: Bool,
    autoFix: Bool,
    optimizerTracking: Bool
  ) {
    WeaveDIConfiguration.enableVerboseLogging = verbose
    WeaveDIConfiguration.enableAutoMonitor = autoMonitor
    WeaveDIConfiguration.enableRegistryAutoFix = autoFix
    WeaveDIConfiguration.enableOptimizerTracking = optimizerTracking
  }
}
