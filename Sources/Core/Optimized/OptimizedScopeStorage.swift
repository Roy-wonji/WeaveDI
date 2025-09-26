//
//  OptimizedScopeStorage.swift
//  WeaveDI
//
//  Created by Wonji Suh on 2025.
//

import Foundation

// MARK: - Once 초기화 시스템

/// 원자적 once 초기화
internal struct AtomicOnce {
    private var token: Int32 = 0

    mutating func execute(_ block: () -> Void) {
        if OSAtomicCompareAndSwap32(0, 1, &token) {
            block()
        }
    }

    var isExecuted: Bool {
        return token != 0
    }
}

/// 타입별 Once 관리자
internal final class OnceManager: @unchecked Sendable {
    private var onceTokens: [ObjectIdentifier: AtomicOnce] = [:]
    private let lock = NSLock()

    func executeOnce<T>(for type: T.Type, block: () -> Void) {
        let key = ObjectIdentifier(type)

        lock.lock()
        defer { lock.unlock() }

        if onceTokens[key] == nil {
            onceTokens[key] = AtomicOnce()
        }
        onceTokens[key]?.execute(block)
    }

    func isExecuted<T>(for type: T.Type) -> Bool {
        let key = ObjectIdentifier(type)
        lock.lock()
        defer { lock.unlock() }
        return onceTokens[key]?.isExecuted ?? false
    }
}

// MARK: - 스코프별 정적 저장소

/// 싱글톤 스코프 저장소 (once 보장)
internal final class SingletonStorage: @unchecked Sendable {
    private var instances: [ObjectIdentifier: Any] = [:]
    private var factories: [ObjectIdentifier: () -> Any] = [:]
    private let onceManager = OnceManager()
    private let lock = NSLock()

    /// Once 보장된 싱글톤 등록
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = ObjectIdentifier(type)

        lock.lock()
        factories[key] = { factory() }
        lock.unlock()
    }

    /// Once 보장된 싱글톤 해결
    @inlinable
    @inline(__always)
    func resolve<T>(_ type: T.Type) -> T? {
        let key = ObjectIdentifier(type)

        // 1. 이미 생성된 인스턴스 체크 (락-프리)
        if let instance = instances[key] as? T {
            return instance
        }

        // 2. Once 보장 초기화
        onceManager.executeOnce(for: type) { [weak self] in
            guard let self = self,
                  let factory = self.factories[key] else { return }

            let instance = factory()
            self.lock.lock()
            self.instances[key] = instance
            self.lock.unlock()
        }

        // 3. 초기화된 인스턴스 반환
        return instances[key] as? T
    }

    func remove<T>(_ type: T.Type) {
        let key = ObjectIdentifier(type)
        lock.lock()
        instances[key] = nil
        factories[key] = nil
        lock.unlock()
    }
}

/// 세션 스코프 저장소
internal final class SessionStorage: @unchecked Sendable {
    private var sessions: [String: [ObjectIdentifier: Any]] = [:]
    private var factories: [ObjectIdentifier: () -> Any] = [:]
    private let lock = NSLock()

    private var currentSessionID: String?

    func setCurrentSession(_ sessionID: String) {
        lock.lock()
        currentSessionID = sessionID
        if sessions[sessionID] == nil {
            sessions[sessionID] = [:]
        }
        lock.unlock()
    }

    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = ObjectIdentifier(type)
        lock.lock()
        factories[key] = { factory() }
        lock.unlock()
    }

    @inlinable
    @inline(__always)
    func resolve<T>(_ type: T.Type) -> T? {
        let key = ObjectIdentifier(type)

        lock.lock()
        defer { lock.unlock() }

        guard let sessionID = currentSessionID else { return nil }

        // 세션 내 인스턴스 체크
        if let instance = sessions[sessionID]?[key] as? T {
            return instance
        }

        // 팩토리로 생성
        guard let factory = factories[key] else { return nil }
        let instance = factory()

        // 세션에 저장
        if sessions[sessionID] == nil {
            sessions[sessionID] = [:]
        }
        sessions[sessionID]?[key] = instance

        return instance as? T
    }

    func clearSession(_ sessionID: String) {
        lock.lock()
        sessions[sessionID] = nil
        lock.unlock()
    }

    func clearCurrentSession() {
        lock.lock()
        if let sessionID = currentSessionID {
            sessions[sessionID] = nil
        }
        lock.unlock()
    }
}

/// 요청 스코프 저장소 (경량)
internal final class RequestStorage: @unchecked Sendable {
    private var currentRequest: [ObjectIdentifier: Any] = [:]
    private var factories: [ObjectIdentifier: () -> Any] = [:]
    private let lock = NSLock()

    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = ObjectIdentifier(type)
        lock.lock()
        factories[key] = { factory() }
        lock.unlock()
    }

    @inlinable
    @inline(__always)
    func resolve<T>(_ type: T.Type) -> T? {
        let key = ObjectIdentifier(type)

        lock.lock()
        defer { lock.unlock() }

        // 현재 요청 내 인스턴스 체크
        if let instance = currentRequest[key] as? T {
            return instance
        }

        // 팩토리로 생성
        guard let factory = factories[key] else { return nil }
        let instance = factory()
        currentRequest[key] = instance

        return instance as? T
    }

    func clearRequest() {
        lock.lock()
        currentRequest.removeAll()
        lock.unlock()
    }
}

// MARK: - 통합 스코프 관리자

/// 모든 스코프를 통합 관리하는 최적화된 저장소
internal final class OptimizedScopeManager: @unchecked Sendable {

    // 스코프별 전용 저장소
    private let singletonStorage = SingletonStorage()
    private let sessionStorage = SessionStorage()
    private let requestStorage = RequestStorage()

    /// 스코프별 등록
    @inlinable
    func register<T>(_ type: T.Type, scope: ScopeKind, factory: @escaping () -> T) {
        switch scope {
        case .singleton:
            singletonStorage.register(type, factory: factory)
        case .session:
            sessionStorage.register(type, factory: factory)
        case .request:
            requestStorage.register(type, factory: factory)
        }
    }

    /// 스코프별 해결 (최적화된 경로)
    @inlinable
    @inline(__always)
    func resolve<T>(_ type: T.Type, scope: ScopeKind) -> T? {
        switch scope {
        case .singleton:
            return singletonStorage.resolve(type)
        case .session:
            return sessionStorage.resolve(type)
        case .request:
            return requestStorage.resolve(type)
        }
    }

    /// 스코프 관리
    func setCurrentSession(_ sessionID: String) {
        sessionStorage.setCurrentSession(sessionID)
    }

    func clearScope(_ scope: ScopeKind) {
        switch scope {
        case .singleton:
            break // 싱글톤은 클리어하지 않음
        case .session:
            sessionStorage.clearCurrentSession()
        case .request:
            requestStorage.clearRequest()
        }
    }

    func clearSession(_ sessionID: String) {
        sessionStorage.clearSession(sessionID)
    }
}

// MARK: - Runtime Optimization Namespace

/// 런타임 최적화 관리 네임스페이스
internal enum RuntimeOptimization {

    /// 최적화 활성화 플래그
    static var isEnabled = false

    /// 공유 최적화 매니저
    static let sharedManager = OptimizedScopeManager()

    /// 최적화 통계
    static func getStats() -> (enabled: Bool, hitCount: Int, missCount: Int) {
        return (enabled: isEnabled, hitCount: 0, missCount: 0) // TODO: 실제 통계
    }
}