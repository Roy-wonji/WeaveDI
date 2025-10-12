import Foundation
import LogMacro

enum DILogChannel {
  case registration
  case optimization
  case health
  case general
  case error
}

enum DILogSeverity {
  case debug
  case info
  case error
}

struct DILogger {
  private static func shouldEmit(channel: DILogChannel) -> Bool {
    let level = AutoDIOptimizer.readSnapshot().logLevel
    switch level {
    case .all:
      return true
    case .registration:
      return channel == .registration || channel == .error
    case .optimization:
      return channel == .optimization || channel == .error
    case .errors:
      return channel == .registration || channel == .error
    case .off:
      return false
    }
  }

  private static func emit(
    _ severity: DILogSeverity,
    channel: DILogChannel,
    _ message: Any,
    _ arguments: [Any]
  ) {
    guard shouldEmit(channel: channel) else { return }

    switch severity {
    case .debug:
      Log.debug(message, arguments...)
    case .info:
      Log.info(message, arguments...)
    case .error:
      Log.error(message, arguments...)
    }
  }

  static func debug(
    channel: DILogChannel = .general,
    _ message: Any,
    _ arguments: Any...
  ) {
    emit(.debug, channel: channel, message, arguments)
  }

  static func info(
    channel: DILogChannel = .general,
    _ message: Any,
    _ arguments: Any...
  ) {
    emit(.info, channel: channel, message, arguments)
  }

  static func error(
    channels: [DILogChannel] = [.error],
    _ message: Any,
    _ arguments: Any...
  ) {
    for channel in channels {
      emit(.error, channel: channel, message, arguments)
    }
  }
}
