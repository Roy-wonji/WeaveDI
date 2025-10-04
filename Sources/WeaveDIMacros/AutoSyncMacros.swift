//
//  AutoSyncMacros.swift
//  WeaveDIMacros
//
//  Created by Wonji Suh on 2025.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftCompilerPlugin
import Foundation

// MARK: - AutoSyncPropertyMacro

/// TCA DependencyValues computed property에 자동 WeaveDI 동기화 코드를 추가하는 매크로
///
/// ## 사용법:
/// ```swift
/// extension DependencyValues {
///   @AutoSyncProperty
///   var myService: MyService {
///     get { self[MyServiceKey.self] }
///     set { self[MyServiceKey.self] = newValue }
///   }
/// }
/// ```
///
/// ## 생성되는 코드:
/// ```swift
/// extension DependencyValues {
///   var myService: MyService {
///     get {
///       let value = self[MyServiceKey.self]
///       TCAAutoSyncContainer.autoSyncToWeaveDI(MyService.self, value: value)
///       return value
///     }
///     set {
///       self[MyServiceKey.self] = newValue
///       TCAAutoSyncContainer.autoSyncToWeaveDI(MyService.self, value: newValue)
///     }
///   }
/// }
/// ```
/// 🎯 **실용적인 @AutoSyncProperty 매크로**
/// 기존 property 옆에 동기화 버전을 생성하는 PeerMacro
///
/// ## 사용법:
/// ```swift
/// extension DependencyValues {
///   @AutoSyncProperty(key: MyServiceKey.self)
///   var myService: MyService {
///     get { self[MyServiceKey.self] }
///     set { self[MyServiceKey.self] = newValue }
///   }
/// }
/// ```
///
/// ## 생성 결과: 기존 property는 그대로 두고 동기화 버전 추가
/// ```swift
/// extension DependencyValues {
///   // 기존 property (그대로 유지)
///   var myService: MyService {
///     get { self[MyServiceKey.self] }
///     set { self[MyServiceKey.self] = newValue }
///   }
///
///   // 매크로가 자동 생성하는 동기화 property
///   var myServiceAutoSync: MyService {
///     get {
///       let value = self[MyServiceKey.self]
///       TCAAutoSyncContainer.autoSyncToWeaveDI(MyService.self, value: value)
///       return value
///     }
///     set {
///       self[MyServiceKey.self] = newValue
///       TCAAutoSyncContainer.autoSyncToWeaveDI(MyService.self, value: newValue)
///     }
///   }
/// }
/// ```
public struct AutoSyncPropertyMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        guard let varDecl = declaration.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
              let type = binding.typeAnnotation?.type else {
            return []
        }

        // 매크로 arguments에서 key 추출
        let keyExpression: String
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self),
           let keyArg = arguments.first(where: { $0.label?.text == "key" }) {
            keyExpression = "\(keyArg.expression)"
        } else {
            // key 파라미터가 없으면 기본 패턴 사용
            keyExpression = "\(identifier.text.capitalized)Key.self"
        }

        let autoSyncPropertyName = "\(identifier.text)AutoSync"

        // 🎯 양방향 동기화 버전의 property 생성
        let autoSyncProperty = """
        var \(autoSyncPropertyName): \(type) {
            get {
                let value = self[\(keyExpression)]
                #if canImport(WeaveDI)
                TCASmartSync.autoDetectAndSync(\(keyExpression), value: value)
                if let reverseSyncValue = TCASmartSync.retrieveTCACompatibleValue(\(type).self) {
                    return reverseSyncValue
                }
                #endif
                return value
            }
            set {
                self[\(keyExpression)] = newValue
                #if canImport(WeaveDI)
                TCASmartSync.autoDetectAndSync(\(keyExpression), value: newValue)
                TCASmartSync.autoDetectWeaveDIRegistration(\(type).self, value: newValue)
                #endif
            }
        }
        """

        return [DeclSyntax(stringLiteral: autoSyncProperty)]
    }
}

// MARK: - GenerateAutoSyncMacro

/// 🎉 **완전 자동 생성 매크로**: 한 줄로 완전한 동기화 property 생성
///
/// ## 사용법:
/// ```swift
/// extension DependencyValues {
///   @GenerateAutoSync(key: MyServiceKey.self, type: MyService.self)
/// }
/// ```
public struct GenerateAutoSyncMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        // 매크로 arguments에서 key와 type 추출
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            return []
        }

        var keyExpression: String?
        var typeExpression: String?

        for argument in arguments {
            if argument.label?.text == "key" {
                keyExpression = "\(argument.expression)"
            } else if argument.label?.text == "type" {
                typeExpression = "\(argument.expression)"
            }
        }

        guard let keyExpr = keyExpression, let _ = typeExpression else {
            return []
        }

        // property 이름 생성 (MyServiceKey.self -> myService)
        let propertyName = extractPropertyName(from: keyExpr)

        // typeExpr에서 .self 제거 (타입만 추출)
        let cleanTypeExpr = typeExpression?.replacingOccurrences(of: ".self", with: "") ?? "Any"

        // 🎯 완전한 양방향 동기화 property 생성
        let autoSyncProperty = """
        var \(propertyName): \(cleanTypeExpr) {
            get {
                let value = self[\(keyExpr)]
                #if canImport(WeaveDI)
                TCASmartSync.autoDetectAndSync(\(keyExpr), value: value)
                if let reverseSyncValue = TCASmartSync.retrieveTCACompatibleValue(\(cleanTypeExpr).self) {
                    return reverseSyncValue
                }
                #endif
                return value
            }
            set {
                self[\(keyExpr)] = newValue
                #if canImport(WeaveDI)
                TCASmartSync.autoDetectAndSync(\(keyExpr), value: newValue)
                TCASmartSync.autoDetectWeaveDIRegistration(\(cleanTypeExpr).self, value: newValue)
                #endif
            }
        }
        """

        return [DeclSyntax(stringLiteral: autoSyncProperty)]
    }

    /// MyServiceKey.self -> myService로 변환
    private static func extractPropertyName(from keyExpression: String) -> String {
        let cleaned = keyExpression.replacingOccurrences(of: ".self", with: "")

        // "MyServiceKey" -> "myService"
        if cleaned.hasSuffix("Key") {
            let withoutKey = String(cleaned.dropLast(3)) // "Key" 제거
            return withoutKey.prefix(1).lowercased() + withoutKey.dropFirst()
        }

        // 기본 변환: 첫 글자만 소문자로
        return cleaned.prefix(1).lowercased() + cleaned.dropFirst()
    }
}

// MARK: - AutoSyncMacro (Main)

/// 🎯 **양방향 @AutoSync 매크로**: 한 줄로 TCA ↔ WeaveDI 완전 자동 동기화!
///
/// ## 사용법 (한 줄로 양방향 동기화):
/// ```swift
/// // TCA DependencyValues → WeaveDI 동기화
/// @AutoSync  // ← 이것만 추가하면 양방향 동기화!
/// extension DependencyValues {
///   var service1: Service1 { get { self[Service1Key.self] } set { self[Service1Key.self] = newValue } }
///   var service2: Service2 { get { self[Service2Key.self] } set { self[Service2Key.self] = newValue } }
/// }
///
/// // WeaveDI InjectedValues → TCA 동기화
/// @AutoSync  // ← InjectedValues도 지원!
/// extension InjectedValues {
///   var service1: Service1 { get { self[Service1Key.self] } set { self[Service1Key.self] = newValue } }
/// }
/// ```
///
/// ## 자동 생성되는 기능:
/// - TCA DependencyKey → WeaveDI InjectedKey ✅
/// - WeaveDI InjectedKey → TCA DependencyKey ✅
/// - 자동 감지 및 동기화 ✅
/// - TestDependencyKey 호환성 해결 ✅
///
/// ## 사용 전 필수 호출:
/// ```swift
/// // AppDelegate 또는 main에서 한 번 호출
/// enableBidirectionalTCASync()
/// ```
public struct AutoSyncMacro: MemberMacro {

    /// 🎯 사용자가 원하는 @AutoSync: extension 내 모든 computed property의 동기화 버전을 자동 생성
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        // DependencyValues 또는 InjectedValues extension인지 확인
        guard let extensionDecl = declaration.as(ExtensionDeclSyntax.self) else {
            return []
        }

        let extendedTypeName = "\(extensionDecl.extendedType)"
        let isDependencyValues = extendedTypeName.contains("DependencyValues")
        let isInjectedValues = extendedTypeName.contains("InjectedValues")

        guard isDependencyValues || isInjectedValues else {
            return []
        }

        var autoSyncMembers: [DeclSyntax] = []

        // extension 내의 모든 computed property를 찾아서 동기화 버전 생성
        for member in extensionDecl.memberBlock.members {
            if let varDecl = member.decl.as(VariableDeclSyntax.self),
               let binding = varDecl.bindings.first,
               let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
               binding.accessorBlock != nil,
               let type = binding.typeAnnotation?.type {

                // property 이름과 타입 추출
                let propertyName = "\(identifier)"
                let propertyType = "\(type)"

                // 실제 accessor body에서 사용되는 Key 추출
                let keyName = extractKeyFromAccessor(binding.accessorBlock) ?? "\(propertyName.prefix(1).uppercased())\(propertyName.dropFirst())Key"

                // 🎯 양방향 동기화 property 생성 (DependencyValues vs InjectedValues에 따라 다른 로직)
                let autoSyncProperty: String
                if isDependencyValues {
                    // TCA DependencyValues → WeaveDI 중심 동기화
                    autoSyncProperty = """
                    var \(propertyName)Sync: \(propertyType) {
                        get {
                            // 🔄 1. TCA → WeaveDI 동기화
                            let value = self[\(keyName).self]
                            #if canImport(WeaveDI)
                            TCASmartSync.autoDetectAndSync(\(keyName).self, value: value)
                            #endif

                            // 🔄 2. WeaveDI → TCA 역방향 동기화 (기존 값이 있다면)
                            #if canImport(WeaveDI)
                            if let reverseSyncValue = TCASmartSync.retrieveTCACompatibleValue(\(propertyType).self) {
                                return reverseSyncValue
                            }
                            #endif

                            return value
                        }
                        set {
                            // 🔄 1. TCA 저장
                            self[\(keyName).self] = newValue

                            // 🔄 2. WeaveDI 양방향 동기화
                            #if canImport(WeaveDI)
                            TCASmartSync.autoDetectAndSync(\(keyName).self, value: newValue)
                            TCASmartSync.autoDetectWeaveDIRegistration(\(propertyType).self, value: newValue)
                            #endif
                        }
                    }
                    """
                } else {
                    // WeaveDI InjectedValues → TCA 중심 동기화
                    autoSyncProperty = """
                    var \(propertyName)Sync: \(propertyType) {
                        get {
                            // 🔄 1. WeaveDI → TCA 역방향 동기화
                            let value = self[\(keyName).self]
                            #if canImport(WeaveDI)
                            TCASmartSync.autoDetectWeaveDIRegistration(\(propertyType).self, value: value)
                            #endif

                            // 🔄 2. TCA에서 동기화된 값 확인
                            #if canImport(WeaveDI)
                            if let tcaSyncValue = TCASmartSync.retrieveTCACompatibleValue(\(propertyType).self) {
                                return tcaSyncValue
                            }
                            #endif

                            return value
                        }
                        set {
                            // 🔄 1. WeaveDI 저장
                            self[\(keyName).self] = newValue

                            // 🔄 2. TCA 양방향 동기화
                            #if canImport(WeaveDI)
                            TCASmartSync.autoDetectWeaveDIRegistration(\(propertyType).self, value: newValue)
                            #endif
                        }
                    }
                    """
                }

                autoSyncMembers.append(DeclSyntax(stringLiteral: autoSyncProperty))
            }
        }

        // 🎯 수동 초기화: 사용자가 enableBidirectionalTCASync() 호출 필요
        // 자동 초기화는 중복 선언 문제로 제거함

        return autoSyncMembers
    }

    /// accessor body를 분석해서 실제 사용되는 Key 이름을 추출
    private static func extractKeyFromAccessor(_ accessorBlock: AccessorBlockSyntax?) -> String? {
        guard let accessorBlock = accessorBlock else { return nil }

        // accessorBlock 전체를 문자열로 변환해서 Key 패턴 찾기
        let blockString = "\(accessorBlock)"

        // self[SomeKey.self] 패턴 추출
        return extractKeyPattern(from: blockString)
    }

    /// 문자열에서 self[SomeKey.self] 패턴의 Key 이름 추출
    private static func extractKeyPattern(from text: String) -> String? {
        // self[SomeKey.self] 패턴 찾기
        let pattern = #"self\[([A-Za-z0-9_]+)\.self\]"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let keyRange = Range(match.range(at: 1), in: text) {
            return String(text[keyRange])
        }
        return nil
    }
}

// MARK: - AutoSyncToWeaveDIMacro (Legacy)

/// TCA DependencyValues extension 전체에 자동 동기화를 추가하는 매크로 (Legacy)
public struct AutoSyncToWeaveDIMacro: MemberAttributeMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // computed property인 경우 AutoSyncProperty 매크로 추가
        guard let varDecl = member.as(VariableDeclSyntax.self),
              varDecl.bindings.allSatisfy({ $0.accessorBlock != nil }) else {
            return []
        }

        return [
            AttributeSyntax(
                attributeName: IdentifierTypeSyntax(
                    name: .identifier("AutoSyncProperty")
                )
            )
        ]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        return []
    }
}

// MARK: - AutoSyncExtensionMacro

/// TCA DependencyValues extension 전체에 멤버별 자동 동기화를 적용하는 매크로
public struct AutoSyncExtensionMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // computed property인 경우에만 AutoSyncProperty 매크로 추가
        guard let varDecl = member.as(VariableDeclSyntax.self),
              varDecl.bindings.allSatisfy({ $0.accessorBlock != nil }) else {
            return []
        }

        return [
            AttributeSyntax(
                attributeName: IdentifierTypeSyntax(
                    name: .identifier("AutoSyncProperty")
                )
            )
        ]
    }
}

// MARK: - Error Types

enum AutoSyncMacroError: Error, CustomStringConvertible {
    case invalidDeclaration
    case unsupportedType

    var description: String {
        switch self {
        case .invalidDeclaration:
            return "AutoSync macro can only be applied to computed properties in DependencyValues extensions"
        case .unsupportedType:
            return "AutoSync macro requires a type that conforms to Sendable"
        }
    }
}

// MARK: - Compiler Plugin

// Note: @main plugin은 Plugin.swift에서 처리됨
// 모든 매크로는 WeaveDIPlugin에 등록되어 있음