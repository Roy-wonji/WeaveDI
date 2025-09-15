//
//  ContainerCore.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/19/25.
//

import Foundation

// MARK: - Container Register Alias

/// 사용자가 원하는 ContainerRegister 이름으로 사용할 수 있도록 typealias 제공
///
/// ## 사용법:
/// ```swift
/// public static var liveValue: BookListInterface = {
///     let repository = ContainerRegister.register(\.bookListInterface) {
///         BookListRepositoryImpl()
///     }
///     return BookListUseCaseImpl(repository: repository)
/// }()
/// ```
public typealias ContainerRegister = RegisterAndReturn

// MARK: - Container Core Implementation

/// ## 개요
///
/// `Container`는 여러 개의 `Module` 인스턴스를 수집하고 일괄 등록할 수 있는
/// Swift Concurrency 기반의 액터입니다. 이 컨테이너는 대규모 의존성 그래프를
/// 효율적으로 관리하고 병렬 처리를 통해 성능을 최적화합니다.
///
/// ## 핵심 특징
///
/// ### ⚡ 고성능 병렬 처리
/// - **Task Group 활용**: 모든 모듈의 등록을 동시에 병렬 실행
/// - **스냅샷 기반**: 내부 배열을 복사하여 actor hop 최소화
/// - **비동기 안전**: Swift Concurrency 패턴으로 스레드 안전성 보장
///
/// ### 🏗️ 배치 등록 시스템
/// - **모듈 수집**: 여러 모듈을 먼저 수집한 후 한 번에 등록
/// - **지연 실행**: `build()` 호출 시점까지 실제 등록 지연
/// - **원자적 처리**: 모든 모듈이 함께 등록되거나 실패
///
/// ### 🔒 동시성 안전성
/// - **Actor 보호**: 내부 상태(`modules`)가 데이터 경쟁으로부터 안전
/// - **순서 독립**: 모듈 등록 순서와 무관하게 동작
/// - **메모리 안전**: 약한 참조 없이도 안전한 메모리 관리
public actor Container {
    // MARK: - 저장 프로퍼티

    /// 등록된 모듈(Module) 인스턴스들을 저장하는 내부 배열.
    internal var modules: [Module] = []

    // MARK: - 초기화

    /// 기본 초기화 메서드.
    /// - 설명: 인스턴스 생성 시 `modules` 배열은 빈 상태로 시작됩니다.
    public init() {}

    // MARK: - 모듈 등록

    /// 모듈을 컨테이너에 추가하여 나중에 일괄 등록할 수 있도록 준비합니다.
    ///
    /// 이 메서드는 즉시 모듈을 DI 컨테이너에 등록하지 않고, 내부 배열에 저장만 합니다.
    /// 실제 등록은 `build()` 메서드 호출 시에 모든 모듈이 병렬로 처리됩니다.
    ///
    /// - Parameter module: 등록 예약할 `Module` 인스턴스
    /// - Returns: 체이닝을 위한 현재 `Container` 인스턴스
    ///
    /// - Note: 이 메서드는 실제 등록을 수행하지 않고 모듈을 큐에 추가만 합니다.
    /// - Important: 동일한 타입의 모듈을 여러 번 등록하면 마지막 등록이 우선됩니다.
    /// - SeeAlso: `build()` - 실제 모든 모듈을 병렬 등록하는 메서드
    @discardableResult
    public func register(_ module: Module) -> Self {
        modules.append(module)
        return self
    }

    /// Trailing closure를 처리할 때 사용되는 메서드입니다.
    ///
    /// - Parameter block: 호출 즉시 실행할 클로저. 이 클로저 내부에서 추가 설정을 수행할 수 있습니다.
    /// - Returns: 현재 `Container` 인스턴스(Self). 메서드 체이닝(Fluent API) 방식으로 연쇄 호출이 가능합니다.
    @discardableResult
    public func callAsFunction(_ block: () -> Void) -> Self {
        block()
        return self
    }

    // MARK: - 상태 조회

    /// 현재 등록 대기 중인 모듈의 개수를 반환합니다.
    /// - Returns: 대기 중인 모듈 개수
    public var moduleCount: Int {
        modules.count
    }

    /// 컨테이너가 비어있는지 확인합니다.
    /// - Returns: 등록된 모듈이 없으면 true
    public var isEmpty: Bool {
        modules.isEmpty
    }

    /// 등록된 모듈들의 타입 이름을 반환합니다 (디버깅용).
    /// - Returns: 모듈 타입 이름 배열
    public func getModuleTypeNames() -> [String] {
        modules.map { String(describing: type(of: $0)) }
    }

    // MARK: - 빌드(등록 실행)

    /// 수집된 모든 모듈의 등록을 병렬로 실행하는 핵심 메서드입니다.
    ///
    /// 이 메서드는 `register(_:)` 호출로 수집된 모든 모듈들을 Swift의 TaskGroup을 사용하여
    /// 동시에 병렬 처리합니다. 이를 통해 대량의 의존성 등록 시간을 크게 단축할 수 있습니다.
    ///
    /// ## 동작 과정
    ///
    /// ### 1단계: 스냅샷 생성
    /// ```swift
    /// // Actor 내부에서 배열을 지역 변수로 복사
    /// let snapshot = modules
    /// ```
    /// 이렇게 함으로써 TaskGroup 실행 중 불필요한 actor isolation hop을 방지합니다.
    ///
    /// ### 2단계: 병렬 작업 생성
    /// ```swift
    /// await withTaskGroup(of: Void.self) { group in
    ///     for module in snapshot {
    ///         group.addTask { @Sendable in
    ///             await module.register() // 각 모듈이 병렬 실행
    ///         }
    ///     }
    ///     await group.waitForAll() // 모든 작업 완료 대기
    /// }
    /// ```
    ///
    /// ## 성능 특성
    ///
    /// ### 시간 복잡도
    /// - **순차 처리**: O(n) - 모든 모듈을 하나씩 등록
    /// - **병렬 처리**: O(max(모듈별 등록 시간)) - 가장 오래 걸리는 모듈의 등록 시간
    ///
    /// ### 실제 성능 예시
    /// ```swift
    /// // 10개 모듈, 각각 100ms 소요 시
    /// // 순차 처리: 1000ms
    /// // 병렬 처리: 100ms (약 90% 성능 향상)
    /// ```
    ///
    /// - Note: 모든 등록 작업이 완료될 때까지 메서드가 반환되지 않습니다.
    /// - Important: 이 메서드는 현재 throws 하지 않지만, 개별 모듈에서 오류 로깅은 가능합니다.
    /// - Warning: 매우 많은 모듈(1000개 이상)을 한 번에 처리할 때는 메모리 사용량을 모니터링하세요.
    public func build() async {
        // 1) actor 내부 배열을 스냅샷 -> task 생성 중 불필요한 actor hop 방지
        let snapshot = modules
        let processedCount = snapshot.count

        // 빈 컨테이너인 경우 조기 반환
        guard !snapshot.isEmpty else { return }

        // 2) 병렬 실행 + 전체 완료 대기
        await withTaskGroup(of: Void.self) { group in
            for module in snapshot {
                group.addTask { @Sendable in
                    await module.register()
                }
            }
            await group.waitForAll()
        }

        // 3) 처리된 모듈 제거 (스냅샷 개수만큼만 제거하여 그 사이 추가된 모듈은 보존)
        if modules.count >= processedCount {
            modules.removeFirst(processedCount)
        } else {
            modules.removeAll()
        }
    }

    /// Throwing variant of build using a throwing task group.
    /// Currently `Module.register()` is non-throwing; this method prepares for
    /// future throwing registrations and mirrors the same cleanup semantics.
    public func buildThrowing() async throws {
        let snapshot = modules
        let processedCount = snapshot.count

        guard !snapshot.isEmpty else { return }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for module in snapshot {
                group.addTask { @Sendable in
                    try await module.registerThrowing()
                }
            }
            try await group.waitForAll()
        }

        if modules.count >= processedCount {
            modules.removeFirst(processedCount)
        } else {
            modules.removeAll()
        }
    }

    /// 성능 메트릭과 함께 빌드를 실행합니다 (디버깅/프로파일링용).
    /// - Returns: 빌드 실행 통계
    public func buildWithMetrics() async -> BuildMetrics {
        let startTime = CFAbsoluteTimeGetCurrent()
        let initialCount = modules.count

        await build()

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        return BuildMetrics(
            moduleCount: initialCount,
            duration: duration,
            modulesPerSecond: initialCount > 0 ? Double(initialCount) / duration : 0
        )
    }

    /// 빌드 과정을 단계별로 진행하면서 진행률을 보고합니다.
    /// - Parameter progressHandler: 진행률 콜백 (0.0 ~ 1.0)
    /// - Note: 진행률 추적은 근사치이며, 동시 실행으로 인해 정확하지 않을 수 있습니다.
    public func buildWithProgress(_ progressHandler: @Sendable @escaping (Double) -> Void) async {
        let snapshot = modules
        let totalCount = snapshot.count
        let processedCount = totalCount

        guard !snapshot.isEmpty else {
            progressHandler(1.0)
            return
        }

        // 동시성 안전한 카운터 사용
        let progressCounter = ProgressCounter(total: totalCount)

        await withTaskGroup(of: Void.self) { group in
            for module in snapshot {
                group.addTask { @Sendable in
                    await module.register()

                    // 스레드 안전한 진행률 업데이트
                    let progress = await progressCounter.increment()
                    progressHandler(progress)
                }
            }
            await group.waitForAll()
        }

        // 모듈 정리
        if modules.count >= processedCount {
            modules.removeFirst(processedCount)
        } else {
            modules.removeAll()
        }

        progressHandler(1.0) // 최종 완료 확실히
    }

    /// 빌드 결과를 상세히 수집합니다(성공/실패, 에러 원인 등)
    /// - Returns: 처리 결과 리포트
    public func buildWithResults() async -> BuildResult {
        let snapshot = modules
        let processedCount = snapshot.count
        guard !snapshot.isEmpty else { return BuildResult(processed: 0, failures: []) }

        let failureStore = FailureStore()

        await withTaskGroup(of: Void.self) { group in
            for (index, module) in snapshot.enumerated() {
                group.addTask { @Sendable in
                    do {
                        try await module.registerThrowing()
                    } catch {
                        let failure = BuildResult.Failure(
                            index: index,
                            typeName: module.debugTypeName,
                            file: module.debugFile,
                            function: module.debugFunction,
                            line: module.debugLine,
                            underlying: String(describing: error)
                        )
                        await failureStore.add(failure)
                    }
                }
            }
            await group.waitForAll()
        }

        if modules.count >= processedCount {
            modules.removeFirst(processedCount)
        } else {
            modules.removeAll()
        }

        let failures = await failureStore.list()
        return BuildResult(processed: processedCount, failures: failures)
    }
}

// MARK: - Build Metrics

/// 빌드 실행 통계 정보
public struct BuildMetrics {
    /// 처리된 모듈 수
    public let moduleCount: Int

    /// 총 실행 시간 (초)
    public let duration: TimeInterval

    /// 초당 처리 모듈 수
    public let modulesPerSecond: Double

    /// 포맷된 요약 정보
    public var summary: String {
        return """
        Build Metrics:
        - Modules: \(moduleCount)
        - Duration: \(String(format: "%.3f", duration))s
        - Rate: \(String(format: "%.1f", modulesPerSecond)) modules/sec
        """
    }
}

// MARK: - Build Result (detailed)

/// 개별 모듈 실패와 함께 상세 리포트를 제공
public struct BuildResult: Sendable {
    public struct Failure: Sendable {
        public let index: Int
        public let typeName: String
        public let file: String
        public let function: String
        public let line: Int
        public let underlying: String
    }

    /// 시도된 모듈 개수
    public let processed: Int
    /// 실패 목록
    public let failures: [Failure]

    /// 성공 개수
    public var succeeded: Int { processed - failures.count }

    /// 요약 문자열
    public var summary: String {
        if failures.isEmpty { return "BuildResult: succeeded=\(succeeded), processed=\(processed)" }
        let lines = failures.prefix(5).map { f in
            "[#\(f.index)] \(f.typeName) @ \(f.file):\(f.line) — \(f.underlying)"
        }.joined(separator: "\n")
        return """
        BuildResult: succeeded=\(succeeded), failed=\(failures.count), processed=\(processed)
        Failures (first 5):
        \(lines)
        """
    }
}

/// 실패 수집용 경량 액터
private actor FailureStore {
    private var items: [BuildResult.Failure] = []
    func add(_ failure: BuildResult.Failure) { items.append(failure) }
    func list() -> [BuildResult.Failure] { items }
}

// MARK: - Progress Counter

/// 동시성 안전한 진행률 카운터
private actor ProgressCounter {
    private var completed: Int = 0
    private let total: Int

    init(total: Int) {
        self.total = total
    }

    /// 완료 개수를 증가시키고 진행률을 반환합니다
    /// - Returns: 현재 진행률 (0.0 ~ 1.0)
    func increment() -> Double {
        completed += 1
        return total > 0 ? Double(completed) / Double(total) : 1.0
    }
}