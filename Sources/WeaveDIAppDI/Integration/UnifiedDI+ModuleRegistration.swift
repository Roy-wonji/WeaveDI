import Foundation
import WeaveDICore

public extension UnifiedDI {
  /// Register modules built by factories or helpers.
  static func registerModules(_ modules: [@Sendable () -> Module]) async {
    await modules.asyncForEach { module in
      await module().register()
    }
  }

  /// Register prebuilt modules.
  static func registerModules(_ modules: [Module]) async {
    await modules.asyncForEach { module in
      await module.register()
    }
  }

  /// Register app-level DI modules via RegisterModule builder.
  static func registerDi(
    _ build: @Sendable (RegisterModule) -> [@Sendable () -> Module]
  ) async {
    let register = RegisterModule()
    await registerModules(build(register))
  }

  /// Register app-level DI modules via prebuilt module list.
  static func registerDi(_ modules: [Module]) async {
    await registerModules(modules)
  }
}
