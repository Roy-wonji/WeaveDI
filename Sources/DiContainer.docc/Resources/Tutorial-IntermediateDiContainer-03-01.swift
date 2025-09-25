import Foundation
import DiContainer
import LogMacro

// MARK: - Custom Scope Definition

/// 커스텀 스코프를 정의하고 구현하는 시스템
/// Singleton, Transient 외에 Session, Request, View 스코프를 만들어봅니다

// MARK: - Scope Types

enum CustomScope: String, Sendable, CaseIterable {
    case singleton = "singleton"      // 앱 생명주기 동안 유지
    case transient = "transient"      // 매번 새로운 인스턴스
    case session = "session"          // 사용자 세션 동안 유지
    case request = "request"          // HTTP 요청 동안 유지
    case view = "view"               // 뷰 생명주기 동안 유지
    case thread = "thread"           // 스레드별로 유지

    var description: String {
        switch self {
        case .singleton:
            return "싱글톤 - 앱 전체에서 하나의 인스턴스"
        case .transient:
            return "일시적 - 매번 새로운 인스턴스 생성"
        case .session:
            return "세션 스코프 - 사용자 세션 동안 유지"
        case .request:
            return "요청 스코프 - HTTP 요청 처리 동안 유지"
        case .view:
            return "뷰 스코프 - 뷰 생명주기 동안 유지"
        case .thread:
            return "스레드 스코프 - 스레드별로 독립적 인스턴스"
        }
    }
}

// MARK: - Scope Manager

/// 커스텀 스코프를 관리하는 매니저
final class CustomScopeManager: @unchecked Sendable {
    static let shared = CustomScopeManager()

    private let accessQueue = DispatchQueue(label: "CustomScopeManager.access", attributes: .concurrent)

    // 스코프별 인스턴스 저장소
    private var _singletonInstances: [String: Any] = [:]
    private var _sessionInstances: [String: Any] = [:]
    private var _requestInstances: [String: [String: Any]] = [:] // requestId -> instances
    private var _viewInstances: [String: [String: Any]] = [:] // viewId -> instances
    private var _threadInstances: [String: Any] = [:]

    // 현재 컨텍스트 정보
    private var _currentSessionId: String?
    private var _currentRequestId: String?
    private var _currentViewId: String?

    private init() {}

    /// 스코프에 따라 인스턴스를 해결합니다
    func resolve<T>(_ type: T.Type, scope: CustomScope, factory: () -> T) -> T {
        let key = String(describing: type)

        return accessQueue.sync {
            switch scope {
            case .singleton:
                return resolveSingleton(key: key, factory: factory)

            case .transient:
                let instance = factory()
                #logInfo("🔄 [Scope] Transient 인스턴스 생성: \(key)")
                return instance

            case .session:
                return resolveSession(key: key, factory: factory)

            case .request:
                return resolveRequest(key: key, factory: factory)

            case .view:
                return resolveView(key: key, factory: factory)

            case .thread:
                return resolveThread(key: key, factory: factory)
            }
        }
    }

    // MARK: - Private Scope Resolution Methods

    private func resolveSingleton<T>(key: String, factory: () -> T) -> T {
        if let existing = _singletonInstances[key] as? T {
            #logInfo("♻️ [Scope] Singleton 재사용: \(key)")
            return existing
        }

        let instance = factory()
        _singletonInstances[key] = instance
        #logInfo("✨ [Scope] Singleton 생성: \(key)")
        return instance
    }

    private func resolveSession<T>(key: String, factory: () -> T) -> T {
        guard let sessionId = _currentSessionId else {
            // 세션이 없으면 임시 세션 생성
            let tempSessionId = "temp_\(UUID().uuidString.prefix(8))"
            setCurrentSession(id: tempSessionId)
            #logInfo("⚠️ [Scope] 임시 세션 생성: \(tempSessionId)")
            return resolveSession(key: key, factory: factory)
        }

        let sessionKey = "\(sessionId)_\(key)"

        if let existing = _sessionInstances[sessionKey] as? T {
            #logInfo("♻️ [Scope] Session 재사용: \(key) (세션: \(sessionId))")
            return existing
        }

        let instance = factory()
        _sessionInstances[sessionKey] = instance
        #logInfo("✨ [Scope] Session 생성: \(key) (세션: \(sessionId))")
        return instance
    }

    private func resolveRequest<T>(key: String, factory: () -> T) -> T {
        guard let requestId = _currentRequestId else {
            // 요청 컨텍스트가 없으면 임시 요청 생성
            let tempRequestId = "temp_\(UUID().uuidString.prefix(8))"
            setCurrentRequest(id: tempRequestId)
            #logInfo("⚠️ [Scope] 임시 요청 생성: \(tempRequestId)")
            return resolveRequest(key: key, factory: factory)
        }

        if _requestInstances[requestId] == nil {
            _requestInstances[requestId] = [:]
        }

        if let existing = _requestInstances[requestId]?[key] as? T {
            #logInfo("♻️ [Scope] Request 재사용: \(key) (요청: \(requestId))")
            return existing
        }

        let instance = factory()
        _requestInstances[requestId]?[key] = instance
        #logInfo("✨ [Scope] Request 생성: \(key) (요청: \(requestId))")
        return instance
    }

    private func resolveView<T>(key: String, factory: () -> T) -> T {
        guard let viewId = _currentViewId else {
            // 뷰 컨텍스트가 없으면 임시 뷰 생성
            let tempViewId = "temp_\(UUID().uuidString.prefix(8))"
            setCurrentView(id: tempViewId)
            #logInfo("⚠️ [Scope] 임시 뷰 생성: \(tempViewId)")
            return resolveView(key: key, factory: factory)
        }

        if _viewInstances[viewId] == nil {
            _viewInstances[viewId] = [:]
        }

        if let existing = _viewInstances[viewId]?[key] as? T {
            #logInfo("♻️ [Scope] View 재사용: \(key) (뷰: \(viewId))")
            return existing
        }

        let instance = factory()
        _viewInstances[viewId]?[key] = instance
        #logInfo("✨ [Scope] View 생성: \(key) (뷰: \(viewId))")
        return instance
    }

    private func resolveThread<T>(key: String, factory: () -> T) -> T {
        let threadKey = "\(Thread.current.description)_\(key)"

        if let existing = _threadInstances[threadKey] as? T {
            #logInfo("♻️ [Scope] Thread 재사용: \(key)")
            return existing
        }

        let instance = factory()
        _threadInstances[threadKey] = instance
        #logInfo("✨ [Scope] Thread 생성: \(key)")
        return instance
    }

    // MARK: - Context Management

    func setCurrentSession(id: String) {
        accessQueue.async(flags: .barrier) {
            self._currentSessionId = id
            #logInfo("👤 [Scope] 세션 설정: \(id)")
        }
    }

    func setCurrentRequest(id: String) {
        accessQueue.async(flags: .barrier) {
            self._currentRequestId = id
            #logInfo("📡 [Scope] 요청 설정: \(id)")
        }
    }

    func setCurrentView(id: String) {
        accessQueue.async(flags: .barrier) {
            self._currentViewId = id
            #logInfo("📱 [Scope] 뷰 설정: \(id)")
        }
    }

    func clearSession(id: String) {
        accessQueue.async(flags: .barrier) {
            let keysToRemove = self._sessionInstances.keys.filter { $0.hasPrefix("\(id)_") }
            for key in keysToRemove {
                self._sessionInstances.removeValue(forKey: key)
            }
            if self._currentSessionId == id {
                self._currentSessionId = nil
            }
            #logInfo("🗑️ [Scope] 세션 정리: \(id) (\(keysToRemove.count)개 인스턴스)")
        }
    }

    func clearRequest(id: String) {
        accessQueue.async(flags: .barrier) {
            let removedCount = self._requestInstances.removeValue(forKey: id)?.count ?? 0
            if self._currentRequestId == id {
                self._currentRequestId = nil
            }
            #logInfo("🗑️ [Scope] 요청 정리: \(id) (\(removedCount)개 인스턴스)")
        }
    }

    func clearView(id: String) {
        accessQueue.async(flags: .barrier) {
            let removedCount = self._viewInstances.removeValue(forKey: id)?.count ?? 0
            if self._currentViewId == id {
                self._currentViewId = nil
            }
            #logInfo("🗑️ [Scope] 뷰 정리: \(id) (\(removedCount)개 인스턴스)")
        }
    }

    /// 현재 스코프 상태를 출력합니다
    func printScopeStatus() {
        accessQueue.sync {
            #logInfo("📊 [Scope] 현재 스코프 상태:")
            #logInfo("  • Singleton: \(_singletonInstances.count)개")
            #logInfo("  • Session: \(_sessionInstances.count)개")
            #logInfo("  • Request: \(_requestInstances.values.reduce(0) { $0 + $1.count })개")
            #logInfo("  • View: \(_viewInstances.values.reduce(0) { $0 + $1.count })개")
            #logInfo("  • Thread: \(_threadInstances.count)개")
            #logInfo("  • 현재 세션: \(_currentSessionId ?? "없음")")
            #logInfo("  • 현재 요청: \(_currentRequestId ?? "없음")")
            #logInfo("  • 현재 뷰: \(_currentViewId ?? "없음")")
        }
    }
}

// MARK: - Custom Scoped Property Wrapper

/// 커스텀 스코프를 사용하는 Property Wrapper
@propertyWrapper
struct ScopedInject<T> {
    private let type: T.Type
    private let scope: CustomScope
    private let factory: () -> T
    private var _cachedValue: T?

    var wrappedValue: T {
        mutating get {
            if scope == .transient {
                // Transient는 항상 새로 생성
                return CustomScopeManager.shared.resolve(type, scope: scope, factory: factory)
            }

            if _cachedValue == nil {
                _cachedValue = CustomScopeManager.shared.resolve(type, scope: scope, factory: factory)
            }
            return _cachedValue!
        }
    }

    init(wrappedValue: @autoclosure @escaping () -> T, scope: CustomScope = .singleton) {
        self.type = T.self
        self.scope = scope
        self.factory = wrappedValue
        self._cachedValue = nil
    }
}

// MARK: - Example Services

protocol DataService: Sendable {
    var id: String { get }
    func fetchData() async -> String
}

protocol CacheService: Sendable {
    var id: String { get }
    func get(key: String) -> String?
    func set(key: String, value: String)
}

protocol LoggerService: Sendable {
    var id: String { get }
    func log(message: String)
}

final class DefaultDataService: DataService, @unchecked Sendable {
    let id = UUID().uuidString.prefix(8).description

    func fetchData() async -> String {
        await Task.sleep(nanoseconds: 100_000_000) // 0.1초
        return "데이터 조회 결과 (\(id))"
    }
}

final class DefaultCacheService: CacheService, @unchecked Sendable {
    let id = UUID().uuidString.prefix(8).description
    private let cache = NSMutableDictionary()

    func get(key: String) -> String? {
        return cache[key] as? String
    }

    func set(key: String, value: String) {
        cache[key] = value
    }
}

final class DefaultLoggerService: LoggerService {
    let id = UUID().uuidString.prefix(8).description

    func log(message: String) {
        #logInfo("📝 [Logger \(id)] \(message)")
    }
}

// MARK: - Usage Example

/// 커스텀 스코프 사용 예제
final class CustomScopeExample {
    @ScopedInject(wrappedValue: DefaultDataService(), scope: .singleton)
    var singletonDataService: DataService

    @ScopedInject(wrappedValue: DefaultDataService(), scope: .session)
    var sessionDataService: DataService

    @ScopedInject(wrappedValue: DefaultDataService(), scope: .request)
    var requestDataService: DataService

    @ScopedInject(wrappedValue: DefaultCacheService(), scope: .view)
    var viewCacheService: CacheService

    @ScopedInject(wrappedValue: DefaultLoggerService(), scope: .transient)
    var transientLogger: LoggerService

    func demonstrateCustomScopes() async {
        #logInfo("🎯 [Example] 커스텀 스코프 예제 시작")

        let scopeManager = CustomScopeManager.shared

        // 세션 설정
        scopeManager.setCurrentSession(id: "user_session_123")
        scopeManager.setCurrentRequest(id: "request_456")
        scopeManager.setCurrentView(id: "main_view_789")

        // 각 스코프별 서비스 사용
        await testSingletonScope()
        await testSessionScope()
        await testRequestScope()
        await testViewScope()
        await testTransientScope()

        // 현재 상태 출력
        scopeManager.printScopeStatus()

        // 정리 작업 테스트
        await testScopeCleanup()

        #logInfo("✅ [Example] 커스텀 스코프 예제 완료")
    }

    private func testSingletonScope() async {
        #logInfo("🔸 [Test] Singleton 스코프 테스트")

        let data1 = await singletonDataService.fetchData()
        let data2 = await singletonDataService.fetchData()

        #logInfo("  데이터1: \(data1)")
        #logInfo("  데이터2: \(data2)")
        #logInfo("  ID 동일?: \(singletonDataService.id == singletonDataService.id)")
    }

    private func testSessionScope() async {
        #logInfo("🔸 [Test] Session 스코프 테스트")

        let data1 = await sessionDataService.fetchData()
        let data2 = await sessionDataService.fetchData()

        #logInfo("  세션 데이터1: \(data1)")
        #logInfo("  세션 데이터2: \(data2)")
        #logInfo("  ID 동일?: \(sessionDataService.id == sessionDataService.id)")
    }

    private func testRequestScope() async {
        #logInfo("🔸 [Test] Request 스코프 테스트")

        let data1 = await requestDataService.fetchData()
        let data2 = await requestDataService.fetchData()

        #logInfo("  요청 데이터1: \(data1)")
        #logInfo("  요청 데이터2: \(data2)")
    }

    private func testViewScope() async {
        #logInfo("🔸 [Test] View 스코프 테스트")

        viewCacheService.set(key: "test_key", value: "test_value")
        let cachedValue = viewCacheService.get(key: "test_key")

        #logInfo("  캐시 저장/조회: \(cachedValue ?? "없음")")
        #logInfo("  캐시 서비스 ID: \(viewCacheService.id)")
    }

    private func testTransientScope() async {
        #logInfo("🔸 [Test] Transient 스코프 테스트")

        let logger1 = transientLogger
        let logger2 = transientLogger

        logger1.log("첫 번째 로거 메시지")
        logger2.log("두 번째 로거 메시지")

        #logInfo("  Logger1 ID: \(logger1.id)")
        #logInfo("  Logger2 ID: \(logger2.id)")
        #logInfo("  ID 다름?: \(logger1.id != logger2.id)")
    }

    private func testScopeCleanup() async {
        #logInfo("🔸 [Test] 스코프 정리 테스트")

        let scopeManager = CustomScopeManager.shared

        // 새로운 컨텍스트 생성
        scopeManager.setCurrentSession(id: "temp_session")
        scopeManager.setCurrentRequest(id: "temp_request")
        scopeManager.setCurrentView(id: "temp_view")

        // 임시 서비스들 생성
        let _ = await sessionDataService.fetchData()
        let _ = await requestDataService.fetchData()
        viewCacheService.set(key: "temp", value: "temp_value")

        scopeManager.printScopeStatus()

        // 정리
        scopeManager.clearSession(id: "temp_session")
        scopeManager.clearRequest(id: "temp_request")
        scopeManager.clearView(id: "temp_view")

        #logInfo("🗑️ [Test] 정리 후 상태:")
        scopeManager.printScopeStatus()
    }
}