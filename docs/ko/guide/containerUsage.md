# Container 사용법

WeaveDI의 Container 시스템은 최적화된 병렬 처리를 통해 효율적인 모듈 기반 의존성 등록을 제공합니다. 모듈을 수집하고 병렬로 등록하여 Actor hop을 최소화하고 Swift 6 동시성 환경에서의 성능을 향상시킵니다.

## 개요

Container 시스템은 각 `Module`이 의존성 등록 작업의 개별 단위를 나타내는 모듈식 아키텍처 위에 구축됩니다. 이 접근 방식은 기존 의존성 주입 패턴에 비해 여러 가지 장점을 제공합니다:

**핵심 개념**:
- **Module**: 하나 이상의 관련 의존성을 포함하는 등록 작업의 최소 단위
- **수집 단계**: 즉시 등록하지 않고 `Container.register(_:)`를 사용하여 모듈 수집
- **병렬 빌드**: 최적 성능을 위해 수집된 모든 모듈을 `build()`로 동시에 등록
- **Actor 최적화**: Swift의 동시성 환경에서 Actor hop 최소화

**성능 이점**:
- **병렬 처리**: 여러 모듈이 순차적이 아닌 동시에 등록됨
- **Actor 효율성**: 더 나은 성능을 위해 actor 간 컨텍스트 스위칭 감소
- **메모리 최적화**: 배치 등록을 통한 효율적인 메모리 사용
- **시작 속도**: 최적화된 의존성 해결을 통한 빠른 애플리케이션 시작

## 기본 사용법

기본적인 Container 패턴은 모듈을 생성하고, 컨테이너에 수집하고, 병렬로 빌드하는 것입니다.

**목적**: 모듈식 접근 방식을 사용하여 여러 관련 의존성을 효율적으로 생성하고 등록합니다.

**작동 방식**:
- **모듈 생성**: 각 의존성이 팩토리 클로저와 함께 Module에 래핑됩니다
- **수집**: 모듈이 즉시 등록되지 않고 컨테이너에 추가됩니다
- **병렬 빌드**: 모든 모듈이 최적 성능을 위해 동시에 등록됩니다

```swift
// 각 의존성에 대한 개별 모듈 생성
let repoModule = Module(RepositoryProtocol.self) {
    DefaultRepository()
}

let useCaseModule = Module(UseCaseProtocol.self) {
    DefaultUseCase(repo: DefaultRepository())
}

// 컨테이너 생성 및 모듈 수집
let container = Container()
container.register(repoModule)      // 수집됨, 아직 등록되지 않음
container.register(useCaseModule)   // 수집됨, 아직 등록되지 않음

// 모든 모듈을 병렬로 빌드 - 실제 등록이 일어나는 곳
await container.build()
```

**`build()` 중 일어나는 일**:
1. **병렬 실행**: 수집된 모든 모듈이 동시에 처리됩니다
2. **의존성 해결**: 팩토리 클로저가 실행되어 인스턴스를 생성합니다
3. **등록**: 의존성이 전역 DI 컨테이너에 등록됩니다
4. **최적화**: 배치 작업을 통해 Actor hop이 최소화됩니다

**모범 사례**:
- 관련 의존성을 모듈로 그룹화하세요
- 더 나은 디버깅을 위해 설명적인 모듈 이름을 사용하세요
- 모든 모듈을 수집한 후 항상 `build()`를 호출하세요
- 많은 의존성이 있는 복잡한 애플리케이션에서는 이 패턴을 선호하세요

## 팩토리와 함께 사용

모듈 팩토리는 복잡한 의존성 계층을 가진 대형 애플리케이션에 완벽한 프로그래매틱 방식으로 여러 관련 모듈을 생성하는 확장 가능한 방법을 제공합니다.

**목적**: 팩토리 패턴을 사용하여 대량의 관련 모듈 세트를 효율적으로 생성하고 등록합니다.

**팩토리 패턴의 장점**:
- **확장성**: 수동 등록 없이 수백 개의 의존성 처리
- **조직**: 도메인이나 계층별로 관련 모듈 그룹화
- **일관성**: 일관된 모듈 생성 패턴 보장
- **유지보수성**: 모듈 생성 로직의 중앙 집중화

```swift
let container = Container()

// 서로 다른 도메인을 위한 특화된 팩토리 생성
let repositoryFactory = RepositoryModuleFactory()
let useCaseFactory = UseCaseModuleFactory()

// 모든 repository 모듈을 생성하고 등록
await repositoryFactory.makeAllModules().asyncForEach { module in
    await container.register(module)
}

// 모든 use case 모듈을 생성하고 등록
await useCaseFactory.makeAllModules().asyncForEach { module in
    await container.register(module)
}

// 수집된 모든 모듈을 병렬로 빌드
await container.build()
```

**팩토리 구현 예제**:

```swift
class RepositoryModuleFactory {
    func makeAllModules() async -> [Module] {
        return [
            Module(UserRepositoryProtocol.self) { UserRepositoryImpl() },
            Module(ProductRepositoryProtocol.self) { ProductRepositoryImpl() },
            Module(OrderRepositoryProtocol.self) { OrderRepositoryImpl() },
            // ... 잠재적으로 수백 개 더
        ]
    }
}

class UseCaseModuleFactory {
    func makeAllModules() async -> [Module] {
        return [
            Module(UserUseCaseProtocol.self) {
                UserUseCaseImpl(repository: UnifiedDI.resolve(UserRepositoryProtocol.self)!)
            },
            Module(ProductUseCaseProtocol.self) {
                ProductUseCaseImpl(repository: UnifiedDI.resolve(ProductRepositoryProtocol.self)!)
            },
            // ... 의존성을 가진 더 많은 use case들
        ]
    }
}
```

**고급 팩토리 패턴**:

```swift
// 조건부 모듈 생성이 있는 팩토리
class PlatformSpecificFactory {
    func makeAllModules() async -> [Module] {
        var modules: [Module] = []

        // 모든 플랫폼을 위한 핵심 모듈
        modules.append(Module(LoggerProtocol.self) { ConsoleLogger() })

        // 플랫폼별 모듈
        #if os(iOS)
        modules.append(Module(LocationServiceProtocol.self) { CoreLocationService() })
        #elseif os(macOS)
        modules.append(Module(LocationServiceProtocol.self) { MacOSLocationService() })
        #endif

        return modules
    }
}

// 동적 모듈 생성이 있는 팩토리
class DatabaseFactory {
    let configurations: [DatabaseConfig]

    func makeAllModules() async -> [Module] {
        return configurations.map { config in
            Module(DatabaseProtocol.self, identifier: config.name) {
                DatabaseImpl(config: config)
            }
        }
    }
}
```

## 조건부 등록

조건부 등록을 사용하면 런타임 조건, 빌드 구성 또는 기능 플래그를 기반으로 등록할 모듈을 동적으로 선택할 수 있습니다.

**목적**: 환경, 구성 또는 런타임 조건에 따라 서로 다른 의존성 세트를 등록합니다.

**일반적인 사용 사례**:
- **Debug vs Release**: 개발과 프로덕션용 서로 다른 구현
- **기능 플래그**: 원격 구성에 따른 기능 활성화/비활성화
- **환경별**: 서로 다른 배포 환경을 위한 서로 다른 서비스
- **A/B 테스트**: 테스트 목적을 위한 서로 다른 구현

```swift
let container = Container()

// 환경 기반 조건부 등록
#if DEBUG
container.register(debugModule)        // 개발용 모킹 서비스
container.register(loggingModule)      // 디버깅용 상세 로깅
#else
container.register(prodModule)         // 프로덕션 구현
container.register(analyticsModule)    // 프로덕션에서만 분석
#endif

await container.build()
```

**고급 조건부 예제**:

```swift
let container = Container()

// 기능 플래그 기반 등록
if FeatureFlags.isNewPaymentSystemEnabled {
    container.register(Module(PaymentServiceProtocol.self) {
        NewPaymentService()
    })
} else {
    container.register(Module(PaymentServiceProtocol.self) {
        LegacyPaymentService()
    })
}

// 환경별 등록
switch AppEnvironment.current {
case .development:
    container.register(Module(APIClientProtocol.self) {
        MockAPIClient()
    })

case .staging:
    container.register(Module(APIClientProtocol.self) {
        StagingAPIClient()
    })

case .production:
    container.register(Module(APIClientProtocol.self) {
        ProductionAPIClient()
    })
}

// 기기별 등록
if UIDevice.current.userInterfaceIdiom == .pad {
    container.register(Module(LayoutServiceProtocol.self) {
        iPadLayoutService()
    })
} else {
    container.register(Module(LayoutServiceProtocol.self) {
        iPhoneLayoutService()
    })
}

await container.build()
```

## 성능 최적화

Container 사용은 애플리케이션 시작 시간과 메모리 사용량을 크게 향상시킬 수 있는 여러 최적화 기회를 제공합니다.

**최적화 전략**:

### 1. 배치 등록
```swift
// ✅ 효율적: 모든 모듈을 배치하고 한 번에 빌드
let container = Container()
container.register(moduleA)
container.register(moduleB)
container.register(moduleC)
await container.build() // 단일 병렬 작업

// ❌ 비효율적: 개별 등록
await WeaveDI.Container.bootstrap { container in
    container.register(TypeA.self) { /* ... */ }
    container.register(TypeB.self) { /* ... */ }
    // 각 등록이 별도
}
```

### 2. 지연 모듈 생성
```swift
// 필요할 때만 모듈 생성
class LazyModuleFactory {
    private var _modules: [Module]?

    func makeAllModules() async -> [Module] {
        if _modules == nil {
            _modules = await createExpensiveModules()
        }
        return _modules!
    }

    private func createExpensiveModules() async -> [Module] {
        // 비용이 많이 드는 모듈 생성 로직
        return [/* modules */]
    }
}
```

### 3. 메모리 관리
```swift
let container = Container()

// 모듈 등록
await factory.makeAllModules().asyncForEach { module in
    await container.register(module)
}

// 빌드하고 나서 메모리 해제를 위해 컨테이너 정리
await container.build()
container.clear() // 메모리에서 수집된 모듈 해제
```

## 오류 처리

컨테이너 사용에서의 적절한 오류 처리는 견고한 애플리케이션 시작과 명확한 디버깅 정보를 보장합니다.

```swift
func setupDependencies() async throws {
    let container = Container()

    do {
        // 잠재적 실패가 있는 모듈 수집
        let repositoryModules = try await RepositoryFactory().makeAllModules()
        let useCaseModules = try await UseCaseFactory().makeAllModules()

        // 모든 모듈 등록
        repositoryModules.forEach { container.register($0) }
        useCaseModules.forEach { container.register($0) }

        // 오류 처리와 함께 빌드
        try await container.build()

        print("✅ 모든 의존성이 성공적으로 등록되었습니다")

    } catch let error as ModuleCreationError {
        print("❌ 모듈 생성 실패: \(error.localizedDescription)")
        throw error

    } catch let error as DependencyResolutionError {
        print("❌ 의존성 해결 실패: \(error.localizedDescription)")
        throw error

    } catch {
        print("❌ 컨테이너 설정 중 예상치 못한 오류: \(error)")
        throw error
    }
}
```

## 모범 사례

### 1. 모듈 조직화
```swift
// ✅ 도메인별로 관련 모듈 그룹화
let userModules = UserModuleFactory().makeAllModules()
let paymentModules = PaymentModuleFactory().makeAllModules()
let analyticsModules = AnalyticsModuleFactory().makeAllModules()

// ✅ 명확한 모듈 네이밍
let coreModule = Module(LoggerProtocol.self, name: "CoreLogger") { ConsoleLogger() }
let networkModule = Module(HTTPClientProtocol.self, name: "NetworkClient") { URLSessionClient() }
```

### 2. 의존성 순서
```swift
let container = Container()

// 논리적 의존성 순서로 등록 (인프라부터)
container.register(loggerModule)      // 의존성 없음
container.register(networkModule)     // logger가 필요할 수 있음
container.register(repositoryModule)  // network 필요
container.register(useCaseModule)     // repository 필요

await container.build()
```

### 3. 리소스 관리
```swift
func setupApplication() async {
    let container = Container()

    // 설정
    await populateContainer(container)
    await container.build()

    // 정리
    container.clear() // 빌드 후 메모리 해제
}
```

## 참고

- [모듈 시스템](./moduleSystem.md) - 상세한 모듈 생성 및 관리
- [모듈 팩토리](./moduleFactory.md) - 고급 팩토리 패턴
- [부트스트랩 가이드](./bootstrap.md) - 대안 등록 접근 방식