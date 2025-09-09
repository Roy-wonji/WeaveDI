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

/// `Container` 는 여러 개의 ``Module`` 을 수집하고,
/// `build()` 호출 시 **모든 모듈의 `register()`를 병렬**로 실행하는 `actor`입니다.
///
/// # 개요
/// - Swift Concurrency 기반의 actor이므로 내부 상태(`modules`)는 **thread-safe** 합니다.
/// - `register(_:)` 로 모듈을 담아두고, `build()`에서 `TaskGroup`으로 **동시 실행**합니다.
/// - **배치/순서 개념이 없습니다.**(기존 `BatchModule` 기반이 아님)
///   의존 순서가 필요한 경우에는 **모듈 구성 시** 이미 필요한 의존성이 등록되도록
///   팩토리/모듈을 설계하거나, 배치 로직이 있는 별도 컨테이너를 사용하세요.
///
/// ## Concurrency
/// - `build()`는 내부 배열을 **스냅샷** 떠서 task 생성 중 불필요한 actor hop을 줄입니다.
/// - 각 task는 `@Sendable` 클로저에서 `module.register()`를 호출합니다.
///
/// ## Error Handling
/// - 현재 `Module.register()` 가 `throws`가 아니므로, `build()`도 throw 하지 않습니다.
///   등록 오류를 수집/전파하려면 Module 설계를 `throws`로 확장하고
///   `withThrowingTaskGroup` 기반의 빌드 경로를 추가하세요.
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

  /// 단일 모듈(Module) 인스턴스를 등록합니다.
  ///
  /// - Parameter module: 등록할 모듈 인스턴스 (`Module`).
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

  /// 등록된 모든 모듈(Module) 인스턴스들의 `register()` 메서드를 **병렬로** 실행합니다.
  ///
  /// - 구현 상세:
  ///   1) `modules` 배열을 지역 상수로 **스냅샷** 하여 actor hop을 최소화합니다.
  ///   2) `withTaskGroup` 으로 각 모듈에 대한 태스크를 생성하고,
  ///      `await module.register()` 를 **동시에** 수행합니다.
  ///   3) `waitForAll()`로 모든 태스크의 완료를 기다립니다.
  ///
  /// - Note: `Module.register()` 가 `throws`가 아니라서 본 메서드는 실패 없이 종료됩니다.
  ///         실패 수집/전파가 필요하면 Module/빌드 경로를 throw 버전으로 확장하세요.
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
