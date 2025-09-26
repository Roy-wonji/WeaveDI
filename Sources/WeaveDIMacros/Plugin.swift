import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct DiContainerPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AutoRegisterMacro.self,
    ]
}