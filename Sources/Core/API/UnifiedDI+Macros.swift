import Foundation

// MARK: - Compile-Time Dependency Graph Verification

@attached(peer, names: named(validateDependencyGraph))
public macro DependencyGraph<T>(_ dependencies: T) = #externalMacro(module: "WeaveDIMacros", type: "DependencyGraphMacro")
