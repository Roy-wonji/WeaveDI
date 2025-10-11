//
//  WeaveDIMacros.swift
//  WeaveDI
//
//  Created by Wonji Suh on 2025.
//

import Foundation

// MARK: - Legacy Macro Definitions (Deprecated)

/// Legacy @Component 매크로 정의 - 이제 MacroDefinitions.swift 사용
@available(*, deprecated, message: "Use macro definitions from MacroDefinitions.swift")
@attached(member, names: named(registerAll))
@attached(extension, conformances: ComponentProtocol)
public macro ComponentLegacy() = #externalMacro(module: "WeaveDIMacros", type: "ComponentMacro")

/// Legacy @Provide 매크로 정의 - 이제 MacroDefinitions.swift 사용
@available(*, deprecated, message: "Use macro definitions from MacroDefinitions.swift")
@attached(accessor)
public macro ProvideLegacy(scope: ProvideScope = .transient) = #externalMacro(module: "WeaveDIMacros", type: "ProvideMacro")