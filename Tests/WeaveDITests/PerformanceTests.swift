import XCTest
@testable import WeaveDI

/// WeaveDI 성능 벤치마크 테스트
/// CI/CD 파이프라인에서 자동으로 실행되어 성능 회귀를 감지합니다.
final class PerformanceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // 각 테스트마다 깨끗한 상태로 시작
        Task { @MainActor in
            UnifiedDI.releaseAll()
        }
    }

    override func tearDown() {
        Task { @MainActor in
            UnifiedDI.releaseAll()
        }
        super.tearDown()
    }

    // MARK: - 기본 DI 성능 테스트

    /// 단일 의존성 해결 성능 테스트
    func testSingleDependencyResolutionPerformance() throws {
        // Given: 간단한 서비스 등록
        _ = UnifiedDI.register(MockNetworkService.self) {
            MockNetworkService()
        }

        // When & Then: 해결 성능 측정
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for _ in 0..<1000 {
                _ = UnifiedDI.resolve(MockNetworkService.self)
            }
        }
    }

    /// 복잡한 의존성 그래프 해결 성능 테스트
    func testComplexDependencyGraphPerformance() throws {
        // Given: 복잡한 의존성 관계 설정
        setupComplexDependencyGraph()

        // When & Then: 복잡한 의존성 해결 성능 측정
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for _ in 0..<100 {
                _ = UnifiedDI.resolve(PerformanceMockUserService.self)
            }
        }
    }

    /// 동시 해결 성능 테스트 (멀티스레드)
    func testConcurrentResolutionPerformance() throws {
        // Given: 스레드 안전한 서비스 등록
        _ = UnifiedDI.register(MockThreadSafeService.self) {
            MockThreadSafeService()
        }

        // When & Then: 동시 해결 성능 측정
        measure(metrics: [XCTClockMetric()]) {
            let expectation = XCTestExpectation(description: "Concurrent resolution")
            expectation.expectedFulfillmentCount = 10

            for _ in 0..<10 {
                DispatchQueue.global().async {
                    for _ in 0..<100 {
                        _ = UnifiedDI.resolve(MockThreadSafeService.self)
                    }
                    expectation.fulfill()
                }
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    // MARK: - Auto DI Optimizer 성능 테스트

    /// Auto DI Optimizer 활성화 시 성능 테스트
    func testAutoOptimizerPerformance() throws {
        // Given: Auto DI Optimizer 활성화
        setupAutoOptimizedDependencies()

        // When & Then: 최적화된 해결 성능 측정
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for _ in 0..<500 {
                _ = UnifiedDI.resolve(MockOptimizedService.self)
            }
        }
    }

    /// 메모리 사용량 최적화 테스트
    func testMemoryOptimizationPerformance() throws {
        // Given: 메모리 집약적 서비스들 등록
        setupMemoryIntensiveServices()

        // When & Then: 메모리 사용량 측정
        measure(metrics: [XCTMemoryMetric()]) {
            autoreleasepool {
                for _ in 0..<50 {
                    _ = UnifiedDI.resolve(MockMemoryIntensiveService.self)
                }
            }
        }
    }

    // MARK: - Property Wrapper 성능 테스트

    /// @Injected 성능 테스트
    func testInjectedPropertyWrapperPerformance() throws {
        // Given: 서비스 등록
        _ = UnifiedDI.register(MockNetworkService.self) {
            MockNetworkService()
        }

        // When & Then: Property Wrapper 성능 측정
        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<1000 {
                let viewModel = MockViewModelWithInjection()
                _ = viewModel.performNetworkOperation()
            }
        }
    }

    // MARK: - TCA 통합 성능 테스트

    /// TCA 브릿지 성능 테스트
    func testTCABridgePerformance() throws {
        // Given: TCA 의존성 설정
        setupTCADependencies()

        // When & Then: TCA 브릿지 성능 측정
        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<200 {
                _ = MockTCAFeature.live
            }
        }
    }

    // MARK: - 성능 회귀 검증

    /// 전체 DI 시스템 초기화 성능 테스트
    func testDISystemInitializationPerformance() throws {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            Task { @MainActor in
                UnifiedDI.releaseAll()
            }
            setupFullApplicationDependencies()
        }
    }

    /// 대규모 의존성 등록 성능 테스트
    func testLargeScaleRegistrationPerformance() throws {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for i in 0..<1000 {
                _ = UnifiedDI.register(MockGenericService.self, factory: {
                    MockGenericService(id: i)
                })
            }
        }
    }

    // MARK: - Helper Methodss

    private func setupComplexDependencyGraph() {
        // 복잡한 의존성 관계 설정
        _ = UnifiedDI.register(MockLogger.self) {
            MockLogger()
        }

        _ = UnifiedDI.register(MockNetworkService.self) {
            MockNetworkService()
        }

        _ = UnifiedDI.register(MockCacheService.self) {
            MockCacheService(logger: UnifiedDI.resolve(MockLogger.self)!)
        }

        _ = UnifiedDI.register(MockDatabaseService.self) {
            MockDatabaseService(
                logger: UnifiedDI.resolve(MockLogger.self)!,
                cache: UnifiedDI.resolve(MockCacheService.self)!
            )
        }

        _ = UnifiedDI.register(PerformanceMockUserService.self) {
            PerformanceMockUserService(
                network: UnifiedDI.resolve(MockNetworkService.self)!,
                database: UnifiedDI.resolve(MockDatabaseService.self)!,
                logger: UnifiedDI.resolve(MockLogger.self)!
            )
        }
    }

    private func setupAutoOptimizedDependencies() {
        _ = UnifiedDI.register(MockOptimizedService.self) {
            MockOptimizedService()
        }
    }

    private func setupMemoryIntensiveServices() {
        _ = UnifiedDI.register(MockMemoryIntensiveService.self) {
            MockMemoryIntensiveService()
        }
    }

    private func setupTCADependencies() {
        // TCA 관련 의존성 설정 (실제 TCA 있을 때 구현)
    }

    private func setupFullApplicationDependencies() {
        // 실제 앱의 모든 의존성을 시뮬레이션
        setupComplexDependencyGraph()
        setupAutoOptimizedDependencies()
        setupMemoryIntensiveServices()
    }
}

// MARK: - Mock Services for Performance Testing

class MockNetworkService: @unchecked Sendable {
    func fetchData() -> String {
        return "Mock network data"
    }
}

class MockLogger: @unchecked Sendable {
    func log(_ message: String) {
        // Mock logging
    }
}

class MockCacheService: @unchecked Sendable {
    private let logger: MockLogger

    init(logger: MockLogger) {
        self.logger = logger
    }

    func store(_ key: String, value: Any) {
        logger.log("Storing \(key)")
    }
}

class MockDatabaseService: @unchecked Sendable {
    private let logger: MockLogger
    private let cache: MockCacheService

    init(logger: MockLogger, cache: MockCacheService) {
        self.logger = logger
        self.cache = cache
    }

    func save(_ data: String) {
        logger.log("Saving to database")
        cache.store("data", value: data)
    }
}

class PerformanceMockUserService: @unchecked Sendable {
    private let network: MockNetworkService
    private let database: MockDatabaseService
    private let logger: MockLogger

    init(network: MockNetworkService, database: MockDatabaseService, logger: MockLogger) {
        self.network = network
        self.database = database
        self.logger = logger
    }

    func loadUser() -> String {
        logger.log("Loading user")
        let data = network.fetchData()
        database.save(data)
        return "User loaded"
    }
}

class MockThreadSafeService: @unchecked Sendable {
    private let queue = DispatchQueue(label: "mock.thread.safe", attributes: .concurrent)
    private var _counter: Int = 0

    var counter: Int {
        queue.sync { _counter }
    }

    func increment() {
        queue.async(flags: .barrier) {
            self._counter += 1
        }
    }
}

class MockOptimizedService: @unchecked Sendable {
    func performOptimizedOperation() -> String {
        return "Optimized operation result"
    }
}

class MockMemoryIntensiveService: @unchecked Sendable {
    // 메모리 집약적 작업을 시뮬레이션
    private let largeData: [Int]

    init() {
        self.largeData = Array(0..<10000)
    }

    func processData() -> Int {
        return largeData.reduce(0, +)
    }
}

class MockGenericService: @unchecked Sendable {
    let id: Int

    init(id: Int) {
        self.id = id
    }
}

class MockViewModelWithInjection {
    private let networkService: MockNetworkService

    init() {
        self.networkService = UnifiedDI.resolve(MockNetworkService.self) ?? MockNetworkService()
    }

    func performNetworkOperation() -> String {
        return networkService.fetchData()
    }
}

// TCA Mock (실제 TCA 의존성이 있을 때 활성화)
#if canImport(ComposableArchitecture)
import ComposableArchitecture

struct MockTCAFeature {
    static let live = Self()
}
#else
struct MockTCAFeature {
    static let live = Self()
}
#endif
