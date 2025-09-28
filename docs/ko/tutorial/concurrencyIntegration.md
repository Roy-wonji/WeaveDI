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
    @Inject var weatherService: WeatherService?

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
3. **@Inject 프로퍼티**: WeaveDI를 통한 안전한 의존성 주입
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

### Actor 기반 서비스 설계

```swift
/// Actor를 사용한 스레드 안전 서비스 구현 (실제 tutorial 패턴)
actor ThreadSafeDataService {
    private var cache: [String: Data] = [:]
    private var isInitialized = false

    /// WeaveDI를 통해 의존성 주입 (Actor 내부에서 안전)
    @Inject var networkService: NetworkService?
    @Inject var logger: LoggerProtocol?

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
3. **@Inject 안전성**: Actor 내부에서도 WeaveDI 주입이 안전하게 작동
4. **비동기 메서드**: Actor 메서드는 외부에서 await로 호출

## 🎯 실제 Tutorial 코드 활용 예제

### CountApp과 동시성 통합

```swift
/// Tutorial에서 사용된 CountApp을 동시성 기능과 통합한 예제
struct AsyncCounterView: View {
    @State private var count = 0
    @State private var isLoading = false
    @Inject var counterRepository: CounterRepository?
    @Inject var logger: LoggerProtocol?

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