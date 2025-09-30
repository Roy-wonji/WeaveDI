//
//  AutoRegisterCollector.swift
//  WeaveDI
//
//  Created by Wonji Suh on 2025.
//  Copyright © 2025 Wonji Suh. All rights reserved.
//

import Foundation

/// @AutoRegister 타입들을 자동으로 수집하는 컬렉터
public final class AutoRegisterCollector: @unchecked Sendable {

    public static let shared = AutoRegisterCollector()

    private let lock = NSLock()
    private var registeredTypes: [Any.Type] = []

    private init() {}

    /// @AutoRegister 타입을 등록합니다
    public func register(_ type: Any.Type) {
        lock.lock()
        defer { lock.unlock() }
        registeredTypes.append(type)
    }

    /// 모든 @AutoRegister 타입들을 가져옵니다
    public func getAllTypes() -> [Any.Type] {
        lock.lock()
        defer { lock.unlock() }
        return registeredTypes
    }

    /// 모든 @AutoRegister 타입들을 강제로 로드합니다
    @discardableResult
    public func loadAll() -> Int {
        lock.lock()
        let types = registeredTypes
        lock.unlock()

        for type in types {
            _ = type
        }
        return types.count
    }

    /// 초기화
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        registeredTypes.removeAll()
    }
}