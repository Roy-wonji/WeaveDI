# WeaveDI Swift 동시성 통합

@DIActor, async/await 패턴, actor 안전 의존성 주입을 포함한 WeaveDI의 Swift 동시성 기능을 마스터하세요.

## 🎯 학습 목표

- **@DIActor**: 스레드 안전 의존성 관리
- **비동기 등록**: 백그라운드 의존성 설정
- **Actor 격리**: 안전한 동시 접근
- **성능 최적화**: Hot path 캐싱
- **실제 패턴**: 실용적인 async/await 사용법

## 🧵 스레드 안전 의존성 주입

### 안전한 작업을 위한 @DIActor 사용

```swift
import WeaveDI

// @DIActor를 사용하여 안전하게 의존성 등록
@DIActor
func setupAppDependencies() async {
    print("🚀 백그라운드 스레드에서 의존성 설정 중...")

    // 실제 WeaveDI @DIActor를 사용한 스레드 안전 등록
    let networkService = await DIActor.shared.register(NetworkService.self) {
        URLSessionNetworkService()
    }

    let cacheService = await DIActor.shared.register(CacheService.self) {
        CoreDataCacheService()
    }

    print("✅ 의존성이 안전하게 등록되었습니다")
}

// 의존성을 안전하게 해결
@DIActor
func getDependencies() async {
    let networkService = await DIActor.shared.resolve(NetworkService.self)
    let cacheService = await DIActor.shared.resolve(CacheService.self)

    print("📦 의존성 해결됨: \(networkService != nil)")
}
```

**🔍 코드 설명:**

1. **@DIActor 함수**: `@DIActor` 속성을 사용하면 함수가 DIActor 컨텍스트에서 실행됩니다
2. **스레드 안전 등록**: `DIActor.shared.register`는 동시 등록을 안전하게 처리합니다
3. **비동기 해결**: `await`를 사용하여 의존성을 비동기적으로 해결합니다
4. **백그라운드 실행**: 메인 스레드를 차단하지 않고 의존성을 설정합니다

### Actor 안전 프로퍼티 주입

```swift
@MainActor
class WeatherViewModel: ObservableObject {
    // 메인 액터에서 UI 업데이트
    @Published var weather: Weather?
    @Published var isLoading = false
    @Published var error: String?

    // 서비스를 안전하게 주입 가능
    @Injected var weatherService: WeatherService?

    func loadWeather(for city: String) async {
        isLoading = true
        error = nil

        do {
            // 주입된 서비스로 백그라운드 작업
            guard let service = weatherService else {
                throw WeatherError.serviceUnavailable
            }

            // 백그라운드 스레드에서 실행
            let weatherData = try await service.fetchWeather(for: city)

            // UI 업데이트는 자동으로 메인 액터에서
            self.weather = weatherData
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
```

**🔍 코드 설명:**

1. **@MainActor 클래스**: 모든 메서드와 프로퍼티가 메인 스레드에서 실행됩니다
2. **@Published 프로퍼티**: UI 바인딩을 위한 SwiftUI 호환 상태
3. **@Injected 프로퍼티**: WeaveDI를 통한 안전한 의존성 주입
4. **백그라운드 작업**: 네트워크 호출은 백그라운드에서 수행됩니다
5. **자동 UI 업데이트**: 상태 변경이 메인 스레드에서 자동으로 처리됩니다

## 🏭 고급 동시성 패턴

### 병렬 의존성 초기화

```swift
/// 여러 서비스를 병렬로 초기화하는 고급 부트스트랩 (실제 tutorial 코드 기반)
class ConcurrentBootstrap {

    @DIActor
    static func setupServicesInParallel() async {
        print("⚡ 병렬 서비스 초기화 시작")

        // TaskGroup을 사용하여 여러 서비스를 동시에 초기화
        await withTaskGroup(of: Void.self) { group in

            // 네트워크 서비스 초기화 (시간이 오래 걸림)
            group.addTask {
                let service = await initializeNetworkService()
                await DIActor.shared.register(NetworkService.self) {
                    service
                }
                print("🌐 NetworkService 초기화 완료")
            }

            // 데이터베이스 서비스 초기화 (시간이 오래 걸림)
            group.addTask {
                let service = await initializeDatabaseService()
                await DIActor.shared.register(DatabaseService.self) {
                    service
                }
                print("🗄️ DatabaseService 초기화 완료")
            }

            // 캐시 서비스 초기화 (빠름)
            group.addTask {
                let service = await initializeCacheService()
                await DIActor.shared.register(CacheService.self) {
                    service
                }
                print("💾 CacheService 초기화 완료")
            }

            // 인증 서비스 초기화 (의존성 있음)
            group.addTask {
                // 네트워크 서비스가 준비될 때까지 대기
                let networkService = await DIActor.shared.resolve(NetworkService.self)
                let authService = await initializeAuthService(networkService: networkService)

                await DIActor.shared.register(AuthService.self) {
                    authService
                }
                print("🔐 AuthService 초기화 완료")
            }
        }

        print("✅ 모든 서비스 병렬 초기화 완료")
    }

    /// 네트워크 서비스를 비동기적으로 초기화
    private static func initializeNetworkService() async -> NetworkService {
        // 시뮬레이션: 네트워크 설정에 시간이 걸림
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1초
        return URLSessionNetworkService()
    }

    /// 데이터베이스 서비스를 비동기적으로 초기화
    private static func initializeDatabaseService() async -> DatabaseService {
        // 시뮬레이션: 데이터베이스 연결에 시간이 걸림
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2초
        return CoreDataService()
    }

    /// 캐시 서비스를 비동기적으로 초기화 (빠름)
    private static func initializeCacheService() async -> CacheService {
        return InMemoryCacheService()
    }

    /// 인증 서비스를 비동기적으로 초기화 (의존성 있음)
    private static func initializeAuthService(networkService: NetworkService?) async -> AuthService {
        guard let network = networkService else {
            fatalError("AuthService requires NetworkService")
        }
        return OAuth2AuthService(networkService: network)
    }
}
```

**🔍 코드 설명:**

1. **TaskGroup**: 여러 작업을 병렬로 실행하기 위한 Swift 동시성 API
2. **비동기 초기화**: 각 서비스가 독립적으로 초기화됩니다
3. **의존성 해결**: AuthService처럼 다른 서비스에 의존하는 경우 순서 보장
4. **성능 향상**: 순차 초기화 대신 병렬 초기화로 시간 단축

### Actor Hop 패턴

**Actor hopping**은 Swift 동시성에서 실행이 서로 다른 액터 간에 이동할 때 발생하는 중요한 개념입니다. Actor hop을 이해하고 최적화하는 것은 성능에 필수적입니다.

```swift
/// 고급 actor hop 최적화 패턴
actor DataProcessor {
    private var cache: [String: ProcessedData] = [:]

    @Injected var networkService: NetworkService?
    @Injected var logger: LoggerProtocol?

    /// 제어된 actor hopping 예제
    func processDataWithOptimizedHops(input: String) async -> ProcessedData? {
        // ✅ 현재 DataProcessor actor에 있음
        logger?.info("🔄 DataProcessor actor에서 데이터 처리 시작")

        // 먼저 캐시 확인 (actor hop 불필요)
        if let cached = cache[input] {
            logger?.info("📋 캐시 히트, 처리 불필요")
            return cached
        }

        // ❌ 피해야 할 패턴: 불필요한 여러 actor hop
        // 여러 hop을 발생시키는 나쁜 패턴:
        /*
        await MainActor.run {
            // MainActor로 hop
            updateUI()
        }
        let networkData = await networkService?.fetchData(input) // network actor로 hop
        await MainActor.run {
            // 다시 MainActor로 hop
            updateProgress()
        }
        */

        // ✅ 최적화된 패턴: hop 최소화

        // 모든 네트워크 작업을 함께 배치
        guard let networkService = networkService else { return nil }
        let networkData = await networkService.fetchData(input)

        // 현재 actor에서 처리 (hop 없음)
        let processed = await processInternalData(networkData)

        // 결과 캐시 (hop 불필요, 여전히 DataProcessor actor에 있음)
        cache[input] = processed

        // 마지막에 UI 업데이트를 위해 MainActor로 한 번만 hop
        await MainActor.run {
            NotificationCenter.default.post(
                name: .dataProcessingComplete,
                object: processed
            )
        }

        return processed
    }

    /// 같은 actor에 머무르는 내부 처리
    private func processInternalData(_ data: Data?) async -> ProcessedData {
        // 이 메서드는 DataProcessor actor에서 실행 - hop 없음
        guard let data = data else {
            return ProcessedData.empty
        }

        // 처리 작업 시뮬레이션
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초

        return ProcessedData(
            id: UUID().uuidString,
            content: String(data: data, encoding: .utf8) ?? "",
            timestamp: Date(),
            processingDuration: 0.1
        )
    }

    /// Actor hop을 최소화하는 효율적인 배치 처리
    func processBatchWithMinimalHops(_ inputs: [String]) async -> [ProcessedData] {
        var results: [ProcessedData] = []

        // 현재 actor에서 모든 입력 처리
        for input in inputs {
            if let result = await processDataWithOptimizedHops(input: input) {
                results.append(result)
            }
        }

        // 최종 알림을 위해 MainActor로 한 번만 hop
        await MainActor.run {
            NotificationCenter.default.post(
                name: .batchProcessingComplete,
                object: results.count
            )
        }

        return results
    }
}

/// 적절한 actor hop 관리를 보여주는 메인 액터 코디네이터
@MainActor
class ActorHopCoordinator: ObservableObject {
    @Published var processingStatus: String = "준비됨"
    @Published var results: [ProcessedData] = []

    @Injected var dataProcessor: DataProcessor?
    @Injected var logger: LoggerProtocol?

    /// 최적화된 actor hop 패턴 시연
    func performOptimizedProcessing(inputs: [String]) async {
        // ✅ MainActor에서 시작 (UI 업데이트)
        processingStatus = "처리 시작 중..."
        logger?.info("🚀 최적화된 처리 시작")

        // ✅ 모든 작업을 위해 DataProcessor actor로 한 번만 hop
        guard let processor = dataProcessor else {
            processingStatus = "오류: 프로세서를 사용할 수 없음"
            return
        }

        // 모든 처리가 DataProcessor actor에서 발생
        let processedResults = await processor.processBatchWithMinimalHops(inputs)

        // ✅ UI 업데이트를 위해 MainActor로 돌아옴 (자동 hop)
        self.results = processedResults
        self.processingStatus = "완료: \(processedResults.count)개 항목"

        logger?.info("✅ 최소한의 actor hop으로 처리 완료")
    }

    /// 하지 말아야 할 예제 - 과도한 actor hopping
    func performPoorlyOptimizedProcessing(inputs: [String]) async {
        // ❌ 이것은 나쁜 예제 - 너무 많은 actor hop

        for input in inputs {
            // Hop 1: 각 항목에 대해 UI 업데이트
            processingStatus = "\(input) 처리 중..."

            // Hop 2: 프로세서로 이동
            let result = await dataProcessor?.processDataWithOptimizedHops(input: input)

            // Hop 3: MainActor로 돌아옴
            if let result = result {
                results.append(result)
            }

            // 이렇게 하면 3 * inputs.count개의 actor hop이 발생!
        }
    }
}

struct ProcessedData {
    let id: String
    let content: String
    let timestamp: Date
    let processingDuration: TimeInterval

    static let empty = ProcessedData(
        id: "",
        content: "",
        timestamp: Date(),
        processingDuration: 0
    )
}

extension Notification.Name {
    static let dataProcessingComplete = Notification.Name("dataProcessingComplete")
    static let batchProcessingComplete = Notification.Name("batchProcessingComplete")
}
```

**🔍 Actor Hop 최적화 원칙:**

1. **Hop 최소화**: 같은 actor에서 수행해야 하는 작업들을 그룹화
2. **UI 업데이트 배치**: 지속적으로 업데이트하지 말고 마지막에 한 번에 UI 업데이트
3. **Actor에 머무르기**: 현재 actor에 머무르는 private 메서드 선호
4. **성능 측정**: Instruments를 사용하여 hop 병목 지점 식별
5. **전략적 Hopping**: 언제 어디서 actor 전환이 필요한지 계획

### 동시성 최적화 패턴

```swift
/// 성능 최적화된 동시성 서비스 매니저 (tutorial 기반 고급 패턴)
@MainActor
class ConcurrencyOptimizedServiceManager {

    // MARK: - 의존성 (WeaveDI를 통해 주입)
    @Injected var dataService: ThreadSafeDataService?
    @Injected var networkService: NetworkService?
    @Injected var logger: LoggerProtocol?

    // MARK: - 내부 상태
    private var operationQueue: [UUID: Task<Void, Never>] = [:]
    private var resultCache: [String: Any] = [:]

    /// 여러 작업을 효율적으로 병렬 처리
    func performBatchOperations<T: Sendable>(
        _ operations: [(id: String, operation: () async throws -> T)]
    ) async -> [String: Result<T, Error>] {

        logger?.info("🚀 배치 작업 시작: \(operations.count)개 작업")

        var results: [String: Result<T, Error>] = [:]

        // TaskGroup을 사용한 병렬 처리
        await withTaskGroup(of: (String, Result<T, Error>).self) { group in

            for (id, operation) in operations {
                group.addTask { [weak self] in
                    // 캐시 확인 (메인 액터에서 안전)
                    if let cached = await self?.getCachedResult(id: id) as? T {
                        self?.logger?.info("📋 캐시된 결과 사용: \(id)")
                        return (id, .success(cached))
                    }

                    // 실제 작업 수행
                    do {
                        let result = try await operation()
                        await self?.cacheResult(id: id, result: result)
                        return (id, .success(result))
                    } catch {
                        self?.logger?.error("❌ 작업 실패 [\(id)]: \(error)")
                        return (id, .failure(error))
                    }
                }
            }

            // 모든 결과 수집
            for await (id, result) in group {
                results[id] = result
            }
        }

        logger?.info("✅ 배치 작업 완료: \(results.count)개 결과")
        return results
    }

    /// 취소 가능한 장기 실행 작업
    func startLongRunningTask(id: String) -> UUID {
        let taskId = UUID()

        let task = Task { [weak self] in
            guard let self = self else { return }

            await self.logger?.info("⏳ 장기 작업 시작: \(id)")

            // 작업 시뮬레이션 (취소 가능)
            for i in 1...100 {
                // 취소 확인
                if Task.isCancelled {
                    await self.logger?.info("🛑 작업 취소됨: \(id)")
                    return
                }

                // 진행률 업데이트
                if i % 10 == 0 {
                    await self.logger?.info("📊 진행률 [\(id)]: \(i)%")
                }

                // 작업 시뮬레이션
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초
            }

            await self.logger?.info("✅ 장기 작업 완료: \(id)")
            await self.removeTask(taskId: taskId)
        }

        operationQueue[taskId] = task
        return taskId
    }

    /// 작업 취소
    func cancelTask(taskId: UUID) {
        operationQueue[taskId]?.cancel()
        operationQueue.removeValue(forKey: taskId)
        logger?.info("🛑 작업 취소 요청: \(taskId)")
    }

    /// 모든 작업 취소
    func cancelAllTasks() {
        logger?.info("🛑 모든 작업 취소")
        for task in operationQueue.values {
            task.cancel()
        }
        operationQueue.removeAll()
    }

    // MARK: - Private Methods

    /// 캐시된 결과 조회 (메인 액터에서 안전)
    private func getCachedResult(id: String) -> Any? {
        return resultCache[id]
    }

    /// 결과 캐시 (메인 액터에서 안전)
    private func cacheResult<T>(id: String, result: T) {
        resultCache[id] = result
        logger?.info("💾 결과 캐시됨: \(id)")
    }

    /// 완료된 작업 제거
    private func removeTask(taskId: UUID) {
        operationQueue.removeValue(forKey: taskId)
    }
}
```

**🔍 코드 설명:**

1. **@MainActor 관리**: UI 관련 상태를 메인 액터에서 안전하게 관리
2. **TaskGroup 활용**: 여러 작업의 병렬 처리와 결과 수집
3. **취소 가능한 작업**: Task.isCancelled를 체크하여 우아한 취소 처리
4. **결과 캐싱**: 중복 작업 방지를 위한 결과 캐싱
5. **작업 추적**: 실행 중인 작업들을 추적하고 관리

## 📋 실제 사용 예제

### 실제 앱에서의 통합

```swift
/// 실제 앱에서 WeaveDI 동시성 기능을 사용하는 예제
@main
struct ConcurrentApp: App {

    /// 앱 시작 시 비동기 초기화
    init() {
        Task {
            await initializeApp()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // 뷰가 나타날 때 추가 초기화
                    await finalizeAppSetup()
                }
        }
    }

    /// 앱 초기화 (백그라운드에서 수행)
    @DIActor
    private func initializeApp() async {
        print("🚀 앱 초기화 시작")

        // 병렬 서비스 초기화
        await ConcurrentBootstrap.setupServicesInParallel()

        // 추가 설정
        await configureLogging()
        await setupAnalytics()

        print("✅ 앱 초기화 완료")
    }

    /// 마지막 설정 단계
    private func finalizeAppSetup() async {
        // UI가 준비된 후 수행할 작업들
        await preloadCriticalData()
        await startBackgroundTasks()
    }

    @DIActor
    private func configureLogging() async {
        // 로깅 시스템 설정
        print("📝 로깅 시스템 설정 완료")
    }

    @DIActor
    private func setupAnalytics() async {
        // 분석 시스템 설정
        print("📊 분석 시스템 설정 완료")
    }

    private func preloadCriticalData() async {
        // 중요한 데이터 미리 로드
        print("📥 중요 데이터 프리로드 완료")
    }

    private func startBackgroundTasks() async {
        // 백그라운드 작업 시작
        print("🔄 백그라운드 작업 시작")
    }
}
```

### SwiftUI와 동시성 통합

```swift
/// WeaveDI를 사용한 비동기 데이터 로딩을 보여주는 SwiftUI 뷰
struct AsyncDataView: View {
    @StateObject private var viewModel = AsyncDataViewModel()
    @State private var isLoading = false
    @State private var data: [DataItem] = []
    @State private var error: String?

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("데이터 로딩 중...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = error {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("오류: \(error)")
                            .multilineTextAlignment(.center)
                        Button("다시 시도") {
                            Task {
                                await loadData()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(data, id: \.id) { item in
                        DataItemRow(item: item)
                    }
                }
            }
            .navigationTitle("비동기 데이터")
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
        }
    }

    @MainActor
    private func loadData() async {
        isLoading = true
        error = nil

        do {
            data = try await viewModel.fetchData()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

/// WeaveDI를 사용한 비동기 작업이 있는 ViewModel
@MainActor
class AsyncDataViewModel: ObservableObject {
    @Injected var dataService: ThreadSafeDataService?
    @Injected var networkService: NetworkService?
    @Injected var logger: LoggerProtocol?

    func fetchData() async throws -> [DataItem] {
        logger?.info("📥 데이터 가져오기 시작")

        // 데이터 서비스 초기화 확인
        await dataService?.initialize()

        // 먼저 캐시된 데이터 확인
        if let cachedData = await dataService?.retrieveData(forKey: "main_data"),
           let items = try? JSONDecoder().decode([DataItem].self, from: cachedData) {
            logger?.info("📋 캐시된 데이터 사용")
            return items
        }

        // 새로운 데이터 가져오기
        guard let network = networkService else {
            throw DataError.serviceUnavailable
        }

        let freshData = try await network.fetchDataItems()
        let encoded = try JSONEncoder().encode(freshData)
        await dataService?.storeData(encoded, forKey: "main_data")

        logger?.info("✅ 새로운 데이터 가져오기 및 캐시 완료")
        return freshData
    }
}

struct DataItem: Codable {
    let id: String
    let title: String
    let description: String
}

struct DataItemRow: View {
    let item: DataItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.headline)
            Text(item.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

enum DataError: Error, LocalizedError {
    case serviceUnavailable
    case networkError

    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "데이터 서비스를 사용할 수 없습니다"
        case .networkError:
            return "네트워크 오류가 발생했습니다"
        }
    }
}
```

### Actor 기반 서비스 설계

```swift
/// Actor를 사용한 스레드 안전 서비스 구현 (실제 tutorial 패턴)
actor ThreadSafeDataService {
    private var cache: [String: Data] = [:]
    private var isInitialized = false

    /// WeaveDI를 통해 의존성 주입 (Actor 내부에서 안전)
    @Injected var networkService: NetworkService?
    @Injected var logger: LoggerProtocol?

    /// Actor 내부 상태를 안전하게 초기화
    func initialize() async {
        guard !isInitialized else { return }

        logger?.info("🔄 ThreadSafeDataService 초기화 시작")

        // 네트워크 서비스 확인
        guard let network = networkService else {
            logger?.error("❌ NetworkService를 사용할 수 없습니다")
            return
        }

        // 초기 데이터 로드
        do {
            let initialData = try await network.fetchInitialData()
            cache["initial"] = initialData
            isInitialized = true
            logger?.info("✅ ThreadSafeDataService 초기화 완료")
        } catch {
            logger?.error("❌ 초기화 실패: \(error)")
        }
    }

    /// 데이터를 안전하게 저장 (Actor 컨텍스트에서 실행)
    func storeData(_ data: Data, forKey key: String) {
        cache[key] = data
        logger?.info("💾 데이터 저장됨: \(key)")
    }

    /// 데이터를 안전하게 조회 (Actor 컨텍스트에서 실행)
    func retrieveData(forKey key: String) -> Data? {
        let data = cache[key]
        logger?.info("📖 데이터 조회: \(key) -> \(data != nil ? "성공" : "실패")")
        return data
    }

    /// 캐시 상태 확인 (외부에서 안전하게 호출 가능)
    var cacheSize: Int {
        cache.count
    }
}
```

**🔍 코드 설명:**

1. **Actor 키워드**: 클래스 대신 actor를 사용하여 자동 동기화
2. **내부 상태 보호**: cache와 isInitialized가 동시 접근으로부터 보호됨
3. **@Injected 안전성**: Actor 내부에서도 WeaveDI 주입이 안전하게 작동
4. **비동기 메서드**: Actor 메서드는 외부에서 await로 호출

## 🎯 실제 Tutorial 코드 활용 예제

### CountApp과 동시성 통합

```swift
/// Tutorial에서 사용된 CountApp을 동시성 기능과 통합한 예제
struct AsyncCounterView: View {
    @State private var count = 0
    @State private var isLoading = false
    @Injected var counterRepository: CounterRepository?
    @Injected var logger: LoggerProtocol?

    var body: some View {
        VStack(spacing: 20) {
            Text("비동기 WeaveDI 카운터")
                .font(.largeTitle)
                .fontWeight(.bold)

            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                Text("\(count)")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.blue)
            }

            HStack(spacing: 20) {
                AsyncButton("−", color: .red) {
                    await decrementCounter()
                }

                AsyncButton("+", color: .green) {
                    await incrementCounter()
                }
            }

            Button("히스토리 보기") {
                Task {
                    await showHistory()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .task {
            await loadInitialCount()
        }
    }

    @MainActor
    private func loadInitialCount() async {
        isLoading = true
        count = await counterRepository?.getCurrentCount() ?? 0
        isLoading = false
        logger?.info("📊 초기 카운트 로드: \(count)")
    }

    @MainActor
    private func incrementCounter() async {
        isLoading = true
        count += 1
        await counterRepository?.saveCount(count)
        isLoading = false
        logger?.info("⬆️ 카운터 증가: \(count)")
    }

    @MainActor
    private func decrementCounter() async {
        isLoading = true
        count -= 1
        await counterRepository?.saveCount(count)
        isLoading = false
        logger?.info("⬇️ 카운터 감소: \(count)")
    }

    private func showHistory() async {
        let history = await counterRepository?.getCountHistory() ?? []
        logger?.info("📈 히스토리: \(history.count)개 항목")
    }
}

struct AsyncButton: View {
    let title: String
    let color: Color
    let action: () async -> Void

    var body: some View {
        Button(title) {
            Task {
                await action()
            }
        }
        .font(.title)
        .frame(width: 50, height: 50)
        .background(color)
        .foregroundColor(.white)
        .clipShape(Circle())
    }
}
```

---

**축하합니다!** WeaveDI의 Swift 동시성 통합을 마스터했습니다. 이제 안전하고 효율적인 동시 프로그래밍을 통해 고성능 iOS 앱을 구축할 수 있습니다.

📖 **관련 문서**: [시작하기](/ko/tutorial/gettingStarted) | [Property Wrappers](/ko/tutorial/propertyWrappers)