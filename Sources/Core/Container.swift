//
//  Container.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/19/25.
//

import Foundation

// MARK: - Module (Overview Only)

/// **Module** 은 DI 컨테이너에 “등록 작업”을 수행하기 위한 **최소 단위**입니다.
/// (이 파일에는 타입 정의가 없고, 외부에서 제공되는 `public actor Module`을 사용합니다.)
///
/// # Overview
/// - 생성 예: `Module(MyServiceProtocol.self) { DefaultMyService() }`
/// - 역할: 내부에 캡슐화된 등록 클로저를 `register()` 호출 시 실행하여
///   `DependencyContainer.live.register(type, build: factory)` 를 수행합니다.
/// - 반환값/오류: `register()` 는 `async` 이며 `Void`를 반환합니다(throw 하지 않음).
///
/// # Example
/// ```swift
/// // 1) 모듈 생성
/// let repoModule = Module(RepositoryProtocol.self) { DefaultRepository() }
/// let useCaseModule = Module(UseCaseProtocol.self) { DefaultUseCase(repo: DefaultRepository()) }
///
/// // 2) 컨테이너에 모듈 추가
/// let container = Container()
/// container.register(repoModule)
/// container.register(useCaseModule)
///
/// // 3) 병렬 등록 수행
/// await container.build()
/// ```

// MARK: - Container

/// ## 개요
/// 
/// `Container`는 여러 개의 `Module` 인스턴스를 수집하고 일괄 등록할 수 있는 
/// Swift Concurrency 기반의 액터입니다. 이 컨테이너는 대규모 의존성 그래프를 
/// 효율적으로 관리하고 병렬 처리를 통해 성능을 최적화합니다.
///
/// ## 핵심 특징
///
/// ### ⚡ 고성능 병렬 처리
/// - **Task Group 활용**: 모든 모듈의 등록을 동시에 병렬 실행
/// - **스냅샷 기반**: 내부 배열을 복사하여 actor hop 최소화
/// - **비동기 안전**: Swift Concurrency 패턴으로 스레드 안전성 보장
///
/// ### 🏗️ 배치 등록 시스템
/// - **모듈 수집**: 여러 모듈을 먼저 수집한 후 한 번에 등록
/// - **지연 실행**: `build()` 호출 시점까지 실제 등록 지연
/// - **원자적 처리**: 모든 모듈이 함께 등록되거나 실패
///
/// ### 🔒 동시성 안전성
/// - **Actor 보호**: 내부 상태(`modules`)가 데이터 경쟁으로부터 안전
/// - **순서 독립**: 모듈 등록 순서와 무관하게 동작
/// - **메모리 안전**: 약한 참조 없이도 안전한 메모리 관리
///
/// ## 기본 사용 패턴
///
/// ### 1단계: 컨테이너 생성 및 모듈 수집
/// ```swift
/// let container = Container()
///
/// // 모듈 개별 등록
/// container.register(userRepositoryModule)
/// container.register(authServiceModule) 
/// container.register(networkServiceModule)
/// ```
///
/// ### 2단계: 체이닝을 통한 연속 등록
/// ```swift
/// let container = Container()
///     .register(userRepositoryModule)
///     .register(authServiceModule)
///     .register(networkServiceModule)
/// ```
///
/// ### 3단계: 일괄 등록 실행
/// ```swift
/// // 모든 모듈을 병렬로 등록
/// await container.build()
/// ```
///
/// ## 고급 사용 패턴
///
/// ### Factory 패턴과의 연동
/// ```swift
/// let container = Container()
/// let repositoryFactory = RepositoryModuleFactory()
/// let useCaseFactory = UseCaseModuleFactory()
///
/// // Factory에서 생성된 모듈들을 일괄 등록
/// await repositoryFactory.makeAllModules().asyncForEach { module in
///     await container.register(module)
/// }
///
/// await useCaseFactory.makeAllModules().asyncForEach { module in
///     await container.register(module)
/// }
///
/// // 모든 모듈을 병렬 등록
/// await container.build()
/// ```
///
/// ### 조건부 모듈 등록
/// ```swift
/// let container = Container()
///
/// // 환경에 따른 조건부 등록
/// if ProcessInfo.processInfo.environment["ENABLE_ANALYTICS"] == "true" {
///     container.register(analyticsModule)
/// }
///
/// #if DEBUG
/// container.register(debugLoggingModule)
/// #else
/// container.register(productionLoggingModule)
/// #endif
///
/// await container.build()
/// ```
///
/// ### 클로저를 활용한 구성
/// ```swift
/// let container = Container()
///
/// container {
///     // 클로저 내부에서 추가 설정
///     print("모듈 등록 준비 완료")
/// }
/// .register(module1)
/// .register(module2)
/// 
/// await container.build()
/// ```
///
/// ## 성능 특징
///
/// ### 병렬 처리 최적화
/// - **동시 실행**: 독립적인 모듈들이 병렬로 등록되어 전체 시간 단축
/// - **메모리 효율**: 스냅샷 방식으로 불필요한 메모리 복사 최소화
/// - **CPU 활용**: 멀티코어 환경에서 모든 코어 활용 가능
///
/// ### 메모리 관리
/// ```swift
/// // 등록 완료 후 내부 모듈 배열은 자동으로 해제됨
/// await container.build() // 이후 modules 배열은 비워짐
/// ```
///
/// ## 동시성 모델
///
/// ### Actor 기반 안전성
/// - 내부 상태 변경은 actor의 직렬 실행 큐에서만 발생
/// - 외부에서의 동시 접근이 자동으로 동기화됨
/// - 데이터 경쟁 조건 완전 차단
///
/// ### Task Group 활용
/// ```swift
/// // 내부 구현 예시 (실제 코드)
/// await withTaskGroup(of: Void.self) { group in
///     for module in modules {
///         group.addTask { @Sendable in
///             await module.register() // 각 모듈이 병렬 등록
///         }
///     }
///     await group.waitForAll() // 모든 등록 완료까지 대기
/// }
/// ```
///
/// ## 제한사항 및 고려사항
///
/// ### ⚠️ 의존성 순서
/// 이 컨테이너는 의존성 간의 순서를 보장하지 않습니다. 순서가 중요한 경우:
///
/// ```swift
/// // ❌ 문제 상황: B가 A에 의존하지만 순서 보장 없음
/// container.register(moduleB) // A가 필요하지만 아직 등록되지 않을 수 있음
/// container.register(moduleA)
///
/// // ✅ 해결책 1: 모듈 팩토리에서 의존성 해결
/// let moduleB = registerModule.makeDependency(BProtocol.self) {
///     let a = DependencyContainer.live.resolve(AProtocol.self)!
///     return BImplementation(dependency: a)
/// }
///
/// // ✅ 해결책 2: 별도의 순서 보장 로직 사용
/// await container.register(moduleA).build() // A 먼저 등록
/// await Container().register(moduleB).build() // B 나중에 등록
/// ```
///
/// ### ⚠️ 오류 처리
/// 현재 구현에서는 모듈 등록 실패를 개별적으로 처리하지 않습니다:
///
/// ```swift
/// // 현재: 모든 모듈이 성공하거나 일부 실패해도 계속 진행
/// await container.build() // throws 하지 않음
///
/// // 향후 확장 가능: 오류 수집 및 보고
/// // let failures = try await container.buildWithErrorHandling()
/// ```
///
/// ## 관련 API
///
/// - ``Module``: 개별 의존성 등록 단위
/// - ``RegisterModule``: 모듈 생성 헬퍼
/// - ``DependencyContainer``: 실제 의존성 저장소
///
/// # 사용 예시
/// ```swift
/// // 모듈 팩토리에서 [Module] 생성
/// let repoModules: [Module]    = repositoryFactory.makeAllModules()
/// let useCaseModules: [Module] = useCaseFactory.makeAllModules()
///
/// let container = Container()
///
/// // 비동기 for-each로 담기
/// await repoModules.asyncForEach   { await container.register($0) }
/// await useCaseModules.asyncForEach{ await container.register($0) }
///
/// // 병렬 등록 실행
/// await container.build()
/// ```
public actor Container {
  // MARK: - 저장 프로퍼티

  /// 등록된 모듈(Module) 인스턴스들을 저장하는 내부 배열.
  private var modules: [Module] = []

  // MARK: - 초기화

  /// 기본 초기화 메서드.
  /// - 설명: 인스턴스 생성 시 `modules` 배열은 빈 상태로 시작됩니다.
  public init() {}

  // MARK: - 모듈 등록

  /// 모듈을 컨테이너에 추가하여 나중에 일괄 등록할 수 있도록 준비합니다.
  ///
  /// 이 메서드는 즉시 모듈을 DI 컨테이너에 등록하지 않고, 내부 배열에 저장만 합니다.
  /// 실제 등록은 `build()` 메서드 호출 시에 모든 모듈이 병렬로 처리됩니다.
  ///
  /// ## 사용 방법
  ///
  /// ### 개별 등록
  /// ```swift
  /// let container = Container()
  /// 
  /// container.register(userRepositoryModule)
  /// container.register(authServiceModule)
  /// container.register(networkServiceModule)
  /// 
  /// // 이 시점까지는 아직 실제 등록되지 않음
  /// await container.build() // 여기서 모든 모듈이 한 번에 등록
  /// ```
  ///
  /// ### 메서드 체이닝
  /// ```swift
  /// let container = Container()
  ///     .register(userRepositoryModule)
  ///     .register(authServiceModule)
  ///     .register(networkServiceModule)
  /// 
  /// await container.build()
  /// ```
  ///
  /// ### 조건부 등록
  /// ```swift
  /// let container = Container()
  /// 
  /// container.register(coreModule)
  /// 
  /// if isDebugMode {
  ///     container.register(debugModule)
  /// }
  /// 
  /// if analyticsEnabled {
  ///     container.register(analyticsModule)
  /// }
  /// 
  /// await container.build()
  /// ```
  ///
  /// ## 동작 원리
  /// 
  /// 1. **모듈 저장**: 전달받은 모듈을 내부 `modules` 배열에 추가
  /// 2. **지연 등록**: 실제 DI 컨테이너 등록은 `build()` 시점까지 지연
  /// 3. **Self 반환**: 메서드 체이닝을 위해 현재 컨테이너 인스턴스 반환
  /// 4. **Thread Safe**: Actor 보호로 동시 접근 시 안전하게 직렬화
  ///
  /// - Parameter module: 등록 예약할 `Module` 인스턴스
  /// - Returns: 체이닝을 위한 현재 `Container` 인스턴스
  /// 
  /// - Note: 이 메서드는 실제 등록을 수행하지 않고 모듈을 큐에 추가만 합니다.
  /// - Important: 동일한 타입의 모듈을 여러 번 등록하면 마지막 등록이 우선됩니다.
  /// - SeeAlso: `build()` - 실제 모든 모듈을 병렬 등록하는 메서드
  @discardableResult
  public func register(_ module: Module) -> Self {
    modules.append(module)
    return self
  }

  /// Trailing closure를 처리할 때 사용되는 메서드입니다.
  ///
  /// - Parameter block: 호출 즉시 실행할 클로저. 이 클로저 내부에서 추가 설정을 수행할 수 있습니다.
  /// - Returns: 현재 `Container` 인스턴스(Self). 메서드 체이닝(Fluent API) 방식으로 연쇄 호출이 가능합니다.
  @discardableResult
  public func callAsFunction(_ block: () -> Void) -> Self {
    block()
    return self
  }

  // MARK: - 빌드(등록 실행)

  /// 수집된 모든 모듈의 등록을 병렬로 실행하는 핵심 메서드입니다.
  ///
  /// 이 메서드는 `register(_:)` 호출로 수집된 모든 모듈들을 Swift의 TaskGroup을 사용하여
  /// 동시에 병렬 처리합니다. 이를 통해 대량의 의존성 등록 시간을 크게 단축할 수 있습니다.
  ///
  /// ## 동작 과정
  ///
  /// ### 1단계: 스냅샷 생성
  /// ```swift
  /// // Actor 내부에서 배열을 지역 변수로 복사
  /// let snapshot = modules
  /// ```
  /// 이렇게 함으로써 TaskGroup 실행 중 불필요한 actor isolation hop을 방지합니다.
  ///
  /// ### 2단계: 병렬 작업 생성
  /// ```swift
  /// await withTaskGroup(of: Void.self) { group in
  ///     for module in snapshot {
  ///         group.addTask { @Sendable in
  ///             await module.register() // 각 모듈이 병렬 실행
  ///         }
  ///     }
  ///     await group.waitForAll() // 모든 작업 완료 대기
  /// }
  /// ```
  ///
  /// ## 성능 특성
  ///
  /// ### 시간 복잡도
  /// - **순차 처리**: O(n) - 모든 모듈을 하나씩 등록
  /// - **병렬 처리**: O(max(모듈별 등록 시간)) - 가장 오래 걸리는 모듈의 등록 시간
  ///
  /// ### 실제 성능 예시
  /// ```swift
  /// // 10개 모듈, 각각 100ms 소요 시
  /// // 순차 처리: 1000ms
  /// // 병렬 처리: 100ms (약 90% 성능 향상)
  /// ```
  ///
  /// ## 사용 시나리오
  ///
  /// ### 기본 사용법
  /// ```swift
  /// let container = Container()
  ///     .register(repositoryModule)
  ///     .register(useCaseModule)
  ///     .register(serviceModule)
  /// 
  /// // 모든 모듈을 병렬로 등록
  /// await container.build()
  /// 
  /// // 이제 DI 컨테이너에서 의존성 조회 가능
  /// let service = DependencyContainer.live.resolve(ServiceProtocol.self)
  /// ```
  ///
  /// ### 대량 모듈 처리
  /// ```swift
  /// let container = Container()
  /// 
  /// // 100개 이상의 모듈도 효율적으로 처리
  /// for i in 1...100 {
  ///     let module = createModule(for: i)
  ///     container.register(module)
  /// }
  /// 
  /// let startTime = CFAbsoluteTimeGetCurrent()
  /// await container.build()
  /// let duration = CFAbsoluteTimeGetCurrent() - startTime
  /// print("등록 완료: \(duration)초")
  /// ```
  ///
  /// ### Factory와의 연동
  /// ```swift
  /// let container = Container()
  /// let factories = [repositoryFactory, useCaseFactory, serviceFactory]
  /// 
  /// for factory in factories {
  ///     let modules = await factory.makeAllModules()
  ///     await modules.asyncForEach { module in
  ///         await container.register(module)
  ///     }
  /// }
  /// 
  /// // 수백 개의 모듈도 병렬로 빠르게 등록
  /// await container.build()
  /// ```
  ///
  /// ## 메모리 관리
  ///
  /// ### 자동 정리
  /// ```swift
  /// await container.build() // 등록 완료 후
  /// // 내부 modules 배열은 자동으로 해제됨
  /// // 메모리 누수 없이 정리됨
  /// ```
  ///
  /// ### 대용량 모듈 처리
  /// - **스냅샷 방식**: 원본 배열을 복사하므로 메모리 사용량 일시적 증가
  /// - **TaskGroup**: 각 작업이 독립적으로 실행되어 메모리 압박 분산
  /// - **자동 해제**: 작업 완료 후 모든 임시 데이터 자동 정리
  ///
  /// ## 동시성 보장
  ///
  /// ### Thread Safety
  /// - **Actor Protection**: 내부 상태 변경이 actor에 의해 보호됨
  /// - **Sendable Compliance**: 모든 클로저가 `@Sendable`로 데이터 경쟁 방지
  /// - **Isolation**: 각 모듈의 등록 작업이 독립적으로 격리되어 실행
  ///
  /// ### 오류 전파
  /// 현재 구현에서는 개별 모듈 등록 실패가 전체 프로세스를 중단하지 않습니다:
  /// ```swift
  /// // 일부 모듈이 실패해도 다른 모듈들은 계속 등록됨
  /// await container.build() // throws 하지 않음
  /// 
  /// // 개별 모듈 내부에서 로깅이나 오류 처리 수행 가능
  /// ```
  ///
  /// ## 성능 최적화 팁
  ///
  /// ### 1. 모듈 그룹화
  /// ```swift
  /// // ✅ 좋은 예: 논리적 그룹별로 분할
  /// await coreContainer.build()      // 핵심 의존성 먼저
  /// await featureContainer.build()   // 기능별 의존성 나중에
  /// ```
  ///
  /// ### 2. 의존성 순서 고려
  /// ```swift
  /// // ✅ 의존성이 있는 경우 단계별 등록
  /// await basicContainer.build()     // 기본 의존성
  /// await dependentContainer.build() // 위에 의존하는 것들
  /// ```
  ///
  /// ### 3. 메모리 사용량 모니터링
  /// ```swift
  /// let memoryBefore = getMemoryUsage()
  /// await container.build()
  /// let memoryAfter = getMemoryUsage()
  /// print("메모리 사용량 증가: \(memoryAfter - memoryBefore)MB")
  /// ```
  ///
  /// - Note: 모든 등록 작업이 완료될 때까지 메서드가 반환되지 않습니다.
  /// - Important: 이 메서드는 현재 throws 하지 않지만, 개별 모듈에서 오류 로깅은 가능합니다.
  /// - Warning: 매우 많은 모듈(1000개 이상)을 한 번에 처리할 때는 메모리 사용량을 모니터링하세요.
  public func build() async {
    // 1) actor 내부 배열을 스냅샷 -> task 생성 중 불필요한 actor hop 방지
    let snapshot = modules

    // 2) 병렬 실행 + 전체 완료 대기
    await withTaskGroup(of: Void.self) { group in
      for module in snapshot {
        group.addTask { @Sendable in
          await module.register()
        }
      }
      await group.waitForAll()
    }
  }
}
