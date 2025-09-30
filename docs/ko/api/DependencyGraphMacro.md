---
title: DependencyGraphMacro
lang: ko-KR
---

# DependencyGraphMacro

Compile-time dependency graph verification macro
Validates dependency relationships and detects circular dependencies

```swift
public struct DependencyGraphMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
}
```

  /// Parse dependency graph from syntax
  /// Extract type name from Type.self syntax
  /// Validate for circular dependencies using DFS
  /// DFS cycle detection
  /// Generate validation code
Custom macro errors
