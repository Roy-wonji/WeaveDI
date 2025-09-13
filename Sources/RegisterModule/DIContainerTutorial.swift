//
//  DIContainerTutorial.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/24/25.
//

import Foundation
import LogMacro

/// # DiContainer 사용 튜토리얼
/// 
/// 이 튜토리얼은 DiContainer 라이브러리의 핵심 기능들을 단계별로 설명합니다.
/// 
/// ## 목차
/// 1. [기본 사용법](#basic-usage)
/// 2. [Repository/UseCase 패턴](#repository-usecase-pattern)  
/// 3. [한번에 등록하기](#bulk-registration)
/// 4. [자동 등록 시스템](#auto-registration)
/// 5. [Needle 스타일 Component](#needle-style)
/// 6. [고급 사용법](#advanced-usage)
public enum DIContainerTutorial {
    
    // MARK: - 1. 기본 사용법
    
    /// ## 1. 기본 사용법
    /// 
    /// 가장 기본적인 의존성 등록과 주입 방법입니다.
    /// 
    /// ### 1-1. 간단한 서비스 등록
    /// ```swift
    /// // 프로토콜 정의
    /// protocol NetworkServiceProtocol {
    ///     func request(_ url: String) async -> Data
    /// }
    /// 
    /// // 구현체
    /// struct DefaultNetworkService: NetworkServiceProtocol {
    ///     func request(_ url: String) async -> Data {
    ///         // 네트워크 요청 구현
    ///         return Data()
    ///     }
    /// }
    /// 
    /// // 등록
    /// let registerModule = RegisterModule()
    /// let networkModule = registerModule.makeModule(NetworkServiceProtocol.self) {
    ///     DefaultNetworkService()
    /// }
    /// 
    /// await container.register(networkModule)
    /// ```
    /// 
    /// ### 1-2. DependencyContainer 사용
    /// ```swift
    /// // 의존성 키 정의
    /// extension DependencyContainer {
    ///     var networkService: NetworkServiceProtocol? {
    ///         resolve(NetworkServiceProtocol.self)
    ///     }
    /// }
    /// 
    /// // 사용
    /// @ContainerRegister(\.networkService, defaultFactory: { DefaultNetworkService() })
    /// private var networkService: NetworkServiceProtocol
    /// ```
    public static let basicUsage = """
    기본 사용법 예제는 위의 주석을 참조하세요.
    """
    
    // MARK: - 2. Repository/UseCase 패턴
    
    /// ## 2. Repository/UseCase 패턴
    /// 
    /// Clean Architecture의 Repository와 UseCase 패턴을 쉽게 구현할 수 있습니다.
    /// 
    /// ### 2-1. 기존 방식 (개별 등록)
    /// ```swift
    /// // Repository 등록
    /// var authRepositoryModule: () -> Module {
    ///     registerModule.makeDependency(AuthInterface.self) {
    ///         AuthRepositoryImpl()
    ///     }
    /// }
    /// 
    /// // UseCase 등록 (Repository 자동 주입)
    /// var authUseCaseModule: () -> Module {
    ///     registerModule.makeUseCaseWithRepository(
    ///         AuthInterface.self,
    ///         repositoryProtocol: AuthInterface.self,
    ///         repositoryFallback: DefaultAuthRepositoryImpl(),
    ///         factory: { repo in AuthUseCaseImpl(repository: repo) }
    ///     )
    /// }
    /// ```
    /// 
    /// ### 2-2. 새로운 방식 (한번에 등록)
    /// ```swift
    /// // 한번에 Repository + UseCase 등록
    /// let authModules = registerModule.authInterface(
    ///     AuthInterface.self,
    ///     repository: { AuthRepositoryImpl() },
    ///     useCase: { repo in AuthUseCaseImpl(repository: repo) },
    ///     fallback: { DefaultAuthRepositoryImpl() }
    /// )
    /// 
    /// // 등록
    /// for moduleFactory in authModules {
    ///     await container.register(moduleFactory())
    /// }
    /// ```
    public static let repositoryUseCasePattern = """
    Repository/UseCase 패턴 예제는 위의 주석을 참조하세요.
    """
    
    // MARK: - 3. 한번에 등록하기
    
    /// ## 3. 한번에 등록하기 (Bulk Registration)
    /// 
    /// 여러 인터페이스를 한번에 등록할 수 있는 강력한 DSL을 제공합니다.
    /// 
    /// ### 3-1. 벌크 등록 DSL
    /// ```swift
    /// let allModules = registerModule.bulkAuthInterfaces {
    ///     AuthInterface.self => (
    ///         repository: { AuthRepositoryImpl() },
    ///         useCase: { repo in AuthUseCaseImpl(repository: repo) },
    ///         fallback: { DefaultAuthRepositoryImpl() }
    ///     )
    ///     
    ///     UserInterface.self => (
    ///         repository: { UserRepositoryImpl() },
    ///         useCase: { repo in UserUseCaseImpl(repository: repo) },
    ///         fallback: { DefaultUserRepositoryImpl() }
    ///     )
    ///     
    ///     PaymentInterface.self => (
    ///         repository: { PaymentRepositoryImpl() },
    ///         useCase: { repo in PaymentUseCaseImpl(repository: repo) },
    ///         fallback: { DefaultPaymentRepositoryImpl() }
    ///     )
    /// }
    /// 
    /// // 모든 모듈 등록
    /// for moduleFactory in allModules {
    ///     await container.register(moduleFactory())
    /// }
    /// ```
    /// 
    /// ### 3-2. RegisterModule Extension 활용
    /// ```swift
    /// extension RegisterModule {
    ///     var allBusinessModules: [() -> Module] {
    ///         bulkAuthInterfaces {
    ///             AuthInterface.self => (
    ///                 repository: { AuthRepositoryImpl() },
    ///                 useCase: { repo in AuthUseCaseImpl(repository: repo) },
    ///                 fallback: { DefaultAuthRepositoryImpl() }
    ///             )
    ///             UserInterface.self => (
    ///                 repository: { UserRepositoryImpl() },
    ///                 useCase: { repo in UserUseCaseImpl(repository: repo) },
    ///                 fallback: { DefaultUserRepositoryImpl() }
    ///             )
    ///         }
    ///     }
    /// }
    /// 
    /// // 사용
    /// let businessModules = registerModule.allBusinessModules
    /// for moduleFactory in businessModules {
    ///     await container.register(moduleFactory())
    /// }
    /// ```
    public static let bulkRegistration = """
    벌크 등록 예제는 위의 주석을 참조하세요.
    """
    
    // MARK: - 4. 자동 등록 시스템
    
    /// ## 4. 자동 등록 시스템 (Auto Registration)
    /// 
    /// ContainerRegister에서 defaultFactory를 생략할 수 있는 자동 등록 시스템입니다.
    /// 
    /// ### 4-1. 타입 매핑 등록
    /// ```swift
    /// // 앱 시작 시 한번만 설정
    /// func setupAutoRegistration() {
    ///     AutoRegistrationRegistry.shared.registerTypes {
    ///         TypeRegistration(AuthInterface.self) {
    ///             AuthRepositoryImpl()
    ///         }
    ///         TypeRegistration(UserInterface.self) {
    ///             UserRepositoryImpl()
    ///         }
    ///         TypeRegistration(PaymentInterface.self) {
    ///             PaymentRepositoryImpl()
    ///         }
    ///     }
    /// }
    /// ```
    /// 
    /// ### 4-2. 간편한 사용
    /// ```swift
    /// // ✅ 기존: 복잡한 방식
    /// // @ContainerRegister(\.authInterface, defaultFactory: { AuthRepositoryImpl() })
    /// // private var authService: AuthInterface
    /// 
    /// // 🛡️ 새로운: 안전한 방식 (크래시 방지)
    /// @ContainerInject(\.authInterface)
    /// private var authService: AuthInterface?
    /// 
    /// @ContainerInject(\.userInterface)
    /// private var userService: UserInterface?
    /// 
    /// @ContainerInject(\.paymentInterface)
    /// private var paymentService: PaymentInterface?
    /// ```
    /// 
    /// ### 4-3. 실제 사용 예시
    /// ```swift
    /// class BookListViewController {
    ///     // 안전하게 AuthRepositoryImpl이 주입됨
    ///     @ContainerInject(\.authInterface)
    ///     private var authService: AuthInterface?
    ///     
    ///     func login() async {
    ///         guard let authService = authService else {
    ///             print("⚠️ AuthInterface not registered")
    ///             return
    ///         }
    ///         do {
    ///             await authService.login(email: "user@example.com", password: "password")
    ///             // 로그인 성공 처리
    ///         } catch {
    ///             // 에러 처리
    ///         }
    ///     }
    /// }
    /// ```
    public static let autoRegistration = """
    자동 등록 시스템 예제는 위의 주석을 참조하세요.
    """
    
    // MARK: - 5. Needle 스타일 Component
    
    /// ## 5. Needle 스타일 Component 패턴
    /// 
    /// Uber의 Needle DI 프레임워크에서 영감을 받은 컴파일 타임 안전한 의존성 관리입니다.
    /// 
    /// ### 5-1. Component와 Dependency 정의
    /// ```swift
    /// // 의존성 정의
    /// protocol NetworkDependency: Dependency {
    ///     // 이 컴포넌트는 외부 의존성 없음
    /// }
    /// 
    /// protocol UserDependency: Dependency {
    ///     var networkService: NetworkServiceProtocol { get }
    ///     var logger: LoggerProtocol { get }
    /// }
    /// 
    /// // Root 컴포넌트
    /// class AppRootComponent: RootComponent {
    ///     var networkService: NetworkServiceProtocol {
    ///         DefaultNetworkService()
    ///     }
    ///     
    ///     var logger: LoggerProtocol {
    ///         ConsoleLogger()
    ///     }
    ///     
    ///     override func makeAllModules() -> [Module] {
    ///         return [
    ///             registerModule.makeModule(NetworkServiceProtocol.self) { 
    ///                 self.networkService 
    ///             },
    ///             registerModule.makeModule(LoggerProtocol.self) { 
    ///                 self.logger 
    ///             }
    ///         ]
    ///     }
    /// }
    /// 
    /// // Child 컴포넌트  
    /// class UserComponent: Component<UserDependency> {
    ///     var userService: UserServiceProtocol {
    ///         UserServiceImpl(
    ///             networkService: dependency.networkService,
    ///             logger: dependency.logger
    ///         )
    ///     }
    ///     
    ///     override func makeAllModules() -> [Module] {
    ///         return [
    ///             registerModule.makeModule(UserServiceProtocol.self) {
    ///                 self.userService
    ///             }
    ///         ]
    ///     }
    /// }
    /// ```
    /// 
    /// ### 5-2. 컴포넌트 등록
    /// ```swift
    /// extension AppDIContainer {
    ///     func registerNeedleStyle() async {
    ///         await registerDependencies { container in
    ///             // Root 컴포넌트 등록
    ///             let rootComponent = AppRootComponent()
    ///             await rootComponent.register(in: container)
    ///             
    ///             // User 컴포넌트 등록 (의존성 주입)
    ///             let userDependency = UserDependencyImpl(
    ///                 networkService: rootComponent.networkService,
    ///                 logger: rootComponent.logger
    ///             )
    ///             let userComponent = UserComponent(dependency: userDependency)
    ///             await userComponent.register(in: container)
    ///         }
    ///     }
    /// }
    /// ```
    public static let needleStyle = """
    Needle 스타일 Component 예제는 위의 주석을 참조하세요.
    """
    
    // MARK: - 6. 고급 사용법
    
    /// ## 6. 고급 사용법
    /// 
    /// ### 6-1. 스코프 기반 의존성 관리
    /// ```swift
    /// // 스코프 정의
    /// struct NetworkScope: DependencyScope {
    ///     typealias Dependencies = EmptyDependencies
    ///     typealias Provides = NetworkServiceProtocol
    ///     
    ///     static func validate() -> Bool {
    ///         return true
    ///     }
    /// }
    /// 
    /// struct UserScope: DependencyScope {
    ///     typealias Dependencies = NetworkServiceProtocol
    ///     typealias Provides = UserServiceProtocol
    ///     
    ///     static func validate() -> Bool {
    ///         return DependencyValidation.isRegistered(NetworkServiceProtocol.self)
    ///     }
    /// }
    /// 
    /// // 스코프 등록
    /// let scopedModules = registerModule.makeScopedDependencies {
    ///     NetworkScope.provides { DefaultNetworkService() }
    ///     UserScope.provides { UserServiceImpl() }
    /// }
    /// ```
    /// 
    /// ### 6-2. 간편한 스코프 DSL
    /// ```swift
    /// let modules = registerModule.easyScopes {
    ///     register(NetworkServiceProtocol.self) { DefaultNetworkService() }
    ///     register(UserServiceProtocol.self) { UserServiceImpl() }
    ///     register(LoggerProtocol.self) { ConsoleLogger() }
    /// }
    /// ```
    /// 
    /// ### 6-3. 조건부 등록
    /// ```swift
    /// let conditionalModule = registerModule.makeUseCaseWithRepositoryOrNil(
    ///     AuthUseCaseProtocol.self,
    ///     repositoryProtocol: AuthRepositoryProtocol.self,
    ///     missing: .skipRegistration { message in
    ///         #logDebug("Skipping AuthUseCase: \(message)")
    ///     }
    /// ) { repo in
    ///     AuthUseCaseImpl(repository: repo)
    /// }
    /// ```
    public static let advancedUsage = """
    고급 사용법 예제는 위의 주석을 참조하세요.
    """
    
    // MARK: - 7. 완전한 실제 예시
    
    /// ## 7. 완전한 실제 사용 예시
    /// 
    /// 실제 앱에서 사용할 수 있는 완전한 예시입니다.
    /// 
    /// ### 7-1. 앱 초기화
    /// ```swift
    /// @main
    /// struct MyApp: App {
    ///     init() {
    ///         setupDependencyInjection()
    ///     }
    ///     
    ///     var body: some Scene {
    ///         WindowGroup { ContentView() }
    ///     }
    ///     
    ///     private func setupDependencyInjection() {
    ///         Task {
    ///             // 1. 자동 등록 설정
    ///             setupAutoRegistration()
    ///             
    ///             // 2. 벌크 등록
    ///             await AppDIContainer.shared.registerBulkModules()
    ///         }
    ///     }
    ///     
    ///     private func setupAutoRegistration() {
    ///         AutoRegistrationRegistry.shared.registerTypes {
    ///             TypeRegistration(AuthInterface.self) { AuthRepositoryImpl() }
    ///             TypeRegistration(UserInterface.self) { UserRepositoryImpl() }
    ///             TypeRegistration(PaymentInterface.self) { PaymentRepositoryImpl() }
    ///         }
    ///     }
    /// }
    /// 
    /// extension AppDIContainer {
    ///     func registerBulkModules() async {
    ///         let registerModule = RegisterModule()
    ///         
    ///         await registerDependencies { container in
    ///             let allModules = registerModule.bulkAuthInterfaces {
    ///                 AuthInterface.self => (
    ///                     repository: { AuthRepositoryImpl() },
    ///                     useCase: { repo in AuthUseCaseImpl(repository: repo) },
    ///                     fallback: { DefaultAuthRepositoryImpl() }
    ///                 )
    ///                 UserInterface.self => (
    ///                     repository: { UserRepositoryImpl() },
    ///                     useCase: { repo in UserUseCaseImpl(repository: repo) },
    ///                     fallback: { DefaultUserRepositoryImpl() }
    ///                 )
    ///             }
    ///             
    ///             for moduleFactory in allModules {
    ///                 await container.register(moduleFactory())
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    /// 
    /// ### 7-2. ViewController에서 사용
    /// ```swift
    /// class AuthViewController: UIViewController {
    ///     // 안전한 자동 주입
    ///     @ContainerInject(\.authInterface)
    ///     private var authService: AuthInterface?
    ///     
    ///     @ContainerInject(\.userInterface)
    ///     private var userService: UserInterface?
    ///     
    ///     override func viewDidLoad() {
    ///         super.viewDidLoad()
    ///         setupUI()
    ///     }
    ///     
    ///     @IBAction func loginButtonTapped() {
    ///         Task {
    ///             do {
    ///                 await authService.login(email: emailField.text ?? "", 
    ///                                       password: passwordField.text ?? "")
    ///                 let user = await userService.getCurrentUser()
    ///                 // UI 업데이트
    ///             } catch {
    ///                 // 에러 처리
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    public static let completeExample = """
    완전한 실제 예시는 위의 주석을 참조하세요.
    """
}

// MARK: - 튜토리얼 헬퍼

/// 튜토리얼에서 사용할 예시 타입들
public enum TutorialExampleTypes {
    
    // MARK: - 기본 타입들
    
    public protocol NetworkServiceProtocol {
        func request(_ url: String) async -> Data
    }
    
    public struct DefaultNetworkService: NetworkServiceProtocol {
        public init() {}
        
        public func request(_ url: String) async -> Data {
            #logDebug("🌐 Making request to: \(url)")
            return Data()
        }
    }
    
    public protocol LoggerProtocol {
        func info(_ message: String)
        func error(_ message: String)
    }
    
    public struct ConsoleLogger: LoggerProtocol {
        public init() {}
        
        public func info(_ message: String) {
            #logInfo("ℹ️ \(message)")
        }
        
        public func error(_ message: String) {
            #logError("❌ \(message)")
        }
    }
    
    // MARK: - Auth 관련 타입들
    
    public protocol AuthInterface {
        func login(email: String, password: String) async throws
        func logout() async
        func getCurrentUser() async -> User?
    }
    
    public struct AuthRepositoryImpl: AuthInterface {
        public init() {}
        
        public func login(email: String, password: String) async throws {
            #logDebug("🔐 AuthRepository: Login for \(email)")
        }
        
        public func logout() async {
            #logDebug("🔐 AuthRepository: Logout")
        }
        
        public func getCurrentUser() async -> User? {
            return User(id: "1", name: "Tutorial User")
        }
    }
    
    public struct AuthUseCaseImpl: AuthInterface {
        private let repository: AuthInterface
        
        public init(repository: AuthInterface) {
            self.repository = repository
        }
        
        public func login(email: String, password: String) async throws {
            #logDebug("🎯 AuthUseCase: Processing login for \(email)")
            try await repository.login(email: email, password: password)
        }
        
        public func logout() async {
            #logDebug("🎯 AuthUseCase: Processing logout")
            await repository.logout()
        }
        
        public func getCurrentUser() async -> User? {
            return await repository.getCurrentUser()
        }
    }
    
    public struct DefaultAuthRepositoryImpl: AuthInterface {
        public init() {}
        
        public func login(email: String, password: String) async throws {
            #logDebug("🔒 Default AuthRepository: Mock login")
        }
        
        public func logout() async {
            #logDebug("🔒 Default AuthRepository: Mock logout")
        }
        
        public func getCurrentUser() async -> User? {
            return User(id: "default", name: "Default User")
        }
    }
    
    // MARK: - User 관련 타입들
    
    public protocol UserInterface {
        func getCurrentUser() async -> User?
        func updateUser(_ user: User) async throws
    }
    
    public struct UserRepositoryImpl: UserInterface {
        public init() {}
        
        public func getCurrentUser() async -> User? {
            return User(id: "1", name: "Repository User")
        }
        
        public func updateUser(_ user: User) async throws {
            #logDebug("👤 UserRepository: Updating user \(user.name)")
        }
    }
    
    public struct UserUseCaseImpl: UserInterface {
        private let repository: UserInterface
        
        public init(repository: UserInterface) {
            self.repository = repository
        }
        
        public func getCurrentUser() async -> User? {
            return await repository.getCurrentUser()
        }
        
        public func updateUser(_ user: User) async throws {
            try await repository.updateUser(user)
        }
    }
    
    public struct DefaultUserRepositoryImpl: UserInterface {
        public init() {}
        
        public func getCurrentUser() async -> User? {
            return User(id: "default", name: "Default User")
        }
        
        public func updateUser(_ user: User) async throws {
            #logDebug("👤 Default UserRepository: Mock update")
        }
    }
    
    // MARK: - 공통 모델
    
    public struct User {
        public let id: String
        public let name: String
        
        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }
}

// MARK: - DependencyContainer 확장 (튜토리얼용)

public extension DependencyContainer {
    var tutorialAuthInterface: TutorialExampleTypes.AuthInterface? {
        resolve(TutorialExampleTypes.AuthInterface.self)
    }
    
    var tutorialUserInterface: TutorialExampleTypes.UserInterface? {
        resolve(TutorialExampleTypes.UserInterface.self)
    }
}