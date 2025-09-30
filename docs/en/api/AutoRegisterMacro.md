---
title: AutoRegisterMacro
lang: en-US
---

# AutoRegisterMacro

AutoRegister 매크로 - 자동으로 의존성을 등록합니다.
사용법:
```swift
@AutoRegister
class UserService: UserServiceProtocol {
    // 자동으로 UnifiedDI.register(UserServiceProtocol.self) { UserService() } 생성
}
```

```swift
public struct AutoRegisterMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
}
```

