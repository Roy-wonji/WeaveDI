import Foundation
import LogMacro

// MARK: - CounterService Protocol

protocol CounterService: Sendable {
    func increment(_ value: Int) -> Int
    func decrement(_ value: Int) -> Int
    func reset() -> Int
}

// MARK: - CounterService Implementation

final class DefaultCounterService: CounterService {
    func increment(_ value: Int) -> Int {
        let newValue = value + 1
        #logInfo("🔢 [CounterService] 증가: \(value) → \(newValue)")
        return newValue
    }

    func decrement(_ value: Int) -> Int {
        let newValue = value - 1
        #logInfo("🔢 [CounterService] 감소: \(value) → \(newValue)")
        return newValue
    }

    func reset() -> Int {
        #logInfo("🔢 [CounterService] 리셋됨")
        return 0
    }
}