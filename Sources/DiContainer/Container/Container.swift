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
  // MARK: - 저장 프로퍼티

  /// 등록된 모듈(Module) 인스턴스들을 저장하는 내부 배열.
  private var modules: [Module] = []

  // MARK: - 초기화

  /// 기본 초기화 메서드.
  /// - 설명: 인스턴스 생성 시 `modules` 배열은 빈 상태로 시작됩니다.
  public init() {}

  // MARK: - 모듈 등록

  /// 단일 모듈(Module) 인스턴스를 등록합니다.
  ///
  /// - Parameter module: 등록할 모듈 인스턴스 (Module 프로토콜을 준수).
  /// - Returns: 현재 `Container` 인스턴스(Self). 메서드 체이닝(Fluent API) 방식으로 연쇄 호출이 가능합니다.
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
  
  /// 등록된 모든 모듈(Module) 인스턴스들의 `register()` 메서드를 `TaskGroup`을 사용해 병렬로 실행합니다.
  ///
  /// - 설명:
  ///   - 내부에 저장된 `modules` 배열의 각 요소에 대해 비동기 태스크를 생성하고, `register()`를 호출합니다.
  ///   - 모든 태스크가 완료될 때까지 대기하므로, 전체 모듈 등록 시간이 단축됩니다.
//  public func build() async {
//    await withTaskGroup(of: Void.self) { group in
//      for module in modules {
//        group.addTask {
//          await module.register()
//        }
//      }
//      // 모든 태스크가 완료될 때까지 대기
//    }
//  }

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
