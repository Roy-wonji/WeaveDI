import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum ComponentMacro {}

private struct ProvideProperty {
  enum Storage { case transient, singleton }
  let name: String
  let type: String
  let storage: Storage
}

private enum ComponentMacroError: Error {
  case invalidDeclaration
  case missingType(String)
}

private struct ComponentDiagnostic: DiagnosticMessage {
  let message: String
  let diagnosticID: MessageID
  let severity: DiagnosticSeverity

  init(_ message: String, node: SyntaxProtocol) {
    self.message = message
    self.diagnosticID = MessageID(domain: "WeaveDI.Component", id: "component-error")
    self.severity = .error
  }
}

extension ComponentMacro: MemberMacro {
  public static func expansion(
    of attribute: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard declaration.is(StructDeclSyntax.self) else {
      throw ComponentMacroError.invalidDeclaration
    }

    let storageVar: DeclSyntax = "private static var __componentIsRegistered = false"
    return [storageVar]
  }
}

extension ComponentMacro: ExtensionMacro {
  public static func expansion(
    of attribute: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard let structDecl = declaration.as(StructDeclSyntax.self) else {
      throw ComponentMacroError.invalidDeclaration
    }

    let properties = try collectProvideProperties(from: structDecl, context: context)
    let typeName = structDecl.name.text

    let statements = properties.map { property -> String in
      switch property.storage {
      case .singleton:
        return "container.register(\(property.type).self, instance: instance.\(property.name))"
      case .transient:
        return "container.register(\(property.type).self) { instance.\(property.name) }"
      }
    }.joined(separator: "\n        ")

    let extensionDecl: DeclSyntax = """
    extension \(raw: typeName): ComponentProtocol {
      public static func registerAll(into container: DIContainer) {
        guard __componentIsRegistered == false else { return }
        __componentIsRegistered = true
        let instance = Self()
        \(raw: statements)
      }

      public static func registerAll() {
        registerAll(into: DIContainer.shared)
      }
    }
    """

    guard let ext = extensionDecl.as(ExtensionDeclSyntax.self) else {
      return []
    }

    return [ext]
  }

  private static func collectProvideProperties(
    from structDecl: StructDeclSyntax,
    context: some MacroExpansionContext
  ) throws -> [ProvideProperty] {
    var result: [ProvideProperty] = []

    for member in structDecl.memberBlock.members {
      guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
      let attributes = varDecl.attributes
      guard !attributes.isEmpty else { continue }
      guard let provideAttribute = attributes.first(where: { attr in
        attr.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "Provide"
      })?.as(AttributeSyntax.self) else { continue }

      guard varDecl.bindings.count == 1,
        let binding = varDecl.bindings.first,
        let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }

      guard let typeAnnotation = binding.typeAnnotation else {
        let message = ComponentDiagnostic("Provide 속성은 명시적 타입이 필요합니다", node: Syntax(varDecl))
        context.diagnose(Diagnostic(node: Syntax(varDecl), message: message))
        throw ComponentMacroError.missingType(pattern.identifier.text)
      }

      let name = pattern.identifier.text
      let type = typeAnnotation.type.trimmedDescription
      let storage = storage(from: provideAttribute)

      result.append(ProvideProperty(name: name, type: type, storage: storage))
    }

    return result
  }

  private static func storage(from attribute: AttributeSyntax) -> ProvideProperty.Storage {
    guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self) else {
      return .transient
    }

    for argument in arguments {
      let label = argument.label?.text ?? ""
      let valueText = argument.expression.trimmedDescription
      if label == "scope" || label.isEmpty {
        if valueText.contains("singleton") {
          return .singleton
        }
      }
    }
    return .transient
  }
}
