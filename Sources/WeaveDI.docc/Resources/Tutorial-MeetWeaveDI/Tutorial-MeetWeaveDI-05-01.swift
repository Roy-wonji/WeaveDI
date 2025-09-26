import Foundation
import WeaveDI
import LogMacro

// MARK: - ModuleFactoryManager

/// 모든 ModuleFactory들을 통합 관리하는 매니저
final class ModuleFactoryManager: Sendable {
    // Factory 인스턴스들
    private var repositoryFactory = RepositoryModuleFactory()
    private var useCaseFactory = UseCaseModuleFactory()

    /// 모든 팩토리에서 기본 정의를 등록합니다
    mutating func registerDefaultDependencies() {
        #logInfo("🏭 [ModuleFactoryManager] 기본 의존성 등록 시작")

        // Repository 계층 먼저 등록
        repositoryFactory.registerDefaultDefinitions()
        #logInfo("✅ Repository Factory 등록 완료")

        // UseCase 계층 등록 (Repository에 의존)
        useCaseFactory.registerDefaultDefinitions()
        #logInfo("✅ UseCase Factory 등록 완료")
    }

    /// 모든 모듈을 컨테이너에 등록합니다
    func registerAll(to container: DIContainer) async {
        #logInfo("📦 [ModuleFactoryManager] 모든 모듈 등록 시작")

        // Repository 모듈들 등록
        let repositoryModules = repositoryFactory.definitions
        for module in repositoryModules {
            await container.register(module())
        }
        #logInfo("✅ Repository 모듈들 등록 완료: \(repositoryModules.count)개")

        // UseCase 모듈들 등록
        let useCaseModules = useCaseFactory.definitions
        for module in useCaseModules {
            await container.register(module())
        }
        #logInfo("✅ UseCase 모듈들 등록 완료: \(useCaseModules.count)개")

        #logInfo("🎯 총 \(repositoryModules.count + useCaseModules.count)개 모듈 등록 완료!")
    }
}