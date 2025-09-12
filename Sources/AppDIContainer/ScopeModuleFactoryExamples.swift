//
//  ScopeModuleFactoryExamples.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/24/25.
//

import Foundation

// MARK: - ScopeModuleFactory 사용 예시

/// ScopeModuleFactory를 실제 프로젝트에서 사용하는 방법들을 보여주는 예시 모음입니다.
//public enum ScopeModuleFactoryExamples {
//    
//    // MARK: - 기본 사용법
//    
//    /// ScopeModuleFactory의 기본 사용법을 보여주는 예시입니다.
//    /// RepositoryModuleFactory와 정확히 동일한 패턴으로 사용합니다.
//    public static func basicUsage() async {
//        // 1. ScopeModuleFactory 생성 (RepositoryModuleFactory와 동일)
//        var scopeFactory = ScopeModuleFactory()
//        
//        // 2. 기본 스코프 정의들 등록 (RepositoryModuleFactory.registerDefaultDefinitions()와 동일)
//        scopeFactory.registerDefaultDefinitions()
//        
//        // 3. 추가 스코프들 등록
//        scopeFactory.registerAuthScopes()
//        scopeFactory.registerUserScopes()
//        
//        // 4. 모든 모듈 생성 및 등록 (RepositoryModuleFactory.makeAllModules()와 동일)
//        await DependencyContainer.bootstrapAsync { _ in
//            let container = Container()
//            
//            // RepositoryModuleFactory와 정확히 동일한 패턴
//            for module in scopeFactory.makeAllModules() {
//                await container.register(module)
//            }
//            
//            await container.build()
//        }
//        
//        print("✅ ScopeModuleFactory 기본 사용법 완료")
//    }
//    
//    // MARK: - 환경별 설정
//    
//    /// 환경별로 다른 스코프 설정을 적용하는 예시입니다.
//    public static func environmentSpecificSetup() async {
//        var debugFactory = ScopeModuleFactory()
//        var releaseFactory = ScopeModuleFactory()
//        
//        // Debug 환경 설정
//        debugFactory.registerDefaultDefinitions()
//        
//        // Release 환경 설정  
//        releaseFactory.registerDefaultDefinitions()
//        
//        #if DEBUG
//        let factory = debugFactory
//        print("🐛 Debug 환경으로 설정됨")
//        #else
//        let factory = releaseFactory
//        print("🚀 Release 환경으로 설정됨")
//        #endif
//        
//        // 선택된 환경에 맞는 팩토리로 등록
//        await DependencyContainer.bootstrapAsync { _ in
//            let container = Container()
//            for module in factory.makeAllModules() {
//                await container.register(module)
//            }
//            await container.build()
//        }
//        
//        print("✅ 환경별 설정 완료")
//    }
//    
//    // MARK: - 피처별 그룹핑
//    
//    /// 피처별로 스코프를 그룹핑하여 관리하는 예시입니다.
//    public static func featureBasedGrouping() async {
//        var scopeFactory = ScopeModuleFactory()
//        
//        // Auth 피처 스코프들
//        scopeFactory.registerAuthScopes()
//        
//        // User Management 피처 스코프들  
//        scopeFactory.registerUserScopes()
//        
//        // 등록 완료
//        await DependencyContainer.bootstrapAsync { _ in
//            let container = Container()
//            for module in scopeFactory.makeAllModules() {
//                await container.register(module)
//            }
//            await container.build()
//        }
//        print("✅ 피처별 그룹핑 완료")
//    }
//    
//    // MARK: - AppDIContainer와 통합
//    
//    /// AppDIContainer와 ScopeModuleFactory를 통합하여 사용하는 예시입니다.
//    /// RepositoryModuleFactory와 정확히 동일한 패턴으로 AppDIContainer에 통합됩니다.
//    public static func appDIContainerIntegration() async {
//        // RepositoryModuleFactory와 동일한 방식으로 ScopeModuleFactory 사용
//        await AppDIContainer.shared.registerWithScopeFactory()
//        
//        // 등록된 의존성 테스트
//        let networkService = DependencyContainer.live.resolve(NetworkServiceProtocol.self)
//        let cacheService = DependencyContainer.live.resolve(CacheServiceProtocol.self)
//        let logger = DependencyContainer.live.resolve(LoggerProtocol.self)
//        
//        print("✅ AppDIContainer 통합 (RepositoryModuleFactory 패턴):")
//        print("   - NetworkService: \(networkService != nil ? "✅" : "❌")")
//        print("   - CacheService: \(cacheService != nil ? "✅" : "❌")")
//        print("   - Logger: \(logger != nil ? "✅" : "❌")")
//    }
//    
//    // MARK: - 커스텀 팩토리 확장
//    
//    /// ScopeModuleFactory를 상속하여 커스텀 팩토리를 만드는 예시입니다.
//    public static func customFactoryExtension() async {
//        let customFactory = CustomScopeModuleFactory()
//        
//        await DependencyContainer.bootstrapAsync { _ in
//            let container = Container()
//            for module in customFactory.makeAllModules() {
//                await container.register(module)
//            }
//            await container.build()
//        }
//        
//        print("✅ 커스텀 팩토리 확장 완료")
//    }
//    
//    // MARK: - 런타임 동적 등록
//    
//    /// 런타임에 동적으로 스코프를 추가하는 예시입니다.
//    public static func dynamicScopeRegistration() async {
//        var scopeFactory = ScopeModuleFactory()
//        
//        // 기본 스코프들 등록
//        scopeFactory.registerDefaultDefinitions()
//        
//        // 조건에 따라 동적으로 스코프 추가
//        let shouldEnableAnalytics = ProcessInfo.processInfo.environment["ENABLE_ANALYTICS"] == "true"
//        
//        if shouldEnableAnalytics {
//            scopeFactory.addScopeDefinition(
//                scopeFactory.registerModule.makeScopedDependency(
//                    scope: AnalyticsScope.self,
//                    factory: { AnalyticsService() }
//                )
//            )
//            print("📊 Analytics 스코프 동적 추가됨")
//        }
//        
//        // A/B 테스트 기능 체크
//        let isABTestEnabled = UserDefaults.standard.bool(forKey: "ab_test_enabled")
//        
//        if isABTestEnabled {
//            scopeFactory.addScopeDefinition(
//                scopeFactory.registerModule.makeScopedDependency(
//                    scope: ABTestScope.self,
//                    factory: { ABTestService() }
//                )
//            )
//            print("🧪 A/B Test 스코프 동적 추가됨")
//        }
//        
//        await DependencyContainer.bootstrapAsync { _ in
//            let container = Container()
//            await scopeFactory.makeAllModules().asyncForEach { module in
//                await container.register(module())
//            }
//            await container.build()
//        }
//        
//        print("✅ 동적 스코프 등록 완료 (총 \(scopeFactory.count)개 스코프)")
//    }
//}
//
//// MARK: - 커스텀 팩토리 예시
//
///// ScopeModuleFactory를 확장한 커스텀 팩토리 예시
//public struct CustomScopeModuleFactory {
//    private var scopeFactory: ScopeModuleFactory
//    
//    public init() {
//        self.scopeFactory = ScopeModuleFactory()
//        setupCustomScopes()
//    }
//    
//    private mutating func setupCustomScopes() {
//        // 기본 스코프들
//        scopeFactory.registerDefaultDefinitions()
//        
//        // 커스텀 비즈니스 로직 스코프들
//        scopeFactory.registerScopes {
//            scopeFactory.registerModule.scopeFactory(PaymentScope.self) {
//                PaymentService()
//            }
//            scopeFactory.registerModule.scopeFactory(NotificationScope.self) {
//                NotificationService()
//            }
//            scopeFactory.registerModule.scopeFactory(LocationScope.self) {
//                LocationService()
//            }
//        }
//    }
//    
//    public func makeAllModules() -> [Module] {
//        return scopeFactory.makeAllModules()
//    }
//    
//    public func debugPrint() {
//        print("🏗️ CustomScopeModuleFactory:")
//        scopeFactory.debugPrint()
//    }
//}
//
//// MARK: - 추가 예시용 스코프들
//
///// 분석 서비스 스코프
//public struct AnalyticsScope: DependencyScope {
//    public typealias Dependencies = EmptyDependencies
//    public typealias Provides = AnalyticsServiceProtocol
//    
//    public static func validate() -> Bool { true }
//}
//
///// A/B 테스트 스코프
//public struct ABTestScope: DependencyScope {
//    public typealias Dependencies = EmptyDependencies
//    public typealias Provides = ABTestServiceProtocol
//    
//    public static func validate() -> Bool { true }
//}
//
///// 결제 서비스 스코프
//public struct PaymentScope: DependencyScope {
//    public typealias Dependencies = NetworkServiceProtocol
//    public typealias Provides = PaymentServiceProtocol
//    
//    public static func validate() -> Bool {
//        DependencyValidation.isRegistered(NetworkServiceProtocol.self)
//    }
//}
//
///// 알림 서비스 스코프
//public struct NotificationScope: DependencyScope {
//    public typealias Dependencies = EmptyDependencies
//    public typealias Provides = NotificationServiceProtocol
//    
//    public static func validate() -> Bool { true }
//}
//
///// 위치 서비스 스코프
//public struct LocationScope: DependencyScope {
//    public typealias Dependencies = EmptyDependencies
//    public typealias Provides = LocationServiceProtocol
//    
//    public static func validate() -> Bool { true }
//}
//
//// MARK: - 예시용 서비스 프로토콜들
//
//public protocol AnalyticsServiceProtocol {
//    func track(event: String, properties: [String: Any])
//}
//
//public protocol ABTestServiceProtocol {
//    func getVariant(for experiment: String) -> String
//}
//
//public protocol PaymentServiceProtocol {
//    func processPayment(amount: Double) async -> Bool
//}
//
//public protocol NotificationServiceProtocol {
//    func sendPushNotification(title: String, body: String)
//}
//
//public protocol LocationServiceProtocol {
//    func getCurrentLocation() async -> (latitude: Double, longitude: Double)?
//}
//
//// MARK: - 예시용 서비스 구현체들
//
//public struct AnalyticsService: AnalyticsServiceProtocol {
//    public init() {}
//    
//    public func track(event: String, properties: [String: Any]) {
//        print("📊 Analytics: \(event) with \(properties)")
//    }
//}
//
//public struct ABTestService: ABTestServiceProtocol {
//    public init() {}
//    
//    public func getVariant(for experiment: String) -> String {
//        print("🧪 A/B Test: Getting variant for \(experiment)")
//        return ["A", "B"].randomElement()!
//    }
//}
//
//public struct PaymentService: PaymentServiceProtocol {
//    public init() {}
//    
//    public func processPayment(amount: Double) async -> Bool {
//        print("💳 Payment: Processing $\(amount)")
//        return true
//    }
//}
//
//public struct NotificationService: NotificationServiceProtocol {
//    public init() {}
//    
//    public func sendPushNotification(title: String, body: String) {
//        print("🔔 Push: \(title) - \(body)")
//    }
//}
//
//public struct LocationService: LocationServiceProtocol {
//    public init() {}
//    
//    public func getCurrentLocation() async -> (latitude: Double, longitude: Double)? {
//        print("📍 Location: Getting current location")
//        return (37.7749, -122.4194) // San Francisco
//    }
//}
//
//// MARK: - 사용 가이드
//
///// ScopeModuleFactory 사용 가이드
//public enum ScopeModuleFactoryGuide {
//    
//    /// 기본 설정 방법 (RepositoryModuleFactory와 동일한 패턴)
//    public static let basicSetup = """
//    // 1. ScopeModuleFactory 생성 및 설정 (RepositoryModuleFactory와 동일)
//    var scopeFactory = ScopeModuleFactory()
//    scopeFactory.registerDefaultDefinitions()
//    scopeFactory.registerAuthScopes()
//    scopeFactory.registerUserScopes()
//    
//    // 2. AppDIContainer에 통합 (RepositoryModuleFactory와 동일한 방식)
//    await AppDIContainer.shared.registerWithScopeFactory()
//    
//    // 3. 의존성 사용
//    let networkService = DependencyContainer.live.resolve(NetworkServiceProtocol.self)
//    """
//    
//    /// Repository/UseCase Factory와 함께 사용하는 방법
//    public static let hybridUsage = """
//    extension RepositoryModuleFactory {
//        public mutating func registerWithScope() {
//            let scopeFactory = ScopeModuleFactory()
//            scopeFactory.registerDefaultDefinitions()
//            
//            // 기존 정의와 스코프 기반 정의 혼합
//            repositoryDefinitions = [
//                registerModule.makeDependency(LegacyRepositoryProtocol.self) {
//                    LegacyRepositoryImpl()
//                }
//            ] + scopeFactory.makeAllModules().map { module in
//                { module }
//            }
//        }
//    }
//    """
//    
//    /// 커스텀 팩토리 생성 방법
//    public static let customFactory = """
//    struct MyAppScopeFactory {
//        private var scopeFactory = ScopeModuleFactory()
//        
//        init() {
//            setupScopes()
//        }
//        
//        private mutating func setupScopes() {
//            scopeFactory.registerFeatureScopes("Payment") {
//                scopeFactory.registerModule.scopeFactory(PaymentScope.self) {
//                    PaymentService()
//                }
//            }
//        }
//        
//        func makeAllModules() -> [Module] {
//            return scopeFactory.makeAllModules()
//        }
//    }
//    """
//}
