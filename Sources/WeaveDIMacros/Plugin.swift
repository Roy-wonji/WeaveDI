import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct WeaveDIPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    // 🚀 Core Implementation Macros (Swift 6 Compatible)
    ComponentMacro.self,              // @Component macro (MemberMacro + ExtensionMacro)
    AutoSyncMacro.self,               // @AutoSync macro (MemberMacro + ExtensionMacro)
    ReverseAutoSyncMacro.self,        // @ReverseAutoSync macro (MemberMacro)
    ProvideMacro.self                 // @Provide macro (AccessorMacro)
  ]
}
