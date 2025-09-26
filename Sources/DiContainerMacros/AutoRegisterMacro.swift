import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// AutoRegister 매크로 - 자동으로 의존성을 등록합니다.
///
/// 사용법:
/// ```swift
/// @AutoRegister
/// class UserService: UserServiceProtocol {
///     // 자동으로 UnifiedDI.register(UserServiceProtocol.self) { UserService() } 생성
/// }
/// ```
public struct AutoRegisterMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {

    // Class 또는 Struct 체크
    let typeDecl: any DeclSyntaxProtocol
    if let classDecl = declaration.as(ClassDeclSyntax.self) {
      typeDecl = classDecl
    } else if let structDecl = declaration.as(StructDeclSyntax.self) {
      typeDecl = structDecl
    } else {
      throw AutoRegisterError.notSupportedType
    }

    let typeName = typeDecl.name.text

    // 상속받는 프로토콜들 찾기
    let protocols = extractConformedProtocols(from: typeDecl)

    // 매크로 인자 파싱
    let arguments = node.arguments?.as(LabeledExprListSyntax.self)
    let lifetime = extractLifetime(from: arguments)

    var registrations: [DeclSyntax] = []

    // 각 프로토콜에 대해 등록 코드 생성
    for protocolName in protocols {
      let registrationCode = generateRegistrationCode(
        protocolName: protocolName,
        implementationName: typeName,
        lifetime: lifetime
      )
      registrations.append(DeclSyntax(stringLiteral: registrationCode))
    }

    // 자기 자신도 등록 (concrete type)
    let selfRegistrationCode = generateRegistrationCode(
      protocolName: typeName,
      implementationName: typeName,
      lifetime: lifetime
    )
    registrations.append(DeclSyntax(stringLiteral: selfRegistrationCode))

    return registrations
  }

  private static func extractConformedProtocols(from typeDecl: some DeclSyntaxProtocol) -> [String] {
    var protocols: [String] = []

    if let classDecl = typeDecl.as(ClassDeclSyntax.self) {
      protocols = extractProtocolsFromInheritanceClause(classDecl.inheritanceClause)
    } else if let structDecl = typeDecl.as(StructDeclSyntax.self) {
      protocols = extractProtocolsFromInheritanceClause(structDecl.inheritanceClause)
    }

    return protocols
  }

  private static func extractProtocolsFromInheritanceClause(_ clause: InheritanceClauseSyntax?) -> [String] {
    guard let clause = clause else { return [] }

    return clause.inheritedTypes.compactMap { inheritedType in
      inheritedType.type.as(IdentifierTypeSyntax.self)?.name.text
    }.filter { protocolName in
      // Swift 내장 프로토콜 제외
      !["Sendable", "Equatable", "Hashable", "Codable", "Encodable", "Decodable"].contains(protocolName)
    }
  }

  private static func extractLifetime(from arguments: LabeledExprListSyntax?) -> String {
    guard let arguments = arguments else { return "singleton" }

    for argument in arguments {
      if argument.label?.text == "lifetime" {
        if let memberAccess = argument.expression.as(MemberAccessExprSyntax.self) {
          return memberAccess.declName.baseName.text
        }
      }
    }

    return "singleton"
  }

  private static func generateRegistrationCode(
    protocolName: String,
    implementationName: String,
    lifetime: String
  ) -> String {
    let uniqueId = "\(protocolName)_\(implementationName)".replacingOccurrences(of: ".", with: "_")

    return """
        private static let __autoRegister_\(uniqueId) = {
            return UnifiedDI.register(\(protocolName).self) { \(implementationName)() }
        }()
        """
  }
}

enum AutoRegisterError: Error, CustomStringConvertible {
  case notSupportedType

  var description: String {
    switch self {
      case .notSupportedType:
        return "@AutoRegister can only be applied to classes or structs"
    }
  }
}

extension DeclSyntaxProtocol {
  var name: TokenSyntax {
    if let classDecl = self.as(ClassDeclSyntax.self) {
      return classDecl.name
    } else if let structDecl = self.as(StructDeclSyntax.self) {
      return structDecl.name
    } else {
      fatalError("Unsupported declaration type")
    }
  }
}
