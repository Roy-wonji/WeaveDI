import Foundation
import WeaveDI
import Darwin

@main
struct Benchmarks {
    static func main() async {
        let args = CommandLine.arguments

        // Command line argument parsing
        let help = args.contains("--help") || args.contains("-h")
        let quick = args.contains("--quick") || args.contains("--once")
        let detailed = args.contains("--detailed")
        let performance = args.contains("--performance") || args.contains("--perf")
        let legacy = args.contains("--legacy")

        let csvPath: String? = {
            guard let i = args.firstIndex(of: "--csv"), i + 1 < args.count else { return nil }
            return args[i+1]
        }()

        let jsonPath: String? = {
            guard let i = args.firstIndex(of: "--json"), i + 1 < args.count else { return nil }
            return args[i+1]
        }()

        let baselinePath: String? = {
            guard let i = args.firstIndex(of: "--baseline"), i + 1 < args.count else { return nil }
            return args[i+1]
        }()

        func intArg(_ flag: String) -> Int? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return Int(args[i+1])
        }

        // Show help
        if help {
            showHelp()
            return
        }

        print("🚀 WeaveDI Benchmark Suite")
        print("=" * 60)

        // Choose benchmark mode
        if performance || (!legacy && !args.contains("--optimizer")) {
            // New performance benchmark system
            await runPerformanceBenchmarks(
                quick: quick,
                detailed: detailed,
                csvPath: csvPath,
                jsonPath: jsonPath,
                baselinePath: baselinePath
            )
        } else {
            // Legacy optimizer benchmarks
            await runLegacyOptimizerBenchmarks(
                quick: quick,
                csvPath: csvPath
            )
        }

        exit(EXIT_SUCCESS)
    }

    // MARK: - Performance Benchmarks (New)

    static func runPerformanceBenchmarks(
        quick: Bool,
        detailed: Bool,
        csvPath: String?,
        jsonPath: String?,
        baselinePath: String?
    ) async {
        print("📊 Running Performance Benchmarks")
        print("")

        // Choose configuration
        let config: PerformanceBenchmarks.BenchmarkConfig
        if detailed {
            config = .detailed
        } else if quick {
            config = .quick
        } else {
            config = .default
        }

        // Run benchmarks
        let results = PerformanceBenchmarks.runAllBenchmarks(config: config)

        // Export results
        if let csvPath = csvPath {
            do {
                try PerformanceBenchmarks.exportResultsToCSV(results, to: csvPath)
            } catch {
                print("❌ Failed to export CSV: \(error)")
            }
        }

        if let jsonPath = jsonPath {
            do {
                try PerformanceBenchmarks.exportResultsToJSON(results, to: jsonPath)
            } catch {
                print("❌ Failed to export JSON: \(error)")
            }
        }

        // Compare with baseline
        if let baselinePath = baselinePath {
            PerformanceBenchmarks.compareWithBaseline(results, baselinePath: baselinePath)
        }

        // Summary
        print("📋 Benchmark Summary")
        print("=" * 60)
        let avgThroughput = results.map(\.throughput).reduce(0, +) / Double(results.count)
        let totalOperations = results.map(\.iterations).reduce(0, +)
        let totalTime = results.map(\.totalTime).reduce(0, +)

        print("📊 Total operations: \(totalOperations)")
        print("⏱️ Total time: \(String(format: "%.2f", totalTime))s")
        print("🚀 Average throughput: \(String(format: "%.0f", avgThroughput)) ops/sec")
        print("")
        print("✅ Performance benchmarks completed successfully!")
    }

    // MARK: - Legacy Optimizer Benchmarks

    static func runLegacyOptimizerBenchmarks(
        quick: Bool,
        csvPath: String?
    ) async {
        func intArg(_ flag: String) -> Int? {
            let args = CommandLine.arguments
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return Int(args[i+1])
        }
        print("🔧 Running Legacy Optimizer Benchmarks")
        print("")

        var counts: [Int] = [10_000, 100_000, 1_000_000]
        var debounces: [Int] = [50, 100, 200]

        if let c = intArg("--count") { counts = [c] }
        if let d = intArg("--debounce") { debounces = [d] }

        // CSV header
        if let path = csvPath {
            if !FileManager.default.fileExists(atPath: path) {
                let header = "timestamp,debounce_ms,count,total_ms,p50_ms,p95_ms,p99_ms\n"
                try? header.data(using: .utf8)?.write(to: URL(fileURLWithPath: path))
            }
        }

        print("📊 Optimizer Bench: counts=\(counts), debounces=\(debounces) (ms)" + (quick ? " [quick]" : ""))

        outer: for db in debounces {
            // UnifiedDI.configureOptimization is removed in v4.0 - simplified architecture
            for n in counts {
                await UnifiedDI.releaseAllAsync()

                protocol Svc: Sendable {}
                struct Impl: Svc {}

                // ③ 재사용 타입은 인스턴스 등록으로 고정
                _ = UnifiedDI.register(Svc.self) { Impl() }

                // 워밍업
#if USE_STATIC_FACTORY
                // ⑤ 핫패스 정적화: 런타임 해석을 제거
                let warm = Impl()
                _ = warm as Svc
#else
                for _ in 0..<1000 { _ = UnifiedDI.resolve(Svc.self) }
#endif

                let t0 = DispatchTime.now().uptimeNanoseconds
                let step = max(1, n / 100_000)
                var samples: [UInt64] = []
                samples.reserveCapacity(min(n, 100_000))
                var last = DispatchTime.now().uptimeNanoseconds

                // ② 반복 루프에서 resolve 캐시
#if USE_STATIC_FACTORY
                let svc = Impl() as Svc
#else
                let svc = UnifiedDI.resolve(Svc.self) as Svc?
#endif

                for i in 0..<n {
                    _ = svc
                    if i % step == 0 {
                        let now = DispatchTime.now().uptimeNanoseconds
                        samples.append(now - last)
                        last = now
                    }
                }

                let t1 = DispatchTime.now().uptimeNanoseconds
                let totalMs = Double(t1 - t0) / 1_000_000.0
                samples.sort()
                func pct(_ p: Double) -> Double {
                    if samples.isEmpty { return 0 }
                    let idx = min(samples.count - 1, Int(Double(samples.count - 1) * p))
                    return Double(samples[idx]) / 1_000_000.0
                }
                let p50 = pct(0.50), p95 = pct(0.95), p99 = pct(0.99)
                print(String(format: "debounce=%3dms, n=%9d | total=%8.2fms | p50=%6.3f p95=%6.3f p99=%6.3f", db, n, totalMs, p50, p95, p99))
                if let path = csvPath {
                    let ts = ISO8601DateFormatter().string(from: Date())
                    let line = String(format: "%@,%d,%d,%.4f,%.4f,%.4f,%.4f\n", ts, db, n, totalMs, p50, p95, p99)
                    if let data = line.data(using: .utf8), let fh = FileHandle(forWritingAtPath: path) {
                        defer { try? fh.close() }
                        _ = try? fh.seekToEnd()
                        try? fh.write(contentsOf: data)
                    }
                }
                if quick { break outer }
            }
        }
        print("✅ Legacy optimizer benchmarks completed!")
    }

    // MARK: - Help

    static func showHelp() {
        print("""
        🚀 WeaveDI Benchmark Suite

        USAGE:
            Benchmarks [OPTIONS]

        OPTIONS:
            --performance, --perf    Run new performance benchmarks (default)
            --legacy                 Run legacy optimizer benchmarks
            --optimizer              Run optimizer-specific benchmarks

            --quick, --once          Quick mode (fewer iterations)
            --detailed               Detailed mode (more iterations & logging)

            --csv PATH               Export results to CSV file
            --json PATH              Export results to JSON file
            --baseline PATH          Compare with baseline results

            --count N                Override iteration count (legacy mode)
            --debounce N             Override debounce setting (legacy mode)

            --help, -h               Show this help message

        EXAMPLES:
            Benchmarks                           # Run default performance benchmarks
            Benchmarks --quick --json results.json  # Quick benchmarks with JSON export
            Benchmarks --detailed --csv data.csv    # Detailed benchmarks with CSV export
            Benchmarks --legacy --count 50000        # Legacy mode with custom count
            Benchmarks --baseline baseline.json      # Compare with baseline

        PERFORMANCE BENCHMARKS:
            • Single Dependency Resolution
            • Complex Dependency Graph
            • Concurrent Resolution
            • Memory Efficiency
            • Auto DI Optimizer
            • Property Wrapper (@Injected)

        LEGACY BENCHMARKS:
            • Optimizer debounce timing
            • Bulk resolution performance
            • Static factory vs dynamic resolution
        """)
    }
}

// MARK: - String Extension

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
