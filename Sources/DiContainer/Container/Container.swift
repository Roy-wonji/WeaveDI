//
//  Container.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/19/25.
//

import Foundation

// MARK: - BatchModule

/// 배치 단위로 실행되는 **모듈 초기화/등록 단위**입니다.
///
/// # Overview
/// `BatchModule`은 앱 부팅 시 필요한 구성 요소(예: Repository, UseCase, Service 등)를
/// DI 컨테이너에 **등록**하기 위해 사용하는 최소 단위입니다.
/// 각 모듈은 정적 프로퍼티 ``BatchModule/batch`` 로 자신이 속한 **배치 번호**를 정의하며,
/// 같은 배치에 속한 모듈들은 **병렬로**, 배치 간에는 **작은 번호부터 순차적으로** 실행됩니다.
///
/// ## Responsibilities
/// - `batch`: 실행 순서를 결정하는 배치 인덱스(작을수록 먼저 실행)
/// - `register()`: 실제 의존성 등록/초기화 로직 (네트워크 클라이언트, 리포지토리 바인딩 등)
///
/// ## Concurrency
/// - 같은 배치에 속한 모듈이 동시에 실행되므로,
///   각 모듈의 `register()` 구현은 **스레드 안전**해야 합니다.
/// - 구조체 기반 구현은 대체로 자동으로 `Sendable`을 만족하지만,
///   클래스 기반 구현은 필요 시 `final class … : @unchecked Sendable, BatchModule` 형태로
///   **직접 안전성 보장**이 필요합니다.
///
/// ## Error Handling
/// - `register()`에서 발생한 오류는 상위(`Container.build()`)로 전파됩니다.
/// - 전체 부팅을 중단하고 싶다면 상위에서 `do/try/catch`로 처리하세요.
/// - 실패를 허용하고 집계하고 싶다면 ``Container/buildIgnoringErrors(onError:)`` 사용을 고려하세요.
///
/// ## Best Practices
/// - **의존 관계**가 있는 모듈은 서로 다른 배치로 나누세요.
///   예: `batch=0` Repository → `batch=1` UseCase → `batch=2` Feature
/// - **독립적인 모듈**은 같은 배치로 묶어 병렬화의 이점을 얻으세요.
///
/// # Example
/// ```swift
/// struct AuthRepositoryModule: BatchModule {
///     static var batch: Int { 0 }
///     func register() async throws {
///         DependencyContainer.live.register(AuthRepositoryProtocol.self) {
///             DefaultAuthRepository()
///         }
///     }
/// }
///
/// struct AuthUseCaseModule: BatchModule {
///     static var batch: Int { 1 }
///     func register() async throws {
///         let repo: AuthRepositoryProtocol = DependencyContainer.live.resolveOrDefault(
///             AuthRepositoryProtocol.self,
///             default: DefaultAuthRepository()
///         )
///         DependencyContainer.live.register(AuthUseCaseProtocol.self) {
///             DefaultAuthUseCase(repository: repo)
///         }
///     }
/// }
/// ```
public protocol BatchModule: Sendable {
  /// 같은 배치(batch) 값의 모듈들은 **동시에 실행**되고,
  /// 배치 간에는 **작은 숫자부터 순차 실행**됩니다.
  static var batch: Int { get }
  
  /// 실제 등록/초기화 로직을 수행합니다.
  /// - Throws: 등록 과정에서 발생한 오류
  func register() async throws
}

// MARK: - Container

/// 등록된 ``BatchModule`` 을 관리하고, **배치 규칙에 따라 모듈 초기화**를 실행하는 `actor`입니다.
///
/// # Overview
/// `Container`는 `register(_:)`를 통해 모듈을 수집하고, ``Container/build()`` 를 호출하면
/// 내부적으로 모듈을 `batch` 기준으로 그룹핑하여:
/// - **배치 간**: 작은 번호부터 **순차 실행**
/// - **배치 내**: 등록된 모듈들을 **병렬 실행**
/// 하는 전략으로 초기화를 수행합니다.
///
/// ## Execution Flow
/// 1. 모듈 등록 시 내부 배열에 **등록 인덱스**를 함께 저장하여 결정적 순서를 보존합니다.
/// 2. `build()` 시 `type(of: module).batch`로 그룹핑 후,
///    각 배치 내부를 **등록 인덱스 오름차순**으로 정렬합니다.
/// 3. 배치를 순서대로 돌며, 배치 내부는 `TaskGroup`으로 **동시에 register()** 를 호출합니다.
///
/// ## Concurrency
/// - `actor`이므로 내부 상태(`modules`, `nextIndex`)는 **thread-safe** 합니다.
/// - 배치 내부의 태스크는 `@Sendable` 클로저로 생성되어 Swift 6 동시성 점검을 통과합니다.
///
/// ## Error Handling
/// - ``Container/build()`` 는 **첫 오류 발생 시 즉시 throw** 합니다.
/// - 실패를 허용하고 집계하고 싶다면 ``Container/buildIgnoringErrors(onError:)`` 를 사용하세요.
///
/// ## Tips
/// - 부팅 시간을 줄이려면 **의존성이 없는 모듈을 같은 배치**에 묶으세요.
/// - I/O가 무거운 초기화(원격 설정, DB 마이그레이션 등)는 병렬 실행되는 배치에 배치하세요.
///
/// # Example
/// ```swift
/// @main
/// struct MyApp {
///     static func main() async {
///         let container = Container()
///
///         container
///             .register(AuthRepositoryModule()) // batch 0
///             .register(AuthUseCaseModule())    // batch 1
///
///         do {
///             try await container.build()
///             print("All modules registered successfully.")
///         } catch {
///             print("Error during registration:", error)
///         }
///     }
/// }
/// ```
public actor Container {
  // MARK: - Properties
  
  /// 등록된 모듈을 **등록 순서(index)** 와 함께 저장합니다.
  ///
  /// - Note: 같은 배치 내 병렬 실행 환경에서도 **결정적 실행 순서**(정렬 기준)를
  ///   제공하기 위해 인덱스를 보존합니다.
  private var modules: [(index: Int, module: BatchModule)] = []
  
  /// 모듈 등록 시 증가하는 인덱스 값 (등록 순서 보존)
  private var nextIndex: Int = 0
  
  // MARK: - Init
  
  /// 기본 생성자입니다.
  public init() {}
  
  // MARK: - Register
  
  /// 단일 모듈을 컨테이너에 등록합니다.
  ///
  /// - Parameter module: 등록할 ``BatchModule`` 인스턴스
  /// - Returns: 현재 컨테이너(`Self`) — **체이닝** 가능
  ///
  /// ### Discussion
  /// 등록된 모듈은 `(index, module)` 형태로 보관되며,
  /// 이후 ``build()`` 단계에서 **배치 asc → 인덱스 asc**로 정렬되어 실행됩니다.
  @discardableResult
  public func register(_ module: BatchModule) -> Self {
    modules.append((index: nextIndex, module: module))
    nextIndex += 1
    return self
  }
  
  /// 여러 모듈을 한 번에 컨테이너에 등록합니다.
  ///
  /// - Parameter modules: 등록할 모듈 시퀀스
  /// - Returns: 현재 컨테이너(`Self`)
  ///
  /// ### Discussion
  /// 내부적으로 ``register(_:)`` 를 반복 호출하여 **등록 순서 보존**을 유지합니다.
  @discardableResult
  public func register<S: Sequence>(_ modules: S) -> Self where S.Element == BatchModule {
    for m in modules { register(m) }
    return self
  }
  
  // MARK: - Build
  
  /// 등록된 모듈들을 **배치 내 병렬, 배치 간 순차**로 실행합니다.
  ///
  /// - Throws: 모듈 초기화 중 첫 번째로 발생한 오류
  ///
  /// ### Algorithm
  /// 1. `Dictionary(grouping:by:)`로 `batch` 기준 그룹핑
  /// 2. 각 그룹 내부를 등록 **인덱스 오름차순**으로 정렬
  /// 3. 배치를 **작은 번호부터 순차**로 순회
  /// 4. 각 배치 내부는 `withThrowingTaskGroup`으로 **동시에 register()** 실행
  ///
  /// ### Notes
  /// - 같은 배치 내에서의 **완료 순서**는 병렬 실행 특성상 보장되지 않습니다.
  /// - 결정적 재현성이 필요하면 배치 분해를 세분화하거나, 해당 배치를 순차 실행으로 전환하는 별도 경로를 고려하세요.
  public func build() async throws {
    let grouped: [(batch: Int, items: [(Int, BatchModule)])] = Dictionary(
      grouping: modules, by: { type(of: $0.module).batch }
    )
      .map { (key: $0.key, value: $0.value.sorted { $0.index < $1.index }) }
      .sorted { $0.key < $1.key }
      .map { (batch: $0.key, items: $0.value) }
    
    for (_, items) in grouped {
      try await withThrowingTaskGroup(of: Void.self) { group in
        for (_, mod) in items {
          let m = mod
          group.addTask { @Sendable in
            try await m.register()
          }
        }
        try await group.waitForAll()
      }
    }
  }
  
  /// 등록 실행 중 발생한 오류를 **무시**하고 계속 진행하는 편의 메서드입니다.
  ///
  /// - Parameter onError: 각 오류를 처리할 선택적 콜백(예: 로깅·메트릭 수집)
  /// - Returns: **실패 횟수**(최초 실패 기준)
  ///
  /// ### Discussion
  /// 이 메서드는 내부적으로 ``build()`` 를 호출하여,
  /// 발생한 오류를 throw 하지 않고 첫 실패만 집계해 `onError`로 전달합니다.
  ///
  /// 만약 **발생한 모든 오류를 개별적으로 집계**하고 싶다면,
  /// `TaskGroup` 결과를 직접 수집하는 전용 빌드 함수를 구현하는 편이 더 적절합니다.
  @discardableResult
  public func buildIgnoringErrors(onError: ((Error) -> Void)? = nil) async -> Int {
    var failures = 0
    do {
      try await build()
    } catch {
      failures += 1
      onError?(error)
    }
    return failures
  }
}
