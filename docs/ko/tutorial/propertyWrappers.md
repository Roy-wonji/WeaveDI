# WeaveDI Property Wrapper 마스터하기

실제 소스 코드 분석을 기반으로 한 WeaveDI의 강력한 프로퍼티 래퍼 시스템 심화 학습. @Inject, @Factory, @SafeInject를 효과적으로 사용하는 방법을 배워보세요.

## 🎯 학습 목표

- **@Inject**: 기본 의존성 주입 패턴
- **@Factory**: 매번 새로운 인스턴스 생성
- **@SafeInject**: 오류 안전 의존성 주입
- **고급 패턴**: 커스텀 프로퍼티 래퍼
- **성능 최적화**: Hot path 캐싱
- **실제 사용법**: 실제 프로젝트의 실용적 예제

## 📚 소스 코드 이해하기

실제 WeaveDI 프로퍼티 래퍼 구현을 `PropertyWrappers.swift`에서 살펴보겠습니다:

### @Inject - 핵심 프로퍼티 래퍼

```swift
// 실제 WeaveDI 소스: PropertyWrappers.swift
@propertyWrapper
public struct Inject<T> {
    // 의존성 해결을 위한 내부 저장소
    private let keyPath: KeyPath<DependencyContainer, T?>?
    private let type: T.Type

    // 세 가지 다른 초기화 패턴

    /// 1. KeyPath 기반 초기화 (타입 안전)
    /// KeyPath를 사용하여 컴파일 타임 안전성 제공
    public init(_ keyPath: KeyPath<DependencyContainer, T?>) {
        self.keyPath = keyPath
        self.type = T.self
    }

    /// 2. 타입 추론 초기화 (가장 일반적)
    /// Swift가 사용 컨텍스트에서 자동으로 타입을 추론
    public init() {
        self.keyPath = nil
        self.type = T.self
    }

    /// 3. 명시적 타입 초기화 (복잡한 시나리오용)
    /// 타입을 명시적으로 지정해야 할 때 사용
    public init(_ type: T.Type) {
        self.keyPath = nil
        self.type = type
    }

    // 마법이 일어나는 곳 - 의존성 해결
    public var wrappedValue: T? {
        if let keyPath = keyPath {
            // KeyPath 해결 - 타입 안전하고 빠름
            return DependencyContainer.live[keyPath: keyPath]
        }
        // 표준 타입 해결
        return DependencyContainer.live.resolve(type)
    }
}
```

**🔍 이것이 의미하는 바:**
- **KeyPath 해결**: `@Inject(\.someService)`를 사용하면 컴파일 타임 안전 KeyPath 사용
- **타입 해결**: `@Inject var service: SomeService?`를 사용하면 타입으로 해결
- **옵셔널 반환**: 항상 옵셔널을 반환하여 크래시 방지

### @Factory - 항상 새로운 인스턴스

```swift
// 실제 WeaveDI 소스: PropertyWrappers.swift
@propertyWrapper
public struct Factory<T> {
    private let keyPath: KeyPath<DependencyContainer, T?>?
    private let directFactory: (() -> T)?

    /// KeyPath 기반 팩토리 (등록된 팩토리 함수)
    public init(_ keyPath: KeyPath<DependencyContainer, T?>) {
        self.keyPath = keyPath
        self.directFactory = nil
    }

    /// 직접 팩토리 함수 (인라인 생성)
    public init(factory: @escaping () -> T) {
        self.keyPath = nil
        self.directFactory = factory
    }

    /// 항상 새로운 인스턴스 반환
    public var wrappedValue: T {
        if let factory = directFactory {
            // 직접 팩토리 - 매번 호출
            return factory()
        }

        if let keyPath = keyPath {
            // KeyPath 팩토리 - 매번 해결하고 호출
            guard let factoryFunction = DependencyContainer.live[keyPath: keyPath] else {
                fatalError("Factory not registered for keyPath: \(keyPath)")
            }
            return factoryFunction
        }

        fatalError("Factory not properly configured")
    }
}
```

**🔍 이것이 의미하는 바:**
- **항상 새로움**: 매번 접근할 때마다 새로운 인스턴스 생성
- **두 가지 모드**: 등록된 팩토리 또는 직접 팩토리
- **옵셔널 아님**: 항상 값을 반환 (사용 불가능하면 크래시)

## 🛠️ 실용적 사용 패턴

### 1. 기본 @Inject 사용법

```swift
import WeaveDI

class UserViewController: UIViewController {
    // ✅ 가장 일반적인 패턴 - 옵셔널 주입
    @Inject var userService: UserService?
    @Inject var logger: LoggerProtocol?

    // ✅ guard 체크가 필요한 필수 서비스
    @Inject var authService: AuthService?

    override func viewDidLoad() {
        super.viewDidLoad()

        // 안전한 언래핑 패턴
        guard let auth = authService else {
            logger?.error("AuthService 사용 불가 - 진행할 수 없습니다")
            showError("인증 서비스를 사용할 수 없습니다")
            return
        }

        // 이제 안전하게 서비스 사용
        if auth.isUserLoggedIn {
            loadUserData()
        } else {
            showLoginScreen()
        }
    }

    private func loadUserData() {
        // 중요하지 않은 서비스에 대한 옵셔널 체이닝
        userService?.fetchCurrentUser { [weak self] result in
            switch result {
            case .success(let user):
                self?.displayUser(user)
            case .failure(let error):
                self?.logger?.error("사용자 로드 실패: \(error)")
            }
        }
    }
}
```

**🎯 핵심 포인트:**
- 대부분의 서비스에 옵셔널 주입 사용
- 중요한 서비스는 항상 nil에 대해 guard 사용
- 디버깅을 위한 로거 주입 사용
- 안전한 접근을 위한 옵셔널 체이닝

### 2. KeyPath 기반 타입 안전 주입

```swift
// 먼저 DependencyContainer를 KeyPath로 확장
extension DependencyContainer {
    var userRepository: UserRepository? {
        resolve(UserRepository.self)
    }

    var apiClient: APIClient? {
        resolve(APIClient.self)
    }

    var imageCache: ImageCache? {
        resolve(ImageCache.self)
    }
}

// 그다음 타입 안전 주입 사용
class DataManager {
    // ✅ 컴파일 타임 체크가 가능한 타입 안전
    @Inject(\.userRepository) var userRepo: UserRepository?
    @Inject(\.apiClient) var api: APIClient?
    @Inject(\.imageCache) var cache: ImageCache?

    func syncUserData() async {
        // 컴파일러가 이러한 타입이 올바른지 확인
        guard let repo = userRepo, let api = api else {
            print("❌ 필요한 서비스를 사용할 수 없습니다")
            return
        }

        do {
            let userData = try await api.fetchUserData()
            try await repo.save(userData)
            print("✅ 사용자 데이터 동기화 성공")
        } catch {
            print("❌ 동기화 실패: \(error)")
        }
    }
}
```

**🎯 장점:**
- **컴파일 타임 안전성**: 빌드 타임에 오타 발견
- **리팩토링 지원**: IDE가 안전하게 이름 변경 가능
- **자동 완성**: 더 나은 개발자 경험

### 3. 상태가 없는 객체를 위한 @Factory

```swift
class DocumentProcessor {
    // ✅ 각 문서마다 새로운 PDF 생성기
    @Factory var pdfGenerator: PDFGenerator

    // ✅ 각 보고서마다 새로운 보고서 빌더
    @Factory var reportBuilder: ReportBuilder

    // ✅ 간단한 객체를 위한 인라인 팩토리
    @Factory(factory: { DateFormatter() }) var dateFormatter: DateFormatter

    func processDocuments(_ documents: [Document]) async {
        await withTaskGroup(of: Void.self) { group in
            for document in documents {
                group.addTask { [self] in
                    // 각 작업은 새로운 PDF 생성기를 얻음
                    // 동시 작업 간에 공유 상태 없음
                    let generator = self.pdfGenerator

                    await generator.configure(for: document)
                    let pdf = await generator.generate()
                    await saveToDatabase(pdf)
                }
            }
        }
    }

    func generateReport(for data: AnalyticsData) -> Report {
        // 새로운 보고서 빌더가 깨끗한 상태를 보장
        let builder = reportBuilder

        return builder
            .setTitle("분석 보고서")
            .setData(data)
            .setTimestamp(dateFormatter.string(from: Date()))
            .build()
    }
}
```

**🎯 @Factory를 사용하는 경우:**
- **상태가 없는 작업**: PDF 생성, 데이터 파싱
- **동시 처리**: 각 작업에 격리된 인스턴스 필요
- **빌더 패턴**: 각 구성에 새로운 빌더
- **포매터**: 공유 상태 문제 방지

## 🧪 프로퍼티 래퍼를 사용한 테스팅

### Mock 등록 전략

```swift
class NetworkManagerTests: XCTestCase {
    var networkManager: NetworkManager!

    override func setUp() async throws {
        await super.setUp()

        // 각 테스트마다 DI 상태 정리
        await DependencyContainer.bootstrap { container in
            // 테스트 더블 등록
            container.register(HTTPClient.self) {
                MockHTTPClient()
            }

            container.register(AuthTokenProvider.self) {
                MockAuthTokenProvider()
            }

            container.register(RequestLogger.self) {
                MockRequestLogger()
            }
        }

        // 테스트 대상 시스템 생성
        networkManager = NetworkManager()
    }

    func testNetworkRequest_Success() async throws {
        // Given
        let mockClient = UnifiedDI.resolve(HTTPClient.self) as! MockHTTPClient
        mockClient.mockResponse = MockResponse.success

        // When
        let result = try await networkManager.fetchUserData(id: "123")

        // Then
        XCTAssertEqual(result.id, "123")
        XCTAssertTrue(mockClient.requestCalled)
    }
}

class NetworkManager {
    @Inject var httpClient: HTTPClient?
    @Inject var authProvider: AuthTokenProvider?
    @Inject var logger: RequestLogger?

    func fetchUserData(id: String) async throws -> UserData {
        guard let client = httpClient else {
            throw NetworkError.clientNotAvailable
        }

        logger?.logRequest("fetchUserData", id: id)

        let request = URLRequest(url: URL(string: "/users/\(id)")!)
        let data = try await client.perform(request)

        return try JSONDecoder().decode(UserData.self, from: data)
    }
}
```

## 📋 모범 사례 요약

### ✅ 해야 할 것

1. **대부분의 의존성에 @Inject 사용**
   ```swift
   @Inject var service: SomeService?
   ```

2. **타입 안전성을 위해 KeyPath 사용**
   ```swift
   @Inject(\.userRepository) var repo: UserRepository?
   ```

3. **상태가 없는 객체에 @Factory 사용**
   ```swift
   @Factory var generator: ReportGenerator
   ```

4. **중요한 서비스는 nil에 대해 guard 사용**
   ```swift
   guard let service = injectedService else {
       handleMissingDependency()
       return
   }
   ```

### ❌ 하지 말아야 할 것

1. **주입된 의존성을 강제 언래핑하지 마세요**
   ```swift
   // ❌ 위험
   @Inject var service: SomeService?
   let result = service!.doSomething()

   // ✅ 안전
   guard let service = service else { return }
   let result = service.doSomething()
   ```

2. **상태가 있는 객체에 @Factory 사용하지 마세요**
   ```swift
   // ❌ 매번 새로운 상태 생성
   @Factory var userSession: UserSession

   // ✅ 공유 상태
   @Inject var userSession: UserSession?
   ```

---

**축하합니다!** 이제 WeaveDI의 프로퍼티 래퍼 시스템의 모든 기능을 이해했습니다. 자신감을 가지고 유지보수 가능하고 테스트 가능하며 성능이 우수한 애플리케이션을 구축할 수 있습니다.