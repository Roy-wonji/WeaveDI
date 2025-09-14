//
//  DIManagement.swift
//  DiContainer
//
//  Created by Claude on 2025-09-14.
//

import Foundation

// MARK: - DI Management & Introspection API

public extension DI {

    // MARK: - Management

    /// 등록된 의존성을 해제합니다
    /// - Parameter type: 해제할 타입
    static func release<T>(_ type: T.Type) {
        DependencyContainer.live.release(type)
    }

    /// 모든 등록된 의존성을 해제합니다 (테스트 용도)
    /// - Warning: 메인 스레드에서만 호출하세요
    @MainActor
    static func releaseAll() {
        // Implementation would need to be added to DependencyContainer
        // For now, create a new container
        DependencyContainer.live = DependencyContainer()

        #if DEBUG
        print("🧹 [DI] All registrations released - container reset")
        #endif
    }

    /// 비동기 환경에서 모든 등록을 해제합니다
    static func releaseAllAsync() async {
        await DIActorGlobalAPI.releaseAll()
    }

    // MARK: - Introspection

    /// 타입 기반 등록 여부 확인
    static func isRegistered<T>(_ type: T.Type) -> Bool {
        DependencyContainer.live.resolve(type) != nil
    }

    /// KeyPath 기반 등록 여부 확인
    static func isRegistered<T>(_ keyPath: KeyPath<DependencyContainer, T?>) -> Bool {
        isRegistered(T.self)
    }

    // MARK: - Container Status

    /// 현재 컨테이너의 상태 정보를 반환합니다
    static func getContainerStatus() async -> DIContainerStatus {
        return DIContainerStatus(
            isBootstrapped: await DependencyContainer.isBootstrapped,
            registrationCount: getApproximateRegistrationCount(),
            memoryUsage: getApproximateMemoryUsage()
        )
    }

    /// 컨테이너의 대략적인 등록 개수를 반환합니다 (디버그 용도)
    private static func getApproximateRegistrationCount() -> Int {
        // 실제 구현에서는 DependencyContainer의 내부 상태를 확인
        return 0 // Placeholder
    }

    /// 컨테이너의 대략적인 메모리 사용량을 반환합니다 (디버그 용도)
    private static func getApproximateMemoryUsage() -> Int {
        // 실제 구현에서는 메모리 프로파일링 도구 사용
        return 0 // Placeholder
    }
}

// MARK: - Container Status

/// DI 컨테이너의 현재 상태 정보
public struct DIContainerStatus {
    public let isBootstrapped: Bool
    public let registrationCount: Int
    public let memoryUsage: Int
    public let timestamp: Date

    public init(isBootstrapped: Bool, registrationCount: Int, memoryUsage: Int) {
        self.isBootstrapped = isBootstrapped
        self.registrationCount = registrationCount
        self.memoryUsage = memoryUsage
        self.timestamp = Date()
    }
}

// MARK: - Diagnostic Utilities

#if DEBUG
public extension DI {
    /// 디버그 정보를 출력합니다
    static func printDebugInfo() async {
        let status = await getContainerStatus()
        print("""
        📊 [DI Debug Info]
        ==================
        Bootstrap: \(status.isBootstrapped ? "✅" : "❌")
        Registrations: \(status.registrationCount)
        Memory Usage: \(status.memoryUsage) bytes
        Timestamp: \(status.timestamp)
        """)
    }

    /// 타입별 해결 성능을 테스트합니다
    static func performanceTest<T>(_ type: T.Type, iterations: Int = 1000) -> TimeInterval {
        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<iterations {
            _ = resolve(type)
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime

        print("🔬 [DI Performance] \(type): \(duration * 1000)ms for \(iterations) iterations")
        return duration
    }
}
#endif