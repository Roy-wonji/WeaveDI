import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct WeaveDIPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    AutoRegisterMacro.self,
    DependencyGraphMacro.self,
  ]
}
