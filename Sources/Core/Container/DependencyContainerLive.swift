//
//  DependencyContainerLive.swift
//  DiContainer
//
//  Created by 서원지 on 6/8/24.
//

import Foundation
import LogMacro

// MARK: - Live Container

public extension DependencyContainer {
    /// 애플리케이션 전역에서 사용하는 **라이브 컨테이너**입니다.
    ///
    /// 내부 레지스트리가 동시성 안전하므로 별도의 락 없이 보관합니다.
    nonisolated(unsafe) private static var _liveContainer = DependencyContainer()

    /// 현재 라이브 컨테이너. 부트스트랩 완료 시 코디네이터를 통해 교체됩니다.
    static var live: DependencyContainer {
        get { _liveContainer }
        set { _liveContainer = newValue }
    }

    /// 부트스트랩 과정을 직렬화하는 **코디네이터 액터**입니다.
    ///
    /// - Note: 외부에 노출되지 않는 내부 구현체입니다.
    internal actor BootstrapCoordinator {
        private var didBootstrap = false
        private var liveContainer = DependencyContainer()

        /// 현재 부트스트랩 여부를 반환합니다.
        internal func isBootstrapped() -> Bool { didBootstrap }

        /// 부트스트랩 플래그를 설정합니다.
        internal func setBootstrapped(_ value: Bool) { didBootstrap = value }

        /// 현재 라이브 컨테이너를 반환합니다.
        internal func getLiveContainer() -> DependencyContainer { liveContainer }

        /// 라이브 컨테이너를 교체합니다.
        internal func setLiveContainer(_ container: DependencyContainer) { liveContainer = container }

        /// 아직 부트스트랩되지 않았다면 동기 구성 클로저로 부트스트랩합니다.
        ///
        /// - Parameter configure: 새 컨테이너를 구성하는 클로저
        /// - Returns: `(성공 여부, 컨테이너)`
        /// - Throws: 구성 중 발생한 오류
        internal func bootstrapIfNotAlready(
            _ configure: (DependencyContainer) throws -> Void
        ) throws -> (success: Bool, container: DependencyContainer) {
            guard !didBootstrap else { return (false, liveContainer) }
            let container = DependencyContainer()
            try configure(container)
            liveContainer = container
            didBootstrap = true
            return (true, container)
        }

        /// 아직 부트스트랩되지 않았다면 **비동기 구성 클로저**로 부트스트랩합니다.
        ///
        /// - Parameter configure: 새 컨테이너를 비동기 구성하는 클로저
        /// - Returns: `(성공 여부, 컨테이너)`
        /// - Throws: 구성 중 발생한 오류
        internal func asyncBootstrapIfNotAlready(
            _ configure: @Sendable (DependencyContainer) async throws -> Void
        ) async throws -> (success: Bool, container: DependencyContainer) {
            guard !didBootstrap else { return (false, liveContainer) }
            let container = DependencyContainer()
            try await configure(container)
            liveContainer = container
            didBootstrap = true
            return (true, container)
        }

        /// 테스트를 위해 상태를 리셋합니다. (DEBUG 전용)
        internal func resetForTesting() {
            #if DEBUG
            didBootstrap = false
            liveContainer = DependencyContainer()
            #endif
        }
    }

    /// 부트스트랩 코디네이터 싱글턴입니다.
    internal static let coordinator = BootstrapCoordinator()
}