import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

private struct ComponentMacroError: Error {
  let message: String
  init(_ message: String) { self.message = message }
}

public enum ComponentMacro {}

extension ComponentMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let structDecl = declaration.as(StructDeclSyntax.self) else {
      throw ComponentMacroError("@Component는 struct에서만 사용할 수 있습니다")
    }

    let registrations = structDecl.memberBlock.members.compactMap { member -> (String, String)? in
      guard
        let varDecl = member.decl.as(VariableDeclSyntax.self),
        !varDecl.modifiers.contains(where: { $0.name.text == "static" }),
        let binding = varDecl.bindings.first,
        let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
        let typeSyntax = binding.typeAnnotation?.type
      else {
        return nil
      }
      let typeName = typeSyntax.description.trimmingCharacters(in: .whitespacesAndNewlines)
      return (identifier, typeName)
    }

    let registrationBody: String
    if registrations.isEmpty {
      registrationBody = """
      guard !Self.isRegistered else { return }
      Self.isRegistered = true
      """
    } else {
      let lines = registrations.map { (name, type) in
        "DIContainer.live.register(\(type).self, build: { self.\(name) })"
      }.joined(separator: "\n      ")
      registrationBody = """
      guard !Self.isRegistered else { return }
      Self.isRegistered = true
      \(lines)
      """
    }

    let isRegisteredDecl: DeclSyntax = "public static var isRegistered: Bool = false"
    let registerDecl: DeclSyntax = """
    public func register() {
      \(raw: registrationBody)
    }
    """

    return [isRegisteredDecl, registerDecl]
  }
}

extension ComponentMacro: ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard declaration.is(StructDeclSyntax.self) else {
      throw ComponentMacroError("@Component는 struct에서만 사용할 수 있습니다")
    }

    let extensionDecl = try ExtensionDeclSyntax("extension \(type): ComponentProtocol {}")
    let sendableDecl = try ExtensionDeclSyntax("extension \(type): @unchecked Sendable {}")
    return [extensionDecl, sendableDecl]
  }
}
