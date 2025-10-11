import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct WeaveDIPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    // 🚀 Core Implementation Macros (Swift 6 Compatible)
    ComponentMacro.self,              // @Component macro (MemberMacro + ExtensionMacro)
    AutoSyncStructMacro.self,         // @AutoSync for DependencyKey structs
    AutoSyncExtensionMacro.self,      // @AutoSyncExtension for DependencyValues/InjectedValues
    AutoSyncPropertyMacro.self,       // @AutoSyncProperty peer macro
    GenerateAutoSyncMacro.self,       // @GenerateAutoSync member macro
    ReverseAutoSyncMacro.self,        // @ReverseAutoSync macro (MemberMacro)
    ProvideMacro.self                 // @Provide macro (AccessorMacro)
  ]
}
