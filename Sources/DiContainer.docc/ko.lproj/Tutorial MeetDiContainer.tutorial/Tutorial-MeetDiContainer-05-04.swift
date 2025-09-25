import Foundation
import UIKit
import DiContainer
import LogMacro

// MARK: - AppDelegate

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        #logInfo("🚀 앱 시작 - DiContainer 초기화 중...")

        // 1단계: AutoDIOptimizer 최적화 활성화
        setupDIOptimizer()

        // 2단계: DIContainer 부트스트랩
        bootstrapDIContainer()

        #logInfo("✅ 앱 초기화 완료!")

        return true
    }
}

// MARK: - Private Setup Methods

private extension AppDelegate {

    /// AutoDIOptimizer 설정
    func setupDIOptimizer() {
        #logInfo("⚡ AutoDIOptimizer 설정 시작...")

        let optimizer = AutoDIOptimizer.shared

        // 최적화 기능 활성화
        optimizer.setOptimizationEnabled(true)
        #logInfo("✅ 최적화 기능 활성화됨")

        // 로그 레벨 설정 (개발/프로덕션에 따라 조정)
        #if DEBUG
        optimizer.setLogLevel(.all)
        #logInfo("🐛 DEBUG 모드: 모든 로그 활성화")
        #else
        optimizer.setLogLevel(.errors)
        #logInfo("🚀 PRODUCTION 모드: 에러만 로깅")
        #endif

        // 성능 모니터링 간격 설정 (선택사항)
        optimizer.setDebounceInterval(ms: 100)

        #logInfo("⚡ AutoDIOptimizer 설정 완료")
    }

    /// DIContainer 부트스트랩
    func bootstrapDIContainer() {
        #logInfo("📦 DIContainer 부트스트랩 시작...")

        // Task 내에서 비동기 초기화
        DIContainer.bootstrapInTask { container in
            #logInfo("🏗️ 의존성 등록 시작...")

            // AppDIContainer를 통한 의존성 등록
            await AppDIContainer.shared.registerDefaultDependencies()

            #logInfo("📊 등록 후 상태 모니터링...")

            // 등록 상태 모니터링
            await AppDIContainer.shared.monitorRegistrationStatus()

            // 건강 상태 확인
            let isHealthy = await AppDIContainer.shared.performHealthCheck()
            if isHealthy {
                #logInfo("💚 시스템 건강 상태: 정상")
            } else {
                #logError("❤️‍🩹 시스템 건강 상태: 문제 발견")
            }

            // 디버그 정보 출력 (DEBUG 모드에서만)
            #if DEBUG
            await AppDIContainer.shared.printDebugInfo()
            #endif

            #logInfo("🎯 DIContainer 부트스트랩 완료!")
        }
    }
}

// MARK: - AppDelegate Lifecycle Extensions

extension AppDelegate {

    func applicationWillResignActive(_ application: UIApplication) {
        #logInfo("📱 앱이 비활성화됨")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        #logInfo("🌙 앱이 백그라운드로 전환됨")

        // 백그라운드에서 불필요한 서비스 정리 (선택사항)
        Task {
            let optimizer = AutoDIOptimizer.shared
            let stats = optimizer.getStats()
            #logInfo("📊 백그라운드 전환 시 통계: \(stats.registered)개 타입, \(stats.resolved)회 해결")
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        #logInfo("🌅 앱이 포그라운드로 복귀됨")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        #logInfo("📱 앱이 활성화됨")

        // 포그라운드 복귀 시 시스템 상태 재확인 (선택사항)
        Task {
            let isHealthy = await AppDIContainer.shared.performHealthCheck()
            if !isHealthy {
                #logError("⚠️ 포그라운드 복귀 후 시스템 상태 이상 감지")
            }
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        #logInfo("🛑 앱 종료 시작")

        // 종료 시 정리 작업
        Task {
            let optimizer = AutoDIOptimizer.shared
            let finalStats = optimizer.getStats()
            #logInfo("📈 최종 통계: \(finalStats.registered)개 타입, \(finalStats.resolved)회 해결")
            #logInfo("👋 DiContainer 정리 완료")
        }
    }
}

// MARK: - AppDelegate Error Handling

extension AppDelegate {

    /// 의존성 관련 에러 처리
    func handleDependencyError(_ error: Error) {
        #logError("🚨 의존성 에러 발생: \(error.localizedDescription)")

        // 에러 복구 시도
        Task {
            #logInfo("🔧 에러 복구 시도 중...")

            // 의존성 재등록 시도
            await AppDIContainer.shared.registerDefaultDependencies()

            let isRecovered = await AppDIContainer.shared.performHealthCheck()
            if isRecovered {
                #logInfo("✅ 에러 복구 성공")
            } else {
                #logError("❌ 에러 복구 실패 - 수동 개입 필요")
            }
        }
    }
}

// MARK: - SceneDelegate (iOS 13+ 앱용)

#if canImport(UIKit)
@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        #logInfo("🎬 Scene 연결됨")

        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = UINavigationController(rootViewController: CounterViewController())
        window?.makeKeyAndVisible()

        #logInfo("🪟 Window 설정 완료")
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        #logInfo("🎬 Scene 연결 해제됨")
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        #logInfo("🎬 Scene 활성화됨")
    }

    func sceneWillResignActive(_ scene: UIScene) {
        #logInfo("🎬 Scene 비활성화됨")
    }
}
#endif

// MARK: - Mock CounterViewController (예시용)

private class CounterViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "DiContainer Counter"
        #logInfo("📱 CounterViewController 로드됨")
    }
}