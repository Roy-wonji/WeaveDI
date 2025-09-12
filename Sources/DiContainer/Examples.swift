//
//  Examples.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/24/25.
//

import Foundation

// MARK: - 사용 예시

/// 개선된 DI Container의 사용 예시들입니다.
/// 
/// 이 파일은 새로운 기능들의 사용 방법을 보여줍니다:
/// 1. 타입 안전한 키 시스템
/// 2. Protocol + Associated Types 패턴
/// 3. 개선된 에러 처리
public struct DIExamples {
    
    // MARK: - 1. 타입 안전한 등록 예시
    
    /// 기본적인 타입 안전 등록 방법
    public static func basicTypeSafeRegistration() async {
        await DependencyContainer.bootstrapAsync { container in
            // 기존 방식 (하위 호환성)
            container.register(NetworkServiceProtocol.self) {
                DefaultNetworkService()
            }
            
            // 타입 안전한 키가 내부적으로 사용됨
            let service: NetworkServiceProtocol? = container.resolve(NetworkServiceProtocol.self)
            print("Network service resolved: \(service != nil)")
        }
    }
    
    // MARK: - 2. Protocol + Associated Types 예시
    
    /// DependencyScope를 활용한 의존성 정의
    public static func dependencyScopeExample() {
        // 네트워크 스코프: 의존성 없음, NetworkService 제공
        struct MyNetworkScope: DependencyScope {
            typealias Dependencies = EmptyDependencies
            typealias Provides = NetworkServiceProtocol
            
            static func validate() -> Bool {
                return true // 의존성이 없으므로 항상 유효
            }
        }
        
        // 사용자 스코프: NetworkService 필요, UserRepository와 UserUseCase 제공
        struct MyUserScope: DependencyScope {
            typealias Dependencies = NetworkServiceProtocol
            typealias Provides = (UserRepositoryProtocol, UserUseCaseProtocol)
            
            static func validate() -> Bool {
                return DependencyValidation.isRegistered(NetworkServiceProtocol.self)
            }
        }
        
        // 검증 실행
        let networkScopeValid = MyNetworkScope.validate()
        let userScopeValid = MyUserScope.validate()
        
        print("Network scope valid: \(networkScopeValid)")
        print("User scope valid: \(userScopeValid)")
    }
    
    // MARK: - 3. 개선된 에러 처리 예시
    
    /// 안전한 의존성 등록 방법들
    public static func safeRegistrationExamples() async {
        let registerModule = RegisterModule()
        
        await DependencyContainer.bootstrapAsync { _ in
            // 1. 타입 안전한 등록 (제네릭 제약 사용)
            let networkModuleSafe = registerModule.makeTypeSafeDependency(
                NetworkServiceProtocol.self
            ) {
                DefaultNetworkService() // 이미 NetworkServiceProtocol을 준수
            }
            
            // 2. 개선된 에러 처리 (DEBUG에서만 크래시, RELEASE에서는 폴백)
            let userModuleImproved = registerModule.makeDependencyImproved(
                UserRepositoryProtocol.self
            ) {
                DefaultUserRepository() // 타입 불일치 시 안전한 처리
            }
            
            let containerInstance = Container()
            await containerInstance.register(networkModuleSafe())
            await containerInstance.register(userModuleImproved())
            await containerInstance.build()
        }
    }
    
    // MARK: - 4. 마이그레이션 가이드
    
    /// 기존 코드에서 새로운 방식으로 마이그레이션하는 예시
    public static func migrationExample() async {
        await DependencyContainer.bootstrapAsync { _ in
            let registerModule = RegisterModule()
            
            // ✅ 새로운 방식 (권장)
            let newWayModule = registerModule.makeTypeSafeDependency(
                NetworkServiceProtocol.self
            ) {
                DefaultNetworkService()
            }
            
            let containerInstance = Container()
            await containerInstance.register(newWayModule())
            await containerInstance.build()
        }
    }
    
    // MARK: - 5. 고급 사용법
    
    /// 복잡한 의존성 그래프 예시
    public static func advancedUsageExample() async {
        let registerModule = RegisterModule()
        
        await DependencyContainer.bootstrapAsync { container in
            // 1단계: 기본 서비스들
            let networkModule = registerModule.makeTypeSafeDependency(
                NetworkServiceProtocol.self
            ) { DefaultNetworkService() }
            
            let databaseModule = registerModule.makeTypeSafeDependency(
                DatabaseServiceProtocol.self
            ) { DefaultDatabaseService() }
            
            // 2단계: Repository (기본 서비스들에 의존)
            let userRepoModule = registerModule.makeUseCaseWithRepository(
                UserRepositoryProtocol.self,
                repositoryProtocol: NetworkServiceProtocol.self,
                repositoryFallback: DefaultNetworkService()
            ) { networkService in
                DefaultUserRepository(networkService: networkService)
            }
            
            // 3단계: UseCase (Repository에 의존)
            let userUseCaseModule = registerModule.makeUseCaseWithRepository(
                UserUseCaseProtocol.self,
                repositoryProtocol: UserRepositoryProtocol.self,
                repositoryFallback: DefaultUserRepository()
            ) { userRepository in
                DefaultUserUseCase(repository: userRepository)
            }
            
            // 병렬 등록
            let container = Container()
            let modules = [networkModule, databaseModule, userRepoModule, userUseCaseModule]
            for module in modules {
                await container.register(module())
            }
            await container.build()
        }
    }
}

// MARK: - 예시용 구현체들

struct DefaultNetworkService: NetworkServiceProtocol {
    func request(_ url: String) async -> Data {
        Data()
    }
}

protocol DatabaseServiceProtocol {
    func query(_ sql: String) async -> [String]
}

struct DefaultDatabaseService: DatabaseServiceProtocol {
    func query(_ sql: String) async -> [String] {
        []
    }
}

struct DefaultUserRepository: UserRepositoryProtocol {
    private let networkService: NetworkServiceProtocol?
    
    init(networkService: NetworkServiceProtocol? = nil) {
        self.networkService = networkService
    }
    
    func fetchUser(id: String) async -> User? {
        User(id: id, name: "Default User")
    }
}

struct DefaultUserUseCase: UserUseCaseProtocol {
    private let repository: UserRepositoryProtocol?
    
    init(repository: UserRepositoryProtocol? = nil) {
        self.repository = repository
    }
    
    func getUser(id: String) async -> User? {
        await repository?.fetchUser(id: id)
    }
}