//
//  BasicExamples.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation

// MARK: - Quick Start Examples

/// 기본 사용 예제
public enum QuickStartExamples {

    /// 간단한 사용법 예제
    public static func basicExample() async {
        print("🚀 Quick Start - Basic Example")

        // 1. 부트스트랩
        await DependencyContainer.bootstrap { container in
            container.register(String.self) { "Hello, DiContainer!" }
            container.register(Int.self) { 42 }
        }

        // 2. 해결
        let message = DI.resolve(String.self)
        let number = DI.resolve(Int.self)

        print("Message: \(message ?? "No message")")
        print("Number: \(number ?? 0)")
    }

    /// 서비스 계층 예제
    public static func serviceLayerExample() async {
        print("🏗️ Service Layer Example")

        // 서비스 등록
        await DependencyContainer.bootstrap { container in
            container.register(LoggerService.self) { ConsoleLoggerService() }
            container.register(NetworkService.self) { URLSessionNetworkService() }
            container.register(UserService.self) { UserServiceImpl() }
        }

        // 서비스 사용
        let userService = DI.resolve(UserService.self)
        await userService?.performOperation()
    }

    /// Property Wrapper 예제
    public static func propertyWrapperExample() async {
        print("🎯 Property Wrapper Example")

        // 의존성 등록
        DI.register(ExampleRepository.self) { ExampleRepositoryImpl() }
        DI.register(ExampleValidator.self) { ExampleValidatorImpl() }

        // 컴포넌트 생성 및 사용
        let component = ExampleComponent()
        component.performTask()
    }

    /// 조건부 등록 예제
    public static func conditionalExample() async {
        print("🔀 Conditional Registration Example")

        let isProduction = false

        // 환경별 조건부 등록
        DI.registerIf(
            APIService.self,
            condition: isProduction,
            factory: { ProductionAPIService() },
            fallback: { MockAPIService() }
        )

        DI.registerIf(
            AnalyticsService.self,
            condition: isProduction,
            factory: { GoogleAnalyticsService() },
            fallback: { NoOpAnalyticsService() }
        )

        // 사용
        let apiService = DI.resolve(APIService.self)
        let analyticsService = DI.resolve(AnalyticsService.self)

        print("API Service: \(type(of: apiService))")
        print("Analytics Service: \(type(of: analyticsService))")
    }

    /// 배치 등록 예제
    public static func batchRegistrationExample() {
        print("📦 Batch Registration Example")

        DI.registerMany {
            Registration(DatabaseService.self) { SQLiteDatabaseService() }
            Registration(CacheService.self) { MemoryCacheService() }
            Registration(ConfigService.self) { DefaultConfigService() }

            Registration(
                EmailService.self,
                condition: true,
                factory: { SMTPEmailService() },
                fallback: { MockEmailService() }
            )
        }

        // 등록 확인
        print("Database registered: \(DI.isRegistered(DatabaseService.self))")
        print("Cache registered: \(DI.isRegistered(CacheService.self))")
        print("Config registered: \(DI.isRegistered(ConfigService.self))")
        print("Email registered: \(DI.isRegistered(EmailService.self))")
    }

    /// KeyPath Factory 사용 예제
    public static func keyPathFactoryExample() async {
        print("🔗 KeyPath Factory Example")

        // AppDIContainer를 통한 Factory 사용
        let appContainer = AppDIContainer.shared

        // Repository Factory 사용 (KeyPath 방식)
        let repositoryFactory = await appContainer.repositoryFactory
        print("✅ Repository Factory 생성됨: \(type(of: repositoryFactory))")

        // UseCase Factory 사용 (KeyPath 방식)
        let useCaseFactory = await appContainer.useCaseFactory
        print("✅ UseCase Factory 생성됨: \(type(of: useCaseFactory))")

        // Scope Factory 사용 (KeyPath 방식)
        let scopeFactory = await appContainer.scopeFactory
        print("✅ Scope Factory 생성됨: \(type(of: scopeFactory))")

        print("🎯 KeyPath Factory 방식의 장점:")
        print("   - 타입 안전성 보장")
        print("   - 컴파일 타임 검증")
        print("   - 자동 완성 지원")
        print("   - 리팩토링 안전성")
    }
}

// MARK: - Example Services

public protocol LoggerService {
    func log(_ message: String)
    func error(_ message: String)
}

public class ConsoleLoggerService: LoggerService {
    public init() {}

    public func log(_ message: String) {
        print("📝 LOG: \(message)")
    }

    public func error(_ message: String) {
        print("❌ ERROR: \(message)")
    }
}

public protocol NetworkService {
    func fetchData() async -> String
}

public class URLSessionNetworkService: NetworkService {
    public init() {}

    public func fetchData() async -> String {
        return "Network data from URLSession"
    }
}

public protocol UserService {
    func performOperation() async
}

public class UserServiceImpl: UserService {
    @Inject var logger: LoggerService?
    @Inject var network: NetworkService?

    public init() {}

    public func performOperation() async {
        logger?.log("Starting user operation")
        let data = await network?.fetchData() ?? "No data"
        logger?.log("Received: \(data)")
    }
}

// MARK: - Property Wrapper Examples

public protocol ExampleRepository {
    func getData() -> String
}

public class ExampleRepositoryImpl: ExampleRepository {
    public init() {}

    public func getData() -> String {
        return "Repository data"
    }
}

public protocol ExampleValidator {
    func validate(_ data: String) -> Bool
}

public class ExampleValidatorImpl: ExampleValidator {
    public init() {}

    public func validate(_ data: String) -> Bool {
        return !data.isEmpty
    }
}

public class ExampleComponent {
    @Inject var repository: ExampleRepository?
    @Inject var validator: ExampleValidator?

    public init() {}

    public func performTask() {
        guard let repo = repository,
              let validator = validator else {
            print("❌ Dependencies not available")
            return
        }

        let data = repo.getData()
        let isValid = validator.validate(data)

        print("✅ Task completed - Data: \(data), Valid: \(isValid)")
    }
}

// MARK: - Conditional Examples

public protocol APIService {
    func request() -> String
}

public class ProductionAPIService: APIService {
    public init() {}
    public func request() -> String { "Production API Response" }
}

public class MockAPIService: APIService {
    public init() {}
    public func request() -> String { "Mock API Response" }
}

public protocol AnalyticsService {
    func track(_ event: String)
}

public class GoogleAnalyticsService: AnalyticsService {
    public init() {}
    public func track(_ event: String) {
        print("📊 Google Analytics: \(event)")
    }
}

public class NoOpAnalyticsService: AnalyticsService {
    public init() {}
    public func track(_ event: String) {
        // No operation for development
    }
}

// MARK: - Batch Registration Examples

public protocol DatabaseService {
    func query(_ sql: String) -> [String]
}

public class SQLiteDatabaseService: DatabaseService {
    public init() {}
    public func query(_ sql: String) -> [String] {
        return ["SQLite result for: \(sql)"]
    }
}

public protocol CacheService {
    func get(_ key: String) -> String?
    func set(_ key: String, value: String)
}

public class MemoryCacheService: CacheService {
    private var cache: [String: String] = [:]

    public init() {}

    public func get(_ key: String) -> String? {
        return cache[key]
    }

    public func set(_ key: String, value: String) {
        cache[key] = value
    }
}

public protocol ConfigService {
    func getValue(_ key: String) -> String?
}

public class DefaultConfigService: ConfigService {
    public init() {}

    public func getValue(_ key: String) -> String? {
        return "Config value for: \(key)"
    }
}

public protocol EmailService {
    func send(to: String, subject: String, body: String)
}

public class SMTPEmailService: EmailService {
    public init() {}

    public func send(to: String, subject: String, body: String) {
        print("📧 SMTP Email sent to: \(to)")
    }
}

public class MockEmailService: EmailService {
    public init() {}

    public func send(to: String, subject: String, body: String) {
        print("📧 Mock Email sent to: \(to)")
    }
}

// MARK: - Demo Runner

public enum ExampleRunner {

    /// 모든 예제를 실행합니다
    public static func runAllExamples() async {
        print("🎬 Running DiContainer Examples")
        print("=" * 50)

        await QuickStartExamples.basicExample()
        print("\n" + "-" * 30 + "\n")

        await QuickStartExamples.serviceLayerExample()
        print("\n" + "-" * 30 + "\n")

        await QuickStartExamples.propertyWrapperExample()
        print("\n" + "-" * 30 + "\n")

        await QuickStartExamples.conditionalExample()
        print("\n" + "-" * 30 + "\n")

        QuickStartExamples.batchRegistrationExample()
        print("\n" + "-" * 30 + "\n")

        await QuickStartExamples.keyPathFactoryExample()

        print("\n🎉 All examples completed!")
    }
}

// MARK: - String Extensions for Demo

extension String {
    static func *(string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}