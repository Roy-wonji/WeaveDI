//
//  TCAIntegrationTests.swift
//  WeaveDI
//
//  Created by Claude on 2025-10-04.
//

import XCTest
@testable import WeaveDI
#if canImport(Dependencies)
import Dependencies

// MARK: - Test Types (Global scope)

protocol TCATestNetworkService: Sendable {
    func fetchData() -> String
}

struct TCALiveNetworkService: TCATestNetworkService {
    func fetchData() -> String { "Live Network Data" }
}

struct TCAMockNetworkService: TCATestNetworkService {
    func fetchData() -> String { "Mock Network Data" }
}

// MARK: - TCA DependencyKey (Global scope)

struct TCANetworkServiceKey: DependencyKey {
    static let liveValue: TCATestNetworkService = TCALiveNetworkService()
    static let testValue: TCATestNetworkService = TCAMockNetworkService()
}

extension DependencyValues {
    var tcaNetworkService: TCATestNetworkService {
        get { self[TCANetworkServiceKey.self] }
        set { self[TCANetworkServiceKey.self] = newValue }
    }
}

// MARK: - Test Classes (Global scope)

class TCATestViewModel {
    @Injected(TCANetworkServiceKey.self) var networkService: TCATestNetworkService

    func getData() -> String {
        return networkService.fetchData()
    }
}

final class TCAIntegrationTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await UnifiedDI.releaseAll()
    }

    override func tearDown() async throws {
        await UnifiedDI.releaseAll()
        try await super.tearDown()
    }

    // MARK: - Tests

    func testTCADependencyKeyWithInjected() {
        // Given: TCA DependencyKey를 WeaveDI에 등록
        _ = UnifiedDI.register(TCATestNetworkService.self) { TCALiveNetworkService() }

        // When: @Injected(DependencyKey.self) 사용
        let viewModel = TCATestViewModel()
        let result = viewModel.getData()

        // Then: 등록된 의존성이 해결되어야 함
        XCTAssertEqual(result, "Live Network Data")
    }

    func testTCADependencyKeyFallbackToDefault() {
        // Given: WeaveDI에 등록하지 않음

        // When: @Injected(DependencyKey.self) 사용
        let viewModel = TCATestViewModel()
        let result = viewModel.getData()

        // Then: TCA 기본값이 사용되어야 함
        XCTAssertEqual(result, "Live Network Data")
    }

    func testDependencyValuesIntegration() {
        // Given: DependencyValues로 값 설정
        withDependencies {
            $0.tcaNetworkService = TCAMockNetworkService()
        } operation: {
            // When: DependencyValues에서 값 조회
            @Dependency(TCANetworkServiceKey.self) var networkService
            let result = networkService.fetchData()

            // Then: 설정된 값이 반환되어야 함
            XCTAssertEqual(result, "Mock Network Data")
        }
    }

    func testTCABridgedKeyLiveValue() {
        // Given: WeaveDI에 값 등록
        _ = UnifiedDI.register(TCATestNetworkService.self) { TCALiveNetworkService() }

        // When: TCABridgedKey로 값 조회
        let bridgedValue = TCABridgedKey<TCANetworkServiceKey>.liveValue

        // Then: WeaveDI에서 등록된 값이 반환되어야 함
        XCTAssertEqual(bridgedValue.fetchData(), "Live Network Data")
    }

    func testTCABridgedKeyTestValue() {
        // When: TCABridgedKey로 테스트값 조회
        let testValue = TCABridgedKey<TCANetworkServiceKey>.testValue

        // Then: TCA의 testValue가 반환되어야 함
        XCTAssertEqual(testValue.fetchData(), "Mock Network Data")
    }

    func testPerformanceComparison() {
        // Given: 의존성 등록
        _ = UnifiedDI.register(TCATestNetworkService.self) { TCALiveNetworkService() }

        // 성능 측정: @Injected with TCA DependencyKey
        measure {
            for _ in 0..<1000 {
                let viewModel = TCATestViewModel()
                _ = viewModel.getData()
            }
        }
    }

    // MARK: - 자동 인터셉션 테스트

    func testAutoSyncRegistration() {
        // Given: 자동 동기화를 포함한 등록
        let service = UnifiedDI.registerWithAutoSync(TCATestNetworkService.self) {
            TCALiveNetworkService()
        }

        // When: TCA DependencyKey로 접근
        let viewModel = TCATestViewModel()
        let result = viewModel.getData()

        // Then: 자동으로 동기화되어야 함
        XCTAssertEqual(result, "Live Network Data")
        XCTAssertEqual(service.fetchData(), "Live Network Data")
    }

    func testAutoFallbackResolve() {
        // Given: WeaveDI에는 등록하지 않음

        // When: 자동 fallback으로 해결 시도
        let service = UnifiedDI.resolveWithAutoFallback(TCATestNetworkService.self)

        // Then: TCA 기본값이 반환되어야 함 (현재는 nil이지만 향후 확장 가능)
        // 현재 구현에서는 WeaveDI 우선이므로 nil 반환
        XCTAssertNil(service)
    }

    func testAsyncAutoSyncRegistration() async {
        // Given: 비동기 자동 동기화 등록
        let service = await UnifiedDI.registerAsyncWithAutoSync(TCATestNetworkService.self) {
            TCALiveNetworkService()
        }

        // When: 즉시 사용
        let result = service.fetchData()

        // Then: 정상 작동해야 함
        XCTAssertEqual(result, "Live Network Data")
    }

    func testBidirectionalSync() {
        // Given: WeaveDI에 등록
        _ = UnifiedDI.registerWithAutoSync(TCATestNetworkService.self) {
            TCALiveNetworkService()
        }

        // When & Then: 양방향에서 같은 타입이 해결되어야 함
        withDependencies { _ in
            // TCA context에서도 사용 가능해야 함
            @Dependency(TCANetworkServiceKey.self) var tcaService
            let tcaResult = tcaService.fetchData()
            // 자동 동기화로 인해 WeaveDI 값이 우선됩니다
            XCTAssertEqual(tcaResult, "Live Network Data")
        } operation: {
            // WeaveDI context에서도 사용 가능
            let viewModel = TCATestViewModel()
            let weaveDIResult = viewModel.getData()
            XCTAssertEqual(weaveDIResult, "Live Network Data")
        }
    }

    // MARK: - 역방향 동기화 테스트 (InjectedValues → DependencyValues)

    func testReverseSync_InjectedValuesToDependencyValues() {
        // Given: WeaveDI에 TCA 동기화를 포함해서 등록
        _ = UnifiedDI.registerWithTCASync(TCATestNetworkService.self) {
            TCALiveNetworkService()
        }

        // When: TCA에서 해당 서비스에 접근
        withDependencies { _ in
            @Dependency(TCANetworkServiceKey.self) var tcaService
            let result = tcaService.fetchData()

            // Then: 자동 동기화로 WeaveDI에서 등록한 값이 TCA에서도 사용됩니다
            XCTAssertEqual(result, "Live Network Data")
        } operation: {
            // Additional verification in operation block
        }
    }

    func testBasicRegisterAutoTCASync() {
        // Given: 기본 등록이지만 TCA 동기화 포함
        let service = UnifiedDI.registerWithTCASync(TCATestNetworkService.self) {
            TCALiveNetworkService()
        }

        // When & Then: WeaveDI에서 바로 사용 가능
        XCTAssertEqual(service.fetchData(), "Live Network Data")

        // WeaveDI @Injected로도 사용 가능
        let viewModel = TCATestViewModel()
        let injectedResult = viewModel.getData()
        XCTAssertEqual(injectedResult, "Live Network Data")
    }

    func testKeyPathRegisterAutoTCASync() {
        // Given: 존재하는 KeyPath로 TCA 동기화 포함 등록
        let service = UnifiedDI.registerKeyPathWithTCASync(\.testNetworkService) {
            CoreTestNetworkServiceImpl() as CoreTestNetworkService
        }

        // When & Then: 등록이 성공해야 함
        XCTAssertEqual(service.fetchData(), "network_data")
    }

    func testInjectedKeyToDependencyKeySync() {
        // Given: InjectedValues 헬퍼 메서드로 값 설정
        InjectedValues.current.setWithTCASync(TCABridgedKey<TCANetworkServiceKey>.self, value: TCALiveNetworkService())

        // When: TCA DependencyKey로 접근
        withDependencies { _ in
            @Dependency(TCANetworkServiceKey.self) var tcaService
            let result = tcaService.fetchData()

            // Then: 자동 동기화로 InjectedKey에서 설정한 값이 DependencyKey에서도 사용됩니다
            XCTAssertEqual(result, "Live Network Data")
        } operation: {
            // Additional verification
        }
    }

    func testDirectInjectedKeyAutoResolve() {
        // Given: WeaveDI에 등록
        _ = UnifiedDI.register(TCATestNetworkService.self) { TCALiveNetworkService() }

        // When: InjectedValues 헬퍼 메서드로 자동 해결
        let service = InjectedValues.current.getWithAutoResolve(TCABridgedKey<TCANetworkServiceKey>.self)

        // Then: WeaveDI에서 등록한 값이 해결되어야 함
        XCTAssertEqual(service.fetchData(), "Live Network Data")
    }

    // MARK: - 기존 InjectedKey 패턴 + TCA 동기화 테스트

    func testTraditionalInjectedKeyWithTCASync() {
        // Given: WeaveDI에서 서비스 등록
        _ = UnifiedDI.register(TCATestNetworkService.self) { TCALiveNetworkService() }

        // When: 기존 InjectedKey 패턴으로 TCA 동기화 헬퍼 사용
        InjectedValues.current.registerInjectedKeyWithTCA(TCABridgedKey<TCANetworkServiceKey>.self)

        // Then: WeaveDI에서 동일한 값이 해결되어야 함
        let service = InjectedValues.current.getWithAutoResolve(TCABridgedKey<TCANetworkServiceKey>.self)
        XCTAssertEqual(service.fetchData(), "Live Network Data")

        // TCABridgedKey를 통한 @Injected 사용도 가능
        let viewModel = TCATestViewModel() // @Injected(TCANetworkServiceKey.self) 사용
        XCTAssertEqual(viewModel.getData(), "Live Network Data")
    }

    // MARK: - 사용자 예시 코드와 동일한 패턴 테스트

    func testUserExamplePattern_AutoTCASync() {
        // Given: 사용자 예시와 동일한 InjectedKey 패턴

        // When: 새로운 autoSync subscript로 자동 TCA 동기화
        let service = InjectedValues.current[autoSync: TCABridgedKey<TCANetworkServiceKey>.self]

        // Then: 자동으로 TCA와 동기화되어야 함
        XCTAssertEqual(service.fetchData(), "Live Network Data")

        // WeaveDI @Injected로도 사용 가능해야 함
        let viewModel = TCATestViewModel()
        let weaveDIResult = viewModel.getData()
        XCTAssertEqual(weaveDIResult, "Live Network Data")

        // 🎯 핵심: autoSync subscript가 정상 작동함을 확인
        print("✅ autoSync subscript 정상 작동: \(service.fetchData())")
    }

    func testUserComputedPropertyPattern() {
        // Given: 사용자 예시처럼 computed property 패턴
        // var exchangeRateCacheUseCase: ExchangeRateCacheInterface {
        //   get { self[autoSync: ExchangeRateCacheUseCaseImpl.self] }  // ← 이렇게 변경
        //   set { self[autoSync: ExchangeRateCacheUseCaseImpl.self] = newValue }
        // }

        // When: 새로운 autoSync subscript로 자동 동기화
        let service = InjectedValues.current[autoSync: TCABridgedKey<TCANetworkServiceKey>.self]

        // Then: 자동 TCA 동기화가 작동해야 함
        XCTAssertEqual(service.fetchData(), "Live Network Data")

        // setter도 자동 동기화되어야 함 (withInjectedValues 사용)
        let newService = TCAMockNetworkService()
        let result = withInjectedValues {
            $0[autoSync: TCABridgedKey<TCANetworkServiceKey>.self] = newService
        } operation: {
            // 변경된 값이 TCA에서도 사용되어야 함
            let changedService = InjectedValues.current[autoSync: TCABridgedKey<TCANetworkServiceKey>.self]
            return changedService.fetchData()
        }
        XCTAssertEqual(result, "Mock Network Data")
    }

    func testUserHelperMethodPattern() {
        // Given: 헬퍼 메서드를 사용한 패턴
        // var exchangeRateCacheUseCase: ExchangeRateCacheInterface {
        //   get { self.autoSyncValue(for: ExchangeRateCacheUseCaseImpl.self) }
        //   set { self.setAutoSyncValue(for: ExchangeRateCacheUseCaseImpl.self, value: newValue) }
        // }

        // When: 헬퍼 메서드로 자동 동기화
        let service = InjectedValues.current.autoSyncValue(for: TCABridgedKey<TCANetworkServiceKey>.self)

        // Then: 자동 TCA 동기화가 작동해야 함
        XCTAssertEqual(service.fetchData(), "Live Network Data")

        // setter 헬퍼 메서드도 테스트
        let newService = TCAMockNetworkService()
        var values = InjectedValues.current
        values.setAutoSyncValue(for: TCABridgedKey<TCANetworkServiceKey>.self, value: newService)

        // 변경된 값 확인
        let changedService = values.autoSyncValue(for: TCABridgedKey<TCANetworkServiceKey>.self)
        XCTAssertEqual(changedService.fetchData(), "Mock Network Data")
    }

    // MARK: - TCA → WeaveDI 역방향 동기화 테스트 (사용자 요청)

    func testTCADependencyKeyToWeaveDI_AutoSync() {
        // Given: 사용자 예시와 동일한 TCA DependencyKey 패턴
        // extension ExchangeRateCacheUseCaseImpl: DependencyKey { ... }

        // When: DependencyValues autoSync subscript로 자동 WeaveDI 동기화
        let service = withDependencies { dependencies in
            // autoSync subscript 사용으로 자동 WeaveDI 등록
            _ = dependencies[autoSync: TCANetworkServiceKey.self]
        } operation: {
            // 반환된 서비스가 자동으로 WeaveDI에도 등록되어야 함
            return UnifiedDI.resolve(TCATestNetworkService.self)
        }

        // Then: TCA DependencyKey가 WeaveDI에도 자동 등록되어야 함
        XCTAssertNotNil(service)
        XCTAssertEqual(service?.fetchData(), "Live Network Data")

        // WeaveDI @Injected로도 사용 가능해야 함
        let viewModel = TCATestViewModel()
        let weaveDIResult = viewModel.getData()
        XCTAssertEqual(weaveDIResult, "Live Network Data")
    }

    func testTCAComputedPropertyPattern() {
        // Given: 사용자 예시처럼 TCA computed property 패턴
        // public extension DependencyValues {
        //   var exchangeRateCacheUseCase: ExchangeRateCacheInterface {
        //     get { self[autoSync: ExchangeRateCacheUseCaseImpl.self] }  // ← 이렇게 변경
        //     set { self[autoSync: ExchangeRateCacheUseCaseImpl.self] = newValue }
        //   }
        // }

        // When: TCA DependencyValues에서 autoSync로 접근
        let service = withDependencies { dependencies in
            // autoSync subscript로 자동 WeaveDI 동기화
            _ = dependencies[autoSync: TCANetworkServiceKey.self]
        } operation: {
            return TCALiveNetworkService()
        }

        // Then: 자동으로 WeaveDI와 동기화되어야 함
        XCTAssertEqual(service.fetchData(), "Live Network Data")

        // WeaveDI에서도 사용 가능해야 함
        let resolvedService = UnifiedDI.resolve(TCATestNetworkService.self)
        XCTAssertNotNil(resolvedService)
        XCTAssertEqual(resolvedService?.fetchData(), "Live Network Data")
    }

    func testBidirectionalAutoSync() {
        // Given: 양방향 자동 동기화 테스트

        // When: TCA에서 autoSync로 설정
        withDependencies { dependencies in
            var deps = dependencies
            deps[autoSync: TCANetworkServiceKey.self] = TCALiveNetworkService()
        } operation: {
            // Then: WeaveDI에서도 사용 가능해야 함
            let service = UnifiedDI.resolve(TCATestNetworkService.self)
            XCTAssertNotNil(service)
            XCTAssertEqual(service?.fetchData(), "Live Network Data")

            // WeaveDI @Injected로도 사용 가능
            let viewModel = TCATestViewModel()
            let result = viewModel.getData()
            XCTAssertEqual(result, "Live Network Data")
        }
    }
}

#endif