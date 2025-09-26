import Foundation
import WeaveDI
import LogMacro

// MARK: - AppDIContainer Production Extension

extension AppDIContainer {
    /// 실무 환경에서 사용하는 기본 의존성 등록 방법
    func registerDefaultDependencies() async {
        #logInfo("🚀 [AppDIContainer] 실무 환경 의존성 등록 시작")

        await registerDependencies { container in
            #logInfo("📦 ModuleFactory 패턴으로 의존성 등록 중...")

            // ModuleFactoryManager를 통한 체계적 등록
            var factory = ModuleFactoryManager()

            // 1단계: Factory들에 기본 정의 등록
            factory.registerDefaultDependencies()

            // 2단계: 모든 모듈을 컨테이너에 등록
            await factory.registerAll(to: container)

            // 3단계: 추가 서비스들 등록 (Factory로 관리되지 않는 것들)
            await registerAdditionalServices(container)

            #logInfo("✅ 모든 의존성 등록 완료!")
        }
    }

    /// Factory로 관리되지 않는 추가 서비스들 등록
    private func registerAdditionalServices(_ container: DIContainer) async {
        #logInfo("🔧 추가 서비스들 등록 중...")

        // 기본 서비스들
        container.register(CounterService.self) {
            DefaultCounterService()
        }

        container.register(LoggingService.self) {
            DefaultLoggingService()
        }

        container.register(NetworkService.self) {
            DefaultNetworkService()
        }

        #logInfo("✅ 추가 서비스 등록 완료")
    }
}

// MARK: - AppDIContainer Monitoring Extension

extension AppDIContainer {
    /// 의존성 등록 상태를 모니터링합니다
    func monitorRegistrationStatus() async {
        #logInfo("📊 [AppDIContainer] 등록 상태 모니터링 시작")

        // AutoDIOptimizer를 통한 상태 확인
        let optimizer = AutoDIOptimizer.shared
        await optimizer.showAll()

        let stats = optimizer.getStats()
        #logInfo("📈 등록 통계: 등록된 타입 \(stats.registered)개, 해결 요청 \(stats.resolved)회")

        // 최적화 제안 확인
        let suggestions = optimizer.getOptimizationSuggestions()
        for suggestion in suggestions {
            #logInfo("💡 최적화 제안: \(suggestion)")
        }

        #logInfo("✅ 모니터링 완료")
    }
}

// MARK: - AppDIContainer Health Check Extension

extension AppDIContainer {
    /// 시스템 건강 상태를 확인합니다
    func performHealthCheck() async -> Bool {
        #logInfo("🏥 [AppDIContainer] 시스템 건강 상태 확인 시작")

        // 핵심 의존성들이 올바르게 등록되었는지 확인
        let criticalServices: [Any.Type] = [
            CounterService.self,
            CounterRepository.self,
            CounterUseCase.self,
            LoggingService.self
        ]

        var allHealthy = true
        for serviceType in criticalServices {
            let isRegistered = UnifiedDI.resolve(serviceType) != nil
            if isRegistered {
                #logInfo("✅ \(serviceType) 등록 확인됨")
            } else {
                #logError("❌ \(serviceType) 등록되지 않음!")
                allHealthy = false
            }
        }

        // 시스템 전체 건강 상태 확인
        let optimizer = AutoDIOptimizer.shared
        let systemHealth = await optimizer.getSystemHealth()
        #logInfo("🏥 시스템 상태: \(systemHealth.status.rawValue)")

        let result = allHealthy && systemHealth.status == .healthy
        #logInfo("🎯 전체 건강 상태: \(result ? "양호" : "문제 있음")")

        return result
    }
}

// MARK: - AppDIContainer Debug Extension

extension AppDIContainer {
    /// 디버그 정보를 출력합니다
    func printDebugInfo() async {
        #logInfo("🐛 [AppDIContainer] 디버그 정보 출력")

        let optimizer = AutoDIOptimizer.shared

        // 등록된 타입들
        let registeredTypes = optimizer.getRegisteredTypes()
        #logInfo("📦 등록된 타입들 (\(registeredTypes.count)개):")
        for type in registeredTypes.sorted() {
            #logInfo("  • \(type)")
        }

        // 의존성 관계
        let dependencies = optimizer.getDependencies()
        if !dependencies.isEmpty {
            #logInfo("🔗 의존성 관계들 (\(dependencies.count)개):")
            for dep in dependencies {
                #logInfo("  • \(dep.from) → \(dep.to)")
            }
        }

        // 자주 사용되는 타입들
        let frequentTypes = optimizer.getTopUsedTypes(limit: 5)
        if !frequentTypes.isEmpty {
            #logInfo("🔥 자주 사용되는 타입들:")
            for type in frequentTypes {
                #logInfo("  • \(type)")
            }
        }

        #logInfo("✅ 디버그 정보 출력 완료")
    }
}