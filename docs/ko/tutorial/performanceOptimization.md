# WeaveDI를 사용한 성능 최적화

WeaveDI로 구동되는 애플리케이션을 위한 성능 최적화 기법을 마스터하세요. 캐싱 전략, 메모리 관리, 벤치마킹 접근법을 배웁니다.

## 🎯 학습 목표

- **Hot Path 최적화**: 자주 접근되는 의존성 최적화
- **메모리 관리**: 메모리 사용량 줄이기와 누수 방지
- **지연 로딩**: 비용이 많이 드는 의존성 초기화 지연
- **캐싱 전략**: 지능적인 의존성 결과 캐싱
- **벤치마킹**: DI 성능 측정 및 개선
- **프로덕션 패턴**: 실제 최적화 기법

## 🚀 Hot Path 최적화

### 성능 병목 지점 식별

```swift
import WeaveDI

/// 병목 지점을 식별하는 성능 모니터링 서비스
/// 이 서비스는 의존성 해결 시간과 빈도를 추적합니다
class DIPerformanceMonitor {

    /// 각 의존성 타입이 해결된 횟수를 추적
    /// 높은 숫자는 최적화가 필요한 "hot path"를 나타냅니다
    private var resolutionCounts: [String: Int] = [:]

    /// 각 의존성 타입을 해결하는 데 소요된 총 시간을 추적
    /// 느리게 해결되는 의존성을 식별하는 데 도움됩니다
    private var resolutionTimes: [String: TimeInterval] = [:]

    /// 각 의존성의 마지막 해결 시간을 추적
    /// 간헐적인 성능 문제를 디버깅하는 데 유용합니다
    private var lastResolutionTimes: [String: Date] = [:]

    /// 의존성 해결 성능 모니터링
    /// 의존성 해결 전후에 이 메서드를 호출하세요
    func trackResolution<T>(for type: T.Type, executionTime: TimeInterval) {
        let typeName = String(describing: type)

        // 해결 횟수 업데이트
        resolutionCounts[typeName, default: 0] += 1

        // 총 시간 업데이트
        resolutionTimes[typeName, default: 0] += executionTime

        // 마지막 해결 시간 업데이트
        lastResolutionTimes[typeName] = Date()

        // 해결이 너무 오래 걸리면 로깅
        if executionTime > 0.1 { // 100ms 이상은 느린 것으로 간주
            print("⚠️ 느린 의존성 해결: \(typeName)이 \(executionTime)초 소요됨")
        }

        // 자주 접근되는 의존성이면 로깅
        let count = resolutionCounts[typeName] ?? 0
        if count > 0 && count % 100 == 0 { // 100번마다
            print("🔥 Hot path 감지: \(typeName)이 \(count)번 해결됨")
        }
    }

    /// 분석을 위한 성능 통계 가져오기
    /// 최적화 기회를 식별하는 데 사용할 수 있는 데이터를 반환합니다
    func getPerformanceStats() -> PerformanceStats {
        var hotPaths: [String] = []
        var slowDependencies: [String] = []

        for (type, count) in resolutionCounts {
            // Hot path 식별 (자주 접근되는 의존성)
            if count > 50 {
                hotPaths.append("\(type): \(count)번")
            }

            // 느린 의존성 식별 (높은 평균 해결 시간)
            let totalTime = resolutionTimes[type] ?? 0
            let averageTime = totalTime / Double(count)
            if averageTime > 0.05 { // 50ms 이상 평균
                slowDependencies.append("\(type): \(averageTime)초 평균")
            }
        }

        return PerformanceStats(
            hotPaths: hotPaths,
            slowDependencies: slowDependencies,
            totalResolutions: resolutionCounts.values.reduce(0, +),
            totalTime: resolutionTimes.values.reduce(0, +)
        )
    }
}

/// 분석을 위한 성능 통계
struct PerformanceStats {
    let hotPaths: [String]           // 자주 접근되는 의존성
    let slowDependencies: [String]   // 느리게 해결되는 의존성
    let totalResolutions: Int        // 총 해결 횟수
    let totalTime: TimeInterval      // 해결에 소요된 총 시간
}
```

**🔍 코드 설명:**
- **해결 추적**: 각 의존성이 얼마나 자주 해결되는지 모니터링
- **성능 측정**: 병목 지점을 식별하기 위해 해결 시간 추적
- **Hot Path 감지**: 자주 접근되는 의존성을 자동으로 식별
- **느린 의존성 감지**: 해결하는 데 너무 오래 걸리는 의존성에 플래그

### 최적화된 의존성 해결

```swift
/// 자주 접근되는 의존성을 캐시하는 최적화된 서비스
/// 이 패턴은 hot path의 성능을 크게 향상시킵니다
class OptimizedServiceManager {

    // MARK: - 캐시된 의존성 (Hot Path 최적화)

    /// 자주 접근되는 네트워크 서비스용 캐시
    /// 반복적인 DI 해결 오버헤드를 피합니다
    private var cachedNetworkService: NetworkService?

    /// 데이터베이스 서비스용 캐시 (초기화 비용이 높음)
    /// 재초기화를 피하기 위해 해결된 인스턴스를 저장합니다
    private var cachedDatabaseService: DatabaseService?

    /// 로거 서비스용 캐시 (모든 곳에서 사용됨)
    /// 일반적인 앱에서 가장 자주 접근되는 의존성
    private var cachedLogger: LoggerProtocol?

    // MARK: - 직접 DI 주입 (덜 자주 사용됨)

    /// 인증 서비스 - 덜 자주 사용됨
    /// hot path가 아니므로 캐싱이 필요하지 않음
    @Inject private var authService: AuthService?

    /// 분석 서비스 - 덜 자주 사용됨
    /// 캐싱이 필요하지 않으며, 새로운 인스턴스가 선호될 수 있음
    @Inject private var analyticsService: AnalyticsService?

    /// 구성 서비스 - 시작 후 거의 접근되지 않음
    /// 자주 접근되지 않으므로 캐싱이 필요하지 않음
    @Inject private var configService: ConfigurationService?

    // MARK: - 최적화된 접근자

    /// 캐싱 최적화를 통한 네트워크 서비스 가져오기
    /// 첫 번째 접근은 DI를 통해 해결하고, 이후 접근은 캐시 사용
    var networkService: NetworkService? {
        if let cached = cachedNetworkService {
            return cached
        }

        // DI를 통해 해결하고 결과를 캐시
        let resolved = WeaveDI.Container.live.resolve(NetworkService.self)
        cachedNetworkService = resolved

        if resolved != nil {
            print("🚀 NetworkService 향후 사용을 위해 캐시됨")
        }

        return resolved
    }

    /// 지연 초기화와 캐싱을 통한 데이터베이스 서비스 가져오기
    /// 데이터베이스 서비스는 종종 초기화 비용이 높습니다
    var databaseService: DatabaseService? {
        if let cached = cachedDatabaseService {
            return cached
        }

        print("📀 데이터베이스 서비스 초기화 중 (비용이 많이 드는 작업)")
        let startTime = Date()

        let resolved = WeaveDI.Container.live.resolve(DatabaseService.self)
        cachedDatabaseService = resolved

        let initTime = Date().timeIntervalSince(startTime)
        print("📀 데이터베이스 서비스가 \(initTime)초에 초기화됨")

        return resolved
    }

    /// 초고속 캐싱을 통한 로거 가져오기
    /// 로거는 일반적으로 가장 자주 접근되는 의존성입니다
    var logger: LoggerProtocol? {
        if let cached = cachedLogger {
            return cached
        }

        let resolved = WeaveDI.Container.live.resolve(LoggerProtocol.self)
        cachedLogger = resolved
        print("📝 로거 캐시됨 (hot path 최적화)")

        return resolved
    }

    // MARK: - 캐시 관리

    /// 캐시된 의존성을 지워서 재해결 강제
    /// 테스트나 의존성이 변경되었을 때 유용합니다
    func clearCache() {
        cachedNetworkService = nil
        cachedDatabaseService = nil
        cachedLogger = nil
        print("🧹 의존성 캐시 지워짐")
    }

    /// 모든 캐시된 의존성을 미리 해결하여 캐시 워밍
    /// 첫 번째 접근 지연을 피하기 위해 앱 시작 시 호출하세요
    func warmUpCache() async {
        print("🔥 의존성 캐시 워밍 중...")

        await withTaskGroup(of: Void.self) { group in
            // 모든 캐시된 의존성을 병렬로 미리 해결
            group.addTask { [weak self] in
                _ = self?.networkService
            }

            group.addTask { [weak self] in
                _ = self?.databaseService
            }

            group.addTask { [weak self] in
                _ = self?.logger
            }
        }

        print("✅ 캐시 워밍 완료")
    }
}
```

**🔍 코드 설명:**
- **선택적 캐싱**: 자주 접근되는 (hot path) 의존성만 캐시
- **지연 초기화**: 첫 번째 접근 시에만 의존성 해결
- **성능 모니터링**: 비용이 많이 드는 작업의 초기화 시간 로깅
- **캐시 관리**: 캐시를 지우고 워밍하는 메서드 제공

## 💾 메모리 관리

### 메모리 효율적인 의존성 패턴

```swift
/// 자동 정리 기능이 있는 메모리 효율적인 의존성 관리
/// 이 패턴은 메모리 누수를 방지하고 메모리 사용량을 줄입니다
class MemoryEfficientManager {

    // MARK: - 중요하지 않은 의존성을 위한 약한 참조

    /// 재생성 가능한 의존성에 약한 참조 사용
    /// 메모리 압박 시 시스템이 메모리를 해제할 수 있습니다
    private weak var weakCacheService: CacheService?
    private weak var weakImageProcessor: ImageProcessor?
    private weak var weakAnalyticsService: AnalyticsService?

    // MARK: - 중요한 의존성을 위한 강한 참조

    /// 중요한 의존성에 강한 참조 유지
    /// 이들은 필수적이며 예기치 않게 해제되어서는 안 됩니다
    @Inject private var databaseService: DatabaseService?
    @Inject private var authService: AuthService?
    @Inject private var networkService: NetworkService?

    // MARK: - 메모리 인식 접근자

    /// 메모리 인식 해결을 통한 캐시 서비스 가져오기
    /// 메모리 압박으로 해제된 경우 서비스를 재생성합니다
    var cacheService: CacheService? {
        // 약한 참조가 여전히 유효한지 확인
        if let existing = weakCacheService {
            return existing
        }

        // 해제된 경우 새 인스턴스 해결
        print("💾 캐시 서비스 재생성 중 (메모리 최적화)")
        let newService = WeaveDI.Container.live.resolve(CacheService.self)
        weakCacheService = newService

        return newService
    }

    /// 자동 재생성을 통한 이미지 프로세서 가져오기
    /// 이미지 프로세서는 메모리 집약적이며 약한 참조의 이점이 있습니다
    var imageProcessor: ImageProcessor? {
        if let existing = weakImageProcessor {
            return existing
        }

        print("🖼️ 이미지 프로세서 재생성 중 (메모리 압박 복구)")
        let newProcessor = WeaveDI.Container.live.resolve(ImageProcessor.self)
        weakImageProcessor = newProcessor

        return newProcessor
    }

    /// 지연 재생성을 통한 분석 서비스 가져오기
    /// 분석은 중요하지 않으며 필요에 따라 재생성할 수 있습니다
    var analyticsService: AnalyticsService? {
        if let existing = weakAnalyticsService {
            return existing
        }

        print("📊 분석 서비스 재생성 중 (메모리 효율적)")
        let newService = WeaveDI.Container.live.resolve(AnalyticsService.self)
        weakAnalyticsService = newService

        return newService
    }

    // MARK: - 메모리 모니터링

    /// 메모리 사용량을 모니터링하고 필요시 정리 수행
    /// 주기적으로 또는 메모리 경고를 받을 때 호출하세요
    func handleMemoryPressure() {
        print("⚠️ 메모리 압박 감지 - 정리 수행 중")

        // 약한 참조를 지워서 해제 허용
        weakCacheService = nil
        weakImageProcessor = nil
        weakAnalyticsService = nil

        // 가비지 컬렉션 강제 (iOS가 자동으로 처리)
        print("🧹 메모리 복구를 위해 중요하지 않은 의존성 정리됨")

        // 현재 메모리 상태 로깅
        logMemoryUsage()
    }

    /// 모니터링을 위한 현재 메모리 사용량 로깅
    /// 메모리 효율성 개선을 추적하는 데 도움됩니다
    private func logMemoryUsage() {
        let memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let usedMemory = memoryInfo.resident_size / 1024 / 1024 // MB로 변환
            print("📊 현재 메모리 사용량: \(usedMemory) MB")
        }
    }
}
```

**🔍 코드 설명:**
- **약한 참조**: 중요하지 않은 의존성에 약한 참조를 사용하여 메모리 회수 허용
- **강한 참조**: 지속되어야 하는 중요한 의존성에 강한 참조 유지
- **자동 재생성**: 다시 접근할 때 해제된 의존성을 재생성
- **메모리 모니터링**: 메모리 압박을 모니터링하고 대응하는 도구 제공

## ⚡ 지연 로딩 전략

### 고급 지연 초기화

```swift
/// 의존성 우선순위 지정을 통한 고급 지연 로딩
/// 이 패턴은 비용이 많이 드는 초기화를 지연시켜 앱 시작 시간을 최적화합니다
class LazyDependencyManager {

    // MARK: - 커스텀 로직을 가진 지연 프로퍼티

    /// 비용이 많이 드는 머신러닝 서비스 - 필요할 때만 초기화
    /// ML 서비스는 종종 큰 메모리 사용량과 긴 초기화 시간을 가집니다
    private lazy var mlService: MachineLearningService? = {
        print("🧠 ML 서비스 초기화 중 (비용이 많이 드는 작업)")
        let startTime = Date()

        let service = WeaveDI.Container.live.resolve(MachineLearningService.self)

        let initTime = Date().timeIntervalSince(startTime)
        print("🧠 ML 서비스가 \(initTime)초에 초기화됨")

        return service
    }()

    /// 이미지 처리 서비스 - 메모리 모니터링과 함께 지연 로드
    /// 이미지 프로세서는 메모리 집약적일 수 있습니다
    private lazy var imageProcessor: ImageProcessingService? = {
        print("🖼️ 이미지 프로세서 초기화 중")

        // 초기화 전 사용 가능한 메모리 확인
        if isMemoryAvailable() {
            let service = WeaveDI.Container.live.resolve(ImageProcessingService.self)
            print("🖼️ 이미지 프로세서 초기화됨")
            return service
        } else {
            print("⚠️ 이미지 프로세서를 위한 메모리 부족")
            return nil
        }
    }()

    /// 비디오 처리 서비스 - 가장 무거운 의존성, 가장 적극적인 지연 로딩
    /// 비디오 처리는 상당한 리소스가 필요합니다
    private lazy var videoProcessor: VideoProcessingService? = {
        print("🎥 비디오 프로세서 초기화 중 (매우 비용이 많이 듦)")

        // 기기가 충분한 리소스를 가진 경우에만 초기화
        guard hasVideoCapabilities() else {
            print("❌ 기기에 비디오 처리 기능 부족")
            return nil
        }

        let startTime = Date()
        let service = WeaveDI.Container.live.resolve(VideoProcessingService.self)
        let initTime = Date().timeIntervalSince(startTime)

        print("🎥 비디오 프로세서가 \(initTime)초에 초기화됨")
        return service
    }()

    // MARK: - 우선순위별 초기화

    /// 우선순위 순서로 의존성 초기화
    /// 중요한 의존성이 먼저 초기화됩니다
    func initializeDependenciesByPriority() async {
        print("🚀 우선순위별 의존성 초기화 시작")

        // 우선순위 1: 필수 서비스 (빠른 초기화)
        await initializeEssentialServices()

        // 우선순위 2: 중요하지만 중요하지 않은 서비스 (중간 시간)
        await initializeImportantServices()

        // 우선순위 3: 선택적 서비스 (지연 가능)
        await initializeOptionalServices()

        print("✅ 우선순위별 초기화 완료")
    }

    /// 앱이 기능하지 못하는 필수 서비스 초기화
    /// 앱 시작 시 즉시 로드됩니다
    private func initializeEssentialServices() async {
        print("⚡ 필수 서비스 초기화 중...")

        await withTaskGroup(of: Void.self) { group in
            // 인증 - 사용자 경험에 중요
            group.addTask {
                _ = WeaveDI.Container.live.resolve(AuthService.self)
                print("🔐 인증 서비스 준비됨")
            }

            // 네트워크 서비스 - 대부분의 작업에 필요
            group.addTask {
                _ = WeaveDI.Container.live.resolve(NetworkService.self)
                print("🌐 네트워크 서비스 준비됨")
            }

            // 로거 - 디버깅과 모니터링에 필요
            group.addTask {
                _ = WeaveDI.Container.live.resolve(LoggerProtocol.self)
                print("📝 로거 준비됨")
            }
        }

        print("✅ 필수 서비스 초기화됨")
    }

    /// 중요하지만 중요하지 않은 서비스 초기화
    /// 기본 기능에 필요하지 않지만 사용자 경험을 향상시킵니다
    private func initializeImportantServices() async {
        print("📦 중요한 서비스 초기화 중...")

        // 리소스 사용량을 관리하기 위해 순차적으로 초기화
        let cacheService = WeaveDI.Container.live.resolve(CacheService.self)
        if cacheService != nil {
            print("💾 캐시 서비스 준비됨")
        }

        let pushService = WeaveDI.Container.live.resolve(PushNotificationService.self)
        if pushService != nil {
            print("🔔 푸시 알림 서비스 준비됨")
        }

        let analyticsService = WeaveDI.Container.live.resolve(AnalyticsService.self)
        if analyticsService != nil {
            print("📊 분석 서비스 준비됨")
        }

        print("✅ 중요한 서비스 초기화됨")
    }

    /// 사용자 경험을 향상시키는 선택적 서비스 초기화
    /// 실제로 필요할 때까지 안전하게 지연 가능합니다
    private func initializeOptionalServices() async {
        print("🎨 선택적 서비스 초기화 중...")

        // 이러한 서비스는 백그라운드에서 초기화됩니다
        Task.detached(priority: .background) { [weak self] in
            // 기기가 지원하는 경우 ML 서비스 미리 로드
            if await self?.isMLCapable() == true {
                _ = self?.mlService
            }

            // 더 나은 UX를 위해 이미지 프로세서 미리 로드
            _ = self?.imageProcessor

            print("🎨 선택적 서비스 초기화 완료")
        }
    }

    // MARK: - 리소스 확인

    /// 리소스 집약적인 작업을 위한 충분한 메모리가 있는지 확인
    private func isMemoryAvailable() -> Bool {
        let availableMemory = getAvailableMemory()
        let requiredMemory: UInt64 = 100 * 1024 * 1024 // 100 MB 필요

        return availableMemory > requiredMemory
    }

    /// 기기가 머신러닝 작업을 지원하는지 확인
    private func isMLCapable() async -> Bool {
        // 기기 기능, OS 버전, 사용 가능한 메모리 등 확인
        guard #available(iOS 13.0, *) else { return false }
        return isMemoryAvailable() && hasMLFramework()
    }

    /// 기기가 비디오 처리 기능을 가지는지 확인
    private func hasVideoCapabilities() -> Bool {
        // 하드웨어 비디오 인코딩/디코딩 지원 확인
        return isMemoryAvailable() && hasVideoHardware()
    }

    /// 사용 가능한 시스템 메모리 가져오기
    private func getAvailableMemory() -> UInt64 {
        // 시스템 메모리를 쿼리하는 구현
        // 데모를 위해 단순화됨
        return 512 * 1024 * 1024 // 512 MB 사용 가능하다고 가정
    }

    /// ML 프레임워크가 사용 가능한지 확인
    private func hasMLFramework() -> Bool {
        // Core ML 또는 기타 ML 프레임워크가 사용 가능한지 확인
        return true // 데모를 위해 단순화됨
    }

    /// 하드웨어 비디오 처리가 사용 가능한지 확인
    private func hasVideoHardware() -> Bool {
        // 하드웨어 비디오 인코딩/디코딩 기능 확인
        return true // 데모를 위해 단순화됨
    }
}
```

**🔍 코드 설명:**
- **지연 프로퍼티**: 자동 지연 초기화를 위해 Swift의 lazy 키워드 사용
- **우선순위 기반 로딩**: 중요도 순으로 의존성 초기화
- **리소스 확인**: 비용이 많이 드는 초기화 전 기기 기능 확인
- **백그라운드 초기화**: 중요하지 않은 의존성에 백그라운드 작업 사용

## 📋 프로덕션 최적화 체크리스트

### ✅ 성능 최적화 단계

1. **Hot Path 식별**
   - 앱을 프로파일링하여 자주 접근되는 의존성 찾기
   - 성능 모니터링을 사용하여 해결 시간 추적
   - 가장 영향력 있는 영역에 최적화 노력 집중

2. **캐싱 전략 구현**
   - 자주 접근되는 의존성 캐시
   - 비용이 많이 드는 초기화에 지연 로딩 사용
   - 최적의 리소스 사용을 위한 메모리 인식 캐싱 구현

3. **메모리 사용량 최적화**
   - 중요하지 않은 의존성에 약한 참조 사용
   - 메모리 압박 처리 구현
   - 의존성 해결 중 메모리 증가 모니터링

4. **벤치마킹과 측정**
   - 자동화된 성능 테스트 설정
   - 시간에 따른 성능 메트릭 추적
   - 다양한 최적화 전략 비교

5. **프로덕션 모니터링**
   - 런타임 성능 모니터링 구현
   - 성능 저하에 대한 알림 설정
   - 실제 사용 데이터를 기반으로 지속적 최적화

---

**축하합니다!** 이제 프로덕션 애플리케이션을 위한 WeaveDI 성능 최적화 지식과 도구를 가지고 있습니다. 이러한 기법을 사용하여 빠르고 효율적이며 확장 가능한 iOS 앱을 구축하세요.
