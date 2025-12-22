import Foundation
import WeaveDICore

public final class OptimizationHookInstaller {
  private static var isInstalled = false

  public static func install() {
    guard !isInstalled else { return }
    isInstalled = true

    OptimizationHooks.trackRegistration = { type in
      Task { @DIActor in
        AutoDIOptimizer.shared.trackRegistration(type)
      }
    }

    OptimizationHooks.trackResolution = { type in
      Task { @DIActor in
        AutoDIOptimizer.shared.trackResolution(type)
      }
    }

    OptimizationHooks.handleNilResolution = { type in
      Task { @DIActor in
        AutoDIOptimizer.shared.handleNilResolution(type)
      }
    }

    OptimizationHooks.setOptimizationEnabled = { enabled in
      Task { @DIActor in
        AutoDIOptimizer.shared.setOptimizationEnabled(enabled)
      }
    }

    OptimizationHooks.resetStats = {
      Task { @DIActor in
        AutoDIOptimizer.shared.resetStats()
      }
    }

    OptimizationHooks.setOptimizerLogLevel = { level in
      let mapped: AutoDIOptimizer.LogLevel
      switch level {
      case .all:
        mapped = .all
      case .errors:
        mapped = .errors
      case .optimization:
        mapped = .optimization
      case .registration:
        mapped = .registration
      case .off:
        mapped = .off
      }
      Task { @DIActor in
        AutoDIOptimizer.shared.setLogLevel(mapped, configureLogger: false)
      }
    }

    OptimizationHooks.setAutoMonitorEnabled = { enabled in
      Task { @DIActor in
        AutoMonitor.isEnabled = enabled
      }
    }

    OptimizationHooks.onModuleRegistered = { type in
      await AutoMonitor.shared.onModuleRegistered(type)
    }

    OptimizationHooks.recordAutoEdgeIfEnabled = { type in
      await CircularDependencyDetector.shared.recordAutoEdgeIfEnabled(for: type)
    }

    OptimizationHooks.beginResolution = { type in
      try await CircularDependencyDetector.shared.beginResolution(type)
    }

    OptimizationHooks.endResolution = { type in
      await CircularDependencyDetector.shared.endResolution(type)
    }

    OptimizationHooks.addGraphNode = { type in
      await DependencyGraph.shared.addNode(type)
    }

    OptimizationHooks.addGraphEdge = { from, to, label in
      await DependencyGraph.shared.addEdge(from: from, to: to, label: label ?? "")
    }
  }
}
