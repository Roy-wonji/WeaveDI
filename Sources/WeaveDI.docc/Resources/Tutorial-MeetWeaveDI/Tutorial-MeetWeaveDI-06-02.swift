import Foundation
import XCTest
import WeaveDI
import LogMacro

// MARK: - Property Wrapper Tests

@testable import WeaveDI
final class PropertyWrapperTests: XCTestCase {

    override func setUp() {
        super.setUp()
        #logInfo("🧪 [테스트] Property Wrapper 테스트 시작")

        // 테스트 시작 전 컨테이너 초기화
        DIContainer.shared.removeAll()
    }

    override func tearDown() {
        #logInfo("🧪 [테스트] Property Wrapper 테스트 종료")

        // 테스트 종료 후 정리
        DIContainer.shared.removeAll()
        super.tearDown()
    }

    // MARK: - @Inject Tests

    func test_inject_property_wrapper_singleton_behavior() async throws {
        #logInfo("🧪 [테스트] @Inject 싱글톤 동작 검증")

        // Given: CounterService 등록
        DIContainer.shared.register(CounterService.self) {
            MockCounterService.createForTesting(initialCount: 10)
        }

        // When: 두 개의 다른 객체에서 @Inject 사용
        class TestObject1 {
            @Inject var counterService: CounterService
        }

        class TestObject2 {
            @Inject var counterService: CounterService
        }

        let obj1 = TestObject1()
        let obj2 = TestObject2()

        // Then: 동일한 인스턴스여야 함
        let service1 = obj1.counterService as! MockCounterService
        let service2 = obj2.counterService as! MockCounterService

        XCTAssertTrue(service1 === service2, "@Inject는 싱글톤이어야 합니다")
        XCTAssertEqual(service1.count, 10)

        // 한쪽에서 변경하면 다른 쪽도 반영되어야 함
        service1.increment()

        // 비동기 작업 완료 대기
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1초

        XCTAssertEqual(service2.count, 11, "싱글톤이므로 변경사항이 공유되어야 합니다")

        #logInfo("✅ [테스트] @Inject 싱글톤 동작 검증 성공")
    }

    func test_inject_property_wrapper_lazy_initialization() async throws {
        #logInfo("🧪 [테스트] @Inject 지연 초기화 검증")

        // Given: 카운터를 가진 Mock 서비스
        var initializationCount = 0

        DIContainer.shared.register(CounterService.self) {
            initializationCount += 1
            #logInfo("📦 [테스트] CounterService 초기화됨 (count: \(initializationCount))")
            return MockCounterService.createForTesting(initialCount: 5)
        }

        class TestObject {
            @Inject var counterService: CounterService
        }

        // When: 객체 생성 (아직 서비스에 접근하지 않음)
        let obj = TestObject()
        XCTAssertEqual(initializationCount, 0, "아직 초기화되지 않아야 합니다")

        // Then: 첫 번째 접근에서 초기화
        let service = obj.counterService
        XCTAssertEqual(initializationCount, 1, "첫 번째 접근에서 초기화되어야 합니다")

        // 두 번째 접근에서는 초기화되지 않음
        let _ = obj.counterService
        XCTAssertEqual(initializationCount, 1, "두 번째 접근에서는 초기화되지 않아야 합니다")

        #logInfo("✅ [테스트] @Inject 지연 초기화 검증 성공")
    }

    // MARK: - @Factory Tests

    func test_factory_property_wrapper_creates_new_instances() async throws {
        #logInfo("🧪 [테스트] @Factory 새 인스턴스 생성 검증")

        // Given: LoggingService를 Factory로 등록
        DIContainer.shared.register(LoggingService.self) {
            MockLoggingService.createForTesting()
        }

        // When: 두 개의 다른 객체에서 @Factory 사용
        class TestObject1 {
            @Factory var loggingService: LoggingService
        }

        class TestObject2 {
            @Factory var loggingService: LoggingService
        }

        let obj1 = TestObject1()
        let obj2 = TestObject2()

        // Then: 서로 다른 인스턴스여야 함
        let service1 = obj1.loggingService as! MockLoggingService
        let service2 = obj2.loggingService as! MockLoggingService

        XCTAssertFalse(service1 === service2, "@Factory는 매번 새 인스턴스를 생성해야 합니다")
        XCTAssertNotEqual(service1.sessionId, service2.sessionId, "세션 ID가 달라야 합니다")

        #logInfo("✅ [테스트] @Factory 새 인스턴스 생성 검증 성공")
    }

    func test_factory_property_wrapper_multiple_access() async throws {
        #logInfo("🧪 [테스트] @Factory 다중 접근 검증")

        // Given: LoggingService Factory 등록
        DIContainer.shared.register(LoggingService.self) {
            MockLoggingService.createForTesting()
        }

        class TestObject {
            @Factory var loggingService: LoggingService
        }

        let obj = TestObject()

        // When: 같은 객체에서 여러 번 접근
        let service1 = obj.loggingService as! MockLoggingService
        let service2 = obj.loggingService as! MockLoggingService

        // Then: 매번 새 인스턴스가 생성되어야 함
        XCTAssertFalse(service1 === service2, "매번 새 인스턴스가 생성되어야 합니다")
        XCTAssertNotEqual(service1.sessionId, service2.sessionId)

        #logInfo("✅ [테스트] @Factory 다중 접근 검증 성공")
    }

    // MARK: - @SafeInject Tests

    func test_safe_inject_with_registered_service() async throws {
        #logInfo("🧪 [테스트] @SafeInject 등록된 서비스 검증")

        // Given: NetworkService 등록
        DIContainer.shared.register(NetworkService.self) {
            MockNetworkService()
        }

        class TestObject {
            @SafeInject var networkService: NetworkService?
        }

        let obj = TestObject()

        // When & Then: 등록된 서비스는 nil이 아니어야 함
        XCTAssertNotNil(obj.networkService, "등록된 서비스는 nil이 아니어야 합니다")

        let service = obj.networkService as! MockNetworkService
        XCTAssertEqual(service.getRequestCount(), 0)

        #logInfo("✅ [테스트] @SafeInject 등록된 서비스 검증 성공")
    }

    func test_safe_inject_with_unregistered_service() async throws {
        #logInfo("🧪 [테스트] @SafeInject 미등록 서비스 검증")

        class TestObject {
            @SafeInject var networkService: NetworkService?
        }

        let obj = TestObject()

        // When & Then: 미등록 서비스는 nil이어야 함
        XCTAssertNil(obj.networkService, "미등록 서비스는 nil이어야 합니다")

        #logInfo("✅ [테스트] @SafeInject 미등록 서비스 검증 성공")
    }

    // MARK: - @RequiredInject Tests (고급 사용법)

    func test_required_inject_with_registered_service() async throws {
        #logInfo("🧪 [테스트] @RequiredInject 등록된 서비스 검증")

        // Given: 필수 서비스 등록
        DIContainer.shared.register(CounterService.self) {
            MockCounterService.createForTesting(initialCount: 100)
        }

        class TestObject {
            @RequiredInject var counterService: CounterService
        }

        let obj = TestObject()

        // When & Then: 정상적으로 서비스가 주입되어야 함
        let service = obj.counterService as! MockCounterService
        XCTAssertEqual(service.count, 100)

        #logInfo("✅ [테스트] @RequiredInject 등록된 서비스 검증 성공")
    }

    func test_required_inject_with_unregistered_service_throws_error() async throws {
        #logInfo("🧪 [테스트] @RequiredInject 미등록 서비스 에러 검증")

        class TestObject {
            @RequiredInject var counterService: CounterService
        }

        let obj = TestObject()

        // When & Then: 미등록 서비스 접근 시 에러가 발생해야 함
        XCTAssertThrowsError(try obj._counterService.resolve()) { error in
            #logInfo("🚨 [테스트] 예상된 에러 발생: \(error.localizedDescription)")
        }

        #logInfo("✅ [테스트] @RequiredInject 미등록 서비스 에러 검증 성공")
    }

    // MARK: - Combined Tests

    func test_mixed_property_wrappers_in_same_class() async throws {
        #logInfo("🧪 [테스트] 혼합 Property Wrapper 사용 검증")

        // Given: 모든 서비스 등록
        DIContainer.shared.register(CounterService.self) {
            MockCounterService.createForTesting(initialCount: 42)
        }

        DIContainer.shared.register(LoggingService.self) {
            MockLoggingService.createForTesting()
        }

        class TestObject {
            @Inject var counterService: CounterService
            @Factory var loggingService: LoggingService
            @SafeInject var networkService: NetworkService? // 의도적으로 등록하지 않음
        }

        let obj1 = TestObject()
        let obj2 = TestObject()

        // When & Then: 각각 올바르게 동작해야 함

        // @Inject: 싱글톤
        let counter1 = obj1.counterService as! MockCounterService
        let counter2 = obj2.counterService as! MockCounterService
        XCTAssertTrue(counter1 === counter2, "@Inject는 싱글톤이어야 함")

        // @Factory: 매번 새 인스턴스
        let logging1 = obj1.loggingService as! MockLoggingService
        let logging2 = obj2.loggingService as! MockLoggingService
        XCTAssertFalse(logging1 === logging2, "@Factory는 새 인스턴스여야 함")

        // @SafeInject: 안전한 nil 처리
        XCTAssertNil(obj1.networkService, "@SafeInject는 미등록 시 nil이어야 함")
        XCTAssertNil(obj2.networkService, "@SafeInject는 미등록 시 nil이어야 함")

        #logInfo("✅ [테스트] 혼합 Property Wrapper 사용 검증 성공")
    }

    // MARK: - Async Tests

    func test_property_wrappers_with_async_services() async throws {
        #logInfo("🧪 [테스트] 비동기 서비스와 Property Wrapper 검증")

        // Given: 비동기 작업을 수행하는 서비스들
        DIContainer.shared.register(CounterUseCase.self) {
            MockCounterUseCase()
        }

        DIContainer.shared.register(CounterRepository.self) {
            MockCounterRepository.createForTesting(initialValue: 20)
        }

        class TestObject {
            @Inject var counterUseCase: CounterUseCase
            @Inject var counterRepository: CounterRepository
        }

        let obj = TestObject()

        // When: 비동기 작업 수행
        let useCase = obj.counterUseCase as! MockCounterUseCase
        let repository = obj.counterRepository as! MockCounterRepository

        try await useCase.increment()
        try await repository.save(value: 25)

        // Then: 비동기 작업이 정상적으로 완료되어야 함
        XCTAssertEqual(useCase.currentValue, 1)
        XCTAssertEqual(useCase.incrementCallCount, 1)

        XCTAssertEqual(repository.currentValue, 25)
        XCTAssertEqual(repository.saveCallCount, 1)

        #logInfo("✅ [테스트] 비동기 서비스와 Property Wrapper 검증 성공")
    }

    // MARK: - Performance Tests

    func test_property_wrapper_performance() async throws {
        #logInfo("🧪 [테스트] Property Wrapper 성능 검증")

        // Given: 서비스 등록
        DIContainer.shared.register(CounterService.self) {
            MockCounterService()
        }

        class TestObject {
            @Inject var counterService: CounterService
        }

        // When: 대량의 객체 생성 및 서비스 접근
        let startTime = CFAbsoluteTimeGetCurrent()

        var objects: [TestObject] = []
        for _ in 0..<1000 {
            let obj = TestObject()
            let _ = obj.counterService // 서비스에 접근
            objects.append(obj)
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime

        // Then: 합리적인 시간 내에 완료되어야 함 (1초 미만)
        XCTAssertLessThan(executionTime, 1.0, "성능이 너무 느립니다")
        XCTAssertEqual(objects.count, 1000)

        #logInfo("⚡ [테스트] Property Wrapper 성능: \(String(format: "%.3f", executionTime))초 (1000개 객체)")
        #logInfo("✅ [테스트] Property Wrapper 성능 검증 성공")
    }
}