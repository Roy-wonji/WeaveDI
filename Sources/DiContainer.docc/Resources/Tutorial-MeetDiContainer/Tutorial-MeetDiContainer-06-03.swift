import Foundation
import XCTest
import DiContainer
import LogMacro

// MARK: - ModuleFactory Pattern Tests

@testable import DiContainer
final class ModuleFactoryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        #logInfo("🧪 [테스트] ModuleFactory 패턴 테스트 시작")

        // 테스트 시작 전 컨테이너 및 최적화 시스템 초기화
        DIContainer.shared.removeAll()
        AutoDIOptimizer.shared.reset()
    }

    override func tearDown() {
        #logInfo("🧪 [테스트] ModuleFactory 패턴 테스트 종료")

        // 테스트 종료 후 정리
        DIContainer.shared.removeAll()
        AutoDIOptimizer.shared.reset()
        super.tearDown()
    }

    // MARK: - ModuleFactoryManager Tests

    func test_module_factory_manager_registration() async throws {
        #logInfo("🧪 [테스트] ModuleFactoryManager 등록 검증")

        // Given: ModuleFactoryManager 생성 및 설정
        var manager = ModuleFactoryManager()
        manager.registerDefaultDependencies()

        // When: 컨테이너에 모든 모듈 등록
        await manager.registerAll(to: DIContainer.shared)

        // Then: 주요 의존성들이 등록되어야 함
        let counterRepository = UnifiedDI.resolve(CounterRepository.self)
        let counterUseCase = UnifiedDI.resolve(CounterUseCase.self)

        XCTAssertNotNil(counterRepository, "CounterRepository가 등록되어야 합니다")
        XCTAssertNotNil(counterUseCase, "CounterUseCase가 등록되어야 합니다")

        // 타입 확인
        XCTAssertTrue(counterRepository is UserDefaultsCounterRepository)
        XCTAssertTrue(counterUseCase is DefaultCounterUseCase)

        #logInfo("✅ [테스트] ModuleFactoryManager 등록 검증 성공")
    }

    func test_repository_module_factory_default_definitions() async throws {
        #logInfo("🧪 [테스트] RepositoryModuleFactory 기본 정의 검증")

        // Given: RepositoryModuleFactory 생성
        var factory = RepositoryModuleFactory()
        factory.registerDefaultDefinitions()

        // When: 정의된 모듈들 확인
        let definitions = factory.definitions
        XCTAssertFalse(definitions.isEmpty, "기본 정의들이 있어야 합니다")

        // Then: 각 모듈을 컨테이너에 등록하고 확인
        for moduleCreator in definitions {
            let module = moduleCreator()
            await DIContainer.shared.register(module)
        }

        // 등록된 Repository들 확인
        let counterRepository = UnifiedDI.resolve(CounterRepository.self)
        XCTAssertNotNil(counterRepository, "CounterRepository가 등록되어야 합니다")

        #logInfo("✅ [테스트] RepositoryModuleFactory 기본 정의 검증 성공")
    }

    func test_use_case_module_factory_default_definitions() async throws {
        #logInfo("🧪 [테스트] UseCaseModuleFactory 기본 정의 검증")

        // Given: Repository 먼저 등록 (UseCase 의존성)
        var repositoryFactory = RepositoryModuleFactory()
        repositoryFactory.registerDefaultDefinitions()

        for moduleCreator in repositoryFactory.definitions {
            let module = moduleCreator()
            await DIContainer.shared.register(module)
        }

        // UseCaseModuleFactory 생성
        var factory = UseCaseModuleFactory()
        factory.registerDefaultDefinitions()

        // When: UseCase 모듈들 등록
        for moduleCreator in factory.definitions {
            let module = moduleCreator()
            await DIContainer.shared.register(module)
        }

        // Then: UseCase가 올바르게 등록되고 의존성 주입이 작동해야 함
        let counterUseCase = UnifiedDI.resolve(CounterUseCase.self)
        XCTAssertNotNil(counterUseCase, "CounterUseCase가 등록되어야 합니다")

        // UseCase 내부의 @Inject Repository가 올바르게 주입되었는지 확인
        let useCase = counterUseCase as! DefaultCounterUseCase
        let currentValue = useCase.currentValue
        XCTAssertEqual(currentValue, 0) // 초기값 확인

        #logInfo("✅ [테스트] UseCaseModuleFactory 기본 정의 검증 성공")
    }

    // MARK: - AppDIContainer Production Tests

    func test_app_di_container_register_default_dependencies() async throws {
        #logInfo("🧪 [테스트] AppDIContainer 기본 의존성 등록 검증")

        // Given: AppDIContainer 인스턴스
        let appContainer = AppDIContainer.shared

        // When: 기본 의존성들 등록
        await appContainer.registerDefaultDependencies()

        // Then: 모든 주요 의존성들이 등록되어야 함
        let services: [(Any.Type, String)] = [
            (CounterService.self, "CounterService"),
            (LoggingService.self, "LoggingService"),
            (NetworkService.self, "NetworkService"),
            (CounterRepository.self, "CounterRepository"),
            (CounterUseCase.self, "CounterUseCase")
        ]

        for (serviceType, serviceName) in services {
            let resolved = UnifiedDI.resolve(serviceType)
            XCTAssertNotNil(resolved, "\(serviceName)이 등록되어야 합니다")
        }

        #logInfo("✅ [테스트] AppDIContainer 기본 의존성 등록 검증 성공")
    }

    func test_app_di_container_health_check() async throws {
        #logInfo("🧪 [테스트] AppDIContainer 건강 상태 확인 검증")

        // Given: 모든 의존성 등록
        let appContainer = AppDIContainer.shared
        await appContainer.registerDefaultDependencies()

        // When: 건강 상태 확인
        let isHealthy = await appContainer.performHealthCheck()

        // Then: 시스템이 건강해야 함
        XCTAssertTrue(isHealthy, "시스템이 건강 상태여야 합니다")

        #logInfo("✅ [테스트] AppDIContainer 건강 상태 확인 검증 성공")
    }

    func test_app_di_container_health_check_with_missing_dependency() async throws {
        #logInfo("🧪 [테스트] AppDIContainer 누락된 의존성과 건강 상태 확인")

        // Given: 일부 의존성만 등록 (의도적으로 누락)
        DIContainer.shared.register(CounterService.self) {
            DefaultCounterService()
        }
        // CounterRepository, CounterUseCase, LoggingService는 등록하지 않음

        // When: 건강 상태 확인
        let appContainer = AppDIContainer.shared
        let isHealthy = await appContainer.performHealthCheck()

        // Then: 시스템이 건강하지 않아야 함
        XCTAssertFalse(isHealthy, "누락된 의존성이 있으면 건강하지 않아야 합니다")

        #logInfo("✅ [테스트] AppDIContainer 누락된 의존성과 건강 상태 확인 검증 성공")
    }

    // MARK: - AutoDIOptimizer Integration Tests

    func test_auto_di_optimizer_integration_with_module_factory() async throws {
        #logInfo("🧪 [테스트] AutoDIOptimizer와 ModuleFactory 통합 검증")

        // Given: AutoDIOptimizer 활성화
        let optimizer = AutoDIOptimizer.shared
        optimizer.setOptimizationEnabled(true)
        optimizer.setLogLevel(.all)

        // ModuleFactoryManager로 의존성 등록
        var manager = ModuleFactoryManager()
        manager.registerDefaultDependencies()
        await manager.registerAll(to: DIContainer.shared)

        // When: 여러 의존성 해결 수행
        for _ in 0..<10 {
            let _ = UnifiedDI.resolve(CounterService.self)
            let _ = UnifiedDI.resolve(CounterRepository.self)
            let _ = UnifiedDI.resolve(CounterUseCase.self)
        }

        // Then: 통계 확인
        let stats = optimizer.getStats()
        XCTAssertGreaterThan(stats.registered, 0, "등록된 타입이 있어야 합니다")
        XCTAssertGreaterThan(stats.resolved, 0, "해결된 요청이 있어야 합니다")

        #logInfo("📊 [테스트] 최적화 통계: 등록 \(stats.registered)개, 해결 \(stats.resolved)회")
        #logInfo("✅ [테스트] AutoDIOptimizer와 ModuleFactory 통합 검증 성공")
    }

    func test_optimization_suggestions() async throws {
        #logInfo("🧪 [테스트] 최적화 제안 검증")

        // Given: AutoDIOptimizer 활성화 및 의존성 등록
        let optimizer = AutoDIOptimizer.shared
        optimizer.setOptimizationEnabled(true)

        var manager = ModuleFactoryManager()
        manager.registerDefaultDependencies()
        await manager.registerAll(to: DIContainer.shared)

        // When: 다양한 패턴으로 의존성 해결
        for _ in 0..<50 {
            let _ = UnifiedDI.resolve(CounterService.self) // 자주 사용
        }

        for _ in 0..<5 {
            let _ = UnifiedDI.resolve(LoggingService.self) // 적게 사용
        }

        // Then: 최적화 제안 확인
        let suggestions = optimizer.getOptimizationSuggestions()
        XCTAssertNotNil(suggestions, "최적화 제안이 있어야 합니다")

        #logInfo("💡 [테스트] 최적화 제안 개수: \(suggestions.count)")
        for suggestion in suggestions {
            #logInfo("  • \(suggestion)")
        }

        #logInfo("✅ [테스트] 최적화 제안 검증 성공")
    }

    // MARK: - Real-world Scenario Tests

    func test_complete_app_bootstrap_scenario() async throws {
        #logInfo("🧪 [테스트] 완전한 앱 부트스트랩 시나리오 검증")

        // Given: 실제 앱 시작과 유사한 시나리오
        let optimizer = AutoDIOptimizer.shared

        // 1단계: Optimizer 설정
        optimizer.setOptimizationEnabled(true)
        optimizer.setLogLevel(.errors)
        optimizer.setDebounceInterval(ms: 100)

        // 2단계: AppDIContainer 부트스트랩
        let appContainer = AppDIContainer.shared
        await appContainer.registerDefaultDependencies()

        // 3단계: 등록 상태 모니터링
        await appContainer.monitorRegistrationStatus()

        // 4단계: 건강 상태 확인
        let isHealthy = await appContainer.performHealthCheck()

        // Then: 모든 단계가 성공해야 함
        XCTAssertTrue(isHealthy, "부트스트랩 후 시스템이 건강해야 합니다")

        let stats = optimizer.getStats()
        XCTAssertGreaterThan(stats.registered, 5, "최소 5개 이상의 타입이 등록되어야 합니다")

        #logInfo("🎯 [테스트] 최종 통계: 등록 \(stats.registered)개, 해결 \(stats.resolved)회")
        #logInfo("✅ [테스트] 완전한 앱 부트스트랩 시나리오 검증 성공")
    }

    func test_concurrent_dependency_resolution() async throws {
        #logInfo("🧪 [테스트] 동시성 의존성 해결 검증")

        // Given: ModuleFactory 패턴으로 설정
        var manager = ModuleFactoryManager()
        manager.registerDefaultDependencies()
        await manager.registerAll(to: DIContainer.shared)

        // When: 여러 Task에서 동시에 의존성 해결
        let tasks = (0..<10).map { index in
            Task {
                for _ in 0..<20 {
                    let counterService = UnifiedDI.resolve(CounterService.self)
                    let loggingService = UnifiedDI.resolve(LoggingService.self)
                    let repository = UnifiedDI.resolve(CounterRepository.self)
                    let useCase = UnifiedDI.resolve(CounterUseCase.self)

                    XCTAssertNotNil(counterService)
                    XCTAssertNotNil(loggingService)
                    XCTAssertNotNil(repository)
                    XCTAssertNotNil(useCase)
                }
                return index
            }
        }

        // Then: 모든 Task가 성공적으로 완료되어야 함
        let results = await withTaskGroup(of: Int.self) { group in
            for task in tasks {
                group.addTask { await task.value }
            }

            var completedTasks: [Int] = []
            for await result in group {
                completedTasks.append(result)
            }
            return completedTasks
        }

        XCTAssertEqual(results.count, 10, "모든 동시성 작업이 완료되어야 합니다")
        XCTAssertEqual(Set(results).count, 10, "모든 Task가 고유한 결과를 반환해야 합니다")

        #logInfo("⚡ [테스트] 동시성 작업 완료: \(results.count)개")
        #logInfo("✅ [테스트] 동시성 의존성 해결 검증 성공")
    }

    // MARK: - Error Handling Tests

    func test_module_factory_error_recovery() async throws {
        #logInfo("🧪 [테스트] ModuleFactory 에러 복구 검증")

        // Given: 일부 의존성을 의도적으로 등록하지 않음
        var repositoryFactory = RepositoryModuleFactory()
        repositoryFactory.registerDefaultDefinitions()

        // Repository만 등록하고 UseCase는 등록하지 않음
        for moduleCreator in repositoryFactory.definitions {
            let module = moduleCreator()
            await DIContainer.shared.register(module)
        }

        // When: 건강 상태 확인 (실패할 것)
        let appContainer = AppDIContainer.shared
        let initialHealth = await appContainer.performHealthCheck()
        XCTAssertFalse(initialHealth, "초기 상태는 건강하지 않아야 합니다")

        // 누락된 UseCase 등록
        var useCaseFactory = UseCaseModuleFactory()
        useCaseFactory.registerDefaultDefinitions()

        for moduleCreator in useCaseFactory.definitions {
            let module = moduleCreator()
            await DIContainer.shared.register(module)
        }

        // 추가 서비스들도 등록
        DIContainer.shared.register(CounterService.self) { DefaultCounterService() }
        DIContainer.shared.register(LoggingService.self) { DefaultLoggingService() }
        DIContainer.shared.register(NetworkService.self) { DefaultNetworkService() }

        // Then: 복구 후 건강 상태 확인
        let recoveredHealth = await appContainer.performHealthCheck()
        XCTAssertTrue(recoveredHealth, "복구 후 시스템이 건강해야 합니다")

        #logInfo("✅ [테스트] ModuleFactory 에러 복구 검증 성공")
    }

    // MARK: - Performance Tests

    func test_module_factory_performance() async throws {
        #logInfo("🧪 [테스트] ModuleFactory 성능 검증")

        // Given: 성능 측정 준비
        let startTime = CFAbsoluteTimeGetCurrent()

        // When: 대량의 ModuleFactory 작업 수행
        for iteration in 0..<100 {
            DIContainer.shared.removeAll()

            var manager = ModuleFactoryManager()
            manager.registerDefaultDependencies()
            await manager.registerAll(to: DIContainer.shared)

            // 의존성 해결 테스트
            for _ in 0..<10 {
                let _ = UnifiedDI.resolve(CounterService.self)
                let _ = UnifiedDI.resolve(CounterRepository.self)
                let _ = UnifiedDI.resolve(CounterUseCase.self)
            }

            if iteration % 20 == 0 {
                #logInfo("📊 [성능 테스트] 진행률: \(iteration)/100")
            }
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime

        // Then: 합리적인 시간 내에 완료되어야 함
        XCTAssertLessThan(executionTime, 10.0, "성능이 너무 느립니다 (10초 초과)")

        #logInfo("⚡ [테스트] ModuleFactory 성능: \(String(format: "%.3f", executionTime))초 (100회 반복)")
        #logInfo("✅ [테스트] ModuleFactory 성능 검증 성공")
    }
}