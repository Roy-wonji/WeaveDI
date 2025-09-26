//
//  AutoRegisterMacro.swift
//  DiContainer
//
//  Created by Wonji Suh on 2024.
//  Copyright © 2024 Wonji Suh. All rights reserved.
//

/// ## 🎯 @AutoRegister - 자동 의존성 등록
///
/// 클래스나 구조체에 이 어노테이션을 추가하면 자동으로 UnifiedDI에 등록됩니다.
/// 프로토콜을 구현하는 경우 해당 프로토콜 타입으로도 자동 등록됩니다.
///
/// ### 기본 사용법:
/// ```swift
/// @AutoRegister
/// class UserService: UserServiceProtocol {
///     // 자동 생성: UnifiedDI.register(UserServiceProtocol.self) { UserService() }
///     // 자동 생성: UnifiedDI.register(UserService.self) { UserService() }
/// }
/// ```
///
/// ### 라이프타임 지정:
/// ```swift
/// @AutoRegister(lifetime: .transient)
/// class TemporaryService {
///     // 매번 새 인스턴스 생성
/// }
/// ```
///
/// ### 지원하는 라이프타임:
/// - `.singleton`: 단일 인스턴스 (기본값)
/// - `.transient`: 매번 새 인스턴스
/// - `.scoped`: 스코프별 인스턴스
@attached(peer, names: arbitrary)
public macro AutoRegister(lifetime: DILifetime = .singleton) = #externalMacro(module: "DiContainerMacros", type: "AutoRegisterMacro")

/// 의존성 생명주기 타입
public enum DILifetime {
    case singleton
    case transient
    case scoped
}