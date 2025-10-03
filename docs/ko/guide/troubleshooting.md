# WeaveDI 문제 해결

WeaveDI를 사용할 때 발생하는 일반적인 문제와 해결 방법입니다.

## 목차

1. [의존성 해결 문제](#의존성-해결-문제)
2. [순환 의존성](#순환-의존성)
3. [메모리 누수](#메모리-누수)
4. [성능 문제](#성능-문제)
5. [Actor 격리 에러](#actor-격리-에러)
6. [테스트 문제](#테스트-문제)
7. [빌드 및 컴파일 에러](#빌드-및-컴파일-에러)
8. [디버깅 팁](#디버깅-팁)

## 의존성 해결 문제

### 증상 1: 주입된 의존성이 nil

```swift
class ViewModel {
    @Injected var userService: UserService?

    func loadUser() {
        guard let service = userService else {
            print("❌ UserService is nil")  // 이 메시지가 출력됨
            return
        }
        // ...
    }
}
```

**원인:**
- 의존성이 등록되지 않음
- 잘못된 타입으로 등록됨
- 의존성 접근 전에 컨테이너가 초기화되지 않음

**해결:**

```swift
// 해결 1: 의존성이 등록되었는지 확인
await WeaveDI.Container.bootstrap { container in
    container.register(UserService.self) {
        UserServiceImpl()
    }
}

// 해결 2: @Injected를 InjectedKey와 함께 사용 (v3.2.0+)
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    static var testValue: UserService = MockUserService()
}

extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

// 사용 - 항상 값을 가짐 (liveValue가 폴백)
class ViewModel {
    @Injected(\.userService) var userService  // nil이 아님
}

// 해결 3: 등록 확인
let isRegistered = await WeaveDI.Container.isRegistered(UserService.self)
if !isRegistered {
    print("⚠️ UserService가 등록되지 않음!")
}
```

### 증상 2: 잘못된 타입이 해결됨

```swift
protocol Animal {
    func makeSound()
}

class Dog: Animal {
    func makeSound() { print("Woof!") }
}

class Cat: Animal {
    func makeSound() { print("Meow!") }
}

// 등록
container.register(Animal.self) { Dog() }

// 사용
@Injected var animal: Animal?
animal?.makeSound()  // "Woof!" 출력 - Cat을 기대했는데?
```

**원인:**
- 같은 프로토콜에 대해 여러 등록
- 마지막 등록이 이전 등록을 덮어씀

**해결:**

```swift
// 해결 1: 구체적인 타입 사용
container.register(Dog.self) { Dog() }
container.register(Cat.self) { Cat() }

@Injected var dog: Dog?
@Injected var cat: Cat?

// 해결 2: 명명된 의존성 사용 (키 기반)
struct DogKey: InjectedKey {
    static var liveValue: Animal = Dog()
}

struct CatKey: InjectedKey {
    static var liveValue: Animal = Cat()
}

extension InjectedValues {
    var dog: Animal {
        get { self[DogKey.self] }
        set { self[DogKey.self] = newValue }
    }

    var cat: Animal {
        get { self[CatKey.self] }
        set { self[CatKey.self] = newValue }
    }
}

// 사용
@Injected(\.dog) var dog
@Injected(\.cat) var cat

dog.makeSound()  // "Woof!"
cat.makeSound()  // "Meow!"

// 해결 3: Wrapper 타입 사용
struct DogService {
    let animal: Animal = Dog()
}

struct CatService {
    let animal: Animal = Cat()
}

container.register(DogService.self) { DogService() }
container.register(CatService.self) { CatService() }
```

### 증상 3: 의존성이 너무 늦게 해결됨

```swift
class AppViewModel {
    @Injected var service: UserService?

    init() {
        // init 중에 service는 nil!
        print("Service: \(service)")  // nil
    }

    func start() {
        // 여기서는 작동함
        print("Service: \(service)")  // UserService 인스턴스
    }
}
```

**원인:**
- Property wrapper는 init 후에 평가됨
- init 중에 주입된 속성에 접근하려고 시도

**해결:**

```swift
// 해결 1: init에서 주입된 속성에 접근하지 않음
class AppViewModel {
    @Injected var service: UserService?

    init() {
        // init 중에 service 사용 안함
    }

    func configure() {
        // 이후에 호출됨
        service?.setup()
    }
}

// 해결 2: @Injected 사용 (비선택적)
class AppViewModel {
    @Injected(\.userService) var service

    init() {
        // init 후에 service 사용
    }

    func start() {
        service.fetchUser()  // 작동함
    }
}

// 해결 3: 생성자 주입 사용
class AppViewModel {
    private let service: UserService

    init(service: UserService) {
        self.service = service
        // init 중에 service 사용 가능
        service.setup()
    }
}

// 팩토리에서 주입
container.register(AppViewModel.self) {
    let service = container.resolve(UserService.self)
    return AppViewModel(service: service)
}
```

## 순환 의존성

### 증상: 무한 루프 또는 스택 오버플로

```swift
// ServiceA가 ServiceB에 의존
class ServiceA {
    @Injected(\.serviceB) var serviceB

    func doWork() {
        serviceB.doWork()
    }
}

// ServiceB가 ServiceA에 의존
class ServiceB {
    @Injected(\.serviceA) var serviceA  // ⚠️ 순환!

    func doWork() {
        serviceA.doWork()  // 무한 루프!
    }
}
```

**원인:**
- ServiceA ↔ ServiceB 순환 의존성
- InjectedKey 정적 초기화 중 재귀

**해결:**

```swift
// 해결 1: 추상화 도입 (Event Bus 패턴)
protocol EventBus {
    func publish(_ event: Event)
    func subscribe<T: Event>(_ eventType: T.Type, handler: @escaping (T) -> Void)
}

class ServiceA {
    @Injected(\.eventBus) var eventBus

    func doWork() {
        // ServiceB를 직접 호출하는 대신 이벤트 발행
        eventBus.publish(WorkRequestEvent())
    }
}

class ServiceB {
    @Injected(\.eventBus) var eventBus

    init() {
        // 이벤트 구독
        eventBus.subscribe(WorkRequestEvent.self) { [weak self] event in
            self?.handleWorkRequest(event)
        }
    }
}

// 해결 2: 프로토콜로 순환 끊기
protocol ServiceBProtocol {
    func doWork()
}

class ServiceA {
    private weak var serviceB: ServiceBProtocol?  // weak 참조

    func setServiceB(_ service: ServiceBProtocol) {
        self.serviceB = service
    }

    func doWork() {
        serviceB?.doWork()
    }
}

class ServiceB: ServiceBProtocol {
    @Injected(\.serviceA) var serviceA

    func doWork() {
        // serviceA 사용
    }
}

// 등록
container.register(ServiceA.self) { ServiceA() }
container.register(ServiceBProtocol.self) {
    let serviceB = ServiceB()
    let serviceA = container.resolve(ServiceA.self)
    serviceA.setServiceB(serviceB)
    return serviceB
}

// 해결 3: 공유 의존성으로 리팩토링
class SharedDependency {
    func performSharedWork() {
        // 둘 다 필요한 작업
    }
}

class ServiceA {
    @Injected(\.shared) var shared

    func doWork() {
        shared.performSharedWork()
    }
}

class ServiceB {
    @Injected(\.shared) var shared

    func doWork() {
        shared.performSharedWork()
    }
}
```

### 진단: 순환 의존성 감지

```swift
// 의존성 그래프 확인
let graph = await WeaveDI.Container.getAutoGeneratedGraph()
print("의존성 그래프:\n\(graph)")

// 순환 의존성 확인
let circular = await WeaveDI.Container.getDetectedCircularDependencies()
if !circular.isEmpty {
    print("⚠️ 순환 의존성 감지:")
    circular.forEach { print("  - \($0)") }
}
```

## 메모리 누수

### 증상: 메모리 사용량이 계속 증가

```swift
class ViewManager {
    @Injected(\.service) var service

    var views: [UIView] = []

    func addView(_ view: UIView) {
        views.append(view)
        // 뷰가 해제되지 않음 - 메모리 누수!
    }
}
```

**원인:**
- 강한 참조 사이클
- 싱글톤이 뷰나 뷰 컨트롤러에 대한 강한 참조 보유
- 클로저 캡처가 self를 강하게 유지

**해결:**

```swift
// 해결 1: Weak 참조 사용
class ViewManager {
    @Injected(\.service) var service

    private var views: [WeakRef<UIView>] = []  // weak 참조 사용

    func addView(_ view: UIView) {
        views.append(WeakRef(view))
    }

    func cleanupDeallocatedViews() {
        views.removeAll { $0.value == nil }
    }
}

// WeakRef helper
class WeakRef<T: AnyObject> {
    weak var value: T?
    init(_ value: T) {
        self.value = value
    }
}

// 해결 2: 클로저에서 [weak self] 사용
class DataService {
    @Injected(\.api) var api

    func fetchData(completion: @escaping (Data) -> Void) {
        api.fetch { [weak self] data in
            guard let self = self else { return }
            self.process(data)
            completion(data)
        }
    }
}

// 해결 3: Deinit에서 정리
class CacheService {
    @Injected(\.cache) var cache
    private var data: [String: Any] = [:]

    deinit {
        // 정리
        data.removeAll()
        cache.clear()
    }
}

// 해결 4: Request 스코프 사용 (단기 객체)
container.register(TemporaryService.self, scope: .request) {
    TemporaryService()
}
```

### 진단: 메모리 누수 감지

```swift
// Instruments 사용: Leaks 템플릿

// 코드에서 감지:
class MemoryMonitor {
    static func trackMemory() {
        let usage = reportMemory()
        print("메모리 사용량: \(usage) MB")
    }

    private static func reportMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        return result == KERN_SUCCESS ? info.resident_size / (1024 * 1024) : 0
    }
}

// 주기적으로 호출
Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
    MemoryMonitor.trackMemory()
}
```

## 성능 문제

### 증상 1: 느린 의존성 해결

```swift
class HeavyService {
    @Injected(\.database) var database
    @Injected(\.networkClient) var networkClient
    @Injected(\.cache) var cache
    @Injected(\.logger) var logger
    @Injected(\.analytics) var analytics

    func performOperation() {
        // 너무 많은 의존성 해결 = 느린 시작
    }
}
```

**원인:**
- 너무 많은 의존성
- 무거운 초기화
- 동기 해결 병목

**해결:**

```swift
// 해결 1: 의존성 수 줄이기 (Facade 패턴)
struct ServiceFacade {
    @Injected(\.database) var database
    @Injected(\.networkClient) var networkClient
    @Injected(\.cache) var cache

    func performComplexOperation() {
        // 여러 서비스 조정
    }
}

class HeavyService {
    @Injected(\.serviceFacade) var facade  // 하나의 의존성

    func performOperation() {
        facade.performComplexOperation()
    }
}

// 해결 2: Lazy 초기화 사용
class HeavyService {
    @Injected(\.database) var database

    // 필요할 때만 초기화
    private lazy var expensiveResource: ExpensiveResource = {
        ExpensiveResource(database: database)
    }()

    func performOperation() {
        // 처음 접근할 때만 생성됨
        expensiveResource.process()
    }
}

// 해결 3: 런타임 최적화 활성화
UnifiedRegistry.shared.enableOptimization()

// 해결 4: 자주 사용하는 의존성 캐시
struct CachedDependencies {
    static var shared = CachedDependencies()

    @Injected(\.userService) var userService
    @Injected(\.apiClient) var apiClient

    private init() {}
}

// 사용
let service = CachedDependencies.shared.userService
```

### 증상 2: 높은 CPU 사용량

```swift
class RealtimeService {
    @Factory var generator: DataGenerator  // 매번 새 인스턴스

    func processStream() {
        for _ in 0..<1000 {
            let gen = generator  // 1000개 인스턴스 생성!
            gen.generate()
        }
    }
}
```

**원인:**
- 너무 많은 @Factory 인스턴스 생성
- 불필요한 해결
- 잘못된 스코프

**해결:**

```swift
// 해결 1: @Injected 사용 (싱글톤)
class RealtimeService {
    @Injected(\.generator) var generator  // 재사용

    func processStream() {
        for _ in 0..<1000 {
            generator.generate()  // 같은 인스턴스
        }
    }
}

// 해결 2: 인스턴스 재사용
class RealtimeService {
    @Factory var generatorFactory: () -> DataGenerator

    func processStream() {
        let generator = generatorFactory()  // 한 번만 생성

        for _ in 0..<1000 {
            generator.generate()
        }
    }
}

// 해결 3: 배치 작업
class RealtimeService {
    @Injected(\.batchProcessor) var processor

    func processStream() {
        let items = (0..<1000).map { Item(id: $0) }
        processor.processBatch(items)  // 하나의 작업
    }
}
```

### 진단: 성능 측정

```swift
// 성능 모니터링
class PerformanceMonitor {
    static func measureResolutionTime() {
        let start = CFAbsoluteTimeGetCurrent()

        // 의존성 해결
        _ = InjectedValues.current.userService

        let duration = CFAbsoluteTimeGetCurrent() - start
        print("해결 시간: \(duration * 1000)ms")
    }

    static func measureInjectionOverhead() {
        class TestClass {
            @Injected(\.userService) var service
        }

        let iterations = 1000
        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0..<iterations {
            let instance = TestClass()
            _ = instance.service
        }

        let duration = CFAbsoluteTimeGetCurrent() - start
        let avgTime = (duration / Double(iterations)) * 1000
        print("평균 주입 시간: \(avgTime)ms")
    }
}
```

## Actor 격리 에러

### 증상: "Expression is 'async' but is not marked with 'await'"

```swift
@MainActor
class ViewModel {
    @Injected(\.userService) var userService  // ❌ Actor 격리 에러

    func loadData() {
        // 컴파일 에러: Actor 격리 경계
    }
}
```

**원인:**
- InjectedValues가 MainActor 격리되지 않음
- Actor 경계를 넘는 접근
- Swift 6 strict concurrency

**해결:**

```swift
// 해결 1: 비Actor 격리된 서비스 사용
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
}

extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

@MainActor
class ViewModel {
    @Injected(\.userService) var userService  // 작동함

    func loadData() async {
        await userService.fetchUser()
    }
}

// 해결 2: nonisolated 사용
@MainActor
class ViewModel {
    nonisolated(unsafe) @Injected(\.userService) var userService

    func loadData() {
        // 동기 접근 가능
        userService.fetchUser()
    }
}

// 해결 3: DIContainerActor 사용
await WeaveDI.Container.bootstrapInTask { @DIContainerActor container in
    container.register(UserService.self) {
        UserServiceImpl()
    }
}

@DIContainerActor
class ViewModel {
    @Injected(\.userService) var userService  // 같은 actor

    func loadData() {
        userService.fetchUser()
    }
}
```

### 증상: Sendable 준수 경고

```swift
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    // ⚠️ 경고: UserService가 Sendable을 준수하지 않음
}
```

**해결:**

```swift
// 해결 1: Sendable 준수 추가
protocol UserService: Sendable {
    func fetchUser() async -> User
}

actor UserServiceImpl: UserService {
    func fetchUser() async -> User {
        // 구현
    }
}

// 해결 2: @unchecked Sendable 사용 (주의해서 사용)
class UserServiceImpl: UserService, @unchecked Sendable {
    private let queue = DispatchQueue(label: "user.service")

    func fetchUser() -> User {
        queue.sync {
            // 스레드 안전 구현
        }
    }
}

// 해결 3: Actor로 래핑
actor UserServiceActor {
    private let impl: UserServiceImpl

    init() {
        self.impl = UserServiceImpl()
    }

    func fetchUser() async -> User {
        await impl.fetchUser()
    }
}
```

## 테스트 문제

### 증상: 테스트에서 이전 의존성 사용

```swift
func testUserLogin() async {
    // 이전 테스트에서 모의 객체 설정
    InjectedValues.current.userService = MockUserService()

    let viewModel = LoginViewModel()
    await viewModel.login()

    // 다음 테스트가 여전히 이전 모의 객체를 가짐!
}

func testUserLogout() async {
    let viewModel = LogoutViewModel()
    await viewModel.logout()
    // ❌ 여전히 MockUserService 사용 중
}
```

**원인:**
- InjectedValues는 테스트 간에 정리되지 않음
- 전역 상태 오염
- 적절한 격리 없음

**해결:**

```swift
// 해결 1: withInjectedValues 사용 (권장)
func testUserLogin() async {
    await withInjectedValues { values in
        values.userService = MockUserService()
    } operation: {
        let viewModel = LoginViewModel()
        await viewModel.login()
        XCTAssertTrue(viewModel.isLoggedIn)
    }
    // 자동으로 되돌림!
}

func testUserLogout() async {
    await withInjectedValues { values in
        values.userService = MockUserService()
    } operation: {
        let viewModel = LogoutViewModel()
        await viewModel.logout()
        XCTAssertFalse(viewModel.isLoggedIn)
    }
    // 깨끗한 상태
}

// 해결 2: setUp/tearDown 사용
class ViewModelTests: XCTestCase {
    override func setUp() async throws {
        // 각 테스트 전에 정리
        await WeaveDI.Container.releaseAll()
    }

    override func tearDown() async throws {
        // 각 테스트 후 정리
        await WeaveDI.Container.releaseAll()
    }
}

// 해결 3: 테스트 헬퍼 만들기
extension XCTestCase {
    func withCleanDependencies(
        operation: () async throws -> Void
    ) async rethrows {
        await WeaveDI.Container.releaseAll()
        try await operation()
        await WeaveDI.Container.releaseAll()
    }
}

// 사용
func testExample() async throws {
    await withCleanDependencies {
        // 테스트 코드
    }
}
```

### 증상: 모의 객체가 호출되지 않음

```swift
class MockUserService: UserService {
    var fetchUserCalled = false

    func fetchUser() async -> User {
        fetchUserCalled = true
        return User(id: "test")
    }
}

func testFetchUser() async {
    let mock = MockUserService()

    await withInjectedValues { values in
        values.userService = mock
    } operation: {
        let service = InjectedValues.current.userService
        await service.fetchUser()
    }

    XCTAssertTrue(mock.fetchUserCalled)  // ❌ 실패 - false
}
```

**원인:**
- 다른 인스턴스 해결됨
- InjectedKey liveValue가 오버라이드를 무시함
- 잘못된 KeyPath 사용

**해결:**

```swift
// 해결 1: withInjectedValues 내에서 테스트
func testFetchUser() async {
    let mock = MockUserService()

    await withInjectedValues { values in
        values.userService = mock
    } operation: {
        let viewModel = UserViewModel()
        await viewModel.loadUser()

        // operation 내에서 검증
        XCTAssertTrue(mock.fetchUserCalled)  // ✅ 성공
    }
}

// 해결 2: 생성자 주입 사용
class UserViewModel {
    private let userService: UserService

    init(userService: UserService) {
        self.userService = userService
    }

    func loadUser() async {
        await userService.fetchUser()
    }
}

func testFetchUser() async {
    let mock = MockUserService()
    let viewModel = UserViewModel(userService: mock)

    await viewModel.loadUser()

    XCTAssertTrue(mock.fetchUserCalled)  // ✅ 성공
}

// 해결 3: testValue 사용
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    static var testValue: UserService = MockUserService()  // 기본 모의 객체
}

func testFetchUser() async {
    // testValue가 자동으로 사용됨
    let viewModel = UserViewModel()
    await viewModel.loadUser()
}
```

## 빌드 및 컴파일 에러

### 증상: "Cannot find 'WeaveDI' in scope"

```swift
import WeaveDI  // ❌ 에러: WeaveDI를 찾을 수 없음

@Injected(\.userService) var userService
```

**원인:**
- WeaveDI가 프로젝트에 추가되지 않음
- 잘못된 import 경로
- SPM 패키지 해결 문제

**해결:**

```swift
// 해결 1: WeaveDI 추가 확인
// File > Add Package Dependencies
// URL: https://github.com/Roy-wonji/WeaveDI.git
// Version: 3.2.0+

// 해결 2: Clean Build
// Product > Clean Build Folder (⇧⌘K)
// 그런 다음 재빌드

// 해결 3: Package.swift 확인
dependencies: [
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.2.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["WeaveDI"]
    )
]

// 해결 4: 패키지 캐시 재설정
// File > Packages > Reset Package Caches
```

### 증상: 타입 추론 실패

```swift
struct ServiceKey: InjectedKey {
    static var liveValue = ServiceImpl()  // ❌ 에러: 타입 추론 실패
}
```

**원인:**
- 컴파일러가 프로토콜 준수를 추론할 수 없음
- 모호한 타입
- 누락된 명시적 타입

**해결:**

```swift
// 해결 1: 명시적 타입 추가
struct ServiceKey: InjectedKey {
    static var liveValue: UserService = ServiceImpl()  // ✅ 명시적 타입
}

// 해결 2: where 절 사용
struct ServiceKey: InjectedKey where Value == UserService {
    static var liveValue: UserService {
        ServiceImpl()
    }
}

// 해결 3: typealias 사용
struct ServiceKey: InjectedKey {
    typealias Value = UserService
    static var liveValue: Value = ServiceImpl()
}
```

### 증상: "Ambiguous use of 'Injected'"

```swift
@Injected(\.service) var service  // ❌ 에러: 모호한 사용
```

**원인:**
- 여러 InjectedValues 확장이 같은 이름을 정의함
- 서로 다른 모듈의 이름 충돌
- import 충돌

**해결:**

```swift
// 해결 1: 고유한 이름 사용
extension InjectedValues {
    var userService: UserService { /* ... */ }  // "userService" 고유
    var authService: AuthService { /* ... */ }  // "authService" 고유
}

// 해결 2: 모듈 한정자 사용
@Injected(MyModule.InjectedValues.userService) var service

// 해결 3: 이름공간 사용
enum UserFeature {
    struct ServiceKey: InjectedKey {
        static var liveValue: UserService = UserServiceImpl()
    }
}

extension InjectedValues {
    var userFeatureService: UserService {
        get { self[UserFeature.ServiceKey.self] }
        set { self[UserFeature.ServiceKey.self] = newValue }
    }
}
```

## 디버깅 팁

### 로깅 활성화

```swift
// WeaveDI 로깅 활성화
UnifiedRegistry.shared.enableLogging()

// 커스텀 로거
class DILogger {
    static func logResolution<T>(_ type: T.Type) {
        print("✅ Resolved: \(type)")
    }

    static func logRegistration<T>(_ type: T.Type) {
        print("📝 Registered: \(type)")
    }

    static func logError(_ message: String) {
        print("❌ Error: \(message)")
    }
}

// 래퍼에서 사용
@propertyWrapper
struct LoggedInjected<T> {
    @Injected var wrappedValue: T

    init(_ keyPath: KeyPath<InjectedValues, T>) {
        self._wrappedValue = Injected(keyPath)
        DILogger.logResolution(T.self)
    }
}
```

### 의존성 그래프 검사

```swift
// 모든 등록된 의존성 출력
let graph = await WeaveDI.Container.getAutoGeneratedGraph()
print("의존성 그래프:")
print(graph)

// 특정 타입의 의존성 확인
let dependencies = await WeaveDI.Container.getDependencies(for: UserViewModel.self)
print("UserViewModel 의존성:")
dependencies.forEach { print("  - \($0)") }

// 해결 경로 추적
func traceDependencyResolution<T>(_ type: T.Type) {
    print("해결 중: \(type)")

    let start = CFAbsoluteTimeGetCurrent()
    let instance = InjectedValues.current[keyPath: \.userService as! KeyPath<InjectedValues, T>]
    let duration = CFAbsoluteTimeGetCurrent() - start

    print("해결됨: \(type) (\(duration * 1000)ms)")
}
```

### 성능 프로파일링

```swift
class DIPerformanceProfiler {
    static var resolutionTimes: [String: TimeInterval] = [:]

    static func profile<T>(_ type: T.Type, operation: () -> T) -> T {
        let typeName = String(describing: type)
        let start = CFAbsoluteTimeGetCurrent()

        let result = operation()

        let duration = CFAbsoluteTimeGetCurrent() - start
        resolutionTimes[typeName] = duration

        return result
    }

    static func printReport() {
        print("\n📊 DI 성능 리포트:")
        resolutionTimes.sorted { $0.value > $1.value }.forEach { type, time in
            print("  \(type): \(time * 1000)ms")
        }
    }
}

// 사용
let service = DIPerformanceProfiler.profile(UserService.self) {
    InjectedValues.current.userService
}

// 나중에
DIPerformanceProfiler.printReport()
```

### 브레이크포인트 및 lldb

```swift
// property wrapper init에 브레이크포인트 설정
@propertyWrapper
struct DebugInjected<T> {
    @Injected var wrappedValue: T

    init(_ keyPath: KeyPath<InjectedValues, T>) {
        print("🔍 Injecting: \(T.self)")  // 여기에 브레이크포인트
        self._wrappedValue = Injected(keyPath)
    }
}

// lldb 명령:
// br set -n "DebugInjected.init"
// po keyPath
// po T.self
// continue
```

### 메모리 검사

```swift
// 약한 참조로 의존성 추적
class DependencyTracker {
    private static var tracked: [String: WeakBox] = [:]

    class WeakBox {
        weak var value: AnyObject?
        init(_ value: AnyObject) {
            self.value = value
        }
    }

    static func track<T: AnyObject>(_ instance: T, name: String) {
        tracked[name] = WeakBox(instance)
    }

    static func checkForLeaks() {
        print("🔍 누수 확인:")
        tracked.forEach { name, box in
            if box.value != nil {
                print("  ⚠️ \(name) 여전히 메모리에 있음")
            } else {
                print("  ✅ \(name) 해제됨")
            }
        }
    }
}

// 사용
let service = UserServiceImpl()
DependencyTracker.track(service, name: "UserService")

// 나중에
DependencyTracker.checkForLeaks()
```

## 도움 받기

문제가 계속되면:

1. **문서 확인**: [WeaveDI 문서](https://roy-wonji.github.io/WeaveDI/)
2. **예제 검토**: [GitHub 예제](https://github.com/Roy-wonji/WeaveDI/tree/main/Examples)
3. **Issue 보고**: [GitHub Issues](https://github.com/Roy-wonji/WeaveDI/issues)
4. **토론 참여**: [GitHub Discussions](https://github.com/Roy-wonji/WeaveDI/discussions)

Issue 보고 시 다음을 포함하세요:
- WeaveDI 버전
- Swift 버전
- 최소 재현 가능한 예제
- 에러 메시지 및 스택 트레이스
- 예상 동작 vs 실제 동작

## 다음 단계

- [모범 사례](./bestPractices.md) - 권장 패턴
- [마이그레이션 가이드](./migrationInjectToInjected.md) - @Injected → @Injected
- [성능 최적화](./runtimeOptimization.md) - 성능 튜닝
- [테스트 가이드](../tutorial/testing.md) - 고급 테스트 전략
