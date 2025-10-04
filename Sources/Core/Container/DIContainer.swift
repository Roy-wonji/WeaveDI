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

// MARK: - Global Actor

/// DIContainer 전용 Global Actor (자동 정의)
@globalActor
public actor DIContainerActor {
  public static let shared = DIContainerActor()
}

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
/// - **Swift 6 동시성**: 기존 API는 동기, Actor API는 자동 생성
public final class DIContainer: ObservableObject, @unchecked Sendable {
  
  // MARK: - Properties
  
  /// 통합된 의존성 저장소 (UnifiedRegistry.shared 사용)
  /// 🔧 Fix: 모든 컨테이너가 동일한 UnifiedRegistry.shared 인스턴스를 사용하도록 수정
  private let unifiedRegistry = UnifiedRegistry.shared
  
  /// 모듈 기반 일괄 등록을 위한 모듈 배열 (동시성 안전: concurrent + barrier)
  private let modulesQueue = DispatchQueue(label: "com.diContainer.modules", attributes: .concurrent)
  private var modules: [Module] = []
  
  /// Parent-Child 관계 지원
  private let parent: DIContainer?
  private var children: [DIContainer] = []
  private let childrenQueue = DispatchQueue(label: "com.diContainer.children", attributes: .concurrent)
  
  /// Swift 6 완전 호환 shared 인스턴스 관리
  nonisolated(unsafe) private static var sharedContainer = DIContainer()
  private static let sharedLock = NSLock()
  
  /// 전역 인스턴스 (동기 API - 기존 호환성)
  public static var shared: DIContainer {
    get {
      sharedLock.lock()
      defer { sharedLock.unlock() }
      return sharedContainer
    }
    set {
      sharedLock.lock()
      defer { sharedLock.unlock() }
      sharedContainer = newValue
    }
  }
  
  // MARK: - Actor Protected API (자동 생성)
  
  /// @DIContainerActor로 보호된 shared 인스턴스
  @DIContainerActor
  public static var actorShared: DIContainer {
    get { shared }  // 내부적으로 락으로 보호됨
    set { shared = newValue }
  }
  
  /// Actor 보호하에 의존성 등록
  @DIContainerActor
  public static func registerAsync<T>(_ type: T.Type, factory: @Sendable @escaping () -> T) -> T where T: Sendable {
    return actorShared.register(type, factory: factory)
  }
  
  /// Actor 보호하에 의존성 해결
  @DIContainerActor
  public static func resolveAsync<T>(_ type: T.Type) -> T? where T: Sendable {
    return actorShared.resolve(type)
  }
  
  
  // MARK: - Initialization
  
  /// 빈 컨테이너를 생성합니다
  /// 기본 초기화 (루트 컨테이너)
  public init() {
    self.parent = nil
  }
  
  /// Parent-Child 초기화
  /// - Parameter parent: 부모 컨테이너 (의존성을 상속받음)
  public init(parent: DIContainer) {
    self.parent = parent
    
    // 부모에 자식으로 등록
    parent.childrenQueue.sync(flags: .barrier) {
      parent.children.append(self)
    }
  }
  
  // MARK: - Parent-Child Container API
  
  /// 새로운 자식 컨테이너를 생성합니다.
  /// 자식 컨테이너는 부모의 의존성을 상속받습니다.
  ///
  /// ### 사용법:
  /// ```swift
  /// let appContainer = DIContainer()
  /// appContainer.register(DatabaseService.self) { DatabaseImpl() }
  ///
  /// let userModule = appContainer.createChild()
  /// userModule.register(UserRepository.self) {
  ///     UserRepositoryImpl(database: resolve()) // 부모에서 Database 해결
  /// }
  /// ```
  ///
  /// - Returns: 새로운 자식 컨테이너
  public func createChild() -> DIContainer {
    return DIContainer(parent: self)
  }
  
  /// 모든 자식 컨테이너를 가져옵니다
  /// - Returns: 현재 등록된 자식 컨테이너들
  public func getChildren() -> [DIContainer] {
    return childrenQueue.sync { children }
  }
  
  /// 부모 컨테이너를 가져옵니다.
  /// - Returns: 부모 컨테이너 (루트인 경우 nil)
  public func getParent() -> DIContainer? {
    return parent
  }
  
  
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
    Task { await unifiedRegistry.register(type, factory: { instance }) }

    // 🚀 기존 자동 그래프 추적 (유지)
    Task { @DIActor in
      AutoDIOptimizer.shared.trackRegistration(type)
    }
    
    // 🔍 간단한 모니터링 (추가 옵션)
    Task {
      await AutoMonitor.shared.onModuleRegistered(type)
    }
    
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
  ) -> @Sendable () -> Void where T: Sendable {
    Task { await unifiedRegistry.register(type, factory: factory) }
    let releaseHandler: @Sendable () -> Void = { [weak self] in
      Task { await self?.unifiedRegistry.release(type) }
    }

    // 🚀 기존 자동 그래프 추적 (유지)
    Task { @DIActor in
      AutoDIOptimizer.shared.trackRegistration(type)
    }
    
    // 🔍 간단한 모니터링 (추가 옵션)
    Task {
      await AutoMonitor.shared.onModuleRegistered(type)
    }
    
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
    Task { await unifiedRegistry.register(type, factory: { instance }) }

    // 🚀 기존 자동 그래프 추적 (유지)
    Task { @DIActor in
      AutoDIOptimizer.shared.trackRegistration(type)
    }
    
    // 🔍 간단한 모니터링 (추가 옵션)
    Task { 
      await AutoMonitor.shared.onModuleRegistered(type)
    }
    
    Log.debug("Registered instance for \(String(describing: type))")
  }
  
  /// Actor 보호된 인스턴스 등록 (동시성 안전)
  @DIContainerActor
  public func actorRegister<T>(
    _ type: T.Type,
    instance: T
  ) where T: Sendable {
    register(type, instance: instance)
  }
  
  // MARK: - Core Resolution API
  
  /// 등록된 의존성을 조회합니다
  ///
  /// 의존성이 등록되지 않은 경우 nil을 반환하므로 안전하게 처리할 수 있습니다.
  ///
  /// - Parameter type: 조회할 타입
  /// - Returns: 해결된 인스턴스 (없으면 nil)
  public func resolve<T>(_ type: T.Type) -> T? where T: Sendable {
    // 🚀 기존 자동 성능 최적화 추적 (유지)
    Task { @DIActor in
      AutoDIOptimizer.shared.trackResolution(type)
    }
    
    // 1. 현재 컨테이너에서 해결 시도 (QoS 우선순위 보존)
    let semaphore = DispatchSemaphore(value: 0)
    var result: T?

    Task.detached { [unifiedRegistry] in
      result = await unifiedRegistry.resolveAsync(type)
      semaphore.signal()
    }

    semaphore.wait()

    if let value = result {
      Log.debug("Resolved \(String(describing: type)) from current container")
      return value
    }
    
    // 2. Parent 컨테이너에서 해결 시도
    if let parent = parent, let result = parent.resolve(type) {
      Log.debug("Resolved \(String(describing: type)) from parent container")
      return result
    }
    
    // 3. 🤖 @AutoRegister 타입 자동 등록 시도
    let typeName = String(describing: type)
    Log.info("🔍 해결: \(typeName) (총 1회)")
    Log.info("⚠️ Nil 해결 감지: \(typeName)")
    Log.error("No registered dependency found for \(typeName)")
    Log.info("💡 @AutoRegister를 사용하여 자동 등록을 활성화하세요")
    
    // 🚨 자동 타입 안전성 처리
    Task { @DIActor in
      AutoDIOptimizer.shared.handleNilResolution(type)
    }
    
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
  ) -> T where T: Sendable {
    resolve(type) ?? defaultValue()
  }
  
  /// 특정 타입의 의존성 등록을 해제합니다
  ///
  /// - Parameter type: 해제할 타입
  public func release<T>(_ type: T.Type) {
    Task { await unifiedRegistry.release(type) }
    Log.debug("Released \(String(describing: type))")
  }
  
  // MARK: - KeyPath Support
  
  /// KeyPath 기반 의존성 조회 서브스크립트
  ///
  /// - Parameter keyPath: WeaveDI.Container의 T?를 가리키는 키패스
  /// - Returns: resolve(T.self) 결과
  public subscript<T>(keyPath: KeyPath<DIContainer, T?>) -> T? where T: Sendable {
    get { resolve(T.self) }
  }
  
  // MARK: - Module System
  
  /// 모듈을 컨테이너에 추가합니다 (스레드 안전)
  ///
  /// 실제 등록은 `buildModules()` 호출 시에 병렬로 처리됩니다.
  ///
  /// - Parameter module: 등록 예약할 Module 인스턴스
  /// - Returns: 체이닝을 위한 현재 컨테이너 인스턴스
  @discardableResult
  public func addModule(_ module: Module) -> Self {
    modulesQueue.sync(flags: .barrier) { self.modules.append(module) }
    return self
  }
  
  /// 수집된 모든 모듈의 등록을 병렬로 실행합니다 (스레드 안전)
  ///
  /// TaskGroup을 사용하여 모든 모듈을 동시에 병렬 처리합니다.
  /// 대량의 의존성 등록 시간을 크게 단축할 수 있습니다.
  public func buildModules() async {
    // 스레드 안전하게 스냅샷 생성
    let (snapshot, processedCount): ([Module], Int) = modulesQueue.sync {
      let snap = self.modules
      return (snap, snap.count)
    }
    
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
    
    // 처리된 모듈 제거 (스레드 안전)
    modulesQueue.sync(flags: .barrier) {
      if self.modules.count >= processedCount {
        self.modules.removeFirst(processedCount)
      } else {
        self.modules.removeAll()
      }
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
    modulesQueue.sync { modules.count }
  }
  
  /// 컨테이너가 비어있는지 확인합니다
  public var isEmpty: Bool {
    modulesQueue.sync { modules.isEmpty }
  }
  
  /// 모듈을 등록하는 편의 메서드
  public func register(_ module: Module) async {
    modulesQueue.sync(flags: .barrier) { self.modules.append(module) }
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

/// 기존 WeaveDI.Container와의 호환성을 위한 별칭

public enum WeaveDI {
  public typealias Container = DIContainer
}

// MARK: - Auto Registration Hook

public extension WeaveDI.Container {
  /// 🎯 모든 의존성을 자동으로 등록하는 훅
  ///
  /// 프로젝트에서 이 메서드를 구현하면 ModuleFactoryManager.registerAll()이 자동으로 호출합니다.
  ///
  /// ### 사용법:
  /// ```swift
  /// // 프로젝트의 AutoDIRegistry.swift
  /// extension WeaveDI.Container {
  ///     static func registerRepositories() async {
  ///         await helper.exchangeRepositoryModule().register()
  ///     }
  ///
  ///     static func registerUseCases() async {
  ///         await helper.exchangeUseCaseModule().register()
  ///     }
  /// }
  /// ```
  static func registerAllDependencies() async {
    // 자동으로 registerRepositories()와 registerUseCases() 호출
    await registerRepositories()
    await registerUseCases()
    
#if DEBUG
    print("✅ WeaveDI.Container.registerAllDependencies() 완료")
#endif
  }
  
  /// 📦 Repository 등록 (프로젝트에서 오버라이드)
  static func registerRepositories() async {
    // 기본 구현 없음
  }
  
  /// 🔧 UseCase 등록 (프로젝트에서 오버라이드)
  static func registerUseCases() async {
    // 기본 구현 없음
  }
}

/// WeaveDI.Container.live 호환성
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
  func getAutoGeneratedGraph() -> String {
    AutoDIOptimizer.readSnapshot().graphText
  }
  
  /// ⚡ 자동 최적화된 타입들을 반환합니다
  ///
  /// 사용 패턴을 분석하여 자동으로 성능 최적화가 적용된 타입들의 목록입니다.
  func getOptimizedTypes() -> Set<String> {
    let freq = AutoDIOptimizer.readSnapshot().frequentlyUsed
    return Set(freq.filter { $0.value >= 3 }.keys)
  }
  
  /// ⚠️ 자동 감지된 순환 의존성을 반환합니다
  ///
  /// 의존성 등록/해결 과정에서 자동으로 감지된 순환 의존성 목록입니다.
  func getDetectedCircularDependencies() -> Set<String> {
    let snap = AutoDIOptimizer.readSnapshot()
    var visited: Set<String> = []
    var stack: Set<String> = []
    var cycles: Set<String> = []
    func dfs(_ node: String) {
      if stack.contains(node) { cycles.insert("순환 감지: \(node)"); return }
      if visited.contains(node) { return }
      visited.insert(node); stack.insert(node)
      for dep in snap.dependencies where dep.from == node { dfs(dep.to) }
      stack.remove(node)
    }
    for t in snap.registered where !visited.contains(t) { dfs(t) }
    return cycles
  }
  
  /// 📊 자동 수집된 성능 통계를 반환합니다
  ///
  /// 각 타입의 사용 빈도가 자동으로 추적됩니다.
  func getUsageStatistics() -> [String: Int] {
    AutoDIOptimizer.readSnapshot().frequentlyUsed
  }
  
  /// 🔍 특정 타입이 자동 최적화되었는지 확인합니다
  ///
  /// - Parameter type: 확인할 타입
  /// - Returns: 최적화 여부
  func isAutoOptimized<T>(_ type: T.Type) -> Bool {
    let name = String(describing: type)
    let freq = AutoDIOptimizer.readSnapshot().frequentlyUsed
    return (freq[name] ?? 0) >= 5
  }
  
  /// ⚙️ 자동 최적화 기능을 제어합니다
  ///
  /// - Parameter enabled: 활성화 여부 (기본값: true)
  func setAutoOptimization(_ enabled: Bool) {
    Task { @DIActor in AutoDIOptimizer.shared.setOptimizationEnabled(enabled) }
  }
  
  /// 🧹 자동 수집된 통계를 초기화합니다
  func resetAutoStats() {
    Task { @DIActor in AutoDIOptimizer.shared.resetStats() }
  }
}

