import Foundation
import DiContainer

// MARK: - RepositoryModuleFactory Extension

extension RepositoryModuleFactory {
    /// Repository 계층의 기본 모듈들을 정의합니다
    public mutating func registerDefaultDefinitions() {
        let register = registerModule

        definitions = {
            return [
                // Counter Repository
                register.counterRepositoryModule,
                // 추가 Repository들...
                register.userRepositoryModule,
                register.productRepositoryModule,
            ]
        }()
    }
}

// MARK: - UseCaseModuleFactory Extension

extension UseCaseModuleFactory {
    /// UseCase 계층의 기본 모듈들을 정의합니다
    public mutating func registerDefaultDefinitions() {
        let register = registerModule

        definitions = {
            return [
                // Counter UseCase
                register.counterUseCaseModule,
                // 추가 UseCase들...
                register.userUseCaseModule,
                register.productUseCaseModule,
            ]
        }()
    }
}

// MARK: - RegisterModule Extensions

extension RegisterModule {
    /// CounterRepository 모듈
    var counterRepositoryModule: () -> Module {
        makeDependencyImproved(CounterRepository.self) {
            UserDefaultsCounterRepository()
        }
    }

    /// CounterUseCase 모듈 (Repository 의존성 자동 주입)
    var counterUseCaseModule: () -> Module {
        makeUseCaseWithRepository(
            CounterUseCase.self,
            repositoryProtocol: CounterRepository.self,
            repositoryFallback: UserDefaultsCounterRepository(),
            factory: { repository in
                // UseCase 내부에서 @Inject로 의존성 주입받으므로
                // 여기서는 기본 생성만 하면 됨
                DefaultCounterUseCase()
            }
        )
    }

    // MARK: - 추가 실무 모듈들 예시

    /// UserRepository 모듈
    var userRepositoryModule: () -> Module {
        makeDependencyImproved("UserRepository") {
            // 실제 구현체로 교체 필요
            MockUserRepository()
        }
    }

    /// UserUseCase 모듈
    var userUseCaseModule: () -> Module {
        makeDependency("UserUseCase") {
            MockUserUseCase()
        }
    }

    /// ProductRepository 모듈
    var productRepositoryModule: () -> Module {
        makeDependencyImproved("ProductRepository") {
            MockProductRepository()
        }
    }

    /// ProductUseCase 모듈
    var productUseCaseModule: () -> Module {
        makeUseCaseWithRepository(
            "ProductUseCase",
            repositoryProtocol: "ProductRepository",
            repositoryFallback: MockProductRepository(),
            factory: { repository in
                MockProductUseCase(repository: repository)
            }
        )
    }
}

// MARK: - Mock Implementations (실제 프로젝트에서는 제거)

private final class MockUserRepository: Sendable {}
private final class MockUserUseCase: Sendable {}
private final class MockProductRepository: Sendable {}
private final class MockProductUseCase: Sendable {
    init(repository: Any) {}
}