//
//  SimplifiedAPIExamples.swift
//  DiContainer
//
//  Created by Claude on 2025-09-14.
//

//import Foundation
//
//// MARK: - 단순화된 API 사용 예제
//
///// 단순화된 DI API 사용법 예제
///// 
///// ## 🎯 목표: 3가지 핵심 패턴만 기억하면 됩니다!
///// 1. `DI.register()` - 의존성 등록
///// 2. `@Inject` - 의존성 주입  
///// 3. `DI.resolve()` - 수동 의존성 해결
//public enum SimplifiedAPIExamples {
//    
//    // MARK: - Example 1: Basic Usage
//    
//    /// 기본 사용법 예제
//    public static func basicUsageExample() {
//        // 1️⃣ 등록 (앱 시작 시 한번)
//        DI.register(NetworkService.self) { URLSessionNetworkService() }
//        DI.register(UserRepository.self) { CoreDataUserRepository() }
//        DI.register(UserService.self) { 
//            UserServiceImpl(
//                repository: DI.requireResolve(UserRepository.self),
//                network: DI.requireResolve(NetworkService.self)
//            )
//        }
//        
//        // 2️⃣ 사용 (뷰모델, 컨트롤러 등에서)
//        final class UserViewController {
//            @Inject(\.userService) private var userService: UserService
//            
//            func loadUser() {
//                // userService가 자동으로 주입됨
//                userService.fetchCurrentUser { user in
//                    // Handle user
//                }
//            }
//        }
//        
//        // 3️⃣ 수동 해결 (필요한 경우)
//        let userService = DI.requireResolve(UserService.self)
//        userService.fetchCurrentUser { _ in }
//    }
//    
//    // MARK: - Example 2: Bulk Registration
//    
//    /// 일괄 등록 예제
//    public static func bulkRegistrationExample() {
//        // 여러 의존성을 한번에 등록
//        DI.registerMany {
//            // 네트워크 계층
//            DIRegistration(NetworkService.self) { URLSessionNetworkService() }
//            DIRegistration(APIClient.self) { RestAPIClient() }
//            
//            // 데이터 계층
//            DIRegistration(UserRepository.self) { CoreDataUserRepository() }
//            DIRegistration(ProductRepository.self) { RealmProductRepository() }
//            
//            // 비즈니스 로직 계층
//            DIRegistration(UserService.self) { 
//                UserServiceImpl(repository: DI.requireResolve(UserRepository.self))
//            }
//            DIRegistration(ProductService.self) { 
//                ProductServiceImpl(
//                    repository: DI.requireResolve(ProductRepository.self),
//                    api: DI.requireResolve(APIClient.self)
//                )
//            }
//        }
//    }
//    
//    // MARK: - Example 3: SwiftUI Integration
//    
//    /// SwiftUI 통합 예제 (개념적 예시)
//    public static func swiftUIExample() {
//        // SwiftUI View에서 사용하는 경우의 예시
//        // import SwiftUI가 필요하므로 실제 구현은 주석 처리
//        
//        /*
//        struct ProductListView: View {
//            @Inject(\.productService) private var productService: ProductService
//            @State private var products: [Product] = []
//            
//            var body: some View {
//                List(products, id: \.id) { product in
//                    Text(product.name)
//                }
//                .onAppear {
//                    loadProducts()
//                }
//            }
//            
//            private func loadProducts() {
//                productService.fetchProducts { fetchedProducts in
//                    DispatchQueue.main.async {
//                        self.products = fetchedProducts
//                    }
//                }
//            }
//        }
//        */
//        
//        print("📱 SwiftUI integration example - see source code for implementation")
//    }
//    
//    // MARK: - Example 4: Optional vs Required Dependencies
//    
//    /// 옵셔널 vs 필수 의존성 예제
//    public static func optionalVsRequiredExample() {
//        final class AnalyticsViewModel {
//            // 필수 의존성 - 앱이 작동하는데 필요
//            @Inject(\.userService) private var userService: UserService
//            
//            // 옵셔널 의존성 - 없어도 앱이 작동함
//            @Inject(\.analyticsService) private var analyticsService: AnalyticsService?
//            
//            func trackUserAction() {
//                let user = userService.currentUser
//                
//                // 옵셔널 의존성은 안전하게 사용
//                analyticsService?.track("user_action", parameters: [
//                    "user_id": user.id
//                ])
//            }
//        }
//    }
//    
//    // MARK: - Example 5: Testing
//    
//    /// 테스트 예제
//    public static func testingExample() {
//        // 테스트 시작 시 모든 의존성 정리
//        DI.releaseAll()
//        
//        // 테스트용 의존성 등록
//        DI.register(UserRepository.self) { MockUserRepository() }
//        DI.register(UserService.self) { 
//            UserServiceImpl(repository: DI.requireResolve(UserRepository.self))
//        }
//        
//        // 테스트 실행
//        final class UserServiceTests {
//            func testFetchUser() {
//                let userService = DI.requireResolve(UserService.self)
//                
//                userService.fetchUser(id: "123") { user in
//                    assert(user.id == "123")
//                }
//            }
//        }
//    }
//    
//    // MARK: - Example 6: Conditional Registration
//    
//    /// 조건부 등록 예제
//    public static func conditionalRegistrationExample() {
//        let isDebugMode = ProcessInfo.processInfo.environment["DEBUG"] != nil
//        
//        // Debug/Release에 따른 다른 구현 등록
//        DI.registerIf(
//            LoggingService.self,
//            condition: isDebugMode,
//            factory: { VerboseLoggingService() },       // Debug용
//            fallback: { SilentLoggingService() }        // Release용
//        )
//        
//        // 네트워크 환경에 따른 다른 구현
//        let isDevelopment = Bundle.main.bundleIdentifier?.contains(".dev") ?? false
//        
//        DI.registerIf(
//            NetworkService.self,
//            condition: isDevelopment,
//            factory: { DevelopmentNetworkService() },   // 개발 서버
//            fallback: { ProductionNetworkService() }    // 운영 서버
//        )
//    }
//}
//
//// MARK: - Sample Protocols and Implementations
//
//// 예제를 위한 샘플 프로토콜들
//protocol NetworkService: Sendable {
//    func request<T: Codable>(_ endpoint: String) async throws -> T
//}
//
//protocol UserRepository: Sendable {
//    func fetchUser(id: String) async throws -> ExampleUser
//    func saveUser(_ user: ExampleUser) async throws
//}
//
//protocol UserService: Sendable {
//    var currentUser: ExampleUser { get }
//    func fetchCurrentUser(completion: @escaping @Sendable (ExampleUser) -> Void)
//    func fetchUser(id: String, completion: @escaping @Sendable (ExampleUser) -> Void)
//}
//
//protocol ProductService: Sendable {
//    func fetchProducts(completion: @escaping @Sendable ([Product]) -> Void)
//}
//
//protocol APIClient: Sendable {
//    func get<T: Codable>(_ path: String) async throws -> T
//}
//
//protocol ProductRepository: Sendable {
//    func fetchAll() async throws -> [Product]
//}
//
//protocol AnalyticsService: Sendable {
//    func track(_ event: String, parameters: [String: Any])
//}
//
//protocol LoggingService: Sendable {
//    func log(_ message: String, level: LogLevel)
//}
//
//// 예제를 위한 샘플 구현체들
//struct URLSessionNetworkService: NetworkService {
//    func request<T: Codable>(_ endpoint: String) async throws -> T {
//        fatalError("Sample implementation")
//    }
//}
//
//struct CoreDataUserRepository: UserRepository {
//    func fetchUser(id: String) async throws -> ExampleUser {
//        return ExampleUser(id: id, name: "Sample User")
//    }
//    
//    func saveUser(_ user: ExampleUser) async throws {
//        // Save to Core Data
//    }
//}
//
//struct UserServiceImpl: UserService {
//    private let repository: UserRepository
//    private let network: NetworkService?
//    
//    init(repository: UserRepository, network: NetworkService? = nil) {
//        self.repository = repository
//        self.network = network
//    }
//    
//    var currentUser: ExampleUser {
//        return ExampleUser(id: "current", name: "Current User")
//    }
//    
//    func fetchCurrentUser(completion: @escaping @Sendable (ExampleUser) -> Void) {
//        Task {
//            do {
//                let user = try await repository.fetchUser(id: "current")
//                completion(user)
//            } catch {
//                // Handle error - for example purposes
//                completion(ExampleUser(id: "error", name: "Error"))
//            }
//        }
//    }
//    
//    func fetchUser(id: String, completion: @escaping @Sendable (ExampleUser) -> Void) {
//        Task {
//            do {
//                let user = try await repository.fetchUser(id: id)
//                completion(user)
//            } catch {
//                // Handle error - for example purposes
//                completion(ExampleUser(id: "error", name: "Error"))
//            }
//        }
//    }
//}
//
//// 샘플 모델들 (renamed to avoid conflict)
//struct ExampleUser: Codable, Sendable {
//    let id: String
//    let name: String
//}
//
//struct Product: Codable, Sendable {
//    let id: String
//    let name: String
//    let price: Double
//}
//
//enum LogLevel {
//    case debug, info, warning, error
//}
//
//// 더미 구현체들
//struct RestAPIClient: APIClient {
//    func get<T: Codable>(_ path: String) async throws -> T {
//        fatalError("Sample implementation")
//    }
//}
//
//struct RealmProductRepository: ProductRepository {
//    func fetchAll() async throws -> [Product] {
//        return []
//    }
//}
//
//struct ProductServiceImpl: ProductService {
//    private let repository: ProductRepository
//    private let api: APIClient
//    
//    init(repository: ProductRepository, api: APIClient) {
//        self.repository = repository
//        self.api = api
//    }
//    
//    func fetchProducts(completion: @escaping @Sendable ([Product]) -> Void) {
//        Task {
//            do {
//                let products = try await repository.fetchAll()
//                completion(products)
//            } catch {
//                // Handle error - for example purposes
//                completion([])
//            }
//        }
//    }
//}
//
//struct MockUserRepository: UserRepository {
//    func fetchUser(id: String) async throws -> ExampleUser {
//        return ExampleUser(id: id, name: "Mock User")
//    }
//    
//    func saveUser(_ user: ExampleUser) async throws {
//        // Mock implementation
//    }
//}
//
//struct VerboseLoggingService: LoggingService {
//    func log(_ message: String, level: LogLevel) {
//        print("[\(level)] \(message)")
//    }
//}
//
//struct SilentLoggingService: LoggingService {
//    func log(_ message: String, level: LogLevel) {
//        // Silent in production
//    }
//}
//
//struct DevelopmentNetworkService: NetworkService {
//    func request<T: Codable>(_ endpoint: String) async throws -> T {
//        print("🔧 Development API call to: \(endpoint)")
//        fatalError("Sample implementation")
//    }
//}
//
//struct ProductionNetworkService: NetworkService {
//    func request<T: Codable>(_ endpoint: String) async throws -> T {
//        fatalError("Sample implementation")
//    }
//}
//
//// MARK: - DependencyContainer Extensions for Examples
//
//extension DependencyContainer {
//    var userService: UserService? {
//        return resolve(UserService.self)
//    }
//    
//    var productService: ProductService? {
//        return resolve(ProductService.self)
//    }
//    
//    var analyticsService: AnalyticsService? {
//        return resolve(AnalyticsService.self)
//    }
//}
