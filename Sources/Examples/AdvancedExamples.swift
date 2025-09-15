//
//  AdvancedExamples.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - Example Protocols

public protocol UserRepository: Sendable {
    func getUser(id: String) async -> String
}

public protocol NetworkRepository: Sendable {
    func fetchData() async -> String
}

public protocol UserUseCase: Sendable {
    func execute() async
}

public protocol NetworkUseCase: Sendable {
    func performNetworkOperation() async
}

// MARK: - Example Implementations

public class UserRepositoryImpl: UserRepository, @unchecked Sendable {
    public init() {}
    public func getUser(id: String) async -> String {
        return "User \(id) from repository"
    }
}

public class NetworkRepositoryImpl: NetworkRepository, @unchecked Sendable {
    public init() {}
    public func fetchData() async -> String {
        return "Network data from repository"
    }
}

public class UserUseCaseImpl: UserUseCase, @unchecked Sendable {
    public init() {}
    public func execute() async {
        #logDebug("🎯 UserUseCase executed")
    }
}

public class NetworkUseCaseImpl: NetworkUseCase, @unchecked Sendable {
    public init() {}
    public func performNetworkOperation() async {
        #logDebug("🌐 NetworkUseCase executed")
    }
}

// MARK: - Advanced Examples

/// 고급 사용 예제들
public enum AdvancedExamples {

    /// Auto Resolution 예제
    public static func autoResolutionExample() async {
        #logDebug("🤖 Auto Resolution Example")

        // 의존성 등록
        DI.register(DatabaseService.self) { SQLiteDatabaseService() }
        DI.register(NetworkService.self) { URLSessionNetworkService() }
        DI.register(LoggerService.self) { ConsoleLoggerService() }

        // Auto Resolution 활성화
        AutoDependencyResolver.enable()

        // Auto Injectable 컴포넌트 생성
        let service = AutoInjectableUserService()

        // 자동 해결 수행
        AutoDependencyResolver.resolve(service)

        // 서비스 사용
        await service.performComplexOperation()
    }

    /// Module Factory 예제
    public static func moduleFactoryExample() async {
        #logDebug("🏭 Module Factory Example")

        // Repository Module Factory (simplified example)
        DI.registerMany {
            Registration(UserRepository.self) { UserRepositoryImpl() }
            Registration(NetworkRepository.self) { NetworkRepositoryImpl() }
        }

        // UseCase Module Factory (simplified example)
        DI.registerMany {
            Registration(UserUseCase.self) { UserUseCaseImpl() }
            Registration(NetworkUseCase.self) { NetworkUseCaseImpl() }
        }

        // 사용
        let userUseCase = DI.resolve(UserUseCase.self)
        await userUseCase?.execute()
    }

    /// Plugin System 예제
    public static func pluginSystemExample() async {
        #logDebug("🔌 Plugin System Example")

        // Plugin Manager 생성 (simplified example)
        #logDebug("🔌 Plugin system would be initialized here")

        // 플러그인들 생성 및 등록 (simplified)
        let loggingPlugin = ExampleLoggingPlugin(identifier: "logging", version: "1.0.0", description: "Logging plugin")
        let performancePlugin = ExamplePerformancePlugin(identifier: "performance", version: "1.0.0", description: "Performance plugin")
        let validationPlugin = ExampleValidationPlugin(identifier: "validation", version: "1.0.0", description: "Validation plugin")

        // 플러그인 활성화 시뮬레이션
        try? await loggingPlugin.activate()
        try? await performancePlugin.activate()
        try? await validationPlugin.activate()

        #logInfo("✅ All plugins activated successfully")

        // 플러그인이 적용된 DI 작업 수행
        DI.register(ExampleService.self) { ExampleServiceImpl() }
        let service = DI.resolve(ExampleService.self)
        service?.performOperation()
    }

    /// Performance Optimization 예제
    public static func performanceOptimizationExample() async {
        #logDebug("⚡ Performance Optimization Example")

        // 성능 최적화 활성화
        await SimplePerformanceOptimizer.enableOptimization()

        // 자주 사용되는 타입들 등록
        await SimplePerformanceOptimizer.markAsFrequentlyUsed(UserService.self)
        await SimplePerformanceOptimizer.markAsFrequentlyUsed(NetworkService.self)
        await SimplePerformanceOptimizer.markAsFrequentlyUsed(DatabaseService.self)

        // 의존성 등록
        DI.register(UserService.self) { UserServiceImpl() }
        DI.register(NetworkService.self) { URLSessionNetworkService() }
        DI.register(DatabaseService.self) { SQLiteDatabaseService() }

        // 성능 테스트
        #if DEBUG
        let userServiceTime = DI.performanceTest(UserService.self, iterations: 1000)
        let networkServiceTime = DI.performanceTest(NetworkService.self, iterations: 1000)

        #logDebug("🔬 Performance Results:")
        #logDebug("   UserService: \(userServiceTime * 1000)ms")
        #logDebug("   NetworkService: \(networkServiceTime * 1000)ms")
        #endif

        // 통계 확인
        let stats = await SimplePerformanceOptimizer.getStats()
        #logInfo("📊 Performance Stats:")
        #logDebug(stats.summary)
    }

    /// Async DI 예제
    public static func asyncDIExample() async {
        #logDebug("🚀 Async DI Example")

        // 비동기 팩토리 등록
        await DIAsync.register(AsyncDatabaseService.self) {
            await AsyncDatabaseService.initialize()
        }

        await DIAsync.register(AsyncNetworkService.self) {
            await AsyncNetworkService.create()
        }

        // 배치 비동기 등록
        await DIAsync.registerMany {
            DIAsyncRegistration(AsyncUserService.self) {
                await AsyncUserService.setup()
            }
            DIAsyncRegistration(AsyncCacheService.self) {
                AsyncCacheService()
            }
        }

        // 비동기 해결
        let dbService = await DIAsync.resolve(AsyncDatabaseService.self)
        let userService = await DIAsync.resolve(AsyncUserService.self)

        await dbService?.performAsyncOperation()
        await userService?.handleAsyncTask()
    }

    /// Needle Style Components 예제
    public static func needleStyleExample() async {
        #logDebug("📦 Needle Style Components Example")

        // Root Component 생성
        let rootComponent = RootComponent()

        // Child Components 생성
        let userComponent = rootComponent.userComponent
        let networkComponent = rootComponent.networkComponent

        // Components 사용
        let userService = userComponent.userService
        let networkService = networkComponent.networkService

        await userService.performOperation()
        let _ = await networkService.fetchData()
    }
}

// MARK: - Auto Resolution Examples

/// Auto Injectable 프로토콜을 구현한 서비스
public class AutoInjectableUserService: AutoInjectible, AutoResolvable {
    private var database: DatabaseService?
    private var network: NetworkService?
    private var logger: LoggerService?

    public init() {}

    public func injectResolvedValue(_ value: Any, forProperty propertyName: String) {
        switch propertyName {
        case "database":
            self.database = value as? DatabaseService
        case "network":
            self.network = value as? NetworkService
        case "logger":
            self.logger = value as? LoggerService
        default:
            break
        }
    }

    public func performComplexOperation() async {
        logger?.log("Starting complex operation")

        let data = await network?.fetchData() ?? "No data"
        let saved = database?.query("INSERT INTO users VALUES ('\(data)')") ?? []

        logger?.log("Operation completed: \(saved)")
    }
}

// MARK: - Plugin Examples

public class ExampleLoggingPlugin: BasePlugin, @unchecked Sendable {
    public override func activate() async throws {
        try await super.activate()
        #logDebug("📝 Logging Plugin activated - All DI operations will be logged")
    }
}

public class ExamplePerformancePlugin: BasePlugin, @unchecked Sendable {
    public override func activate() async throws {
        try await super.activate()
        #logDebug("⚡ Performance Plugin activated - DI performance will be tracked")
    }
}

public class ExampleValidationPlugin: BasePlugin, @unchecked Sendable {
    public override func activate() async throws {
        try await super.activate()
        #logInfo("✅ Validation Plugin activated - DI registrations will be validated")
    }
}

public protocol ExampleService {
    func performOperation()
}

public class ExampleServiceImpl: ExampleService {
    public init() {}

    public func performOperation() {
        #logDebug("🔧 ExampleService operation performed with plugin support")
    }
}

// MARK: - Async Services

public class AsyncDatabaseService {
    public static func initialize() async -> AsyncDatabaseService {
        // 비동기 초기화 시뮬레이션
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초
        #logDebug("🗄️ AsyncDatabaseService initialized")
        return AsyncDatabaseService()
    }

    private init() {}

    public func performAsyncOperation() async {
        #logDebug("🗄️ Performing async database operation")
    }
}

public class AsyncNetworkService {
    public static func create() async -> AsyncNetworkService {
        // 비동기 생성 시뮬레이션
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05초
        #logDebug("🌐 AsyncNetworkService created")
        return AsyncNetworkService()
    }

    private init() {}
}

public class AsyncUserService {
    public static func setup() async -> AsyncUserService {
        #logDebug("👤 AsyncUserService setup")
        return AsyncUserService()
    }

    private init() {}

    public func handleAsyncTask() async {
        #logDebug("👤 Handling async user task")
    }
}

public class AsyncCacheService {
    public init() {
        #logDebug("💾 AsyncCacheService created")
    }
}

// MARK: - Needle Style Components

/// Root Component (Needle 스타일)
public class RootComponent {

    public lazy var userComponent: UserComponent = {
        return UserComponent(parent: self)
    }()

    public lazy var networkComponent: NetworkComponent = {
        return NetworkComponent(parent: self)
    }()

    // Shared dependencies
    public lazy var logger: LoggerService = {
        return ConsoleLoggerService()
    }()

    public init() {}
}

/// User Component
public class UserComponent {
    private let parent: RootComponent

    public init(parent: RootComponent) {
        self.parent = parent
    }

    public lazy var userService: UserService = {
        return UserServiceImpl()
    }()

    public lazy var userRepository: NeedleUserRepository = {
        return NeedleUserRepositoryImpl(database: parent.networkComponent.database)
    }()
}

/// Network Component
public class NetworkComponent {
    private let parent: RootComponent

    public init(parent: RootComponent) {
        self.parent = parent
    }

    public lazy var networkService: NetworkService = {
        return URLSessionNetworkService()
    }()

    public lazy var database: DatabaseService = {
        return SQLiteDatabaseService()
    }()
}

/// User Repository for Needle example
public protocol NeedleUserRepository {
    func findUser(id: String) async -> String?
}

public class NeedleUserRepositoryImpl: NeedleUserRepository {
    private let database: DatabaseService

    public init(database: DatabaseService) {
        self.database = database
    }

    public func findUser(id: String) async -> String? {
        let results = database.query("SELECT * FROM users WHERE id = '\(id)'")
        return results.first
    }
}

// MARK: - Demo Runner for Advanced Examples

public enum AdvancedExampleRunner {

    /// 모든 고급 예제를 실행합니다
    public static func runAllAdvancedExamples() async {
        #logDebug("🎬 Running Advanced DiContainer Examples")
        #logDebug("=" * 60)

        await AdvancedExamples.autoResolutionExample()
        #logDebug("\n" + "-" * 40 + "\n")

        await AdvancedExamples.moduleFactoryExample()
        #logDebug("\n" + "-" * 40 + "\n")

        await AdvancedExamples.pluginSystemExample()
        #logDebug("\n" + "-" * 40 + "\n")

        await AdvancedExamples.performanceOptimizationExample()
        #logDebug("\n" + "-" * 40 + "\n")

        await AdvancedExamples.asyncDIExample()
        #logDebug("\n" + "-" * 40 + "\n")

        await AdvancedExamples.needleStyleExample()

        #logDebug("\n🚀 All advanced examples completed!")
    }
}