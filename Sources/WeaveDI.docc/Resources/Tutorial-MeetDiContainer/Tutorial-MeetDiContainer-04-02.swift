import Foundation
import DiContainer

// MARK: - Clean Architecture: UseCase Layer

/// 비즈니스 로직을 캡슐화하는 UseCase
protocol CounterUseCase: Sendable {
    func loadInitialCount() async -> Int
    func incrementCounter(current: Int) async -> Int
    func decrementCounter(current: Int) async -> Int
    func resetCounter() async -> Int
    func getCounterHistory() async -> [CounterHistory]
}

/// UseCase 구현체
final class DefaultCounterUseCase: CounterUseCase {
    // Repository 의존성 주입
    @Inject private var repository: CounterRepository?
    @Inject private var counterService: CounterService?
    @Factory private var logger: LoggingService?

    func loadInitialCount() async -> Int {
        logger?.logInfo("초기 카운트 로딩 시작")

        guard let repository else {
            logger?.logInfo("Repository를 찾을 수 없음, 기본값 0 반환")
            return 0
        }

        let count = await repository.getCurrentCount()
        logger?.logInfo("초기 카운트 로딩 완료: \(count)")
        return count
    }

    func incrementCounter(current: Int) async -> Int {
        guard let repository, let counterService else {
            logger?.logInfo("필수 서비스를 찾을 수 없음")
            return current
        }

        // 비즈니스 로직: CounterService로 계산
        let newCount = counterService.increment(current)

        // 데이터 영속화
        await repository.saveCount(newCount)

        logger?.logAction("카운터 증가: \(current) → \(newCount)")
        return newCount
    }

    func decrementCounter(current: Int) async -> Int {
        guard let repository, let counterService else {
            logger?.logInfo("필수 서비스를 찾을 수 없음")
            return current
        }

        // 비즈니스 규칙: 0 이하로 내려가지 않음
        if current <= 0 {
            logger?.logAction("카운터 감소 차단: 이미 0 이하입니다")
            return current
        }

        let newCount = counterService.decrement(current)
        await repository.saveCount(newCount)

        logger?.logAction("카운터 감소: \(current) → \(newCount)")
        return newCount
    }

    func resetCounter() async -> Int {
        guard let repository, let counterService else {
            logger?.logInfo("필수 서비스를 찾을 수 없음")
            return 0
        }

        let resetValue = counterService.reset()
        await repository.saveCount(resetValue)

        logger?.logAction("카운터 리셋됨")
        return resetValue
    }

    func getCounterHistory() async -> [CounterHistory] {
        guard let repository else {
            logger?.logInfo("Repository를 찾을 수 없음, 빈 히스토리 반환")
            return []
        }

        let history = await repository.getCounterHistory()
        logger?.logInfo("히스토리 로딩: \(history.count)개 항목")
        return history
    }
}