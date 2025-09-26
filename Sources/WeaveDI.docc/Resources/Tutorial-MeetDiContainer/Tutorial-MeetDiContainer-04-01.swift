import Foundation

// MARK: - Clean Architecture: Repository Layer

/// 데이터 저장소를 추상화하는 Repository 프로토콜
protocol CounterRepository: Sendable {
    func getCurrentCount() async -> Int
    func saveCount(_ count: Int) async
    func getCountHistory() async -> [CounterHistory]
}

/// Repository 구현체
final class UserDefaultsCounterRepository: CounterRepository {
    private let userDefaults = UserDefaults.standard
    private let countKey = "saved_counter_value"
    private let historyKey = "counter_history"

    func getCurrentCount() async -> Int {
        let count = userDefaults.integer(forKey: countKey)
        print("💾 [Repository] 저장된 카운트 불러오기: \(count)")
        return count
    }

    func saveCount(_ count: Int) async {
        userDefaults.set(count, forKey: countKey)

        // 히스토리에도 추가
        var history = await getCountHistory()
        let newEntry = CounterHistory(
            count: count,
            timestamp: Date(),
            action: count > (history.last?.count ?? 0) ? "증가" : "감소"
        )
        history.append(newEntry)

        // 최근 10개만 유지
        if history.count > 10 {
            history = Array(history.suffix(10))
        }

        if let encoded = try? JSONEncoder().encode(history) {
            userDefaults.set(encoded, forKey: historyKey)
        }

        print("💾 [Repository] 카운트 저장: \(count)")
    }

    func getCountHistory() async -> [CounterHistory] {
        guard let data = userDefaults.data(forKey: historyKey),
              let history = try? JSONDecoder().decode([CounterHistory].self, from: data) else {
            return []
        }
        return history
    }
}

// MARK: - CounterHistory Model

struct CounterHistory: Codable, Sendable {
    let count: Int
    let timestamp: Date
    let action: String

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}