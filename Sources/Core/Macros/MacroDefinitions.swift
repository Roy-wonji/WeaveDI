//
//  MacroDefinitions.swift
//  WeaveDI
//
//  Created by Wonji Suh on 2025.
//

import Foundation

// MARK: - @AutoSync Macro Definition

/// @AutoSync 매크로: TCA DependencyKey를 WeaveDI InjectedKey로 자동 변환하고 동기화합니다.
///
/// ## 사용법:
/// ```swift
/// @AutoSync
/// struct UserServiceKey: DependencyKey {
///     static let liveValue = UserServiceImpl()
/// }
/// ```
///
/// ## 생성되는 코드:
/// ```swift
/// struct UserServiceKey: DependencyKey, InjectedKey {
///     static let liveValue = UserServiceImpl()
///
///     // 자동 생성된 InjectedKey conformance
///     static var testValue: UserServiceImpl { liveValue }
///     static var previewValue: UserServiceImpl { liveValue }
///
///     // 자동 생성된 TCA ↔ WeaveDI 동기화
///     private static let _autoSyncTrigger: Void = {
///         TCASmartSync.autoDetectAndSync(UserServiceKey.self, value: liveValue)
///         return ()
///     }()
/// }
///
/// // 자동 생성된 InjectedValues extension
/// extension InjectedValues {
///     var userService: UserServiceImpl {
///         get { self[UserServiceKey.self] }
///         set { self[UserServiceKey.self] = newValue }
///     }
/// }
/// ```
///
/// ## 장점:
/// - ✅ **완전 자동**: DependencyKey → InjectedKey 변환이 자동으로 이루어집니다
/// - ✅ **양방향 호환**: `@Dependency`와 `@Injected` 모두에서 사용 가능합니다
/// - ✅ **타입 안전**: 컴파일 타임에 타입 검증이 이루어집니다
/// - ✅ **KeyPath 지원**: InjectedValues의 KeyPath 접근이 자동 생성됩니다
/// - ✅ **런타임 동기화**: TCASmartSync를 통한 자동 런타임 동기화
///
/// ## 주의사항:
/// - DependencyKey를 conform하는 struct에만 적용 가능합니다
/// - liveValue의 타입이 명확해야 합니다 (타입 어노테이션 또는 추론 가능한 초기화)
@attached(member, names: named(testValue), named(previewValue), named(_autoSyncTrigger))
@attached(extension, conformances: InjectedKey)
public macro AutoSync() = #externalMacro(module: "WeaveDIMacros", type: "AutoSyncMacro")

// MARK: - @ReverseAutoSync Macro Definition

/// @ReverseAutoSync 매크로: WeaveDI InjectedKey를 TCA DependencyKey로 자동 변환합니다.
///
/// ## 사용법:
/// ```swift
/// @ReverseAutoSync
/// struct NetworkServiceKey: InjectedKey {
///     static let liveValue = NetworkServiceImpl()
///     static let testValue = MockNetworkService()
///     static let previewValue = PreviewNetworkService()
/// }
/// ```
///
/// ## 생성되는 코드:
/// ```swift
/// struct NetworkServiceKey: InjectedKey, DependencyKey {
///     typealias Value = NetworkServiceImpl
///     static let liveValue = NetworkServiceImpl()
///     static let testValue = MockNetworkService()
///     static let previewValue = PreviewNetworkService()
///
///     // 자동 생성된 TCA 동기화
///     private static let _tcaSyncTrigger: Void = {
///         TCASmartSync.autoDetectWeaveDIRegistration(Value.self, value: liveValue)
///         return ()
///     }()
/// }
/// ```
///
/// ## 장점:
/// - ✅ **역방향 변환**: InjectedKey → DependencyKey 자동 변환
/// - ✅ **기존 코드 보존**: 기존 InjectedKey 코드를 수정하지 않고 TCA 호환성 추가
/// - ✅ **자동 동기화**: WeaveDI 등록을 TCA에 자동 전파
@attached(member, names: named(Value), named(_tcaSyncTrigger))
public macro ReverseAutoSync() = #externalMacro(module: "WeaveDIMacros", type: "ReverseAutoSyncMacro")

// MARK: - @Component Macro Definition

/// @Component 매크로: 의존성 컴포넌트를 자동 생성합니다.
///
/// ## 사용법:
/// ```swift
/// @Component
/// struct AppComponent {
///     @Provide(.singleton) var userService: UserService { UserServiceImpl() }
///     @Provide(.transient) var networkService: NetworkService { NetworkServiceImpl() }
/// }
/// ```
///
/// ## 생성되는 코드:
/// ```swift
/// struct AppComponent: ComponentProtocol {
///     @Provide(.singleton) var userService: UserService { UserServiceImpl() }
///     @Provide(.transient) var networkService: NetworkService { NetworkServiceImpl() }
///
///     // 자동 생성된 ComponentProtocol conformance
///     static func registerAll(into container: DIContainer) {
///         let component = AppComponent()
///         container.register(UserService.self, scope: .singleton) { component.userService }
///         container.register(NetworkService.self, scope: .transient) { component.networkService }
///     }
/// }
/// ```
///
/// ## 장점:
/// - ✅ **자동 등록**: @Provide로 표시된 의존성들이 자동으로 컨테이너에 등록됩니다
/// - ✅ **스코프 지원**: .singleton, .transient 스코프를 지원합니다
/// - ✅ **타입 안전**: 컴파일 타임에 의존성 타입 검증이 이루어집니다
/// - ✅ **@Injected 호환**: 등록된 의존성은 @Injected로 주입 가능합니다
@attached(member, names: arbitrary)
@attached(extension, conformances: ComponentProtocol)
public macro Component() = #externalMacro(module: "WeaveDIMacros", type: "ComponentMacro")

// MARK: - @Provide Macro Definition

/// @Provide 매크로: 컴포넌트 내에서 제공할 의존성을 표시합니다.
///
/// ## 사용법:
/// ```swift
/// @Component
/// struct AppComponent {
///     @Provide(.singleton)
///     var userService: UserService { UserServiceImpl() }
///
///     @Provide(.transient)
///     var networkService: NetworkService { NetworkServiceImpl() }
/// }
/// ```
///
/// ## 스코프 옵션:
/// - `.singleton`: 앱 전체에서 하나의 인스턴스만 생성
/// - `.transient`: 매번 새로운 인스턴스 생성
///
/// ## 장점:
/// - ✅ **명시적 스코프**: 의존성의 생명주기를 명확하게 정의
/// - ✅ **자동 등록**: @Component와 함께 사용하면 자동으로 컨테이너에 등록
/// - ✅ **타입 안전**: getter의 리턴 타입으로 의존성 타입 자동 추론
@attached(accessor)
public macro Provide(_ scope: ProvideScope = .transient) = #externalMacro(module: "WeaveDIMacros", type: "ProvideMacro")

// MARK: - Usage Examples

/*
 // MARK: - 실제 사용 예제

 // 1. TCA DependencyKey를 WeaveDI와 호환되게 만들기
 @AutoSync
 struct UserServiceKey: DependencyKey {
     static let liveValue = UserServiceImpl()
 }

 // 이제 다음 두 방식이 모두 동일한 인스턴스를 반환합니다:
 struct ExchangeFeature: Reducer {
     @Injected(\.userService) var userService1      // WeaveDI 방식
     @Dependency(\.userService) var userService2    // TCA 방식
     // userService1 === userService2 ✅
 }

 // 2. WeaveDI InjectedKey를 TCA와 호환되게 만들기
 @ReverseAutoSync
 struct NetworkServiceKey: InjectedKey {
     static let liveValue = NetworkServiceImpl()
     static let testValue = MockNetworkService()
     static let previewValue = PreviewNetworkService()
 }

 // 3. Component 시스템으로 의존성 그룹 관리
 @Component
 struct AppComponent {
     @Provide(.singleton)
     var userService: UserService { UserServiceImpl() }

     @Provide(.transient)
     var networkService: NetworkService {
         NetworkServiceImpl(userService: userService)
     }
 }

 // 컴포넌트 등록
 AppComponent.registerAll()

 // 4. 완전한 통합 예제
 @AutoSync
 struct DatabaseServiceKey: DependencyKey {
     static let liveValue = DatabaseServiceImpl()
 }

 @Component
 struct DatabaseComponent {
     @Provide(.singleton)
     var database: DatabaseService { DatabaseServiceImpl() }

     @Provide(.transient)
     var repository: UserRepository {
         UserRepositoryImpl(database: database)
     }
 }

 struct UserFeature: Reducer {
     // 모든 방식이 동일한 인스턴스를 반환
     @Injected(\.databaseService) var db1           // KeyPath 방식
     @Injected(DatabaseServiceKey.self) var db2     // Type 방식
     @Dependency(\.databaseService) var db3         // TCA 방식

     @Injected(UserRepository.self) var repo        // Component에서 제공
 }
 */