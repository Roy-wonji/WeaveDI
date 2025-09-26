//
//  ScopeSupport.swift
//  DiContainer
//
//  Created by Assistant on 2025-09-15.
//

import Foundation

/// 사전 정의된 스코프 종류
public enum ScopeKind: String, Hashable, Sendable {
    case singleton
    case screen
    case session
    case request
}

/// 스코프 식별자
public struct ScopeID: Hashable, Sendable {
    public let kind: ScopeKind
    public let id: String

    public init(kind: ScopeKind, id: String) {
        self.kind = kind
        self.id = id
    }
}

/// 타입 + 스코프 키 조합
public struct ScopedTypeKey: Hashable, Sendable {
    public let type: AnyTypeIdentifier
    public let scope: ScopeID

    public init(type: AnyTypeIdentifier, scope: ScopeID) {
        self.type = type
        self.scope = scope
    }
}

/// 현재 스코프 ID를 관리하는 컨텍스트
/// 간단한 동기화 큐로 안전하게 관리합니다.
public final class ScopeContext: @unchecked Sendable {
    public static let shared = ScopeContext()

    private let syncQueue = DispatchQueue(label: "com.diContainer.scopeContext", attributes: .concurrent)
    private var current: [ScopeKind: String] = [:]

    private init() {}

    public func setCurrent(_ kind: ScopeKind, id: String) {
        syncQueue.sync(flags: .barrier) {
            self.current[kind] = id
        }
    }

    public func clear(_ kind: ScopeKind) {
        syncQueue.sync(flags: .barrier) {
            self.current[kind] = nil
        }
    }

    public func currentID(for kind: ScopeKind) -> String? {
        syncQueue.sync { current[kind] }
    }
}

