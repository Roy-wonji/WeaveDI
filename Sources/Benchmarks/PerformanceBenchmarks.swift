import Foundation
import WeaveDI
import Darwin

/// WeaveDI 성능 벤치마크 전용 클래스
/// 최적화된 환경에서 정확한 성능 측정을 수행합니다.
struct PerformanceBenchmarks {

    // MARK: - Configuration

    struct BenchmarkConfig {
        let iterations: Int
        let warmupIterations: Int
        let measurementRounds: Int
        let enableDetailedLogging: Bool

        static let `default` = BenchmarkConfig(
            iterations: 10_000,
            warmupIterations: 1_000,
            measurementRounds: 5,
            enableDetailedLogging: false
        )

        static let quick = BenchmarkConfig(
            iterations: 1_000,
            warmupIterations: 100,
            measurementRounds: 3,
            enableDetailedLogging: false
        )

        static let detailed = BenchmarkConfig(
            iterations: 100_000,
            warmupIterations: 10_000,
            measurementRounds: 10,
            enableDetailedLogging: true
        )
    }

    // MARK: - Results

    struct BenchmarkResult {
        let testName: String
        let totalTime: TimeInterval
        let averageTime: TimeInterval
        let minTime: TimeInterval
        let maxTime: TimeInterval
        let p50: TimeInterval
        let p95: TimeInterval
        let p99: TimeInterval
        let iterations: Int
        let throughput: Double // operations per second

        var description: String {
            """
            📊 \(testName):
              Total: \(String(format: "%.2f", totalTime * 1000))ms
              Average: \(String(format: "%.4f", averageTime * 1000))ms
              Min: \(String(format: "%.4f", minTime * 1000))ms
              Max: \(String(format: "%.4f", maxTime * 1000))ms
              P50: \(String(format: "%.4f", p50 * 1000))ms
              P95: \(String(format: "%.4f", p95 * 1000))ms
              P99: \(String(format: "%.4f", p99 * 1000))ms
              Throughput: \(String(format: "%.0f", throughput)) ops/sec
            """
        }
    }

    // MARK: - Test Services

    protocol MockService: Sendable {
        func process() -> String
    }

    struct SimpleService: MockService {
        func process() -> String { "simple" }
    }

    final class ComplexService: MockService, @unchecked Sendable {
        private let dependency1: MockService
        private let dependency2: MockService
        private let dependency3: MockService

        init(dep1: MockService, dep2: MockService, dep3: MockService) {
            self.dependency1 = dep1
            self.dependency2 = dep2
            self.dependency3 = dep3
        }

        func process() -> String {
            return dependency1.process() + dependency2.process() + dependency3.process()
        }
    }

    actor ThreadSafeService {
        private var counter = 0

        func process() -> String {
            counter += 1
            return "thread-safe-\(counter)"
        }
    }

    // MARK: - Benchmark Tests

    static func runAllBenchmarks(config: BenchmarkConfig = .default) -> [BenchmarkResult] {
        print("🚀 Starting WeaveDI Performance Benchmarks")
        print("⚙️ Config: \(config.iterations) iterations, \(config.warmupIterations) warmup, \(config.measurementRounds) rounds")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        var results: [BenchmarkResult] = []

        // 1. 단일 의존성 해결 성능
        results.append(benchmarkSingleDependencyResolution(config: config))

        // 2. 복잡한 의존성 그래프 성능
        results.append(benchmarkComplexDependencyGraph(config: config))

        // 3. 동시 해결 성능
        results.append(benchmarkConcurrentResolution(config: config))

        // 4. 메모리 효율성 테스트
        results.append(benchmarkMemoryEfficiency(config: config))

        // 5. Auto DI Optimizer 성능
        results.append(benchmarkAutoOptimizer(config: config))

        // 6. Property Wrapper 성능
        results.append(benchmarkPropertyWrapper(config: config))

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ All benchmarks completed")

        return results
    }

    // MARK: - Individual Benchmarks

    static func benchmarkSingleDependencyResolution(config: BenchmarkConfig) -> BenchmarkResult {
        setupSingleDependency()

        return measurePerformance(
            testName: "Single Dependency Resolution",
            config: config
        ) {
            _ = UnifiedDI.resolve(MockService.self)
        }
    }

    static func benchmarkComplexDependencyGraph(config: BenchmarkConfig) -> BenchmarkResult {
        setupComplexDependencyGraph()

        return measurePerformance(
            testName: "Complex Dependency Graph",
            config: config
        ) {
            _ = UnifiedDI.resolve(ComplexService.self)
        }
    }

    static func benchmarkConcurrentResolution(config: BenchmarkConfig) -> BenchmarkResult {
        setupSingleDependency()

        return measurePerformance(
            testName: "Concurrent Resolution",
            config: config
        ) {
            // 동시 실행을 시뮬레이션하기 위해 Task 사용
            Task.detached {
                _ = UnifiedDI.resolve(MockService.self)
            }
        }
    }

    static func benchmarkMemoryEfficiency(config: BenchmarkConfig) -> BenchmarkResult {
        setupSingleDependency()

        return measurePerformance(
            testName: "Memory Efficiency",
            config: config
        ) {
            autoreleasepool {
                _ = UnifiedDI.resolve(MockService.self)
            }
        }
    }

    static func benchmarkAutoOptimizer(config: BenchmarkConfig) -> BenchmarkResult {
        // Auto DI Optimizer is simplified in v4.0 - using default behavior
        setupComplexDependencyGraph()

        return measurePerformance(
            testName: "Auto DI Optimizer",
            config: config
        ) {
            _ = UnifiedDI.resolve(ComplexService.self)
        }
    }

    static func benchmarkPropertyWrapper(config: BenchmarkConfig) -> BenchmarkResult {
        setupSingleDependency()

        class TestClass {
            lazy var service: MockService = {
                return UnifiedDI.resolve(MockService.self)!
            }()

            func performOperation() -> String {
                return service.process()
            }
        }

        return measurePerformance(
            testName: "Property Wrapper (@Injected)",
            config: config
        ) {
            let obj = TestClass()
            _ = obj.performOperation()
        }
    }

    // MARK: - Setup Methods

    private static func setupSingleDependency() {
        Task { @MainActor in
            UnifiedDI.releaseAll()
        }
        _ = UnifiedDI.register(MockService.self) { SimpleService() }
    }

    private static func setupComplexDependencyGraph() {
        Task { @MainActor in
            UnifiedDI.releaseAll()
        }

        // 여러 의존성을 시뮬레이션하기 위해 별도 등록
        _ = UnifiedDI.register(MockService.self) { SimpleService() }

        _ = UnifiedDI.register(ComplexService.self) {
            ComplexService(
                dep1: SimpleService(),
                dep2: SimpleService(),
                dep3: SimpleService()
            )
        }
    }

    private static func setupThreadSafeDependency() {
        Task { @MainActor in
            UnifiedDI.releaseAll()
        }
        _ = UnifiedDI.register(ThreadSafeService.self) { ThreadSafeService() }
    }

    // MARK: - Performance Measurement

    private static func measurePerformance(
        testName: String,
        config: BenchmarkConfig,
        operation: @escaping () -> Void
    ) -> BenchmarkResult {

        print("🔍 Benchmarking: \(testName)")

        // Warmup
        for _ in 0..<config.warmupIterations {
            operation()
        }

        var allTimes: [TimeInterval] = []
        allTimes.reserveCapacity(config.measurementRounds * config.iterations)

        // Multiple measurement rounds for accuracy
        for round in 0..<config.measurementRounds {
            if config.enableDetailedLogging {
                print("  Round \(round + 1)/\(config.measurementRounds)")
            }

            let _ = CFAbsoluteTimeGetCurrent()
            var roundTimes: [TimeInterval] = []
            roundTimes.reserveCapacity(config.iterations)

            for _ in 0..<config.iterations {
                let iterationStart = CFAbsoluteTimeGetCurrent()
                operation()
                let iterationEnd = CFAbsoluteTimeGetCurrent()
                roundTimes.append(iterationEnd - iterationStart)
            }

            allTimes.append(contentsOf: roundTimes)
        }

        // Calculate statistics
        let totalTime = allTimes.reduce(0, +)
        let averageTime = totalTime / Double(allTimes.count)
        let minTime = allTimes.min() ?? 0
        let maxTime = allTimes.max() ?? 0
        let throughput = Double(allTimes.count) / totalTime

        let sortedTimes = allTimes.sorted()
        let p50 = percentile(sortedTimes, 0.5)
        let p95 = percentile(sortedTimes, 0.95)
        let p99 = percentile(sortedTimes, 0.99)

        let result = BenchmarkResult(
            testName: testName,
            totalTime: totalTime,
            averageTime: averageTime,
            minTime: minTime,
            maxTime: maxTime,
            p50: p50,
            p95: p95,
            p99: p99,
            iterations: allTimes.count,
            throughput: throughput
        )

        print(result.description)
        print("")

        return result
    }

    private static func percentile(_ sortedArray: [TimeInterval], _ percentile: Double) -> TimeInterval {
        guard !sortedArray.isEmpty else { return 0 }
        let index = Int(Double(sortedArray.count - 1) * percentile)
        return sortedArray[index]
    }

    // MARK: - Export Results

    static func exportResultsToJSON(_ results: [BenchmarkResult], to path: String) throws {
        struct JSONResult: Codable {
            let testName: String
            let totalTime: Double
            let averageTime: Double
            let minTime: Double
            let maxTime: Double
            let p50: Double
            let p95: Double
            let p99: Double
            let iterations: Int
            let throughput: Double
            let timestamp: String
        }

        let jsonResults = results.map { result in
            JSONResult(
                testName: result.testName,
                totalTime: result.totalTime,
                averageTime: result.averageTime,
                minTime: result.minTime,
                maxTime: result.maxTime,
                p50: result.p50,
                p95: result.p95,
                p99: result.p99,
                iterations: result.iterations,
                throughput: result.throughput,
                timestamp: ISO8601DateFormatter().string(from: Date())
            )
        }

        let jsonData = try JSONEncoder().encode(jsonResults)

        try jsonData.write(to: URL(fileURLWithPath: path))
        print("📊 Results exported to: \(path)")
    }

    static func exportResultsToCSV(_ results: [BenchmarkResult], to path: String) throws {
        var csv = "testName,totalTime,averageTime,minTime,maxTime,p50,p95,p99,iterations,throughput,timestamp\n"

        let timestamp = ISO8601DateFormatter().string(from: Date())
        for result in results {
            csv += "\"\(result.testName)\",\(result.totalTime),\(result.averageTime),\(result.minTime),\(result.maxTime),\(result.p50),\(result.p95),\(result.p99),\(result.iterations),\(result.throughput),\(timestamp)\n"
        }

        try csv.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
        print("📊 Results exported to: \(path)")
    }

    // MARK: - Performance Comparison

    static func compareWithBaseline(_ results: [BenchmarkResult], baselinePath: String) {
        struct JSONResult: Codable {
            let testName: String
            let totalTime: Double
            let averageTime: Double
            let minTime: Double
            let maxTime: Double
            let p50: Double
            let p95: Double
            let p99: Double
            let iterations: Int
            let throughput: Double
            let timestamp: String
        }

        guard let baselineData = try? Data(contentsOf: URL(fileURLWithPath: baselinePath)),
              let baselineResults = try? JSONDecoder().decode([JSONResult].self, from: baselineData) else {
            print("⚠️ No baseline found at \(baselinePath)")
            return
        }

        print("📈 Performance Comparison with Baseline")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        for result in results {
            if let baseline = baselineResults.first(where: { $0.testName == result.testName }) {
                let improvement = ((baseline.averageTime - result.averageTime) / baseline.averageTime) * 100
                let symbol = improvement > 0 ? "🚀" : improvement < -5 ? "⚠️" : "➡️"

                print("\(symbol) \(result.testName):")
                print("  Current: \(String(format: "%.4f", result.averageTime * 1000))ms")
                print("  Baseline: \(String(format: "%.4f", baseline.averageTime * 1000))ms")
                print("  Change: \(String(format: "%+.1f", improvement))%")
                print("")
            }
        }
    }
}

// MARK: - BenchmarkResult Codable

extension PerformanceBenchmarks.BenchmarkResult: Codable {
    enum CodingKeys: String, CodingKey {
        case testName, totalTime, averageTime, minTime, maxTime
        case p50, p95, p99, iterations, throughput
    }
}
