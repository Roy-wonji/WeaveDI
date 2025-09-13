//
//  SimpleExamples.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/24/25.
//

import Foundation
import LogMacro

/// 간단하고 실용적인 사용 예시들
public enum SimpleExamples {
    
    /// ## 🎯 사용자의 기존 패턴을 새 시스템으로 변환하는 완전한 예시
    /// 
    /// ### 기존 방식:
    /// ```swift
    /// public extension RegisterModule {
    ///   var authUseCaseImplModule: () -> Module {
    ///     makeUseCaseWithRepository(
    ///       AuthInterface.self,
    ///       repositoryProtocol: AuthInterface.self,
    ///       repositoryFallback: DefaultAuthRepositoryImpl(),
    ///       factory: { repo in AuthUseCaseImpl(repository: repo) }
    ///     )
    ///   }
    ///
    ///   var authRepositoryImplModule: () -> Module {
    ///     makeDependency(AuthInterface.self) {
    ///       AuthRepositoryImpl()
    ///     }
    ///   }
    /// }
    /// ```
    /// 
    /// ### 🔥 새로운 방식 (한번에 등록):
    /// ```swift
    /// let authModules = registerModule.interface(
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
    public static func basicAuthInterfaceUsage() async {
        let registerModule = RegisterModule()
        
        // 사용자의 기존 코드와 완전히 동일한 결과를 한번에
        let authModules = registerModule.interface(
            ExampleTypes.AuthInterface.self,
            repository: { ExampleTypes.AuthRepositoryImpl() },
            useCase: { repo in ExampleTypes.AuthUseCaseImpl(repository: repo) },
            fallback: { ExampleTypes.DefaultAuthRepositoryImpl() }
        )
        
        // 모듈 등록
        await AppDIContainer.shared.registerDependencies { container in
            for moduleFactory in authModules {
                await container.register(moduleFactory())
            }
        }
        
        #logInfo("✅ Auth modules registered successfully!")
    }
    
    /// ## 📦 여러 인터페이스를 한번에 등록하는 벌크 방식
    /// 
    /// ```swift
    /// let allModules = registerModule.bulkInterfaces {
    ///     AuthInterface.self => (
    ///         repository: { AuthRepositoryImpl() },
    ///         useCase: { repo in AuthUseCaseImpl(repository: repo) },
    ///         fallback: { DefaultAuthRepositoryImpl() }
    ///     )
    ///     UserInterface.self => (
    ///         repository: { UserRepositoryImpl() },
    ///         useCase: { repo in UserUseCaseImpl(repository: repo) },
    ///         fallback: { DefaultUserRepositoryImpl() }
    ///     )
    /// }
    /// ```
    public static func bulkRegistrationUsage() async {
        let registerModule = RegisterModule()
        
        // 여러 인터페이스를 한번에 등록
        let allModules = registerModule.bulkInterfaces {
            ExampleTypes.AuthInterface.self => (
                repository: { ExampleTypes.AuthRepositoryImpl() },
                useCase: { repo in ExampleTypes.AuthUseCaseImpl(repository: repo) },
                fallback: { ExampleTypes.DefaultAuthRepositoryImpl() }
            )
            ExampleTypes.UserInterface.self => (
                repository: { ExampleTypes.UserRepositoryImpl() },
                useCase: { repo in ExampleTypes.UserUseCaseImpl(repository: repo) },
                fallback: { ExampleTypes.DefaultUserRepositoryImpl() }
            )
        }
        
        // 모든 모듈 등록
        await AppDIContainer.shared.registerDependencies { container in
            for moduleFactory in allModules {
                await container.register(moduleFactory())
            }
        }
        
        #logInfo("✅ All business modules registered successfully!")
    }
    
    /// ## 🚀 자동 등록 시스템 사용법
    /// 
    /// ```swift
    /// // 1. 앱 시작 시 한번만 설정
    /// AutoRegistrationRegistry.shared.registerTypes {
    ///     TypeRegistration(AuthInterface.self) { AuthRepositoryImpl() }
    ///     TypeRegistration(UserInterface.self) { UserRepositoryImpl() }
    /// }
    /// 
    /// // 2. 이후 간편하게 사용
    /// @ContainerRegisterWrapper(\.authInterface)
    /// private var authService: AuthInterface
    /// ```
    public static func autoRegistrationUsage() {
        // 앱 시작 시 한번만 설정
        AutoRegistrationRegistry.shared.registerTypes {
            TypeRegistration(ExampleTypes.AuthInterface.self) {
                ExampleTypes.AuthRepositoryImpl()
            }
            TypeRegistration(ExampleTypes.UserInterface.self) {
                ExampleTypes.UserRepositoryImpl()
            }
        }
        
        #logInfo("✅ Auto registration setup complete!")
        #logInfo("Now you can use: @ContainerRegisterWrapper(\\.authInterface) without defaultFactory")
    }
    
    /// ## 🏗️ RegisterModule Extension 활용법
    /// 
    /// ```swift
    /// extension RegisterModule {
    ///     var allBusinessModules: [() -> Module] {
    ///         return interface(
    ///             AuthInterface.self,
    ///             repository: { AuthRepositoryImpl() },
    ///             useCase: { repo in AuthUseCaseImpl(repository: repo) },
    ///             fallback: { DefaultAuthRepositoryImpl() }
    ///         )
    ///     }
    /// }
    /// ```
    public static func extensionUsage() async {
        let registerModule = ExampleRegisterModuleExtensions()
        
        // Extension에서 정의한 모듈들 사용
        let businessModules = registerModule.allBusinessModules
        
        await AppDIContainer.shared.registerDependencies { container in
            for moduleFactory in businessModules {
                await container.register(moduleFactory())
            }
        }
        
        #logInfo("✅ Extension-based modules registered!")
    }
    
    /// ## 📱 완전한 실제 앱 예시
    /// 
    /// 실제 앱에서 사용할 수 있는 완전한 설정 예시입니다.
    public static func completeAppSetup() async {
        // 1. 자동 등록 설정
        setupAutoRegistration()
        
        // 2. 벌크 등록
        await setupBulkModules()
        
        #logInfo("🎉 Complete app DI setup finished!")
    }
    
    private static func setupAutoRegistration() {
        AutoRegistrationRegistry.shared.registerTypes {
            TypeRegistration(ExampleTypes.AuthInterface.self) {
                ExampleTypes.AuthRepositoryImpl()
            }
            TypeRegistration(ExampleTypes.UserInterface.self) {
                ExampleTypes.UserRepositoryImpl()
            }
        }
    }
    
    private static func setupBulkModules() async {
        let registerModule = RegisterModule()
        
        await AppDIContainer.shared.registerDependencies { container in
            let modules = registerModule.bulkInterfaces {
                ExampleTypes.AuthInterface.self => (
                    repository: { ExampleTypes.AuthRepositoryImpl() },
                    useCase: { repo in ExampleTypes.AuthUseCaseImpl(repository: repo) },
                    fallback: { ExampleTypes.DefaultAuthRepositoryImpl() }
                )
                ExampleTypes.UserInterface.self => (
                    repository: { ExampleTypes.UserRepositoryImpl() },
                    useCase: { repo in ExampleTypes.UserUseCaseImpl(repository: repo) },
                    fallback: { ExampleTypes.DefaultUserRepositoryImpl() }
                )
            }
            
            for moduleFactory in modules {
                await container.register(moduleFactory())
            }
        }
    }
}

// MARK: - Example Extension

/// RegisterModule Extension 예시
struct ExampleRegisterModuleExtensions {
    private let registerModule = RegisterModule()
    
    /// 모든 비즈니스 모듈을 한번에 반환
    var allBusinessModules: [() -> Module] {
        return registerModule.interface(
            ExampleTypes.AuthInterface.self,
            repository: { ExampleTypes.AuthRepositoryImpl() },
            useCase: { repo in ExampleTypes.AuthUseCaseImpl(repository: repo) },
            fallback: { ExampleTypes.DefaultAuthRepositoryImpl() }
        )
    }
}

// MARK: - Example Types

/// 예시를 위한 타입들
public enum ExampleTypes {
    
    // MARK: - Auth 관련
    
    public protocol AuthInterface {
        func login(email: String, password: String) async throws
        func logout() async
    }
    
    public struct AuthRepositoryImpl: AuthInterface {
        public init() {}
        
        public func login(email: String, password: String) async throws {
            #logDebug("🔐 AuthRepository: Login for \(email)")
        }
        
        public func logout() async {
            #logDebug("🔐 AuthRepository: Logout")
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
    }
    
    public struct DefaultAuthRepositoryImpl: AuthInterface {
        public init() {}
        
        public func login(email: String, password: String) async throws {
            #logDebug("🔒 Default AuthRepository: Mock login")
        }
        
        public func logout() async {
            #logDebug("🔒 Default AuthRepository: Mock logout")
        }
    }
    
    // MARK: - User 관련
    
    public protocol UserInterface {
        func getCurrentUser() async -> String?
        func updateUser(name: String) async throws
    }
    
    public struct UserRepositoryImpl: UserInterface {
        public init() {}
        
        public func getCurrentUser() async -> String? {
            return "Repository User"
        }
        
        public func updateUser(name: String) async throws {
            #logDebug("👤 UserRepository: Updating user \(name)")
        }
    }
    
    public struct UserUseCaseImpl: UserInterface {
        private let repository: UserInterface
        
        public init(repository: UserInterface) {
            self.repository = repository
        }
        
        public func getCurrentUser() async -> String? {
            return await repository.getCurrentUser()
        }
        
        public func updateUser(name: String) async throws {
            try await repository.updateUser(name: name)
        }
    }
    
    public struct DefaultUserRepositoryImpl: UserInterface {
        public init() {}
        
        public func getCurrentUser() async -> String? {
            return "Default User"
        }
        
        public func updateUser(name: String) async throws {
            #logDebug("👤 Default UserRepository: Mock update")
        }
    }
}

// MARK: - DependencyContainer 확장

public extension DependencyContainer {
    var authInterface: ExampleTypes.AuthInterface? {
        resolve(ExampleTypes.AuthInterface.self)
    }
    
    var userInterface: ExampleTypes.UserInterface? {
        resolve(ExampleTypes.UserInterface.self)
    }
}