//
//  DIContainer.swift
//  DiContainer
//
//  Created by Wonji Suh on 2024.
//  Copyright © 2024 Wonji Suh. All rights reserved.
//

import Foundation
import LogMacro
import Combine

// MARK: - DIContainer

/// ## 개요
///
/// `DIContainer`는 현대적이고 직관적인 의존성 주입 컨테이너입니다.
/// 기존의 여러 Container 클래스들을 하나로 통합하여 단순화했습니다.
///
/// ## 핵심 특징
///
/// ### 🔒 스레드 안전성
/// - **타입 안전한 레지스트리**: TypeSafeRegistry 사용
/// - **동시성 지원**: Swift Concurrency와 완벽 호환
/// - **멀티스레드 안전**: 여러 스레드에서 동시 접근 가능
///
/// ### 📝 통합된 등록 시스템
/// - **즉시 등록**: `register(_:factory:)` - 바로 사용 가능
/// - **인스턴스 등록**: `register(_:instance:)` - 이미 생성된 객체
/// - **KeyPath 지원**: `\.keyPath` 방식으로 타입 안전 보장
/// - **모듈 시스템**: 대량 등록을 위한 Module 패턴
///
/// ### 🚀 부트스트랩 시스템
/// - **안전한 초기화**: 앱 시작 시 의존성 준비
/// - **원자적 교체**: 컨테이너 전체를 한 번에 교체
/// - **테스트 지원**: 테스트 간 격리 보장
public final class DIContainer: @unchecked Sendable, ObservableObject {

    // MARK: - Properties

    /// 타입 안전한 의존성 저장소
    private let typeSafeRegistry = TypeSafeRegistry()

    /// 모듈 기반 일괄 등록을 위한 모듈 배열
    private var modules: [Module] = []

    /// 스레드 안전한 shared 인스턴스 관리
    private nonisolated(unsafe) static var instance = DIContainer()

    /// 전역 인스턴스
    public static var shared: DIContainer {
        get { instance }
        set { instance = newValue }
    }

    // MARK: - Initialization

    /// 빈 컨테이너를 생성합니다
    public init() {}

    // MARK: - Core Registration API

    /// 의존성을 등록하고 즉시 생성된 인스턴스를 반환합니다
    ///
    /// 팩토리를 즉시 실행하여 인스턴스를 생성하고, 컨테이너에 등록한 후 반환합니다.
    /// 가장 직관적이고 권장되는 등록 방법입니다.
    ///
    /// - Parameters:
    ///   - type: 등록할 타입
    ///   - factory: 인스턴스를 생성하는 클로저
    /// - Returns: 생성된 인스턴스
    ///
    /// ### 사용 예시:
    /// ```swift
    /// let repository = container.register(UserRepository.self) {
    ///     UserRepositoryImpl()
    /// }
    /// ```
    @discardableResult
    public func register<T>(
        _ type: T.Type,
        factory: @escaping @Sendable () -> T
    ) -> T where T: Sendable {
        let instance = factory()
        typeSafeRegistry.register(type, instance: instance)

        // 🚀 자동 그래프 추적
        AutoDIOptimizer.shared.trackRegistration(type)

        Log.debug("Registered instance for \(String(describing: type))")
        return instance
    }

    /// 팩토리 패턴으로 의존성을 등록합니다 (지연 생성)
    ///
    /// 실제 `resolve` 호출 시에만 팩토리가 실행되어 매번 새로운 인스턴스가 생성됩니다.
    /// 메모리 효율성이 중요하거나 생성 비용이 높은 경우 사용합니다.
    ///
    /// - Parameters:
    ///   - type: 등록할 타입
    ///   - factory: 인스턴스를 생성하는 클로저
    /// - Returns: 등록 해제 핸들러
    @discardableResult
    public func register<T>(
        _ type: T.Type,
        build factory: @escaping @Sendable () -> T
    ) -> @Sendable () -> Void {
        let releaseHandler = typeSafeRegistry.register(type, factory: factory)

        // 🚀 자동 그래프 추적
        AutoDIOptimizer.shared.trackRegistration(type)

        Log.debug("Registered factory for \(String(describing: type))")
        return releaseHandler
    }

    /// 이미 생성된 인스턴스를 등록합니다
    ///
    /// - Parameters:
    ///   - type: 등록할 타입
    ///   - instance: 등록할 인스턴스
    public func register<T>(
        _ type: T.Type,
        instance: T
    ) where T: Sendable {
        typeSafeRegistry.register(type, instance: instance)

        // 🚀 자동 그래프 추적
        AutoDIOptimizer.shared.trackRegistration(type)

        Log.debug("Registered instance for \(String(describing: type))")
    }

    // MARK: - Core Resolution API

    /// 등록된 의존성을 조회합니다
    ///
    /// 의존성이 등록되지 않은 경우 nil을 반환하므로 안전하게 처리할 수 있습니다.
    ///
    /// - Parameter type: 조회할 타입
    /// - Returns: 해결된 인스턴스 (없으면 nil)
    public func resolve<T>(_ type: T.Type) -> T? {
        // 🚀 자동 성능 최적화 추적
        AutoDIOptimizer.shared.trackResolution(type)

        if let result = typeSafeRegistry.resolve(type) {
            Log.debug("Resolved \(String(describing: type))")
            return result
        }

        // 🚨 자동 타입 안전성 처리
        AutoDIOptimizer.shared.handleNilResolution(type)

        Log.error("No registered dependency found for \(String(describing: type))")
        return nil
    }

    /// 의존성을 조회하거나 기본값을 반환합니다
    ///
    /// - Parameters:
    ///   - type: 조회할 타입
    ///   - defaultValue: 해결 실패 시 사용할 기본값
    /// - Returns: 해결된 인스턴스 또는 기본값
    public func resolveOrDefault<T>(
        _ type: T.Type,
        default defaultValue: @autoclosure () -> T
    ) -> T {
        resolve(type) ?? defaultValue()
    }

    /// 특정 타입의 의존성 등록을 해제합니다
    ///
    /// - Parameter type: 해제할 타입
    public func release<T>(_ type: T.Type) {
        typeSafeRegistry.release(type)
        Log.debug("Released \(String(describing: type))")
    }

    // MARK: - KeyPath Support

    /// KeyPath 기반 의존성 조회 서브스크립트
    ///
    /// - Parameter keyPath: DependencyContainer의 T?를 가리키는 키패스
    /// - Returns: resolve(T.self) 결과
    public subscript<T>(keyPath: KeyPath<DIContainer, T?>) -> T? {
        get { resolve(T.self) }
    }

    // MARK: - Module System

    /// 모듈을 컨테이너에 추가합니다
    ///
    /// 실제 등록은 `buildModules()` 호출 시에 병렬로 처리됩니다.
    ///
    /// - Parameter module: 등록 예약할 Module 인스턴스
    /// - Returns: 체이닝을 위한 현재 컨테이너 인스턴스
    @discardableResult
    public func addModule(_ module: Module) -> Self {
        modules.append(module)
        return self
    }

    /// 수집된 모든 모듈의 등록을 병렬로 실행합니다
    ///
    /// TaskGroup을 사용하여 모든 모듈을 동시에 병렬 처리합니다.
    /// 대량의 의존성 등록 시간을 크게 단축할 수 있습니다.
    public func buildModules() async {
        let snapshot = modules
        let processedCount = snapshot.count

        guard !snapshot.isEmpty else { return }

        // 병렬 실행 + 전체 완료 대기
        await withTaskGroup(of: Void.self) { group in
            for module in snapshot {
                group.addTask { @Sendable in
                    await module.register()
                }
            }
            await group.waitForAll()
        }

        // 처리된 모듈 제거
        if modules.count >= processedCount {
            modules.removeFirst(processedCount)
        } else {
            modules.removeAll()
        }

        Log.debug("Built \(processedCount) modules")
    }

    /// 성능 메트릭과 함께 모듈을 빌드합니다
    ///
    /// - Returns: 빌드 실행 통계
    public func buildModulesWithMetrics() async -> ModuleBuildMetrics {
        let startTime = CFAbsoluteTimeGetCurrent()
        let initialCount = modules.count

        await buildModules()

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        return ModuleBuildMetrics(
            moduleCount: initialCount,
            duration: duration,
            modulesPerSecond: initialCount > 0 ? Double(initialCount) / duration : 0
        )
    }

    /// 현재 등록 대기 중인 모듈의 개수를 반환합니다
    public var moduleCount: Int {
        modules.count
    }

    /// 컨테이너가 비어있는지 확인합니다
    public var isEmpty: Bool {
        modules.isEmpty
    }

    /// 모듈을 등록하는 편의 메서드
    public func register(_ module: Module) async {
        modules.append(module)
        await module.register()
    }

    /// 함수 호출 스타일을 지원하는 메서드 (체이닝용)
    @discardableResult
    public func callAsFunction(_ configure: () -> Void = {}) -> Self {
        configure()
        return self
    }

    /// 모듈 빌드 메서드 (기존 buildModules와 동일)
    public func build() async {
        await buildModules()
    }
}

// MARK: - Bootstrap System

public extension DIContainer {

    /// 컨테이너를 부트스트랩합니다 (동기 등록)
    ///
    /// 앱 시작 시 의존성을 안전하게 초기화하기 위한 메서드입니다.
    /// 원자적으로 컨테이너를 교체하여 초기화 경합을 방지합니다.
    ///
    /// - Parameter configure: 의존성 등록 클로저
    static func bootstrap(_ configure: @Sendable (DIContainer) -> Void) async {
        let newContainer = DIContainer()
        configure(newContainer)
        Self.shared = newContainer
        Log.debug("Container bootstrapped (sync)")
    }

    /// 컨테이너를 부트스트랩합니다 (비동기 등록)
    ///
    /// 비동기 초기화가 필요한 의존성(예: 데이터베이스, 원격 설정)이 있을 때 사용합니다.
    ///
    /// - Parameter configure: 비동기 의존성 등록 클로저
    @discardableResult
    static func bootstrapAsync(_ configure: @Sendable (DIContainer) async throws -> Void) async -> Bool {
        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            Log.debug("Starting Container async bootstrap...")

            let newContainer = DIContainer()
            try await configure(newContainer)
            Self.shared = newContainer

            let duration = CFAbsoluteTimeGetCurrent() - startTime
            Log.debug("Container bootstrapped successfully in \(String(format: "%.3f", duration))s")
            return true
        } catch {
            Log.error("Container bootstrap failed: \(error)")
            #if DEBUG
            fatalError("Container bootstrap failed: \(error)")
            #else
            return false
            #endif
        }
    }

    /// 별도의 Task 컨텍스트에서 비동기 부트스트랩을 수행하는 편의 메서드입니다
    static func bootstrapInTask(_ configure: @Sendable @escaping (DIContainer) async throws -> Void) {
        Task.detached(priority: .high) {
            let success = await bootstrapAsync(configure)
            if success {
                await MainActor.run { Log.debug("Container bootstrap completed in background task") }
            } else {
                await MainActor.run { Log.error("Container bootstrap failed in background task") }
            }
        }
    }

    /// 혼합 부트스트랩 (동기 + 비동기)
    ///
    /// - Parameters:
    ///   - sync: 즉시 필요한 의존성 등록
    ///   - async: 비동기 초기화가 필요한 의존성 등록
    @MainActor
    static func bootstrapMixed(
        sync: @Sendable (DIContainer) -> Void,
        async: @Sendable (DIContainer) async -> Void
    ) async {
        let newContainer = DIContainer()
        // 1) 동기 등록
        sync(newContainer)
        Log.debug("Core dependencies registered synchronously")
        // 2) 비동기 등록
        await async(newContainer)
        Log.debug("Extended dependencies registered asynchronously")

        Self.shared = newContainer
        Log.debug("Container bootstrapped with mixed dependencies")
    }

    /// 이미 부트스트랩되어 있지 않은 경우에만 실행합니다
    ///
    /// - Parameter configure: 의존성 등록 클로저
    /// - Returns: 부트스트랩이 수행되었는지 여부
    @discardableResult
    static func bootstrapIfNeeded(_ configure: @Sendable (DIContainer) -> Void) async -> Bool {
        // 간단한 체크: shared 인스턴스가 비어있으면 부트스트랩
        if shared.isEmpty {
            await bootstrap(configure)
            return true
        }
        Log.debug("Container bootstrap skipped - already initialized")
        return false
    }

    /// 이미 부트스트랩되어 있지 않은 경우에만 비동기 부트스트랩을 수행합니다
    @discardableResult
    static func bootstrapAsyncIfNeeded(_ configure: @Sendable (DIContainer) async throws -> Void) async -> Bool {
        if shared.isEmpty {
            return await bootstrapAsync(configure)
        } else {
            Log.debug("Container bootstrap skipped - already initialized")
            return false
        }
    }

    /// 런타임에 의존성을 업데이트합니다 (동기)
    ///
    /// - Parameter configure: 업데이트할 의존성 등록 클로저
    static func update(_ configure: @Sendable (DIContainer) -> Void) async {
        configure(shared)
        Log.debug("Container updated (sync)")
    }

    /// 런타임에 의존성을 업데이트합니다 (비동기)
    ///
    /// - Parameter configure: 비동기 업데이트 클로저
    static func updateAsync(_ configure: @Sendable (DIContainer) async -> Void) async {
        await configure(shared)
        Log.debug("Container updated (async)")
    }

    /// DI 컨테이너 접근 전, 부트스트랩이 완료되었는지를 보장합니다
    static func ensureBootstrapped(
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        precondition(
            isBootstrapped,
            "DI not bootstrapped. Call DIContainer.bootstrap(...) first.",
            file: file,
            line: line
        )
    }

    /// 테스트를 위해 컨테이너를 초기화합니다
    ///
    /// ⚠️ DEBUG 빌드에서만 사용 가능합니다.
    @MainActor
    static func resetForTesting() {
        #if DEBUG
        Self.shared = DIContainer()
        Log.debug("Container reset for testing")
        #else
        fatalError("resetForTesting() is only available in DEBUG builds")
        #endif
    }

    /// 부트스트랩 상태를 확인합니다
    static var isBootstrapped: Bool {
        !shared.isEmpty
    }
}

// MARK: - Legacy Compatibility

/// 기존 DependencyContainer와의 호환성을 위한 별칭
public typealias DependencyContainer = DIContainer

/// 기존 Container와의 호환성을 위한 별칭
public typealias Container = DIContainer

/// DependencyContainer.live 호환성
public extension DIContainer {
    static var live: DIContainer {
        get { shared }
        set { shared = newValue }
    }
}

// MARK: - Factory KeyPath Extensions

/// Factory 타입들을 위한 KeyPath 확장
public extension DIContainer {

    /// Repository 모듈 팩토리 KeyPath
    var repositoryFactory: RepositoryModuleFactory? {
        resolve(RepositoryModuleFactory.self)
    }

    /// UseCase 모듈 팩토리 KeyPath
    var useCaseFactory: UseCaseModuleFactory? {
        resolve(UseCaseModuleFactory.self)
    }

    /// Scope 모듈 팩토리 KeyPath
    var scopeFactory: ScopeModuleFactory? {
        resolve(ScopeModuleFactory.self)
    }

    /// 모듈 팩토리 매니저 KeyPath
    var moduleFactoryManager: ModuleFactoryManager? {
        resolve(ModuleFactoryManager.self)
    }
}

// MARK: - Build Metrics

/// 모듈 빌드 실행 통계 정보
public struct ModuleBuildMetrics {
    /// 처리된 모듈 수
    public let moduleCount: Int

    /// 총 실행 시간 (초)
    public let duration: TimeInterval

    /// 초당 처리 모듈 수
    public let modulesPerSecond: Double

    /// 포맷된 요약 정보
    public var summary: String {
        return """
        Module Build Metrics:
        - Modules: \(moduleCount)
        - Duration: \(String(format: "%.3f", duration))s
        - Rate: \(String(format: "%.1f", modulesPerSecond)) modules/sec
        """
    }
}

// MARK: - Auto DI Features

/// 자동 의존성 주입 기능 확장
public extension DIContainer {

    /// 🚀 자동 생성된 의존성 그래프를 시각화합니다
    ///
    /// 별도 설정 없이 자동으로 수집된 의존성 관계를 텍스트로 출력합니다.
    var autoGeneratedGraph: String {
        AutoDIOptimizer.shared.visualizeGraph()
    }

    /// ⚡ 자동 최적화된 타입들을 반환합니다
    ///
    /// 사용 패턴을 분석하여 자동으로 성능 최적화가 적용된 타입들의 목록입니다.
    var optimizedTypes: Set<String> {
        AutoDIOptimizer.shared.frequentlyUsedTypes
    }

    /// ⚠️ 자동 감지된 순환 의존성을 반환합니다
    ///
    /// 의존성 등록/해결 과정에서 자동으로 감지된 순환 의존성 목록입니다.
    var detectedCircularDependencies: Set<String> {
        AutoDIOptimizer.shared.detectedCircularDependencies
    }

    /// 📊 자동 수집된 성능 통계를 반환합니다
    ///
    /// 각 타입의 사용 빈도가 자동으로 추적됩니다.
    var usageStatistics: [String: Int] {
        AutoDIOptimizer.shared.currentStats
    }

    /// 🔍 특정 타입이 자동 최적화되었는지 확인합니다
    ///
    /// - Parameter type: 확인할 타입
    /// - Returns: 최적화 여부
    func isAutoOptimized<T>(_ type: T.Type) -> Bool {
        AutoDIOptimizer.shared.isOptimized(type)
    }

    /// ⚙️ 자동 최적화 기능을 제어합니다
    ///
    /// - Parameter enabled: 활성화 여부 (기본값: true)
    func setAutoOptimization(_ enabled: Bool) {
        AutoDIOptimizer.shared.setOptimizationEnabled(enabled)
    }

    /// 🧹 자동 수집된 통계를 초기화합니다
    func resetAutoStats() {
        AutoDIOptimizer.shared.resetStats()
    }
}