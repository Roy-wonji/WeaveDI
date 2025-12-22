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
