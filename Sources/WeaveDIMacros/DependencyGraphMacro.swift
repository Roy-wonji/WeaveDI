import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Compile-time dependency graph verification macro
/// Validates dependency relationships and detects circular dependencies
public struct DependencyGraphMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    
    // Extract dependency information from the attribute
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
          let firstArgument = arguments.first?.expression else {
      throw MacroError.invalidSyntax("DependencyGraph requires dependency specification")
    }
    
    // Parse the dependency graph structure
    let dependencies = try parseDependencyGraph(from: firstArgument)
    
    // Validate for circular dependencies
    try validateCircularDependencies(dependencies)
    
    // Generate compile-time dependency graph validation code
    let validationCode = generateValidationCode(dependencies)
    
    return [DeclSyntax(validationCode)]
  }
  
  /// Parse dependency graph from syntax
  private static func parseDependencyGraph(from expression: ExprSyntax) throws -> [String: [String]] {
    var dependencies: [String: [String]] = [:]
    
    // Handle dictionary literal syntax: [Type.self: [Dep1.self, Dep2.self]]
    if let dictExpr = expression.as(DictionaryExprSyntax.self) {
      for element in dictExpr.content.as(DictionaryElementListSyntax.self) ?? [] {
        if let keyExpr = element.key.as(MemberAccessExprSyntax.self),
           let valueArray = element.value.as(ArrayExprSyntax.self) {
          
          let typeName = extractTypeName(from: keyExpr)
          var deps: [String] = []
          
          for arrayElement in valueArray.elements {
            if let depExpr = arrayElement.expression.as(MemberAccessExprSyntax.self) {
              deps.append(extractTypeName(from: depExpr))
            }
          }
          
          dependencies[typeName] = deps
        }
      }
    }
    
    return dependencies
  }
  
  /// Extract type name from Type.self syntax
  private static func extractTypeName(from expr: MemberAccessExprSyntax) -> String {
    if let baseType = expr.base?.as(DeclReferenceExprSyntax.self) {
      return baseType.baseName.text
    }
    return "Unknown"
  }
  
  /// Validate for circular dependencies using DFS
  private static func validateCircularDependencies(_ dependencies: [String: [String]]) throws {
    var visited: Set<String> = []
    var recursionStack: Set<String> = []
    
    for type in dependencies.keys {
      if !visited.contains(type) {
        if hasCycle(type, dependencies, &visited, &recursionStack) {
          throw MacroError.circularDependency("Circular dependency detected involving: \(type)")
        }
      }
    }
  }
  
  /// DFS cycle detection
  private static func hasCycle(
    _ type: String,
    _ dependencies: [String: [String]],
    _ visited: inout Set<String>,
    _ recursionStack: inout Set<String>
  ) -> Bool {
    visited.insert(type)
    recursionStack.insert(type)
    
    if let deps = dependencies[type] {
      for dep in deps {
        if !visited.contains(dep) {
          if hasCycle(dep, dependencies, &visited, &recursionStack) {
            return true
          }
        } else if recursionStack.contains(dep) {
          return true
        }
      }
    }
    
    recursionStack.remove(type)
    return false
  }
  
  /// Generate validation code
  private static func generateValidationCode(_ dependencies: [String: [String]]) -> FunctionDeclSyntax {
    return FunctionDeclSyntax(
      modifiers: [DeclModifierSyntax(name: .keyword(.private))],
      name: .identifier("validateDependencyGraph"),
      signature: FunctionSignatureSyntax(
        parameterClause: FunctionParameterClauseSyntax(parameters: []),
        returnClause: ReturnClauseSyntax(type: TypeSyntax(stringLiteral: "Void"))
      )
    ) {
      // Generate validation logic
      CodeBlockItemSyntax(item: .expr(ExprSyntax(stringLiteral: """
            // Compile-time validated dependency graph
            // Dependencies: \(dependencies.description)
            // ✅ No circular dependencies detected
            """)))
    }
  }
}

/// Custom macro errors
enum MacroError: Error, CustomStringConvertible {
  case invalidSyntax(String)
  case circularDependency(String)
  
  var description: String {
    switch self {
      case .invalidSyntax(let message):
        return "Invalid syntax: \(message)"
      case .circularDependency(let message):
        return "Circular dependency error: \(message)"
    }
  }
}
