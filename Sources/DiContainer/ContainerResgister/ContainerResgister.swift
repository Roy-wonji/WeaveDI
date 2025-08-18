//
//  ContainerResgister.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/27/25.
//

import Foundation

// MARK: - ContainerResgister

/// `ContainerResgister`는 전역 ``DependencyContainer``에서 특정 타입의 의존성을 가져오기 위한 프로퍼티 래퍼입니다.
///
/// # 개요
/// - 전역 컨테이너(`DependencyContainer.live`)에 등록된 의존성을
///   `KeyPath` 기반으로 주입받습니다.
/// - 제네릭 타입 `T`는 주입받을 의존성의 실제 타입을 의미합니다.
/// - `wrappedValue` 접근 시, 해당 의존성이 존재하지 않으면
///   `fatalError`로 런타임에서 즉시 종료됩니다.
///
/// ## Concurrency
/// - `DependencyContainer`가 thread-safe하게 설계되어 있으므로,
///   동시성 환경에서 안전하게 접근할 수 있습니다.
/// - 단, `fatalError`는 회피 불가능하므로 반드시 App 초기화 시점에서
///   의존성이 선등록되어야 합니다.
///
/// ## Example
///
/// ### 1. DependencyContainer 확장
/// ```swift
/// extension DependencyContainer {
///     var networkService: NetworkService? {
///         resolve(NetworkService.self)
///     }
/// }
/// ```
///
/// ### 2. 의존성 프로토콜 및 구현체 정의
/// ```swift
/// protocol NetworkService {
///     func fetchData(endpoint: String) async throws -> Data
/// }
///
/// struct DefaultNetworkService: NetworkService {
///     func fetchData(endpoint: String) async throws -> Data {
///         return Data() // 네트워크 요청 로직
///     }
/// }
/// ```
///
/// ### 3. App 초기화 시 등록
/// ```swift
/// @main
/// struct MyApp {
///     static func main() async {
///         DependencyContainer.live.register(NetworkService.self) {
///             DefaultNetworkService()
///         }
///
///         let client = APIClient()
///         await client.loadContent()
///     }
/// }
/// ```
///
/// ### 4. APIClient에서 사용
/// ```swift
/// final class APIClient {
///     @ContainerResgister(\.networkService)
///     private var networkService: NetworkService
///
///     func loadContent() async {
///         do {
///             let data = try await networkService.fetchData(endpoint: "/posts")
///             print("Received:", data)
///         } catch {
///             print("Error:", error)
///         }
///     }
/// }
/// ```
@propertyWrapper
public struct ContainerResgister<T> {
  
  // MARK: - Properties
  
  /// `DependencyContainer` 내부의 `T?` 프로퍼티를 가리키는 KeyPath.
  private let keyPath: KeyPath<DependencyContainer, T?>
  
  // MARK: - Init
  
  /// KeyPath를 통해 주입받을 프로퍼티를 지정합니다.
  ///
  /// - Parameter keyPath: `DependencyContainer`의 `T?` 프로퍼티를 가리키는 KeyPath.
  public init(_ keyPath: KeyPath<DependencyContainer, T?>) {
    self.keyPath = keyPath
  }
  
  // MARK: - Wrapped Value
  
  /// 전역 ``DependencyContainer/live``에서 의존성을 가져옵니다.
  /// 만약 해당 의존성이 `nil`이라면 `fatalError`를 발생시킵니다.
  public var wrappedValue: T {
    guard let value = DependencyContainer.live[keyPath: keyPath] else {
      fatalError("No registered dependency found for \(T.self)")
    }
    return value
  }
}
