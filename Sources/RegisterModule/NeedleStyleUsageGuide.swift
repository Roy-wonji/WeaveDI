//
//  NeedleStyleUsageGuide.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/24/25.
//

import Foundation

// MARK: - Needle 스타일 사용 가이드

/// 우리 라이브러리에 적용된 Needle 스타일 사용법을 보여주는 종합 가이드입니다.
///
/// ## 🎯 Needle의 핵심 개념 적용
///
/// ### Needle이란?
/// - **Uber에서 개발한 Swift DI 프레임워크**
/// - **컴파일 타임 안전성**: "컴파일되면 동작한다" 보장
/// - **계층적 구조**: Component와 Dependency로 계층 관리
/// - **고성능**: 코드 생성을 통한 런타임 오버헤드 최소화
///
/// ### 우리 라이브러리에 적용된 개념들:
/// 1. **Component**: 의존성 스코프를 정의하는 단위
/// 2. **Dependency**: 상위 스코프에서 받아올 의존성들
/// 3. **Hierarchical**: 계층적 의존성 구조
/// 4. **Auto-Registration**: 자동 타입 매핑 및 등록
public enum NeedleStyleUsageGuide {
    
    // MARK: - 1. ContainerRegister 간편 사용법
    
    /// ContainerRegister의 새로운 간편 사용법입니다.
    public static let containerRegisterUsage = """
    // 🔥 NEW! 간편한 자동 등록 방식
    
    // 1. 앱 시작 시 타입 매핑 설정
    func setupDI() {
        AutoRegistrationRegistry.shared.registerTypes {
            TypeRegistration(BookListInterface.self) { 
                BookListRepositoryImpl() 
            }
            TypeRegistration(UserServiceProtocol.self) { 
                UserServiceImpl() 
            }
        }
    }
    
    // 2. 이제 간편하게 사용 가능!
    class MyViewController {
        // ✅ 기존: 복잡한 방식
        // @ContainerRegister(\\.bookListInterface, defaultFactory: { BookListRepositoryImpl() })
        // private var repository: BookListInterface
        
        // 🚀 NEW: 안전한 방식 (크래시 방지)
        @ContainerInject(\\.bookListInterface)
        private var repository: BookListInterface?
        
        func loadBooks() async {
            guard let repository = repository else {
                print("⚠️ BookListInterface not registered - skipping")
                return
            }
            let books = try await repository.fetchBooks()
            // 안전하게 BookListRepositoryImpl이 주입됨!
        }
    }
    """
    
    // MARK: - 2. Needle 스타일 Component 패턴
    
    /// Needle 스타일의 Component 패턴 사용법입니다.
    public static let componentPatternUsage = """
    // 🎯 Needle 스타일 Component 패턴
    
    // 1. Root Component (최상위)
    class AppRootComponent: RootComponent {
        
        var networkService: NetworkServiceProtocol {
            DefaultNetworkService()
        }
        
        var logger: LoggerProtocol {
            ConsoleLogger()
        }
        
        override func makeAllModules() -> [Module] {
            return [
                registerModule.makeModule(NetworkServiceProtocol.self) { self.networkService },
                registerModule.makeModule(LoggerProtocol.self) { self.logger }
            ]
        }
    }
    
    // 2. Dependency 정의 (상위 스코프에서 필요한 것들)
    protocol UserDependency: Dependency {
        var networkService: NetworkServiceProtocol { get }
        var logger: LoggerProtocol { get }
    }
    
    // 3. Child Component (하위 스코프)
    class UserComponent: Component<UserDependency> {
        
        var userRepository: UserRepositoryProtocol {
            UserRepositoryImpl(
                networkService: dependency.networkService,
                logger: dependency.logger
            )
        }
        
        var userUseCase: UserUseCaseProtocol {
            UserUseCaseImpl(repository: userRepository)
        }
        
        override func makeAllModules() -> [Module] {
            return [
                registerModule.makeModule(UserRepositoryProtocol.self) { self.userRepository },
                registerModule.makeModule(UserUseCaseProtocol.self) { self.userUseCase }
            ]
        }
    }
    
    // 4. AppDIContainer에서 사용
    extension AppDIContainer {
        func registerNeedleStyle() async {
            let registerModule = RegisterModule()
            
            await registerDependencies { container in
                // Root Component 등록
                let rootComponent = AppRootComponent()
                let rootModules = registerModule.makeNeedleComponent(rootComponent)
                
                for moduleFactory in rootModules {
                    await container.register(moduleFactory())
                }
                
                // User Component 등록 (의존성 주입)
                let userDependency = UserDependencyImpl(
                    networkService: rootComponent.networkService,
                    logger: rootComponent.logger
                )
                let userComponent = UserComponent(dependency: userDependency)
                let userModules = registerModule.makeNeedleComponent(userComponent)
                
                for moduleFactory in userModules {
                    await container.register(moduleFactory())
                }
            }
        }
    }
    """
    
    // MARK: - 3. 간편한 스코프 등록 DSL
    
    /// 새로 추가된 간편한 스코프 등록 DSL 사용법입니다.
    public static let easyScopeUsage = """
    // 🚀 간편한 스코프 등록 DSL
    
    extension RegisterModule {
        
        // 방법 1: Needle 스타일 DSL
        func registerNeedleStyleScopes() -> [() -> Module] {
            return registerScopes {
                NetworkScope.provides { DefaultNetworkService() }
                CacheScope.provides { InMemoryCacheService() }
                AuthScope.provides { AuthRepositoryImpl() }
                UserScope.provides { UserUseCaseImpl() }
            }
        }
        
        // 방법 2: 타입 안전한 간편 등록
        func registerEasyScopes() -> [() -> Module] {
            return easyScopes {
                register(NetworkServiceProtocol.self) { DefaultNetworkService() }
                register(CacheServiceProtocol.self) { InMemoryCacheService() }
                register(LoggerProtocol.self) { ConsoleLogger() }
                register(AuthInterface.self) { AuthRepositoryImpl() }
            }
        }
    }
    
    // ScopeModuleFactory에서 사용
    extension ScopeModuleFactory {
        public mutating func registerWithNeedleStyle() {
            let helper = registerModule
            
            // 간편한 등록
            let modules = helper.easyScopes {
                register(NetworkServiceProtocol.self) { DefaultNetworkService() }
                register(CacheServiceProtocol.self) { InMemoryCacheService() }
                register(LoggerProtocol.self) { ConsoleLogger() }
            }
            
            scopeDefinitions.append(contentsOf: modules)
        }
    }
    """
    
    // MARK: - 4. 통합 사용 예시
    
    /// 모든 기능을 통합한 실제 사용 예시입니다.
    public static let fullIntegrationExample = """
    // 🎯 완전한 Needle 스타일 통합 예시
    
    @main
    struct MyApp: App {
        init() {
            setupDependencyInjection()
        }
        
        var body: some Scene {
            WindowGroup { ContentView() }
        }
        
        private func setupDependencyInjection() {
            Task {
                // 1. 자동 등록 설정
                setupAutoRegistration()
                
                // 2. Needle 스타일 Component 등록
                await AppDIContainer.shared.registerNeedleStyle()
                
                // 3. 기존 방식과 함께 사용
                await AppDIContainer.shared.registerWithScopeFactory()
            }
        }
        
        private func setupAutoRegistration() {
            AutoRegistrationRegistry.shared.registerTypes {
                TypeRegistration(BookListInterface.self) { BookListRepositoryImpl() }
                TypeRegistration(UserServiceProtocol.self) { UserServiceImpl() }
                TypeRegistration(PaymentServiceProtocol.self) { PaymentServiceImpl() }
            }
        }
    }
    
    // 실제 사용
    class BookListViewController {
        // 🛡️ 안전한 자동 주입 (크래시 방지)
        @ContainerInject(\\.bookListInterface)
        private var repository: BookListInterface?
        
        @ContainerInject(\\.userService) 
        private var userService: UserServiceProtocol?
        
        func loadData() async {
            // 안전한 옵셔널 체이닝으로 크래시 방지
            guard let repository = repository,
                  let userService = userService else {
                print("⚠️ Required services not registered")
                return
            }
            
            let books = try await repository.fetchBooks()
            let user = await userService.getCurrentUser()
            
            // UI 업데이트...
        }
    }
    """
    
    // MARK: - 5. 마이그레이션 가이드
    
    /// 기존 코드에서 Needle 스타일로 마이그레이션하는 방법입니다.
    public static let migrationGuide = """
    // 🔄 기존 코드 → Needle 스타일 마이그레이션
    
    // === BEFORE (기존 방식) ===
    extension RegisterModule {
        var authUseCaseImplModule: () -> Module {
            makeUseCaseWithRepository(
                AuthInterface.self,
                repositoryProtocol: AuthInterface.self,
                repositoryFallback: DefaultAuthRepositoryImpl(),
                factory: { repo in AuthUseCaseImpl(repository: repo) }
            )
        }
    }
    
    @ContainerInject(\\.bookListInterface, defaultFactory: { BookListRepositoryImpl() })
    private var repository: BookListInterface?
    
    // === AFTER (Needle 스타일) ===
    
    // 1. 자동 등록 설정 (앱 시작 시 한 번)
    AutoRegistrationRegistry.shared.register(BookListInterface.self) {
        BookListRepositoryImpl()
    }
    
    // 2. 안전한 의존성 주입 (크래시 방지)
    @ContainerInject(\\.bookListInterface)
    private var repository: BookListInterface?
    
    // 3. Component 스타일 (선택적)
    class AuthComponent: RootComponent {
        var authRepository: AuthInterface { AuthRepositoryImpl() }
        var authUseCase: AuthInterface { 
            AuthUseCaseImpl(repository: authRepository) 
        }
        
        override func makeAllModules() -> [Module] {
            return [
                registerModule.makeModule(AuthInterface.self) { self.authUseCase }
            ]
        }
    }
    
    // 4. 간편한 스코프 등록
    let modules = registerModule.easyScopes {
        register(AuthInterface.self) { AuthRepositoryImpl() }
        register(UserServiceProtocol.self) { UserServiceImpl() }
    }
    """
}

// MARK: - 실제 구현 예시들

/// UserDependency의 실제 구현체 (예시 - 실제 LoggerProtocol이 정의되면 활성화)
// public struct UserDependencyImpl: UserDependency {
//     public let networkService: NetworkServiceProtocol  
//     public let logger: LoggerProtocol
//     
//     public init(networkService: NetworkServiceProtocol, logger: LoggerProtocol) {
//         self.networkService = networkService
//         self.logger = logger
//     }
// }

/// 비교 테이블
public enum ComparisonTable {
    public static let needleVsOriginal = """
    
    📊 Needle 스타일 vs 기존 방식 비교
    
    ┌─────────────────────┬──────────────────────────┬─────────────────────────────┐
    │      측면           │        기존 방식          │      Needle 스타일          │
    ├─────────────────────┼──────────────────────────┼─────────────────────────────┤
    │ 의존성 주입         │ 수동 defaultFactory 필요 │ 자동 등록 가능              │
    │ 코드 길이           │ 길고 복잡                │ 짧고 간결                   │
    │ 타입 안전성         │ 런타임 체크              │ 컴파일 타임 체크            │
    │ 계층 구조 관리      │ 수동 관리                │ Component로 자동 관리       │
    │ 가독성              │ 보통                     │ 우수                        │
    │ 학습 곡선           │ 낮음                     │ 중간 (Needle 개념 필요)     │
    │ 하위 호환성         │ 100%                     │ 100% (기존 방식도 지원)     │
    └─────────────────────┴──────────────────────────┴─────────────────────────────┘
    
    💡 결론: 새로운 코드는 Needle 스타일을, 기존 코드는 점진적 마이그레이션 권장
    """
}