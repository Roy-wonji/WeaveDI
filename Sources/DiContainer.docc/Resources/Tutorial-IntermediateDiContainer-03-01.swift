import Foundation
import DiContainer
import LogMacro

// MARK: - 스코프 기반 의존성 관리

/// 애플리케이션의 다양한 스코프(범위)에 따라 의존성의 생명주기를 관리하는
/// 고급 스코프 관리 시스템을 구현합니다.

// MARK: - 스코프 정의

enum DependencyScope: String, Sendable {
    case singleton = "singleton"         // 앱 전체 생명주기
    case session = "session"            // 사용자 세션 생명주기
    case screen = "screen"              // 화면 생명주기
    case request = "request"            // 요청별 생명주기
    case transient = "transient"        // 매번 새로운 인스턴스

    var displayName: String {
        switch self {
        case .singleton: return "싱글톤"
        case .session: return "세션"
        case .screen: return "화면"
        case .request: return "요청"
        case .transient: return "임시"
        }
    }
}

// MARK: - 스코프 관리자

/// 다양한 스코프의 인스턴스들을 관리합니다
final class ScopeManager: @unchecked Sendable {
    private let queue = DispatchQueue(label: "ScopeManager", attributes: .concurrent)

    // 스코프별 인스턴스 저장소
    private var _singletonInstances: [String: Any] = [:]
    private var _sessionInstances: [String: [String: Any]] = [:]
    private var _screenInstances: [String: [String: Any]] = [:]
    private var _requestInstances: [String: [String: Any]] = [:]

    // 현재 활성 스코프들
    private var _currentSessionId: String?
    private var _currentScreenId: String?
    private var _currentRequestId: String?

    /// 싱글톤 인스턴스를 저장하거나 가져옵니다
    func getSingletonInstance<T>(key: String, factory: () -> T) -> T {
        return queue.sync {
            if let existing = _singletonInstances[key] as? T {
                return existing
            }

            let newInstance = factory()
            _singletonInstances[key] = newInstance
            #logInfo("🔄 [Singleton] 인스턴스 생성: \(key)")
            return newInstance
        }
    }

    /// 세션 스코프 인스턴스를 관리합니다
    func getSessionInstance<T>(key: String, sessionId: String, factory: () -> T) -> T {
        return queue.sync {
            if _sessionInstances[sessionId] == nil {
                _sessionInstances[sessionId] = [:]
            }

            if let existing = _sessionInstances[sessionId]?[key] as? T {
                return existing
            }

            let newInstance = factory()
            _sessionInstances[sessionId]?[key] = newInstance
            #logInfo("👤 [Session:\(sessionId)] 인스턴스 생성: \(key)")
            return newInstance
        }
    }

    /// 화면 스코프 인스턴스를 관리합니다
    func getScreenInstance<T>(key: String, screenId: String, factory: () -> T) -> T {
        return queue.sync {
            if _screenInstances[screenId] == nil {
                _screenInstances[screenId] = [:]
            }

            if let existing = _screenInstances[screenId]?[key] as? T {
                return existing
            }

            let newInstance = factory()
            _screenInstances[screenId]?[key] = newInstance
            #logInfo("📱 [Screen:\(screenId)] 인스턴스 생성: \(key)")
            return newInstance
        }
    }

    /// 요청 스코프 인스턴스를 관리합니다
    func getRequestInstance<T>(key: String, requestId: String, factory: () -> T) -> T {
        return queue.sync {
            if _requestInstances[requestId] == nil {
                _requestInstances[requestId] = [:]
            }

            if let existing = _requestInstances[requestId]?[key] as? T {
                return existing
            }

            let newInstance = factory()
            _requestInstances[requestId]?[key] = newInstance
            #logInfo("🌐 [Request:\(requestId)] 인스턴스 생성: \(key)")
            return newInstance
        }
    }

    /// 세션 스코프를 시작합니다
    func beginSession(sessionId: String) {
        queue.async(flags: .barrier) {
            self._currentSessionId = sessionId
            self._sessionInstances[sessionId] = [:]
            #logInfo("🎬 세션 시작: \(sessionId)")
        }
    }

    /// 화면 스코프를 시작합니다
    func beginScreen(screenId: String) {
        queue.async(flags: .barrier) {
            self._currentScreenId = screenId
            self._screenInstances[screenId] = [:]
            #logInfo("📱 화면 시작: \(screenId)")
        }
    }

    /// 요청 스코프를 시작합니다
    func beginRequest(requestId: String) {
        queue.async(flags: .barrier) {
            self._currentRequestId = requestId
            self._requestInstances[requestId] = [:]
            #logInfo("🌐 요청 시작: \(requestId)")
        }
    }

    /// 세션을 종료하고 관련 인스턴스들을 정리합니다
    func endSession(sessionId: String) {
        queue.async(flags: .barrier) {
            if let instances = self._sessionInstances[sessionId] {
                #logInfo("🧹 세션 정리: \(sessionId) (\(instances.count)개 인스턴스)")
                self._sessionInstances.removeValue(forKey: sessionId)
            }

            if self._currentSessionId == sessionId {
                self._currentSessionId = nil
            }
        }
    }

    /// 화면을 종료하고 관련 인스턴스들을 정리합니다
    func endScreen(screenId: String) {
        queue.async(flags: .barrier) {
            if let instances = self._screenInstances[screenId] {
                #logInfo("🧹 화면 정리: \(screenId) (\(instances.count)개 인스턴스)")

                // Disposable 인스턴스들 정리
                for (_, instance) in instances {
                    if let disposable = instance as? Disposable {
                        disposable.dispose()
                    }
                }

                self._screenInstances.removeValue(forKey: screenId)
            }

            if self._currentScreenId == screenId {
                self._currentScreenId = nil
            }
        }
    }

    /// 요청을 종료하고 관련 인스턴스들을 정리합니다
    func endRequest(requestId: String) {
        queue.async(flags: .barrier) {
            if let instances = self._requestInstances[requestId] {
                #logInfo("🧹 요청 정리: \(requestId) (\(instances.count)개 인스턴스)")
                self._requestInstances.removeValue(forKey: requestId)
            }

            if self._currentRequestId == requestId {
                self._currentRequestId = nil
            }
        }
    }

    /// 현재 스코프 정보를 반환합니다
    func getCurrentScopeInfo() -> ScopeInfo {
        return queue.sync {
            ScopeInfo(
                currentSessionId: _currentSessionId,
                currentScreenId: _currentScreenId,
                currentRequestId: _currentRequestId,
                singletonCount: _singletonInstances.count,
                sessionCount: _sessionInstances.count,
                screenCount: _screenInstances.count,
                requestCount: _requestInstances.count
            )
        }
    }
}

struct ScopeInfo {
    let currentSessionId: String?
    let currentScreenId: String?
    let currentRequestId: String?
    let singletonCount: Int
    let sessionCount: Int
    let screenCount: Int
    let requestCount: Int
}

/// 리소스 정리가 필요한 객체를 위한 프로토콜
protocol Disposable {
    func dispose()
}

// MARK: - 스코프별 서비스 예제

// MARK: 싱글톤 서비스 (앱 전체 생명주기)

final class ConfigurationService: @unchecked Sendable {
    private var _settings: [String: Any] = [:]
    private let queue = DispatchQueue(label: "ConfigurationService", attributes: .concurrent)

    init() {
        #logInfo("⚙️ [Singleton] ConfigurationService 초기화")
        loadDefaultSettings()
    }

    private func loadDefaultSettings() {
        queue.async(flags: .barrier) {
            self._settings = [
                "api_timeout": 30.0,
                "max_retries": 3,
                "cache_enabled": true
            ]
        }
    }

    func getSetting<T>(key: String) -> T? {
        return queue.sync {
            return _settings[key] as? T
        }
    }

    func setSetting<T>(key: String, value: T) {
        queue.async(flags: .barrier) {
            self._settings[key] = value
        }
    }
}

// MARK: 세션 스코프 서비스 (사용자 로그인 ~ 로그아웃)

final class UserSessionService: @unchecked Sendable {
    private var _userId: String?
    private var _loginTime: Date?
    private let queue = DispatchQueue(label: "UserSessionService", attributes: .concurrent)

    init(userId: String) {
        self._userId = userId
        self._loginTime = Date()
        #logInfo("👤 [Session] UserSessionService 초기화: \(userId)")
    }

    var userId: String? {
        queue.sync { _userId }
    }

    var sessionDuration: TimeInterval? {
        queue.sync {
            guard let loginTime = _loginTime else { return nil }
            return Date().timeIntervalSince(loginTime)
        }
    }

    func logout() {
        queue.async(flags: .barrier) {
            #logInfo("👋 [Session] 사용자 로그아웃: \(self._userId ?? "unknown")")
            self._userId = nil
            self._loginTime = nil
        }
    }
}

// MARK: 화면 스코프 서비스 (화면 생성 ~ 종료)

final class ScreenAnalyticsService: Disposable {
    private let screenName: String
    private let startTime: Date

    init(screenName: String) {
        self.screenName = screenName
        self.startTime = Date()
        #logInfo("📊 [Screen] ScreenAnalyticsService 시작: \(screenName)")
    }

    func trackEvent(name: String, parameters: [String: Any] = [:]) {
        #logInfo("📈 [Screen:\(screenName)] 이벤트 추적: \(name)")
    }

    func dispose() {
        let duration = Date().timeIntervalSince(startTime)
        #logInfo("📊 [Screen] ScreenAnalyticsService 종료: \(screenName) (지속시간: \(String(format: "%.1f", duration))초)")
    }
}

// MARK: 요청 스코프 서비스 (API 요청 시작 ~ 완료)

final class RequestContextService {
    private let requestId: String
    private let startTime: Date
    private var metadata: [String: Any] = [:]

    init(requestId: String) {
        self.requestId = requestId
        self.startTime = Date()
        #logInfo("🌐 [Request] RequestContextService 시작: \(requestId)")
    }

    func setMetadata(key: String, value: Any) {
        metadata[key] = value
        #logInfo("📝 [Request:\(requestId)] 메타데이터 설정: \(key)")
    }

    func getMetadata(key: String) -> Any? {
        return metadata[key]
    }

    deinit {
        let duration = Date().timeIntervalSince(startTime)
        #logInfo("🌐 [Request] RequestContextService 종료: \(requestId) (지속시간: \(String(format: "%.3f", duration))초)")
    }
}

// MARK: - 스코프 인식 DI 컨테이너 확장

extension DIContainer {
    private static var scopeManagerKey = "ScopeManager"

    /// 스코프 관리자를 설정합니다
    func setupScopeManagement() {
        let scopeManager = ScopeManager()
        registerSingleton(ScopeManager.self) { scopeManager }

        #logInfo("🔧 스코프 관리 시스템 설정 완료")
    }

    /// 스코프에 따른 인스턴스 해결
    func resolveScoped<T>(_ type: T.Type, scope: DependencyScope, scopeId: String? = nil) -> T? {
        let scopeManager: ScopeManager = resolve()
        let key = String(describing: type)

        switch scope {
        case .singleton:
            return scopeManager.getSingletonInstance(key: key) {
                createInstance(type)
            }

        case .session:
            guard let sessionId = scopeId ?? getCurrentSessionId() else {
                #logWarning("⚠️ 세션 ID가 없어서 인스턴스를 생성할 수 없습니다")
                return nil
            }
            return scopeManager.getSessionInstance(key: key, sessionId: sessionId) {
                createInstance(type)
            }

        case .screen:
            guard let screenId = scopeId ?? getCurrentScreenId() else {
                #logWarning("⚠️ 화면 ID가 없어서 인스턴스를 생성할 수 없습니다")
                return nil
            }
            return scopeManager.getScreenInstance(key: key, screenId: screenId) {
                createInstance(type)
            }

        case .request:
            guard let requestId = scopeId ?? getCurrentRequestId() else {
                #logWarning("⚠️ 요청 ID가 없어서 인스턴스를 생성할 수 없습니다")
                return nil
            }
            return scopeManager.getRequestInstance(key: key, requestId: requestId) {
                createInstance(type)
            }

        case .transient:
            return createInstance(type)
        }
    }

    private func createInstance<T>(_ type: T.Type) -> T {
        // 실제 구현에서는 등록된 팩토리를 사용
        // 여기서는 예제를 위해 간단한 생성 로직
        if type == ConfigurationService.self {
            return ConfigurationService() as! T
        } else if type == UserSessionService.self {
            return UserSessionService(userId: "demo_user") as! T
        } else if type == ScreenAnalyticsService.self {
            return ScreenAnalyticsService(screenName: "demo_screen") as! T
        } else if type == RequestContextService.self {
            return RequestContextService(requestId: UUID().uuidString) as! T
        }

        fatalError("타입 \(type)에 대한 팩토리가 등록되지 않았습니다")
    }

    // 현재 스코프 ID들을 가져오는 헬퍼 메서드들
    private func getCurrentSessionId() -> String? {
        let scopeManager: ScopeManager = resolve()
        return scopeManager.getCurrentScopeInfo().currentSessionId
    }

    private func getCurrentScreenId() -> String? {
        let scopeManager: ScopeManager = resolve()
        return scopeManager.getCurrentScopeInfo().currentScreenId
    }

    private func getCurrentRequestId() -> String? {
        let scopeManager: ScopeManager = resolve()
        return scopeManager.getCurrentScopeInfo().currentRequestId
    }

    /// 세션을 시작합니다
    func beginSession(sessionId: String) {
        let scopeManager: ScopeManager = resolve()
        scopeManager.beginSession(sessionId: sessionId)
    }

    /// 화면을 시작합니다
    func beginScreen(screenId: String) {
        let scopeManager: ScopeManager = resolve()
        scopeManager.beginScreen(screenId: screenId)
    }

    /// 요청을 시작합니다
    func beginRequest(requestId: String) {
        let scopeManager: ScopeManager = resolve()
        scopeManager.beginRequest(requestId: requestId)
    }

    /// 세션을 종료합니다
    func endSession(sessionId: String) {
        let scopeManager: ScopeManager = resolve()
        scopeManager.endSession(sessionId: sessionId)
    }

    /// 화면을 종료합니다
    func endScreen(screenId: String) {
        let scopeManager: ScopeManager = resolve()
        scopeManager.endScreen(screenId: screenId)
    }

    /// 요청을 종료합니다
    func endRequest(requestId: String) {
        let scopeManager: ScopeManager = resolve()
        scopeManager.endRequest(requestId: requestId)
    }
}

// MARK: - 스코프 사용 예제

final class ScopedDependencyDemo {
    private let container = DIContainer()

    init() {
        container.setupScopeManagement()
    }

    /// 스코프별 의존성 사용을 데모합니다
    func demonstrateScopedDependencies() async {
        #logInfo("🎬 스코프 기반 의존성 데모 시작")

        // 1. 싱글톤 테스트
        await testSingletonScope()

        // 2. 세션 스코프 테스트
        await testSessionScope()

        // 3. 화면 스코프 테스트
        await testScreenScope()

        // 4. 요청 스코프 테스트
        await testRequestScope()

        // 5. 스코프 정보 확인
        showScopeInfo()

        #logInfo("🎉 스코프 기반 의존성 데모 완료")
    }

    private func testSingletonScope() async {
        #logInfo("\n1️⃣ 싱글톤 스코프 테스트")

        let config1 = container.resolveScoped(ConfigurationService.self, scope: .singleton)
        let config2 = container.resolveScoped(ConfigurationService.self, scope: .singleton)

        #logInfo("동일한 인스턴스인가? \(config1 === config2)")
    }

    private func testSessionScope() async {
        #logInfo("\n2️⃣ 세션 스코프 테스트")

        // 첫 번째 세션
        container.beginSession(sessionId: "session_1")
        let session1_a = container.resolveScoped(UserSessionService.self, scope: .session)
        let session1_b = container.resolveScoped(UserSessionService.self, scope: .session)
        #logInfo("세션1 - 동일한 인스턴스인가? \(session1_a === session1_b)")

        // 두 번째 세션
        container.beginSession(sessionId: "session_2")
        let session2 = container.resolveScoped(UserSessionService.self, scope: .session)
        #logInfo("세션1과 세션2는 다른 인스턴스인가? \(session1_a !== session2)")

        // 첫 번째 세션 종료
        container.endSession(sessionId: "session_1")
        container.endSession(sessionId: "session_2")
    }

    private func testScreenScope() async {
        #logInfo("\n3️⃣ 화면 스코프 테스트")

        container.beginScreen(screenId: "home_screen")
        let homeAnalytics = container.resolveScoped(ScreenAnalyticsService.self, scope: .screen)
        homeAnalytics?.trackEvent(name: "screen_viewed")

        container.beginScreen(screenId: "profile_screen")
        let profileAnalytics = container.resolveScoped(ScreenAnalyticsService.self, scope: .screen)
        profileAnalytics?.trackEvent(name: "profile_viewed")

        // 화면들 종료 (Disposable 정리됨)
        container.endScreen(screenId: "home_screen")
        container.endScreen(screenId: "profile_screen")
    }

    private func testRequestScope() async {
        #logInfo("\n4️⃣ 요청 스코프 테스트")

        // 동시에 여러 요청 처리
        await withTaskGroup(of: Void.self) { group in
            for i in 1...3 {
                group.addTask {
                    let requestId = "request_\(i)"
                    self.container.beginRequest(requestId: requestId)

                    let requestContext = self.container.resolveScoped(
                        RequestContextService.self,
                        scope: .request
                    )
                    requestContext?.setMetadata(key: "request_number", value: i)

                    // 요청 처리 시뮬레이션
                    try? await Task.sleep(nanoseconds: UInt64(i * 100_000_000))

                    self.container.endRequest(requestId: requestId)
                }
            }
        }
    }

    private func showScopeInfo() {
        #logInfo("\n📊 현재 스코프 정보")
        let scopeManager: ScopeManager = container.resolve()
        let info = scopeManager.getCurrentScopeInfo()

        #logInfo("- 현재 세션: \(info.currentSessionId ?? "없음")")
        #logInfo("- 현재 화면: \(info.currentScreenId ?? "없음")")
        #logInfo("- 현재 요청: \(info.currentRequestId ?? "없음")")
        #logInfo("- 싱글톤 개수: \(info.singletonCount)")
        #logInfo("- 세션 개수: \(info.sessionCount)")
        #logInfo("- 화면 개수: \(info.screenCount)")
        #logInfo("- 요청 개수: \(info.requestCount)")
    }
}

// MARK: - 스코프 기반 의존성 관리 데모

enum ScopedDependencyExample {
    static func demonstrateScopedDependencies() async {
        #logInfo("🎬 스코프 기반 의존성 관리 데모 시작")

        let demo = ScopedDependencyDemo()
        await demo.demonstrateScopedDependencies()

        #logInfo("🎉 스코프 기반 의존성 관리 데모 완료")
    }
}