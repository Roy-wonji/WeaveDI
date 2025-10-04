import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct WeaveDIPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    ComponentMacro.self,        // 🚀 Needle-style Component
    AutoRegisterMacro.self,
    DependencyGraphMacro.self,
    // 🎯 TCA Auto Sync Macros
    AutoSyncMacro.self,               // Main: @AutoSync
    AutoSyncPropertyMacro.self,       // Individual property (PeerMacro)
    GenerateAutoSyncMacro.self,       // 🎉 Complete auto-generation (MemberMacro)
    AutoSyncToWeaveDIMacro.self,      // Legacy
    AutoSyncExtensionMacro.self       // Extension-wide
  ]
}
