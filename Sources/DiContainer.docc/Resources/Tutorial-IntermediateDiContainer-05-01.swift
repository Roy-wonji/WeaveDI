import Foundation
import DiContainer
import LogMacro

// MARK: - 테스트 친화적 의존성 주입

/// 단위 테스트와 통합 테스트에서 효과적으로 의존성 주입을 활용하는
/// 고급 테스트 패턴들을 구현합니다.

// MARK: - 테스트용 DI 컨테이너

/// 테스트 환경에 최적화된 DI 컨테이너
final class TestDIContainer {
    private let baseContainer: DIContainer
    private var testOverrides: [String: Any] = [:]
    private var mockRegistry: [String: Any] = [:]

    init(baseContainer: DIContainer = DIContainer()) {
        self.baseContainer = baseContainer
    }

    /// 테스트용 Mock 객체를 등록합니다
    func registerMock<T>(_ mock: T, for type: T.Type, name: String? = nil) {
        let key = Self.makeKey(for: type, name: name)
        testOverrides[key] = mock
        mockRegistry[key] = mock

        #logInfo("🎭 Mock 등록: \(key)")
    }

    /// 테스트용 실제 구현체를 등록합니다
    func registerTestImpl<T>(_ factory: @escaping () -> T, for type: T.Type, name: String? = nil) {
        let key = Self.makeKey(for: type, name: name)
        testOverrides[key] = factory

        #logInfo("🧪 테스트 구현체 등록: \(key)")
    }

    /// 의존성을 해결합니다 (테스트 오버라이드 우선)
    func resolve<T>(_ type: T.Type, name: String? = nil) -> T {
        let key = Self.makeKey(for: type, name: name)

        // 1. 테스트 오버라이드 확인
        if let override = testOverrides[key] {
            if let instance = override as? T {
                #logInfo("✅ 테스트 오버라이드 사용: \(key)")
                return instance
            } else if let factory = override as? () -> T {
                #logInfo("🏭 테스트 팩토리 사용: \(key)")
                return factory()
            }
        }

        // 2. 기본 컨테이너에서 해결
        if let named = name {
            return baseContainer.resolve(type, name: named)
        } else {
            return baseContainer.resolve(type)
        }
    }

    /// Mock 객체가 등록되어 있는지 확인합니다
    func isMockRegistered<T>(for type: T.Type, name: String? = nil) -> Bool {
        let key = Self.makeKey(for: type, name: name)
        return mockRegistry[key] != nil
    }

    /// 등록된 Mock들을 모두 제거합니다
    func clearMocks() {
        let mockCount = testOverrides.count
        testOverrides.removeAll()
        mockRegistry.removeAll()

        #logInfo("🧹 Mock 정리 완료: \(mockCount)개 제거")
    }

    /// Mock 호출 통계를 확인할 수 있는 Mock들을 반환합니다
    func getTrackableMocks() -> [String: TrackableMock] {
        var trackableMocks: [String: TrackableMock] = [:]

        for (key, mock) in mockRegistry {
            if let trackable = mock as? TrackableMock {
                trackableMocks[key] = trackable
            }
        }

        return trackableMocks
    }

    private static func makeKey<T>(for type: T.Type, name: String?) -> String {
        let typeName = String(describing: type)
        return name.map { "\(typeName):\($0)" } ?? typeName
    }
}

// MARK: - 추적 가능한 Mock 프로토콜

/// Mock 호출을 추적할 수 있는 프로토콜
protocol TrackableMock: AnyObject {
    var callCount: Int { get }
    var lastCallParameters: [String: Any]? { get }
    var callHistory: [[String: Any]] { get }

    func resetTracking()
}

/// 기본 추적 기능을 제공하는 Mock 베이스 클래스
class BaseMock: TrackableMock {
    private(set) var callCount: Int = 0
    private(set) var lastCallParameters: [String: Any]?
    private(set) var callHistory: [[String: Any]] = []

    func trackCall(method: String, parameters: [String: Any] = [:]) {
        callCount += 1
        var callInfo = parameters
        callInfo["method"] = method
        callInfo["timestamp"] = Date().timeIntervalSince1970

        lastCallParameters = callInfo
        callHistory.append(callInfo)

        #logInfo("📞 Mock 호출 추적: \(method) (총 \(callCount)회)")
    }

    func resetTracking() {
        callCount = 0
        lastCallParameters = nil
        callHistory.removeAll()

        #logInfo("🔄 Mock 추적 초기화")
    }
}

// MARK: - 실용적인 Mock 객체 예제들

// MARK: 네트워크 서비스 Mock

protocol NetworkService: Sendable {
    func fetchData(from url: String) async throws -> Data
    func postData(_ data: Data, to url: String) async throws -> String
}

final class MockNetworkService: BaseMock, NetworkService {
    private var stubbedResponses: [String: Data] = [:]
    private var stubbedErrors: [String: Error] = [:]
    private var shouldSimulateDelay: Bool = false
    private var delayAmount: TimeInterval = 0.1

    func stubResponse(for url: String, data: Data) {
        stubbedResponses[url] = data
        stubbedErrors.removeValue(forKey: url)
        #logInfo("📄 Mock 응답 설정: \(url)")
    }

    func stubError(for url: String, error: Error) {
        stubbedErrors[url] = error
        stubbedResponses.removeValue(forKey: url)
        #logInfo("❌ Mock 에러 설정: \(url)")
    }

    func setSimulateDelay(_ simulate: Bool, amount: TimeInterval = 0.1) {
        shouldSimulateDelay = simulate
        delayAmount = amount
    }

    func fetchData(from url: String) async throws -> Data {
        trackCall(method: "fetchData", parameters: ["url": url])

        if shouldSimulateDelay {
            try await Task.sleep(nanoseconds: UInt64(delayAmount * 1_000_000_000))
        }

        if let error = stubbedErrors[url] {
            throw error
        }

        return stubbedResponses[url] ?? Data("Mock Response".utf8)
    }

    func postData(_ data: Data, to url: String) async throws -> String {
        trackCall(method: "postData", parameters: ["url": url, "dataSize": data.count])

        if shouldSimulateDelay {
            try await Task.sleep(nanoseconds: UInt64(delayAmount * 1_000_000_000))
        }

        if let error = stubbedErrors[url] {
            throw error
        }

        return "Mock Post Response"
    }
}

// MARK: 데이터베이스 Mock

protocol DatabaseService: Sendable {
    func save<T: Codable>(_ entity: T, id: String) async throws
    func fetch<T: Codable>(_ type: T.Type, id: String) async throws -> T?
    func delete(id: String) async throws
}

final class MockDatabaseService: BaseMock, DatabaseService {
    private var storage: [String: Data] = [:]
    private var shouldFailOperations: Set<String> = []

    func setOperationToFail(_ operation: String) {
        shouldFailOperations.insert(operation)
        #logInfo("💥 Mock 실패 설정: \(operation)")
    }

    func clearFailures() {
        shouldFailOperations.removeAll()
    }

    func save<T: Codable>(_ entity: T, id: String) async throws {
        trackCall(method: "save", parameters: ["id": id, "type": String(describing: T.self)])

        if shouldFailOperations.contains("save") {
            throw MockError.operationFailed("save")
        }

        let data = try JSONEncoder().encode(entity)
        storage[id] = data

        #logInfo("💾 Mock 저장: \(id)")
    }

    func fetch<T: Codable>(_ type: T.Type, id: String) async throws -> T? {
        trackCall(method: "fetch", parameters: ["id": id, "type": String(describing: type)])

        if shouldFailOperations.contains("fetch") {
            throw MockError.operationFailed("fetch")
        }

        guard let data = storage[id] else {
            #logInfo("🔍 Mock 조회 실패: \(id)")
            return nil
        }

        let entity = try JSONDecoder().decode(type, from: data)
        #logInfo("📖 Mock 조회 성공: \(id)")
        return entity
    }

    func delete(id: String) async throws {
        trackCall(method: "delete", parameters: ["id": id])

        if shouldFailOperations.contains("delete") {
            throw MockError.operationFailed("delete")
        }

        storage.removeValue(forKey: id)
        #logInfo("🗑️ Mock 삭제: \(id)")
    }

    func getStoredIds() -> [String] {
        return Array(storage.keys)
    }
}

enum MockError: Error, LocalizedError {
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .operationFailed(let operation):
            return "Mock operation failed: \(operation)"
        }
    }
}

// MARK: 이벤트 버스 Mock

protocol EventBus: Sendable {
    func publish<T: Codable>(_ event: T) async
    func subscribe<T: Codable>(to eventType: T.Type, handler: @escaping (T) async -> Void)
}

final class MockEventBus: BaseMock, EventBus {
    private var publishedEvents: [Any] = []
    private var subscribers: [String: [(Any) async -> Void]] = [:]

    func publish<T: Codable>(_ event: T) async {
        let eventType = String(describing: T.self)
        trackCall(method: "publish", parameters: ["eventType": eventType])

        publishedEvents.append(event)
        #logInfo("📢 Mock 이벤트 발행: \(eventType)")

        // 구독자들에게 이벤트 전달 시뮬레이션
        if let handlers = subscribers[eventType] {
            for handler in handlers {
                await handler(event)
            }
        }
    }

    func subscribe<T: Codable>(to eventType: T.Type, handler: @escaping (T) async -> Void) {
        let key = String(describing: eventType)
        trackCall(method: "subscribe", parameters: ["eventType": key])

        if subscribers[key] == nil {
            subscribers[key] = []
        }

        let wrappedHandler: (Any) async -> Void = { event in
            if let typedEvent = event as? T {
                await handler(typedEvent)
            }
        }

        subscribers[key]?.append(wrappedHandler)
        #logInfo("👂 Mock 구독 등록: \(key)")
    }

    func getPublishedEvents<T: Codable>(ofType type: T.Type) -> [T] {
        return publishedEvents.compactMap { $0 as? T }
    }

    func clearPublishedEvents() {
        publishedEvents.removeAll()
        #logInfo("🧹 Mock 이벤트 기록 정리")
    }
}

// MARK: - 테스트 시나리오 빌더

/// 복잡한 테스트 시나리오를 쉽게 구성할 수 있는 빌더
final class TestScenarioBuilder {
    private let container: TestDIContainer
    private var setupActions: [() async throws -> Void] = []
    private var verificationActions: [() async throws -> Void] = []

    init(container: TestDIContainer) {
        self.container = container
    }

    /// Mock 객체를 설정합니다
    func withMock<T>(_ type: T.Type, name: String? = nil, setup: (inout T) throws -> Void) -> TestScenarioBuilder {
        setupActions.append {
            var mock = self.container.resolve(type, name: name)
            try setup(&mock)
        }
        return self
    }

    /// 데이터를 준비합니다
    func withData(_ setupData: @escaping () async throws -> Void) -> TestScenarioBuilder {
        setupActions.append(setupData)
        return self
    }

    /// 검증 액션을 추가합니다
    func verify(_ verification: @escaping () async throws -> Void) -> TestScenarioBuilder {
        verificationActions.append(verification)
        return self
    }

    /// 시나리오를 실행합니다
    func execute(_ testAction: () async throws -> Void) async throws {
        #logInfo("🎬 테스트 시나리오 실행 시작")

        // 1. 설정 단계
        for setup in setupActions {
            try await setup()
        }

        #logInfo("✅ 테스트 설정 완료")

        // 2. 테스트 액션 실행
        try await testAction()

        #logInfo("✅ 테스트 액션 완료")

        // 3. 검증 단계
        for verification in verificationActions {
            try await verification()
        }

        #logInfo("✅ 테스트 검증 완료")
    }
}

// MARK: - 테스트 유틸리티

/// 테스트에서 자주 사용되는 유틸리티 함수들
final class DITestUtils {
    /// Mock의 메서드 호출을 검증합니다
    static func verifyMethodCalled(
        on mock: TrackableMock,
        method: String,
        times: Int? = nil,
        withParameters parameters: [String: Any]? = nil
    ) throws {
        guard mock.callCount > 0 else {
            throw TestAssertionError.mockNotCalled(method: method)
        }

        if let expectedTimes = times {
            let actualCalls = mock.callHistory.filter { call in
                call["method"] as? String == method
            }.count

            guard actualCalls == expectedTimes else {
                throw TestAssertionError.unexpectedCallCount(
                    method: method,
                    expected: expectedTimes,
                    actual: actualCalls
                )
            }
        }

        if let expectedParams = parameters {
            let methodCalls = mock.callHistory.filter { call in
                call["method"] as? String == method
            }

            let hasMatchingCall = methodCalls.contains { call in
                for (key, expectedValue) in expectedParams {
                    guard let actualValue = call[key],
                          String(describing: actualValue) == String(describing: expectedValue) else {
                        return false
                    }
                }
                return true
            }

            guard hasMatchingCall else {
                throw TestAssertionError.parametersNotMatched(
                    method: method,
                    expected: expectedParams
                )
            }
        }

        #logInfo("✅ Mock 검증 성공: \(method)")
    }

    /// 비동기 조건을 대기합니다
    static func waitUntil(
        timeout: TimeInterval = 5.0,
        condition: @escaping () async -> Bool
    ) async throws {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            if await condition() {
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1초 대기
        }

        throw TestAssertionError.timeoutWaiting(timeout: timeout)
    }
}

enum TestAssertionError: Error, LocalizedError {
    case mockNotCalled(method: String)
    case unexpectedCallCount(method: String, expected: Int, actual: Int)
    case parametersNotMatched(method: String, expected: [String: Any])
    case timeoutWaiting(timeout: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .mockNotCalled(let method):
            return "Mock method '\(method)' was not called"
        case .unexpectedCallCount(let method, let expected, let actual):
            return "Mock method '\(method)' expected \(expected) calls, got \(actual)"
        case .parametersNotMatched(let method, let expected):
            return "Mock method '\(method)' parameters didn't match: \(expected)"
        case .timeoutWaiting(let timeout):
            return "Timeout waiting for condition after \(timeout) seconds"
        }
    }
}

// MARK: - 테스트 예제

/// 실제 비즈니스 로직 클래스 (테스트 대상)
final class UserService {
    @Inject private var networkService: NetworkService
    @Inject private var databaseService: DatabaseService
    @Inject private var eventBus: EventBus

    func createUser(name: String, email: String) async throws -> String {
        #logInfo("👤 사용자 생성: \(name)")

        // 1. 외부 API에서 사용자 검증
        let validationData = try await networkService.fetchData(from: "https://api.example.com/validate")
        #logInfo("✅ 사용자 검증 완료")

        // 2. 데이터베이스에 사용자 저장
        let userId = UUID().uuidString
        let user = ["id": userId, "name": name, "email": email]
        try await databaseService.save(user, id: userId)

        // 3. 사용자 생성 이벤트 발행
        let event = ["userId": userId, "eventType": "userCreated"]
        await eventBus.publish(event)

        return userId
    }

    func getUser(id: String) async throws -> [String: Any]? {
        return try await databaseService.fetch([String: Any].self, id: id)
    }
}

// MARK: - 테스트 친화적 패턴 데모

final class TestFriendlyPatternsDemo {
    private var container: TestDIContainer!

    init() {
        setupTestContainer()
    }

    private func setupTestContainer() {
        container = TestDIContainer()

        // Mock 객체들 등록
        container.registerMock(MockNetworkService(), for: NetworkService.self)
        container.registerMock(MockDatabaseService(), for: DatabaseService.self)
        container.registerMock(MockEventBus(), for: EventBus.self)

        // 테스트 대상 서비스 등록
        container.registerTestImpl({ UserService() }, for: UserService.self)
    }

    func demonstrateTestFriendlyPatterns() async throws {
        #logInfo("🎬 테스트 친화적 패턴 데모 시작")

        try await testSuccessfulUserCreation()
        try await testNetworkFailureHandling()
        try await testMockInteractions()
        showMockStatistics()

        #logInfo("🎉 테스트 친화적 패턴 데모 완료")
    }

    private func testSuccessfulUserCreation() async throws {
        #logInfo("\n1️⃣ 성공적인 사용자 생성 테스트")

        try await TestScenarioBuilder(container: container)
            .withMock(MockNetworkService.self) { mock in
                mock.stubResponse(for: "https://api.example.com/validate", data: Data("valid".utf8))
            }
            .verify {
                let eventBus = self.container.resolve(MockEventBus.self)
                let publishedEvents = eventBus.getPublishedEvents(ofType: [String: Any].self)

                guard publishedEvents.count == 1 else {
                    throw TestAssertionError.unexpectedCallCount(
                        method: "publish",
                        expected: 1,
                        actual: publishedEvents.count
                    )
                }

                #logInfo("✅ 이벤트 발행 검증 완료")
            }
            .execute {
                let userService = self.container.resolve(UserService.self)
                let userId = try await userService.createUser(name: "Test User", email: "test@example.com")

                #logInfo("✅ 사용자 생성 완료: \(userId)")

                // 생성된 사용자 조회 테스트
                let retrievedUser = try await userService.getUser(id: userId)
                guard retrievedUser != nil else {
                    throw TestAssertionError.mockNotCalled(method: "fetch")
                }

                #logInfo("✅ 사용자 조회 완료")
            }
    }

    private func testNetworkFailureHandling() async throws {
        #logInfo("\n2️⃣ 네트워크 실패 처리 테스트")

        let networkMock = container.resolve(MockNetworkService.self)
        networkMock.resetTracking()
        networkMock.stubError(for: "https://api.example.com/validate", error: MockError.operationFailed("network"))

        let userService = container.resolve(UserService.self)

        do {
            _ = try await userService.createUser(name: "Failed User", email: "fail@example.com")
            throw TestAssertionError.mockNotCalled(method: "error should have been thrown")
        } catch {
            #logInfo("✅ 예상된 에러 발생: \(error.localizedDescription)")
        }

        // 네트워크 호출이 시도되었는지 확인
        try DITestUtils.verifyMethodCalled(
            on: networkMock,
            method: "fetchData",
            times: 1,
            withParameters: ["url": "https://api.example.com/validate"]
        )
    }

    private func testMockInteractions() async throws {
        #logInfo("\n3️⃣ Mock 상호작용 테스트")

        let databaseMock = container.resolve(MockDatabaseService.self)
        databaseMock.resetTracking()
        databaseMock.clearFailures()

        let networkMock = container.resolve(MockNetworkService.self)
        networkMock.resetTracking()
        networkMock.stubResponse(for: "https://api.example.com/validate", data: Data("valid".utf8))

        let userService = container.resolve(UserService.self)
        _ = try await userService.createUser(name: "Mock Test", email: "mock@example.com")

        // 각 Mock의 상호작용 검증
        try DITestUtils.verifyMethodCalled(on: networkMock, method: "fetchData", times: 1)
        try DITestUtils.verifyMethodCalled(on: databaseMock, method: "save", times: 1)

        #logInfo("✅ Mock 상호작용 검증 완료")
    }

    private func showMockStatistics() {
        #logInfo("\n📊 Mock 통계")

        let trackableMocks = container.getTrackableMocks()

        for (key, mock) in trackableMocks {
            #logInfo("- \(key): \(mock.callCount)회 호출")

            if mock.callCount > 0 {
                for (index, call) in mock.callHistory.enumerated() {
                    let method = call["method"] as? String ?? "unknown"
                    #logInfo("  \(index + 1). \(method)")
                }
            }
        }
    }
}

// MARK: - 테스트 친화적 패턴 데모

enum TestFriendlyPatternsExample {
    static func demonstrateTestFriendlyPatterns() async throws {
        #logInfo("🎬 테스트 친화적 패턴 데모 시작")

        let demo = TestFriendlyPatternsDemo()
        try await demo.demonstrateTestFriendlyPatterns()

        #logInfo("🎉 테스트 친화적 패턴 데모 완료")
    }
}