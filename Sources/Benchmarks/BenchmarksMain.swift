import Foundation
import DiContainer
import Darwin

@main
struct Benchmarks {
    static func main() async {
        let args = CommandLine.arguments
        var counts: [Int] = [10_000, 100_000, 1_000_000]
        var debounces: [Int] = [50, 100, 200]
        let quick = args.contains("--quick") || args.contains("--once")
        let csvPath: String? = {
            guard let i = args.firstIndex(of: "--csv"), i + 1 < args.count else { return nil }
            return args[i+1]
        }()

        func intArg(_ flag: String) -> Int? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return Int(args[i+1])
        }

        if let c = intArg("--count") { counts = [c] }
        if let d = intArg("--debounce") { debounces = [d] }

        // CSV header
        if let path = csvPath {
            if !FileManager.default.fileExists(atPath: path) {
                let header = "timestamp,debounce_ms,count,total_ms,p50_ms,p95_ms,p99_ms\n"
                try? header.data(using: .utf8)?.write(to: URL(fileURLWithPath: path))
            }
        }

        print("📊 Bench: counts=\(counts), debounces=\(debounces) (ms)" + (quick ? " [quick]" : ""))

        outer: for db in debounces {
            UnifiedDI.configureOptimization(debounceMs: db, threshold: 10, realTimeUpdate: false)
            for n in counts {
                await MainActor.run { UnifiedDI.releaseAll() }

                protocol Svc: Sendable {}
                struct Impl: Svc {}
                _ = UnifiedDI.register(Svc.self) { Impl() }

                for _ in 0..<1000 { _ = UnifiedDI.resolve(Svc.self) }

                let t0 = DispatchTime.now().uptimeNanoseconds
                let step = max(1, n / 100_000)
                var samples: [UInt64] = []
                samples.reserveCapacity(min(n, 100_000))
                var last = DispatchTime.now().uptimeNanoseconds

                for i in 0..<n {
                    _ = UnifiedDI.resolve(Svc.self)
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
                        try? fh.seekToEnd()
                        try? fh.write(contentsOf: data)
                    }
                }
                if quick { break outer }
            }
        }
        print("✅ Bench done")
        exit(EXIT_SUCCESS)
    }
}
