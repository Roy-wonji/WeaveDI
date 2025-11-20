//
//  DIContainer+Legacy.swift
//  DiContainer
//
//  Created by Wonji Suh on 2024.
//

import Foundation

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
    await registerDi()
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

  /// 🔧 Di 등록 (프로젝트에서 오버라이드)
  static func registerDi() async {
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
