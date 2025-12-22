import Foundation
import WeaveDICore

// MARK: - WeaveDI Namespace Components

/// ## 🚀 WeaveDI.Components - Needle-style Component System
///
/// WeaveDI의 네임스페이스 기반 컴포넌트 시스템입니다.
/// Needle보다 빠른 성능을 제공하면서도 동일한 편의성을 제공합니다.
///
/// ### 사용법:
/// ```swift
/// @Component
/// struct AppComponent {
///     var userService: UserService { UserServiceImpl() }
/// }
///
/// let component = await WeaveDI.Components.register(AppComponent.self)
/// let resolved = await WeaveDI.Components.resolve(AppComponent.self)
/// ```
public extension WeaveDI {

  /// 컴포넌트 관리 네임스페이스
  enum Components {

    /// UnifiedRegistry 기반 컴포넌트 저장소 (Actor 기반 동시성 보장)
    private static let registry = UnifiedRegistry()

    /// @Component 매크로로 생성된 컴포넌트를 등록합니다.
    @discardableResult
    public static func register<T>(_ componentType: T.Type) async -> T where T: ComponentProtocol {
      // 이미 등록된 컴포넌트가 있는지 확인
      if let existing = await registry.resolveAsync(componentType) {
        return existing
      }

      // 새 컴포넌트 인스턴스 생성 및 의존성 등록
      let component = T()
      componentType.registerAll()

      // UnifiedRegistry에 싱글톤으로 등록
      await registry.registerScoped(
        componentType,
        scope: .singleton,
        factory: { component }
      )

#if DEBUG && WEAVE_DI_VERBOSE
      let typeName = String(describing: componentType)
      print("📦 [WeaveDI.Components] \(typeName) 등록 완료")
#endif

      return component
    }

    /// 등록된 컴포넌트를 조회합니다.
    public static func resolve<T>(_ componentType: T.Type) async -> T? where T: ComponentProtocol {
      return await registry.resolveAsync(componentType)
    }

    /// 등록된 컴포넌트 개수를 반환합니다.
    public static func registeredComponentCount() async -> Int {
      return await registry.registeredTypeCount()
    }

    /// 테스트를 위해 레지스트리를 초기화합니다.
    public static func clearRegistry() async {
      await registry.releaseAll()
    }
  }
}
