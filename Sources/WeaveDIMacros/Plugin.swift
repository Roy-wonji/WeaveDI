import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct WeaveDIPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    ComponentMacro.self,        // 🚀 Needle-style Component
    AutoRegisterMacro.self,
    DependencyGraphMacro.self,
  ]
}
