import Foundation
import DiContainer
import LogMacro

// MARK: - 스코프 정리 및 리소스 관리

/// 스코프가 종료될 때 안전하고 효율적으로 리소스를 정리하는
/// 고급 메모리 관리 및 정리 시스템을 구현합니다.

// MARK: - 리소스 정리 프로토콜들

/// 기본적인 리소스 정리를 위한 프로토콜
protocol Disposable {
    func dispose()
}

/// 비동기 리소스 정리를 위한 프로토콜
protocol AsyncDisposable {
    func dispose() async
}

/// 고급 리소스 정리 정보를 제공하는 프로토콜
protocol AdvancedDisposable: Disposable {
    var disposalPriority: DisposalPriority { get }
    var resourceDescription: String { get }
    func willDispose()
}

enum DisposalPriority: Int, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    static func < (lhs: DisposalPriority, rhs: DisposalPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - 고급 스코프 정리 관리자

final class AdvancedScopeCleanupManager: @unchecked Sendable {
    private let queue = DispatchQueue(label: "AdvancedScopeCleanupManager", attributes: .concurrent)

    // 스코프별 정리 대상 인스턴스들
    private var _scopedDisposables: [String: [WeakDisposableWrapper]] = [:]
    private var _disposalCallbacks: [String: [() -> Void]] = [:]

    /// 스코프에 정리 대상 인스턴스를 등록합니다
    func register<T: AnyObject>(_ instance: T, forScope scopeId: String) {
        queue.async(flags: .barrier) {
            if self._scopedDisposables[scopeId] == nil {
                self._scopedDisposables[scopeId] = []
            }

            let wrapper = WeakDisposableWrapper(instance: instance)
            self._scopedDisposables[scopeId]?.append(wrapper)

            #logInfo("📝 스코프 정리 대상 등록: \(scopeId) - \(type(of: instance))")
        }
    }

    /// 스코프 정리 콜백을 등록합니다
    func registerCleanupCallback(forScope scopeId: String, callback: @escaping () -> Void) {
        queue.async(flags: .barrier) {
            if self._disposalCallbacks[scopeId] == nil {
                self._disposalCallbacks[scopeId] = []
            }
            self._disposalCallbacks[scopeId]?.append(callback)

            #logInfo("🔗 스코프 정리 콜백 등록: \(scopeId)")
        }
    }

    /// 스코프를 정리합니다
    func cleanupScope(_ scopeId: String) async {
        #logInfo("🧹 스코프 정리 시작: \(scopeId)")
        let startTime = Date()

        let (disposables, callbacks) = queue.sync {
            let disposables = _scopedDisposables[scopeId] ?? []
            let callbacks = _disposalCallbacks[scopeId] ?? []

            // 스코프 데이터 제거
            _scopedDisposables.removeValue(forKey: scopeId)
            _disposalCallbacks.removeValue(forKey: scopeId)

            return (disposables, callbacks)
        }

        // 1. Disposable 인스턴스들 정리 (우선순위순)
        await cleanupDisposables(disposables, scopeId: scopeId)

        // 2. 정리 콜백들 실행
        executeCleanupCallbacks(callbacks, scopeId: scopeId)

        let duration = Date().timeIntervalSince(startTime)
        #logInfo("✅ 스코프 정리 완료: \(scopeId) (소요시간: \(String(format: "%.3f", duration))초)")
    }

    private func cleanupDisposables(_ disposables: [WeakDisposableWrapper], scopeId: String) async {
        // 살아있는 인스턴스들만 필터링
        let aliveDisposables = disposables.compactMap { $0.instance }

        guard !aliveDisposables.isEmpty else {
            #logInfo("🗑️ 정리할 인스턴스가 없음: \(scopeId)")
            return
        }

        #logInfo("🗑️ 인스턴스 정리 시작: \(scopeId) (\(aliveDisposables.count)개)")

        // 우선순위별로 그룹핑
        let advancedDisposables = aliveDisposables.compactMap { $0 as? AdvancedDisposable }
        let asyncDisposables = aliveDisposables.compactMap { $0 as? AsyncDisposable }
        let basicDisposables = aliveDisposables.compactMap { $0 as? Disposable }

        // 1. AdvancedDisposable들을 우선순위순으로 정리
        await cleanupAdvancedDisposables(advancedDisposables)

        // 2. AsyncDisposable들을 비동기로 정리
        await cleanupAsyncDisposables(asyncDisposables)

        // 3. 기본 Disposable들을 정리
        cleanupBasicDisposables(basicDisposables)
    }

    private func cleanupAdvancedDisposables(_ disposables: [AdvancedDisposable]) async {
        guard !disposables.isEmpty else { return }

        // 우선순위순으로 정렬 (높은 우선순위부터)
        let sortedDisposables = disposables.sorted { $0.disposalPriority > $1.disposalPriority }

        for disposable in sortedDisposables {
            #logInfo("🔧 고급 정리: \(disposable.resourceDescription) (우선순위: \(disposable.disposalPriority))")

            disposable.willDispose()
            disposable.dispose()

            #logInfo("✅ 고급 정리 완료: \(disposable.resourceDescription)")
        }
    }

    private func cleanupAsyncDisposables(_ disposables: [AsyncDisposable]) async {
        guard !disposables.isEmpty else { return }

        #logInfo("⏳ 비동기 정리 시작: \(disposables.count)개")

        await withTaskGroup(of: Void.self) { group in
            for disposable in disposables {
                group.addTask {
                    await disposable.dispose()
                }
            }
        }

        #logInfo("✅ 비동기 정리 완료")
    }

    private func cleanupBasicDisposables(_ disposables: [Disposable]) {
        guard !disposables.isEmpty else { return }

        #logInfo("🧹 기본 정리 시작: \(disposables.count)개")

        for disposable in disposables {
            disposable.dispose()
        }

        #logInfo("✅ 기본 정리 완료")
    }

    private func executeCleanupCallbacks(_ callbacks: [() -> Void], scopeId: String) {
        guard !callbacks.isEmpty else { return }

        #logInfo("📞 정리 콜백 실행: \(scopeId) (\(callbacks.count)개)")

        for callback in callbacks {
            callback()
        }

        #logInfo("✅ 정리 콜백 완료: \(scopeId)")
    }

    /// 현재 스코프별 정리 대상 개수를 반환합니다
    func getScopeCleanupInfo() -> [String: Int] {
        return queue.sync {
            var info: [String: Int] = [:]
            for (scopeId, disposables) in _scopedDisposables {
                let aliveCount = disposables.compactMap { $0.instance }.count
                info[scopeId] = aliveCount
            }
            return info
        }
    }
}

// MARK: - 약한 참조 래퍼

private class WeakDisposableWrapper {
    weak var instance: AnyObject?

    init(instance: AnyObject) {
        self.instance = instance
    }
}

// MARK: - 실용적인 리소스 관리 예제들

// MARK: 네트워크 연결 관리

final class NetworkConnectionManager: AdvancedDisposable {
    private let connectionId: String
    private var isConnected: Bool = false
    private var activeRequests: Int = 0

    init(connectionId: String) {
        self.connectionId = connectionId
        connect()
    }

    private func connect() {
        isConnected = true
        #logInfo("🌐 네트워크 연결 시작: \(connectionId)")
    }

    func makeRequest() {
        guard isConnected else {
            #logWarning("⚠️ 연결이 끊어져 요청할 수 없음: \(connectionId)")
            return
        }

        activeRequests += 1
        #logInfo("📡 네트워크 요청 시작: \(connectionId) (활성: \(activeRequests))")
    }

    func completeRequest() {
        activeRequests = max(0, activeRequests - 1)
        #logInfo("✅ 네트워크 요청 완료: \(connectionId) (활성: \(activeRequests))")
    }

    // MARK: - AdvancedDisposable

    var disposalPriority: DisposalPriority { .high }
    var resourceDescription: String { "NetworkConnection(\(connectionId))" }

    func willDispose() {
        #logInfo("⚠️ 네트워크 연결 정리 준비: \(connectionId) (활성 요청: \(activeRequests))")

        if activeRequests > 0 {
            #logWarning("🚨 활성 요청이 있는 상태에서 연결을 정리합니다")
        }
    }

    func dispose() {
        isConnected = false
        activeRequests = 0
        #logInfo("🔌 네트워크 연결 종료: \(connectionId)")
    }
}

// MARK: 파일 스트림 관리

final class FileStreamManager: AsyncDisposable {
    private let filePath: String
    private var isOpen: Bool = false
    private var bufferSize: Int = 0

    init(filePath: String) {
        self.filePath = filePath
        openFile()
    }

    private func openFile() {
        isOpen = true
        bufferSize = 1024 * 1024 // 1MB 버퍼
        #logInfo("📁 파일 스트림 열기: \(filePath)")
    }

    func writeData(_ data: Data) {
        guard isOpen else {
            #logWarning("⚠️ 파일이 닫혀있어 쓸 수 없음: \(filePath)")
            return
        }

        #logInfo("✏️ 파일 쓰기: \(filePath) (\(data.count) bytes)")
    }

    // MARK: - AsyncDisposable

    func dispose() async {
        guard isOpen else { return }

        #logInfo("💾 파일 버퍼 플러시 시작: \(filePath)")

        // 버퍼 플러시 시뮬레이션
        if bufferSize > 0 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초
            #logInfo("💾 버퍼 플러시 완료: \(bufferSize) bytes")
        }

        isOpen = false
        bufferSize = 0
        #logInfo("📁 파일 스트림 닫기: \(filePath)")
    }
}

// MARK: 타이머 관리

final class TimerManager: Disposable {
    private let timerId: String
    private var timer: Timer?
    private var tickCount: Int = 0

    init(timerId: String, interval: TimeInterval) {
        self.timerId = timerId
        startTimer(interval: interval)
    }

    private func startTimer(interval: TimeInterval) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        #logInfo("⏰ 타이머 시작: \(timerId) (간격: \(interval)초)")
    }

    private func tick() {
        tickCount += 1
        #logInfo("⏰ 타이머 틱: \(timerId) (\(tickCount))")
    }

    // MARK: - Disposable

    func dispose() {
        timer?.invalidate()
        timer = nil
        #logInfo("⏰ 타이머 정지: \(timerId) (총 \(tickCount)틱)")
    }
}

// MARK: 메모리 캐시 관리

final class MemoryCacheManager: AdvancedDisposable {
    private let cacheId: String
    private var cache: [String: Any] = [:]
    private var accessCount: Int = 0

    init(cacheId: String) {
        self.cacheId = cacheId
        #logInfo("💾 메모리 캐시 초기화: \(cacheId)")
    }

    func set(key: String, value: Any) {
        cache[key] = value
        accessCount += 1
        #logInfo("💾 캐시 저장: \(cacheId)[\(key)] (총 \(cache.count)개)")
    }

    func get(key: String) -> Any? {
        accessCount += 1
        let value = cache[key]
        #logInfo("💾 캐시 조회: \(cacheId)[\(key)] \(value != nil ? "히트" : "미스")")
        return value
    }

    // MARK: - AdvancedDisposable

    var disposalPriority: DisposalPriority { .normal }
    var resourceDescription: String { "MemoryCache(\(cacheId))" }

    func willDispose() {
        #logInfo("📊 캐시 통계 - \(cacheId): 항목 \(cache.count)개, 접근 \(accessCount)회")
    }

    func dispose() {
        let itemCount = cache.count
        cache.removeAll()
        #logInfo("🗑️ 메모리 캐시 정리: \(cacheId) (\(itemCount)개 항목 삭제)")
    }
}

// MARK: - DI 컨테이너 스코프 정리 확장

extension DIContainer {
    private static var cleanupManagerKey = "AdvancedScopeCleanupManager"

    /// 고급 스코프 정리 시스템을 설정합니다
    func setupAdvancedScopeCleanup() {
        let cleanupManager = AdvancedScopeCleanupManager()
        registerSingleton(AdvancedScopeCleanupManager.self) { cleanupManager }

        #logInfo("🔧 고급 스코프 정리 시스템 설정 완료")
    }

    /// 스코프에 리소스 정리 대상을 등록합니다
    func registerForCleanup<T: AnyObject>(_ instance: T, scope: String) {
        let cleanupManager: AdvancedScopeCleanupManager = resolve()
        cleanupManager.register(instance, forScope: scope)
    }

    /// 스코프 정리 콜백을 등록합니다
    func registerScopeCleanupCallback(scope: String, callback: @escaping () -> Void) {
        let cleanupManager: AdvancedScopeCleanupManager = resolve()
        cleanupManager.registerCleanupCallback(forScope: scope, callback: callback)
    }

    /// 스코프를 안전하게 정리합니다
    func cleanupScope(_ scopeId: String) async {
        let cleanupManager: AdvancedScopeCleanupManager = resolve()
        await cleanupManager.cleanupScope(scopeId)
    }

    /// 스코프 정리 정보를 반환합니다
    func getScopeCleanupInfo() -> [String: Int] {
        let cleanupManager: AdvancedScopeCleanupManager = resolve()
        return cleanupManager.getScopeCleanupInfo()
    }
}

// MARK: - 스코프 정리 사용 예제

final class ScopeCleanupDemo {
    private let container = DIContainer()

    init() {
        container.setupAdvancedScopeCleanup()
    }

    /// 다양한 리소스 정리 시나리오를 데모합니다
    func demonstrateScopeCleanup() async {
        #logInfo("🎬 스코프 정리 데모 시작")

        await testBasicCleanup()
        await testPriorityCleanup()
        await testAsyncCleanup()
        await testCallbackCleanup()

        showCleanupInfo()

        #logInfo("🎉 스코프 정리 데모 완료")
    }

    private func testBasicCleanup() async {
        #logInfo("\n1️⃣ 기본 정리 테스트")

        let scopeId = "basic_cleanup_scope"

        // 다양한 리소스들 생성 및 등록
        let timer = TimerManager(timerId: "demo_timer", interval: 1.0)
        let cache = MemoryCacheManager(cacheId: "demo_cache")

        cache.set(key: "test_key", value: "test_value")

        container.registerForCleanup(timer, scope: scopeId)
        container.registerForCleanup(cache, scope: scopeId)

        // 스코프 정리
        await container.cleanupScope(scopeId)
    }

    private func testPriorityCleanup() async {
        #logInfo("\n2️⃣ 우선순위 정리 테스트")

        let scopeId = "priority_cleanup_scope"

        let network = NetworkConnectionManager(connectionId: "demo_connection")
        let cache = MemoryCacheManager(cacheId: "priority_cache")

        // 네트워크 요청 시뮬레이션
        network.makeRequest()

        container.registerForCleanup(network, scope: scopeId)
        container.registerForCleanup(cache, scope: scopeId)

        await container.cleanupScope(scopeId)
    }

    private func testAsyncCleanup() async {
        #logInfo("\n3️⃣ 비동기 정리 테스트")

        let scopeId = "async_cleanup_scope"

        let fileStream1 = FileStreamManager(filePath: "/tmp/demo1.txt")
        let fileStream2 = FileStreamManager(filePath: "/tmp/demo2.txt")

        fileStream1.writeData(Data("Hello".utf8))
        fileStream2.writeData(Data("World".utf8))

        container.registerForCleanup(fileStream1, scope: scopeId)
        container.registerForCleanup(fileStream2, scope: scopeId)

        await container.cleanupScope(scopeId)
    }

    private func testCallbackCleanup() async {
        #logInfo("\n4️⃣ 콜백 정리 테스트")

        let scopeId = "callback_cleanup_scope"

        // 정리 콜백들 등록
        container.registerScopeCleanupCallback(scope: scopeId) {
            #logInfo("📞 콜백 1: 외부 서비스 연결 해제")
        }

        container.registerScopeCleanupCallback(scope: scopeId) {
            #logInfo("📞 콜백 2: 통계 데이터 저장")
        }

        container.registerScopeCleanupCallback(scope: scopeId) {
            #logInfo("📞 콜백 3: 로그 플러시")
        }

        await container.cleanupScope(scopeId)
    }

    private func showCleanupInfo() {
        #logInfo("\n📊 현재 스코프 정리 정보")

        let cleanupInfo = container.getScopeCleanupInfo()

        if cleanupInfo.isEmpty {
            #logInfo("정리 대상이 없습니다. ✅")
        } else {
            for (scopeId, count) in cleanupInfo {
                #logInfo("- \(scopeId): \(count)개 정리 대상")
            }
        }
    }
}

// MARK: - 스코프 정리 데모

enum ScopeCleanupExample {
    static func demonstrateScopeCleanup() async {
        #logInfo("🎬 스코프 정리 및 리소스 관리 데모 시작")

        let demo = ScopeCleanupDemo()
        await demo.demonstrateScopeCleanup()

        #logInfo("🎉 스코프 정리 및 리소스 관리 데모 완료")
    }
}