//
//  ContainerResgister.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/27/25.
//

import Foundation
import LogMacro

// MARK: - 자동 구현체 등록 시스템

/// 글로벌 자동 등록 시스템
public class GlobalAutoRegister {
    
    /// 특정 타입에 대해 자동 구현체 찾기 시도
    public static func tryAutoRegister<T>(for type: T.Type) -> Bool {
        let typeName = String(describing: type)
        
        // Interface -> RepositoryImpl 패턴
        if typeName.hasSuffix("Interface") {
            let baseName = String(typeName.dropLast("Interface".count))
            let candidates = [
                "\(baseName)RepositoryImpl",
                "\(baseName)Impl",
                "\(baseName)Implementation"
            ]
            
            for candidate in candidates {
                if let implType = lookupType(candidate) {
                    // Any 타입으로 등록해서 나중에 캐스팅
                    AutoRegistrationRegistry.shared.register(type) {
                        implType.init() as! T
                    }
                    #logInfo("✅ [GlobalAutoRegister] Found \(candidate) for \(typeName)")
                    return true
                }
            }
        }
        
        // Protocol -> Impl 패턴  
        if typeName.hasSuffix("Protocol") {
            let baseName = String(typeName.dropLast("Protocol".count))
            let candidates = [
                "\(baseName)Impl",
                "\(baseName)Implementation"
            ]
            
            for candidate in candidates {
                if let implType = lookupType(candidate) {
                    AutoRegistrationRegistry.shared.register(type) {
                        implType.init() as! T
                    }
                    #logInfo("✅ [GlobalAutoRegister] Found \(candidate) for \(typeName)")
                    return true
                }
            }
        }
        
        #logError("❌ [GlobalAutoRegister] No implementation found for \(typeName)")
        return false
    }
    
    private static func lookupType(_ name: String) -> NSObject.Type? {
        // 여러 모듈명으로 시도
        let bundleId = Bundle.main.bundleIdentifier ?? "UnknownBundle"
        let candidates = [
            name,
            "\(bundleId).\(name)",
            "Main.\(name)",
            "_TtC\(name.count)\(name)", // Swift mangled name 패턴
        ]
        
        #logDebug("🔍 [Lookup] Searching for class: \(name)")
        #logDebug("🔍 [Lookup] Bundle identifier: \(bundleId)")
        
        for candidate in candidates {
            #logDebug("🔍 [Lookup] Trying: \(candidate)")
            if let type = NSClassFromString(candidate) as? NSObject.Type {
                #logDebug("✅ [Lookup] Found class: \(candidate)")
                return type
            }
        }
        
        #logDebug("❌ [Lookup] No class found for: \(name)")
        return nil
    }
}

// MARK: - ContainerRegister

/// ## 개요
/// 
/// `ContainerRegister`는 Swift의 프로퍼티 래퍼(Property Wrapper) 기능을 활용하여
/// 의존성 주입을 선언적이고 타입 안전하게 수행할 수 있도록 하는 핵심 컴포넌트입니다.
/// 
/// 이 프로퍼티 래퍼는 전역 `DependencyContainer.live`와 KeyPath를 사용하여
/// 컴파일 타임 타입 체크와 런타임 안전성을 모두 보장합니다.
///
/// ## 핵심 특징
///
/// ### 🎯 선언적 의존성 주입
/// - **간결한 구문**: `@ContainerRegister(\.service)` 한 줄로 의존성 주입 완료
/// - **타입 안전**: 컴파일 타임에 타입 불일치 검출
/// - **KeyPath 기반**: 문자열이 아닌 타입 안전한 키 사용
///
/// ### 🔒 안전한 폴백 메커니즘  
/// - **기본 팩토리**: 의존성 누락 시 자동으로 기본 구현체 등록
/// - **조기 오류 검출**: 설정 문제를 런타임 초기에 발견
/// - **명확한 오류 메시지**: 문제 해결을 위한 상세한 가이드 제공
///
/// ### ⚡ 성능 최적화
/// - **지연 초기화**: 실제 사용 시점에만 의존성 해결
/// - **스레드 안전**: 동시성 환경에서 안전한 접근
/// - **메모리 효율**: 불필요한 인스턴스 생성 방지
///
/// ## 기본 사용 패턴
///
/// ### 1단계: DependencyContainer 확장 정의
/// ```swift
/// extension DependencyContainer {
///     /// 사용자 서비스 의존성
///     var userService: UserServiceProtocol? {
///         resolve(UserServiceProtocol.self)
///     }
///     
///     /// 네트워크 서비스 의존성  
///     var networkService: NetworkServiceProtocol? {
///         resolve(NetworkServiceProtocol.self)
///     }
///     
///     /// 로거 의존성
///     var logger: LoggerProtocol? {
///         resolve(LoggerProtocol.self)
///     }
/// }
/// ```
///
/// ### 2단계: 의존성 등록 (부트스트랩 시)
/// ```swift
/// await DependencyContainer.bootstrap { container in
///     container.register(UserServiceProtocol.self) {
///         UserService()
///     }
///     
///     container.register(NetworkServiceProtocol.self) {
///         NetworkService(baseURL: URL(string: "https://api.example.com")!)
///     }
///     
///     container.register(LoggerProtocol.self) {
///         ConsoleLogger()
///     }
/// }
/// ```
///
/// ### 3단계: 프로퍼티 래퍼를 통한 의존성 주입
/// ```swift
/// class UserViewModel: ObservableObject {
///     @ContainerRegister(\.userService)
///     private var userService: UserServiceProtocol
///     
///     @ContainerRegister(\.networkService)  
///     private var networkService: NetworkServiceProtocol
///     
///     @ContainerRegister(\.logger)
///     private var logger: LoggerProtocol
///     
///     func loadUser(id: String) async {
///         logger.info("사용자 로딩 시작: \(id)")
///         
///         do {
///             let user = try await userService.getUser(id: id)
///             logger.info("사용자 로딩 성공: \(user.name)")
///             // UI 업데이트...
///         } catch {
///             logger.error("사용자 로딩 실패: \(error)")
///         }
///     }
/// }
/// ```
///
/// ## 고급 사용 패턴
///
/// ### 기본 팩토리를 활용한 안전한 주입
/// ```swift
/// class WeatherService {
///     // 프로덕션 환경에서는 실제 서비스, 개발/테스트에서는 Mock 사용
///     @ContainerRegister(\.locationService, defaultFactory: { 
///         MockLocationService() 
///     })
///     private var locationService: LocationServiceProtocol
///     
///     // 네트워크 실패 시 로컬 캐시 사용
///     @ContainerRegister(\.weatherDataSource, defaultFactory: { 
///         LocalWeatherDataSource() 
///     })
///     private var weatherDataSource: WeatherDataSourceProtocol
///     
///     func getCurrentWeather() async throws -> Weather {
///         let location = try await locationService.getCurrentLocation()
///         return try await weatherDataSource.getWeather(for: location)
///     }
/// }
/// ```
///
/// ### 테스트에서의 활용
/// ```swift
/// class UserViewModelTests: XCTestCase {
///     
///     override func setUp() async throws {
///         await super.setUp()
///         
///         // 테스트용 의존성 등록
///         await DependencyContainer.resetForTesting()
///         await DependencyContainer.bootstrap { container in
///             container.register(UserServiceProtocol.self) {
///                 MockUserService(shouldFail: false)
///             }
///             container.register(LoggerProtocol.self) {
///                 MockLogger()
///             }
///         }
///     }
///     
///     func testLoadUserSuccess() async throws {
///         let viewModel = UserViewModel()
///         
///         await viewModel.loadUser(id: "123")
///         
///         // 검증 로직...
///     }
///     
///     func testLoadUserFailure() async throws {
///         // 실패 시나리오를 위한 Mock 교체
///         await DependencyContainer.update { container in
///             container.register(UserServiceProtocol.self) {
///                 MockUserService(shouldFail: true)
///             }
///         }
///         
///         let viewModel = UserViewModel()
///         await viewModel.loadUser(id: "123")
///         
///         // 에러 처리 검증...
///     }
/// }
/// ```
///
/// ### 조건부 의존성 주입
/// ```swift
/// class AnalyticsManager {
///     @ContainerRegister(\.analyticsService, defaultFactory: {
///         #if DEBUG
///         return MockAnalyticsService()
///         #else
///         return FirebaseAnalyticsService()
///         #endif
///     })
///     private var analyticsService: AnalyticsServiceProtocol
///     
///     func trackEvent(_ event: String, parameters: [String: Any] = [:]) {
///         analyticsService.track(event, parameters: parameters)
///     }
/// }
/// ```
///
/// ## 동작 원리
///
/// ### 의존성 해결 순서
/// 1. **KeyPath 조회**: 지정된 KeyPath로 `DependencyContainer.live`에서 조회
/// 2. **등록된 의존성 확인**: 타입이 이미 등록되어 있는지 확인  
/// 3. **기본 팩토리 실행**: 미등록 상태이고 `defaultFactory`가 제공된 경우 실행
/// 4. **자동 등록**: 기본 팩토리로 생성된 인스턴스를 컨테이너에 등록
/// 5. **인스턴스 반환**: 해결된 의존성 인스턴스 반환
///
/// ### 오류 처리 메커니즘
/// ```swift
/// // 등록되지 않았고 기본 팩토리도 없는 경우
/// @ContainerRegister(\.missingService)
/// private var missingService: MissingServiceProtocol
/// // ↓ 접근 시 fatalError 발생
/// // "MissingServiceProtocol 타입의 등록된 의존성을 찾을 수 없으며, 기본 팩토리도 제공되지 않았습니다."
/// ```
///
/// ### 스레드 안전성 보장
/// - `DependencyContainer`의 동시성 안전 큐를 통한 스레드 안전 접근
/// - 여러 스레드에서 동시에 같은 의존성에 접근해도 안전
/// - 기본 팩토리 실행 중 다른 스레드의 접근을 적절히 직렬화
///
/// ## 베스트 프랙티스
///
/// ### ✅ 권장 사용법
/// ```swift
/// class GoodService {
///     // 프로토콜 타입으로 의존성 선언
///     @ContainerRegister(\.userRepository)
///     private var userRepository: UserRepositoryProtocol
///     
///     // 기본 구현체 제공으로 안전성 확보
///     @ContainerRegister(\.logger, defaultFactory: { ConsoleLogger() })
///     private var logger: LoggerProtocol
///     
///     // private 접근 제어로 캡슐화
///     private init() {}
/// }
/// ```
///
/// ### ❌ 피해야 할 패턴  
/// ```swift
/// class BadService {
///     // 구체 타입에 직접 의존 - 테스트 어려움
///     @ContainerRegister(\.userRepository)
///     private var userRepository: ConcreteUserRepository
///     
///     // public으로 노출 - 캡슐화 위반
///     @ContainerRegister(\.logger)
///     public var logger: LoggerProtocol
///     
///     // 기본 팩토리 없이 사용 - 런타임 크래시 위험
///     @ContainerRegister(\.optionalService)
///     private var optionalService: OptionalServiceProtocol
/// }
/// ```
///
/// ## 성능 고려사항
///
/// ### 메모리 사용량
/// - **프로퍼티 래퍼 오버헤드**: 거의 없음 (KeyPath와 옵셔널 클로저만 저장)
/// - **지연 해결**: 실제 사용 시점까지 인스턴스 생성 지연
/// - **인스턴스 재사용**: 등록된 의존성은 컨테이너에서 관리
///
/// ### 성능 최적화 팁
/// ```swift
/// class OptimizedService {
///     // 자주 사용되는 의존성은 생성자에서 해결
///     private let criticalService: CriticalServiceProtocol
///     
///     // 가끔 사용되는 의존성은 프로퍼티 래퍼로 지연 해결
///     @ContainerRegister(\.optionalService, defaultFactory: { DefaultOptionalService() })
///     private var optionalService: OptionalServiceProtocol
///     
///     init() {
///         self.criticalService = DependencyContainer.live.resolve(CriticalServiceProtocol.self)!
///     }
/// }
/// ```
///
/// ## 문제 해결 가이드
///
/// ### 일반적인 오류와 해결방법
///
/// #### 1. 키패스 타입 불일치
/// ```swift
/// // ❌ 오류: 타입 불일치
/// extension DependencyContainer {
///     var userService: UserServiceProtocol? {
///         resolve(AnotherServiceProtocol.self) // 잘못된 타입
///     }
/// }
/// 
/// // ✅ 해결: 일치하는 타입 사용
/// extension DependencyContainer {
///     var userService: UserServiceProtocol? {
///         resolve(UserServiceProtocol.self) // 올바른 타입
///     }
/// }
/// ```
///
/// #### 2. 순환 의존성 문제
/// ```swift
/// // ❌ 문제: 순환 참조
/// class ServiceA {
///     @ContainerRegister(\.serviceB)
///     private var serviceB: ServiceBProtocol
/// }
///
/// class ServiceB {
///     @ContainerRegister(\.serviceA) 
///     private var serviceA: ServiceAProtocol
/// }
///
/// // ✅ 해결: 인터페이스 분리
/// protocol ServiceADelegate: AnyObject {
///     func handleEvent()
/// }
///
/// class ServiceA: ServiceADelegate {
///     @ContainerRegister(\.serviceB)
///     private var serviceB: ServiceBProtocol
///     
///     func handleEvent() {
///         // 처리 로직
///     }
/// }
///
/// class ServiceB {
///     weak var delegate: ServiceADelegate?
/// }
/// ```
///
/// ## 관련 API
/// 
/// - ``DependencyContainer``: 의존성 컨테이너 본체
/// - ``RegisterModule``: 모듈 기반 의존성 등록
/// - ``Container``: 배치 등록용 컨테이너
///
/// ## 사용법
///
/// ### 기본 의존성 주입
///
/// 먼저 `DependencyContainer`를 확장하여 의존성에 대한 계산 프로퍼티를 제공합니다:
///
/// ```swift
/// extension DependencyContainer {
///     var networkService: NetworkServiceProtocol? {
///         resolve(NetworkServiceProtocol.self)
///     }
///
///     var authRepository: AuthRepositoryProtocol? {
///         resolve(AuthRepositoryProtocol.self)
///     }
/// }
/// ```
///
/// 앱 초기화 중에 의존성을 등록합니다:
///
/// ```swift
/// // 앱의 부트스트랩/설정 단계에서
/// DependencyContainer.live.register(NetworkServiceProtocol.self) {
///     DefaultNetworkService()
/// }
///
/// DependencyContainer.live.register(AuthRepositoryProtocol.self) {
///     DefaultAuthRepository()
/// }
/// ```
///
/// 마지막으로 타입에서 의존성을 주입합니다:
///
/// ```swift
/// final class APIClient {
///     @ContainerRegister(\.networkService)
///     private var networkService: NetworkServiceProtocol
///
///     @ContainerRegister(\.authRepository)
///     private var authRepository: AuthRepositoryProtocol
///
///     func performAuthenticatedRequest() async throws -> Data {
///         let token = try await authRepository.getAccessToken()
///         return try await networkService.request("/api/data", headers: ["Authorization": "Bearer \(token)"])
///     }
/// }
/// ```
///
/// ### 기본 팩토리를 이용한 자동 등록
///
/// 테스트나 개발 환경에서는 기본 구현체를 제공할 수 있습니다:
///
/// ```swift
/// final class TestableService {
///     @ContainerRegister(\.networkService, defaultFactory: { MockNetworkService() })
///     private var networkService: NetworkServiceProtocol
///
///     // 실제 구현체가 등록되지 않은 경우 MockNetworkService를 사용합니다
/// }
/// ```
///
/// ## 주제
///
/// ### 초기화자
/// - ``init(_:)``
/// - ``init(_:defaultFactory:)``
///
/// ### 프로퍼티
/// - ``wrappedValue``
///
@propertyWrapper
public struct ContainerRegister<T: Sendable> {

    // MARK: - 프로퍼티

    /// `DependencyContainer` 내부의 `T?` 프로퍼티를 가리키는 KeyPath입니다.
    private let keyPath: KeyPath<DependencyContainer, T?>

    /// 의존성이 등록되지 않은 경우 기본 인스턴스를 생성하는 옵셔널 팩토리 클로저입니다.
    private let defaultFactory: (() -> T)?

    // MARK: - 초기화자

    /// KeyPath를 사용하여 의존성 주입 프로퍼티 래퍼를 생성합니다.
    ///
    /// 엄격한 의존성 등록 강제를 원할 때 이 초기화자를 사용하세요.
    /// 의존성에 접근할 때 등록되지 않은 경우, 애플리케이션이 fatal error와 함께
    /// 종료됩니다.
    ///
    /// - Parameter keyPath: 주입할 의존성을 나타내는 `DependencyContainer`의
    ///   `T?` 프로퍼티를 가리키는 KeyPath입니다.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// final class UserService {
    ///     @ContainerRegister(\.authRepository)
    ///     private var authRepository: AuthRepositoryProtocol
    ///
    ///     func getCurrentUser() async throws -> User {
    ///         return try await authRepository.getCurrentUser()
    ///     }
    /// }
    /// ```
    public init(_ keyPath: KeyPath<DependencyContainer, T?>) {
        self.keyPath = keyPath
        // 자동으로 AutoRegistrationRegistry에서 팩토리 찾기
        self.defaultFactory = Self.createAutoFactory()
    }
    
    /// KeyPath를 사용하여 자동 등록 기능이 있는 의존성 주입 프로퍼티 래퍼를 생성합니다.
    ///
    /// 이 초기화자는 Needle 스타일의 자동 등록을 제공합니다.
    /// 의존성이 등록되지 않은 경우, 타입 정보를 기반으로 자동으로 기본 구현체를 등록하려고 시도합니다.
    ///
    /// - Parameter keyPath: 주입할 의존성을 나타내는 `DependencyContainer`의
    ///   `T?` 프로퍼티를 가리키는 KeyPath입니다.
    /// - Parameter autoRegister: 자동 등록 활성화 여부 (기본값: true)
    ///
    /// ## 예시
    ///
    /// ```swift
    /// final class UserService {
    ///     @ContainerRegister(\.bookListInterface, autoRegister: true)
    ///     private var repository: BookListInterface
    ///
    ///     func getBooks() async throws -> [Book] {
    ///         return try await repository.fetchBooks()
    ///     }
    /// }
    /// ```
    public init(_ keyPath: KeyPath<DependencyContainer, T?>, autoRegister: Bool = true) {
        self.keyPath = keyPath
        
        if autoRegister {
            // 자동 등록 로직: 타입 정보를 기반으로 기본 팩토리 생성 시도
            self.defaultFactory = Self.createAutoFactory()
        } else {
            self.defaultFactory = nil
        }
    }
    
    /// 타입 정보를 기반으로 자동 팩토리를 생성하는 정적 메서드
    /// 
    /// 이 메서드는 AutoRegistrationRegistry를 사용하거나 타입 이름 기반으로 자동 구현체를 생성합니다.
    private static func createAutoFactory() -> (() -> T)? {
        return {
            // 1. AutoRegistrationRegistry에서 등록된 팩토리 찾기
            if let instance = AutoRegistrationRegistry.shared.createInstance(for: T.self) {
                return instance
            }
            
            // 2. 타입 이름 기반 자동 구현체 생성 시도
            if let autoInstance = Self.createAutoImplementation() {
                // 성공하면 AutoRegistrationRegistry에도 등록해두기 (한번만)
                let typeName = String(describing: T.self)
                #logInfo("🔧 [AUTO] Auto-registering \(typeName) for future use")
                AutoRegistrationRegistry.shared.register(T.self) { autoInstance }
                return autoInstance
            }
            
            // 3. 모든 시도 실패 시 도움말 메시지
            let typeName = String(describing: T.self)
            let suggestedImplementationName = Self.getSuggestedImplementationName(for: typeName)
            
            fatalError("""
                ❌ [DI] No registered dependency found for \(typeName)
                
                💡 해결 방법:
                1. 앱 시작 시 등록: AutoRegister().add(\(typeName).self) { \(suggestedImplementationName)() }
                2. 기본 팩토리 사용: @ContainerRegister(\\.dependency, defaultFactory: { YourImpl() })
                
                💡 예시:
                // AppDelegate나 App.swift에서
                AutoRegister().add(\(typeName).self) { 
                    \(suggestedImplementationName)() 
                }
                
                현재 등록된 타입 수: \(AutoRegistrationRegistry.shared.registeredCount)
                """)
        }
    }
    
    /// 타입 이름을 기반으로 자동 구현체 생성 시도
  /// 타입 이름을 기반으로 자동 구현체 생성 시도
  private static func createAutoImplementation() -> T? {
      let typeName = String(describing: T.self)
      #logDebug("🔍 [AUTO] Looking up auto implementation for: \(typeName)")

      // 1. AutoRegistrationRegistry에 등록된 팩토리로 시도
      if let instance: T = AutoRegistrationRegistry.shared.createInstance(for: T.self) {
          #logDebug("✅ [AUTO] Resolved \(typeName) from AutoRegistrationRegistry")
          return instance
      }

      // 2. 자동 등록 제안 - 사용자에게 가이드 제공
      #logInfo("💡 [AUTO] \(typeName) not registered. You need to register it manually.")
      #logInfo("💡 [AUTO] Add this to your app startup: AutoRegister.add(\(typeName).self) { YourImplementation() }")
      
      return nil
  }

    /// 타입 이름을 기반으로 제안하는 구현체 이름을 생성합니다.
    private static func getSuggestedImplementationName(for typeName: String) -> String {
        if typeName.hasSuffix("Interface") {
            // BookListInterface → BookListRepositoryImpl
            let baseName = String(typeName.dropLast("Interface".count))
            return "\(baseName)RepositoryImpl"
        } else if typeName.hasSuffix("Protocol") {
            // UserServiceProtocol → UserServiceImpl
            let baseName = String(typeName.dropLast("Protocol".count))
            return "\(baseName)Impl"
        } else {
            // 기본 규칙: MyService → MyServiceImpl
            return "\(typeName)Impl"
        }
    }

    /// 자동 등록 폴백 기능을 가진 의존성 주입 프로퍼티 래퍼를 생성합니다.
    ///
    /// 이 초기화자는 컨테이너에서 의존성을 찾을 수 없을 때 자동으로 의존성을
    /// 등록할 수 있도록 하는 안전 메커니즘을 제공합니다. 테스트 시나리오나
    /// 모킹 구현체를 제공하려는 경우에 특히 유용합니다.
    ///
    /// - Parameters:
    ///   - keyPath: `DependencyContainer`의 `T?` 프로퍼티를 가리키는 KeyPath입니다.
    ///   - defaultFactory: 컨테이너에 의존성이 등록되지 않은 경우 `T`의 기본
    ///     인스턴스를 생성하는 클로저입니다.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// final class WeatherService {
    ///     @ContainerRegister(\.locationService, defaultFactory: { MockLocationService() })
    ///     private var locationService: LocationServiceProtocol
    ///
    ///     func getCurrentWeather() async throws -> Weather {
    ///         let location = try await locationService.getCurrentLocation()
    ///         return try await fetchWeather(for: location)
    ///     }
    /// }
    /// ```
    ///
    /// - Important: 기본 팩토리는 의존성이 이미 등록되지 않은 경우에만 호출됩니다.
    ///   한 번 등록된 후(수동 또는 자동 등록)에는 후속 접근에서 등록된 인스턴스를
    ///   사용합니다.
    public init(_ keyPath: KeyPath<DependencyContainer, T?>, defaultFactory: @escaping () -> T) {
        self.keyPath = keyPath
        self.defaultFactory = defaultFactory
    }

    // MARK: - 래핑된 값

    /// 주입된 의존성 인스턴스입니다.
    ///
    /// 이 프로퍼티는 지정된 KeyPath를 사용하여 전역 `DependencyContainer.live`에서
    /// 의존성을 해결합니다. 해결 순서는 다음과 같습니다:
    ///
    /// 1. 등록된 의존성이 있는 경우 반환
    /// 2. 등록되지 않았고 `defaultFactory`가 존재하는 경우, 기본 인스턴스를 생성하고 등록
    /// 3. `defaultFactory`가 제공되지 않은 경우, `fatalError`로 애플리케이션 종료
    ///
    /// - Returns: `T` 타입의 해결된 의존성 인스턴스를 반환합니다.
    ///
    /// - Important: 의존성이 등록되지 않았고 기본 팩토리가 제공되지 않은 상태에서
    ///   이 프로퍼티에 접근하면 애플리케이션이 즉시 종료됩니다. 애플리케이션
    ///   부트스트랩 중에 모든 필수 의존성이 등록되었는지 확인하세요.
    ///
    /// ## 스레드 안전성
    ///
    /// 이 프로퍼티는 하위 `DependencyContainer`의 동시성 큐 구현으로 인해
    /// 스레드 안전합니다. 여러 스레드에서 동일한 의존성에 동시에 안전하게
    /// 접근할 수 있습니다.
    public var wrappedValue: T {
        // 먼저 의존성이 이미 등록되어 있는지 확인
        if let value = DependencyContainer.live[keyPath: keyPath] {
            return value
        }

        // Bootstrap 타이밍 문제 해결: 잠시 기다려보면서 시도
        return resolveWithBootstrapWait()
    }
    
    /// Bootstrap 완료를 기다리면서 의존성 해결을 시도합니다 (병렬 안전)
    private func resolveWithBootstrapWait() -> T {
        let maxRetries = 10
        let baseDelay: UInt32 = 50_000 // 0.05초 (microseconds)
        
        for attempt in 1...maxRetries {
            // 1. 등록된 의존성 재확인
            if let value = DependencyContainer.live[keyPath: keyPath] {
                #logDebug("✅ [DI-Timing] \(T.self) resolved after \(attempt) attempts")
                return value
            }
            
            // 2. 자동 팩토리 시도 (병렬 안전)
            if let factory = defaultFactory {
                let instance = factory()
                DependencyContainer.live.register(T.self, instance: instance)
                
                // 등록 후 재확인
                if let registeredValue = DependencyContainer.live[keyPath: keyPath] {
                    #logInfo("🔧 [DI-Auto] \(T.self) auto-registered successfully")
                    return registeredValue
                }
            }
            
            // 3. 마지막 시도가 아니면 대기 (지수 백오프)
            if attempt < maxRetries {
                let delay = baseDelay * UInt32(attempt)
                #logDebug("⏳ [DI-Timing] Waiting for \(T.self) (\(attempt)/\(maxRetries)), delay: \(delay/1000)ms")
                usleep(delay)
            }
        }
        
        // 모든 시도 실패
        let typeName = String(describing: T.self)
        fatalError("""
            ❌ [DI-Timing] Failed to resolve \(typeName) after \(maxRetries) attempts
            
            💡 Bootstrap 타이밍 문제일 수 있습니다. 해결책:
            1. 앱 시작 시 등록: AutoRegister.add(\(typeName).self) { YourImpl() }
            2. 기본 팩토리: @ContainerRegister(\\.dep, defaultFactory: { YourImpl() })
            3. Bootstrap 완료 후 사용: await DependencyContainer.ensureBootstrapped()
            
            현재 등록된 타입 수: \(AutoRegistrationRegistry.shared.registeredCount)
            """)
    }
}
