//
//  ContainerBuildEngine.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/19/25.
//

import Foundation

// MARK: - Container Build Engine

public extension Container {
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
    func build() async {
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

    /// 성능 메트릭과 함께 빌드를 실행합니다 (디버깅/프로파일링용).
    /// - Returns: 빌드 실행 통계
    func buildWithMetrics() async -> BuildMetrics {
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
    func buildWithProgress(_ progressHandler: @Sendable @escaping (Double) -> Void) async {
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