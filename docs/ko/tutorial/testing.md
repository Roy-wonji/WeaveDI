# WeaveDI를 사용한 테스팅 전략

WeaveDI로 구동되는 애플리케이션을 위한 포괄적인 테스팅 접근법을 마스터하세요. 실제 예제를 통해 유닛 테스팅, 통합 테스팅, 모킹 전략을 배웁니다.

## 🎯 학습 목표

- **유닛 테스팅**: DI를 사용한 개별 컴포넌트 테스팅
- **통합 테스팅**: 컴포넌트 간 상호작용 테스팅
- **모킹 전략**: 효과적인 테스트 더블 생성
- **테스트 환경 설정**: 테스트를 위한 DI 구성
- **성능 테스팅**: DI 성능 벤치마킹
- **모범 사례**: 프로덕션 준비 테스팅 패턴

## 🧪 테스트 환경 설정

### 기본 테스트 구성

```swift
import XCTest
import WeaveDI
@testable import YourApp

/// 각 테스트를 위해 깨끗한 DI 환경을 설정하는 기본 테스트 클래스
/// 테스트 격리를 보장하고 테스트 간 상호 의존성을 방지합니다
class WeaveDITestCase: XCTestCase {

    /// 각 테스트 메서드 전에 호출됨
    /// 테스트 격리를 보장하기 위해 새로운 DI 컨테이너를 설정합니다
    override func setUp() async throws {
        await super.setUp()

        // 기존 DI 상태를 정리하여 새로 시작
        await DependencyContainer.reset()

        // 테스트 전용 의존성 설정
        await setupTestDependencies()

        print("🧪 테스트 환경 초기화됨")
    }

    /// 각 테스트 메서드 후에 호출됨
    /// 테스트 오염을 방지하기 위해 DI 상태를 정리합니다
    override func tearDown() async throws {
        // 각 테스트 후 DI 컨테이너 정리
        await DependencyContainer.reset()

        await super.tearDown()
        print("🧹 테스트 환경 정리됨")
    }

    /// 서브클래스에서 이 메서드를 오버라이드하여 테스트별 의존성을 등록하세요
    /// 각 테스트 클래스가 자체 모킹 객체를 정의할 수 있습니다
    func setupTestDependencies() async {
        await DependencyContainer.bootstrap { container in
            // 기본 테스트 의존성
            container.register(LoggerProtocol.self) {
                MockLogger()
            }
        }
    }
}
```

**🔍 코드 설명:**
- **테스트 격리**: 각 테스트가 새로운 DI 컨테이너를 받아 간섭을 방지
- **setUp/tearDown**: 라이프사이클 메서드가 각 테스트의 깨끗한 상태를 보장
- **상속**: 기본 클래스가 공통 테스트 인프라를 제공
- **커스터마이징**: 서브클래스가 특정 요구사항에 맞게 setupTestDependencies를 오버라이드 가능

### 고급 테스트 부트스트랩

```swift
/// 다양한 테스팅 시나리오를 위한 고급 테스트 부트스트랩
class TestBootstrap {

    /// 유닛 테스팅을 위한 모킹 의존성 설정
    /// 모든 외부 의존성이 제어 가능한 모킹으로 교체됩니다
    static func setupUnitTestDependencies() async {
        await DependencyContainer.bootstrap { container in

            // MARK: - 네트워크 레이어 모킹

            /// 예측 가능한 응답을 반환하는 모킹 HTTP 클라이언트
            /// 실제 네트워크 호출 없이 네트워크 의존 코드를 테스트할 수 있습니다
            container.register(HTTPClientProtocol.self) {
                let mock = MockHTTPClient()
                // 일반적인 시나리오를 위한 기본 응답 구성
                mock.defaultResponse = MockHTTPResponse.success
                mock.defaultDelay = 0.0 // 빠른 테스트를 위해 지연 없음
                return mock
            }

            // MARK: - 데이터 레이어 모킹

            /// 메모리에 데이터를 저장하는 모킹 데이터베이스 서비스
            /// 테스트 시나리오를 위한 빠르고 격리된 저장소를 제공합니다
            container.register(DatabaseServiceProtocol.self) {
                let mock = MockDatabaseService()
                // 필요한 경우 테스트 데이터로 미리 채움
                mock.seedTestData = true
                return mock
            }

            /// 제어 가능한 동작을 가진 모킹 캐시 서비스
            /// 캐시 히트/미스 시나리오를 테스트할 수 있습니다
            container.register(CacheServiceProtocol.self) {
                let mock = MockCacheService()
                mock.shouldSimulateHits = true // 기본적으로 캐시 히트
                return mock
            }

            // MARK: - 비즈니스 로직 모킹

            /// 미리 정의된 상태를 가진 모킹 인증 서비스
            /// 다양한 인증 시나리오를 테스트할 수 있습니다
            container.register(AuthServiceProtocol.self) {
                let mock = MockAuthService()
                mock.isAuthenticated = true // 기본적으로 인증된 상태
                mock.currentUser = TestUser.sampleUser
                return mock
            }

            /// 이벤트를 캡처하는 모킹 분석 서비스
            /// 분석 이벤트가 올바르게 발생하는지 확인할 수 있습니다
            container.register(AnalyticsServiceProtocol.self) {
                let mock = MockAnalyticsService()
                mock.shouldCaptureEvents = true
                return mock
            }

            print("✅ 유닛 테스트 의존성 구성됨")
        }
    }

    /// 통합 테스트 의존성 설정
    /// 가능한 곳에서 실제 구현을 사용하고, 외부 서비스만 모킹합니다
    static func setupIntegrationTestDependencies() async {
        await DependencyContainer.bootstrap { container in

            // MARK: - 실제 내부 서비스

            /// 통합 테스팅을 위한 실제 캐시 서비스 사용
            /// 실제 캐싱 동작과 성능을 테스트합니다
            container.register(CacheServiceProtocol.self) {
                InMemoryCacheService() // 실제 구현
            }

            /// 실제 비즈니스 로직 서비스 사용
            /// 실제 비즈니스 규칙과 워크플로우를 테스트합니다
            container.register(UserServiceProtocol.self) {
                UserService() // 의존성이 주입된 실제 구현
            }

            // MARK: - 외부 서비스 모킹

            /// 네트워크 의존성을 피하기 위해 외부 API 모킹
            /// 하지만 현실적인 응답 데이터와 타이밍을 사용합니다
            container.register(HTTPClientProtocol.self) {
                let mock = MockHTTPClient()
                mock.useRealisticTiming = true // 네트워크 지연 시뮬레이션
                mock.useRealResponseFormats = true // 실제 API 응답 구조 사용
                return mock
            }

            /// 데이터 오염을 피하기 위해 외부 분석 모킹
            /// 하지만 검증을 위해 이벤트를 캡처합니다
            container.register(AnalyticsServiceProtocol.self) {
                let mock = MockAnalyticsService()
                mock.shouldLogEvents = true // 디버깅을 위한 이벤트 로깅
                return mock
            }

            print("✅ 통합 테스트 의존성 구성됨")
        }
    }

    /// E2E 테스트 의존성 설정
    /// 테스트 데이터베이스와 스테이징 API로 실제 서비스를 사용합니다
    static func setupE2ETestDependencies() async {
        await DependencyContainer.bootstrap { container in

            // MARK: - 테스트 구성을 가진 실제 서비스

            /// 스테이징 환경을 가리키는 실제 HTTP 클라이언트
            /// 제어된 환경에서 실제 백엔드 서비스에 대해 테스트합니다
            container.register(HTTPClientProtocol.self) {
                let client = URLSessionHTTPClient()
                client.baseURL = "https://staging-api.yourapp.com" // 스테이징 환경
                client.timeout = 30.0 // 스테이징을 위한 더 긴 타임아웃
                return client
            }

            /// 테스트 데이터베이스를 사용하는 실제 데이터베이스 서비스
            /// 프로덕션 데이터에 영향을 주지 않도록 별도 데이터베이스 사용
            container.register(DatabaseServiceProtocol.self) {
                let service = CoreDataService()
                service.usePersistentStore = false // 테스트를 위한 인메모리 저장소 사용
                return service
            }

            /// 테스트 계정을 사용하는 실제 인증 서비스
            /// 실제 인증 플로우를 사용하지만 전용 테스트 계정으로
            container.register(AuthServiceProtocol.self) {
                let service = FirebaseAuthService()
                service.useTestConfiguration = true // 테스트 Firebase 프로젝트 사용
                return service
            }

            print("✅ E2E 테스트 의존성 구성됨")
        }
    }
}
```

**🔍 코드 설명:**
- **계층화된 테스팅**: 유닛, 통합, E2E 테스트를 위한 다양한 의존성 설정
- **현실적인 모킹**: 통합 테스트는 실제 동작을 시뮬레이션하는 모킹 사용
- **외부 서비스 격리**: 통합 테스트에서는 외부 의존성만 모킹
- **구성 유연성**: 각 테스트 타입이 적절한 의존성 구성을 가짐

## 🎭 모킹 객체 전략

### 포괄적인 모킹 구현

```swift
/// 동작 시뮬레이션을 가진 정교한 모킹 HTTP 클라이언트
class MockHTTPClient: HTTPClientProtocol {

    // MARK: - 구성 프로퍼티

    /// 네트워크 지연을 시뮬레이션할지 제어
    var useRealisticTiming = false

    /// 실제 API 응답 형식을 사용할지 제어
    var useRealResponseFormats = true

    /// 특정 응답이 구성되지 않았을 때 반환할 기본 응답
    var defaultResponse: MockHTTPResponse = .success

    /// 시뮬레이션된 네트워크 호출의 기본 지연(초)
    var defaultDelay: TimeInterval = 0.1

    // MARK: - 동작 추적

    /// 모킹 클라이언트에 대한 모든 요청을 추적
    /// 예상된 API 호출이 이루어졌는지 확인하는 데 유용
    private(set) var requestLog: [MockHTTPRequest] = []

    /// 특정 엔드포인트가 호출된 횟수를 추적
    private(set) var callCounts: [String: Int] = [:]

    /// 특정 엔드포인트에 대해 구성된 응답을 저장
    private var configuredResponses: [String: MockHTTPResponse] = [:]

    // MARK: - 공개 API

    /// HTTP 요청을 수행하는 주요 메서드
    /// 네트워크 동작을 시뮬레이션하고 구성된 응답을 반환합니다
    func perform<T: Codable>(_ request: URLRequest) async throws -> T {
        // 확인을 위해 요청을 로깅
        let mockRequest = MockHTTPRequest(
            url: request.url,
            method: request.httpMethod ?? "GET",
            timestamp: Date()
        )
        requestLog.append(mockRequest)

        // 호출 횟수 업데이트
        let endpoint = extractEndpoint(from: request.url)
        callCounts[endpoint, default: 0] += 1

        print("📡 모킹 HTTP 호출: \(mockRequest.method) \(endpoint)")

        // 구성된 경우 네트워크 지연 시뮬레이션
        if useRealisticTiming {
            let delay = randomDelay()
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        // 구성된 응답을 가져오거나 기본값 사용
        let response = configuredResponses[endpoint] ?? defaultResponse

        // 다양한 응답 타입 처리
        switch response {
        case .success(let data):
            return try decodeResponse(data: data, type: T.self)

        case .failure(let error):
            throw error

        case .timeout:
            throw URLError(.timedOut)

        case .networkError:
            throw URLError(.networkConnectionLost)
        }
    }

    // MARK: - 구성 메서드

    /// 엔드포인트에 대한 특정 응답 구성
    /// 테스트가 반환될 데이터를 제어할 수 있습니다
    func configureResponse(for endpoint: String, response: MockHTTPResponse) {
        configuredResponses[endpoint] = response
        print("🔧 \(endpoint)에 대한 응답 구성됨: \(response)")
    }

    /// 특정 데이터로 성공 응답 구성
    /// 일반적인 성공 시나리오를 위한 편의 메서드
    func configureSuccess<T: Codable>(for endpoint: String, data: T) {
        let jsonData = try! JSONEncoder().encode(data)
        configureResponse(for: endpoint, response: .success(jsonData))
    }

    /// 특정 오류로 실패 응답 구성
    /// 오류 시나리오 테스트를 위한 편의 메서드
    func configureFailure(for endpoint: String, error: Error) {
        configureResponse(for: endpoint, response: .failure(error))
    }

    // MARK: - 검증 메서드

    /// 특정 엔드포인트가 호출되었는지 확인
    /// 엔드포인트가 적어도 한 번 호출되었으면 true 반환
    func wasEndpointCalled(_ endpoint: String) -> Bool {
        return callCounts[endpoint] ?? 0 > 0
    }

    /// 엔드포인트가 호출된 횟수 가져오기
    /// 재시도 로직이나 중복 호출 방지를 확인하는 데 유용
    func callCount(for endpoint: String) -> Int {
        return callCounts[endpoint] ?? 0
    }

    /// 엔드포인트가 특정 순서로 호출되었는지 확인
    /// 순차적인 API 호출이 필요한 워크플로우 테스트에 유용
    func verifyCallOrder(_ expectedOrder: [String]) -> Bool {
        let actualOrder = requestLog.map { extractEndpoint(from: $0.url) }
        return actualOrder == expectedOrder
    }

    /// 모든 추적 데이터 재설정
    /// 테스트 시나리오를 격리하는 데 유용
    func reset() {
        requestLog.removeAll()
        callCounts.removeAll()
        configuredResponses.removeAll()
        print("🧹 모킹 HTTP 클라이언트 재설정됨")
    }

    // MARK: - 비공개 메서드

    /// URL에서 엔드포인트 식별자 추출
    private func extractEndpoint(from url: URL?) -> String {
        guard let url = url else { return "unknown" }
        return "\(url.path)?query=\(url.query ?? "")"
    }

    /// 현실적인 타이밍 시뮬레이션을 위한 랜덤 지연 생성
    private func randomDelay() -> TimeInterval {
        // 50ms에서 500ms 사이의 현실적인 네트워크 지연 시뮬레이션
        return TimeInterval.random(in: 0.05...0.5)
    }

    /// 응답 데이터를 예상 타입으로 디코딩
    private func decodeResponse<T: Codable>(data: Data, type: T.Type) throws -> T {
        if useRealResponseFormats {
            // 실제 JSON 디코딩을 사용하여 직렬화 문제 포착
            return try JSONDecoder().decode(type, from: data)
        } else {
            // 간단한 테스트의 경우 모킹 객체를 직접 반환
            // 이를 위해서는 T가 생성 가능하거나 팩토리 메서드를 사용해야 합니다
            fatalError("\(type)에 대한 간단한 모킹 디코딩이 구현되지 않음")
        }
    }
}

/// 테스팅을 위한 다양한 HTTP 응답 타입
enum MockHTTPResponse {
    case success(Data)
    case failure(Error)
    case timeout
    case networkError
}

/// 검증을 위한 로깅된 HTTP 요청
struct MockHTTPRequest {
    let url: URL?
    let method: String
    let timestamp: Date
}
```

**🔍 코드 설명:**
- **포괄적인 추적**: 검증을 위해 모든 요청과 호출 횟수를 로깅
- **유연한 구성**: 다양한 엔드포인트에 대해 특정 응답 설정 가능
- **현실적인 시뮬레이션**: 네트워크 지연과 실제 응답 형식을 시뮬레이션 가능
- **검증 메서드**: 예상 동작을 확인하는 다양한 방법 제공
- **재설정 기능**: 테스트 간 상태 정리 가능

## 📋 추가 예정

완전한 테스팅 문서 포함:

1. **통합 테스팅 패턴**
2. **DI를 사용한 성능 테스팅**
3. **모킹된 의존성을 사용한 UI 테스팅**
4. **테스트 데이터 관리**
5. **지속적 통합 설정**

---

📖 **관련 문서**: [시작하기](/ko/tutorial/gettingStarted) | [Property Wrapper](/ko/tutorial/propertyWrappers)