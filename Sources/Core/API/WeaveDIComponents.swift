import Foundation

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
/// WeaveDI.Components.register(AppComponent.self)
/// ```
public extension WeaveDI {

  /// 컴포넌트 관리 네임스페이스
  enum Components {

    /// 등록된 컴포넌트를 보관하는 레지스트리 (NSLock으로 동시성 보장)
    private nonisolated(unsafe) static var registry: [String: Any] = [:]
    private static let lock = NSLock()

    /// @Component 매크로로 생성된 컴포넌트를 등록합니다.
    @discardableResult
    public static func register<T>(_ componentType: T.Type) -> T where T: ComponentProtocol {
      lock.lock()
      defer { lock.unlock() }

      let key = String(describing: componentType)

      if let existing = registry[key] as? T {
        return existing
      }

      let component = componentType.init()
      component.register()
      registry[key] = component

      // DIContainer에 동일한 컴포넌트를 등록해 Needle-style resolve와 호환
      DIContainer.live.register(componentType, instance: component)

#if DEBUG && WEAVE_DI_VERBOSE
      print("📦 [WeaveDI.Components] \(key) 등록 완료")
#endif

      return component
    }

    /// 등록된 컴포넌트를 조회합니다.
    public static func resolve<T>(_ componentType: T.Type) -> T? where T: ComponentProtocol {
      let key = String(describing: componentType)
      lock.lock()
      let cached = registry[key] as? T
      lock.unlock()

      if let cached { return cached }
      return DIContainer.live.resolve(componentType)
    }

    /// 등록된 컴포넌트 이름 목록을 반환합니다.
    public static var registeredComponents: [String] {
      lock.lock()
      defer { lock.unlock() }
      return Array(registry.keys)
    }

    /// 테스트를 위해 레지스트리를 초기화합니다.
    public static func clearRegistry() {
      lock.lock()
      registry.removeAll()
      lock.unlock()
    }
  }
}

/// @Component 매크로로 생성된 타입이 채택하는 기본 프로토콜입니다.
public protocol ComponentProtocol: Sendable {
  init()
  func register()
  static var isRegistered: Bool { get }
}
