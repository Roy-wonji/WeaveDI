//
//  ContainerResgister.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/27/25.
//

import Foundation


/// `ContainerResgister`는 전역 `DependencyContainer`에서 특정 타입의 의존성을 가져오는 프로퍼티 래퍼입니다.
///
/// - 제네릭 타입 `T`는 주입받을 의존성의 타입을 의미합니다.
/// - `keyPath`는 `DependencyContainer` 내부의 `T?` 타입 프로퍼티를 가리킵니다.
/// - `wrappedValue`에 접근할 때, 전역 컨테이너(`DependencyContainer.live`)에서
///   `keyPath`를 통해 의존성을 가져옵니다. 만약 해당 의존성이 `nil`이라면,
///   `fatalError`를 통해 런타임에서 즉시 에러가 발생합니다.
///
/// ## 사용 예시
/// ```swift
/// import Foundation
///
/// // 1) DependencyContainer 확장: 프로퍼티로 접근할 키 추가
/// extension DependencyContainer {
///     var networkService: NetworkService? {
///         resolve(NetworkService.self)
///     }
/// }
///
/// // 2) 실제 네트워크 서비스 프로토콜 및 구현체 정의
/// protocol NetworkService {
///     func fetchData(endpoint: String) async throws -> Data
/// }
///
/// struct DefaultNetworkService: NetworkService {
///     func fetchData(endpoint: String) async throws -> Data {
///         // 네트워크 요청 구현...
///         return Data()
///     }
/// }
///
/// // 3) App 초기화 시 DefaultNetworkService를 DI 컨테이너에 등록
/// @main
/// struct MyApp {
///     static func main() async {
///         DependencyContainer.live.register(NetworkService.self) {
///             DefaultNetworkService()
///         }
///
///         // 4) 원하는 위치에서 @ContainerResgister를 사용하여 주입
///         let client = APIClient()
///         await client.loadContent()
///     }
/// }
///
/// // 4) APIClient 예시: property wrapper로 의존성 주입
/// class APIClient {
///     @ContainerResgister(\.networkService)
///     private var networkService: NetworkService
///
///     func loadContent() async {
///         do {
///             let data = try await networkService.fetchData(endpoint: "/posts")
///             print("Received data:", data)
///         } catch {
///             print("Error fetching data:", error)
///         }
///     }
/// }
/// ```
///
@propertyWrapper
public struct ContainerResgister<T> {
    // MARK: - 저장 프로퍼티

    /// `DependencyContainer` 내부의 `T?` 프로퍼티를 가리키는 KeyPath.
    private let keyPath: KeyPath<DependencyContainer, T?>

    // MARK: - 초기화

    /// KeyPath를 통해 주입받을 프로퍼티를 설정합니다.
    ///
    /// - Parameter keyPath: `DependencyContainer`의 `T?` 타입 프로퍼티를 가리키는 KeyPath.
    public init(_ keyPath: KeyPath<DependencyContainer, T?>) {
        self.keyPath = keyPath
    }

    // MARK: - 래퍼된 값

    /// 전역 `DependencyContainer.live`에서 `keyPath`를 통해 `T` 타입의 의존성을 가져옵니다.
    /// 만약 해당 의존성이 `nil`일 경우, 런타임에서 즉시 `fatalError`가 발생합니다.
    public var wrappedValue: T {
        guard let value = DependencyContainer.live[keyPath: keyPath] else {
            fatalError("No registered dependency found for \(T.self)")
        }
        return value
    }
}
/// `ContainerResgister`는 전역 `DependencyContainer`에서 특정 타입의 의존성을 가져오는 프로퍼티 래퍼입니다.
///
/// - 제네릭 타입 `T`는 주입받을 의존성의 타입을 의미합니다.
/// - `keyPath`는 `DependencyContainer` 내부의 `T?` 타입 프로퍼티를 가리킵니다.
/// - `wrappedValue`에 접근할 때, 전역 컨테이너(`DependencyContainer.live`)에서
///   `keyPath`를 통해 의존성을 가져옵니다. 만약 해당 의존성이 `nil`이라면,
///   `fatalError`를 통해 런타임에서 즉시 에러가 발생합니다.
///
/// ## 사용 예시
/// ```swift
/// import Foundation
///
/// // 1) DependencyContainer 확장: 프로퍼티로 접근할 키 추가
/// extension DependencyContainer {
///     var networkService: NetworkService? {
///         resolve(NetworkService.self)
///     }
/// }
///
/// // 2) 실제 네트워크 서비스 프로토콜 및 구현체 정의
/// protocol NetworkService {
///     func fetchData(endpoint: String) async throws -> Data
/// }
///
/// struct DefaultNetworkService: NetworkService {
///     func fetchData(endpoint: String) async throws -> Data {
///         // 네트워크 요청 구현...
///         return Data()
///     }
/// }
///
/// // 3) App 초기화 시 DefaultNetworkService를 DI 컨테이너에 등록
/// @main
/// struct MyApp {
///     static func main() async {
///         DependencyContainer.live.register(NetworkService.self) {
///             DefaultNetworkService()
///         }
///
///         // 4) 원하는 위치에서 @ContainerResgister를 사용하여 주입
///         let client = APIClient()
///         await client.loadContent()
///     }
/// }
///
/// // 4) APIClient 예시: property wrapper로 의존성 주입
/// class APIClient {
///     @ContainerResgister(\.networkService)
///     private var networkService: NetworkService
///
///     func loadContent() async {
///         do {
///             let data = try await networkService.fetchData(endpoint: "/posts")
///             print("Received data:", data)
///         } catch {
///             print("Error fetching data:", error)
///         }
///     }
/// }
/// ```
///
