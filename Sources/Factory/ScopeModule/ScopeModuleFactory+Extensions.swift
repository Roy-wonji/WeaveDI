//
//  ScopeModuleFactory+Extensions.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/24/25.
//

//import Foundation
//
//// MARK: - ScopeModuleFactory Extensions
//
///// ScopeModuleFactory에 대한 편의 메서드들을 제공합니다.
///// RepositoryModuleFactory와 동일한 패턴으로 확장 메서드를 제공합니다.
//public extension ScopeModuleFactory {
//    
//    /// 기본 스코프 정의들을 등록합니다.
//    /// 이 메서드는 앱에서 사용하는 기본적인 스코프들을 한 번에 설정할 때 사용됩니다.
//    ///
//    /// ## 사용 예시:
//    /// ```swift
//    /// extension ScopeModuleFactory {
//    ///     public mutating func registerDefaultDefinitions() {
//    ///         let helper = registerModule
//    ///         scopeDefinitions = [
//    ///             helper.makeScopedDependency(
//    ///                 scope: NetworkScope.self,
//    ///                 factory: { DefaultNetworkService() }
//    ///             )
//    ///         ]
//    ///     }
//    /// }
//    /// ```
//    mutating func registerDefaultDefinitions() {
//        let helper = registerModule
//        scopeDefinitions = [
//            // Network Layer Scopes
//            helper.makeScopedDependency(
//                scope: NetworkScope.self,
//                factory: { DefaultNetworkService() }
//            ),
//            
//            // Cache Layer Scopes  
//            helper.makeScopedDependency(
//                scope: CacheScope.self,
//                factory: { InMemoryCacheService() }
//            ),
//            
//            // Logger Scopes
//            helper.makeScopedDependency(
//                scope: LoggerScope.self,
//                factory: { ConsoleLogger() }
//            ),
//            
//            // Config Scopes
//            helper.makeScopedDependency(
//                scope: ConfigScope.self,
//                factory: { DefaultConfigService() }
//            )
//        ]
//    }
//    
//    /// 인증 관련 스코프들을 등록합니다.
//    mutating func registerAuthScopes() {
//        let helper = registerModule
//        let authModules: [() -> Module] = [
//            helper.makeScopedDependency(
//                scope: AuthScope.self,
//                factory: { AuthRepositoryImpl() }
//            ),
//            
//            helper.makeScopedChain(
//                parent: AuthScope.self,
//                child: AuthUseCaseScope.self
//            ) { authRepository in
//                AuthUseCaseImpl(repository: authRepository)
//            }
//        ]
//        
//        scopeDefinitions.append(contentsOf: authModules)
//    }
//    
//    /// 사용자 관련 스코프들을 등록합니다.
//    mutating func registerUserScopes() {
//        let helper = registerModule
//        let userModules: [() -> Module] = [
//            helper.makeScopedChain(
//                parent: NetworkScope.self,
//                child: UserRepositoryScope.self
//            ) { networkService in
//                UserRepositoryImpl(networkService: networkService)
//            },
//            
//            helper.makeScopedChain(
//                parent: UserRepositoryScope.self,
//                child: UserUseCaseScope.self
//            ) { userRepository in
//                UserUseCaseImpl(repository: userRepository)
//            }
//        ]
//        
//        scopeDefinitions.append(contentsOf: userModules)
//    }
//}
//
//// MARK: - 예시용 스코프들과 구현체들
//
///// 인증 UseCase 스코프
//public struct AuthUseCaseScope: DependencyScope {
//    public typealias Dependencies = AuthRepositoryProtocol
//    public typealias Provides = AuthUseCaseProtocol
//    
//    public static func validate() -> Bool {
//        DependencyValidation.isRegistered(AuthRepositoryProtocol.self)
//    }
//}
//
///// 인증 UseCase 프로토콜
//public protocol AuthUseCaseProtocol {
//    func login(email: String, password: String) async -> Bool
//    func logout() async
//}
//
///// 인증 UseCase 구현체
//public struct AuthUseCaseImpl: AuthUseCaseProtocol {
//    private let repository: AuthRepositoryProtocol
//    
//    public init(repository: AuthRepositoryProtocol) {
//        self.repository = repository
//    }
//    
//    public func login(email: String, password: String) async -> Bool {
//        print("🔐 AuthUseCase: Processing login for \(email)")
//        return await repository.login(email: email, password: password)
//    }
//    
//    public func logout() async {
//        print("🔐 AuthUseCase: Processing logout")
//        // 로그아웃 로직
//    }
//}
//
//// MARK: - 기본 구현체들
//
///// 기본 네트워크 서비스 구현체
//public struct DefaultNetworkService: NetworkServiceProtocol {
//    public init() {}
//    
//    public func request(_ url: String) async -> Data {
//        print("🌐 Network: Making request to \(url)")
//        return Data()
//    }
//}
//
///// Mock 네트워크 서비스
//public struct MockNetworkService: NetworkServiceProtocol {
//    public init() {}
//    
//    public func request(_ url: String) async -> Data {
//        print("🧪 Mock Network: Simulating request to \(url)")
//        return Data("mock response".utf8)
//    }
//}
//
///// 사용 가이드 예시
//public enum ScopeModuleFactoryUsageGuide {
//    
//    /// RepositoryModuleFactory와 동일한 패턴으로 사용하는 방법
//    public static let repositoryPattern = """
//    // RepositoryModuleFactory와 동일한 패턴
//    extension ScopeModuleFactory {
//        public mutating func registerMyScopes() {
//            let helper = registerModule
//            scopeDefinitions = [
//                helper.makeScopedDependency(
//                    scope: MyScope.self,
//                    factory: { MyServiceImpl() }
//                )
//            ]
//        }
//    }
//    
//    // AppDIContainer에서 사용
//    extension AppDIContainer {
//        public func registerMyScopes() async {
//            var factoryCopy = scopeFactory
//            factoryCopy.registerMyScopes()
//            
//            await registerDependencies { container in
//                for module in factoryCopy.makeAllModules() {
//                    await container.register(module)
//                }
//            }
//        }
//    }
//    """
//    
//    /// 기본 사용법
//    public static let basicUsage = """
//    // 1. ScopeModuleFactory 생성
//    var scopeFactory = ScopeModuleFactory()
//    
//    // 2. 기본 스코프들 등록
//    scopeFactory.registerDefaultDefinitions()
//    
//    // 3. 추가 스코프들 등록
//    scopeFactory.registerAuthScopes()
//    scopeFactory.registerUserScopes()
//    
//    // 4. 모든 모듈 생성
//    let modules = scopeFactory.makeAllModules()
//    """
//}
