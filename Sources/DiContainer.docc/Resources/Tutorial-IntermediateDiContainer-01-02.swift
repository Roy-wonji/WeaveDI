import Foundation
import DiContainer
import LogMacro

// MARK: - 의존성 그래프 최적화 도구

/// 의존성 해결 성능을 모니터링하고 병목 지점을 찾아 최적화하는 시스템입니다.
/// 실제 프로덕션 환경에서 성능 이슈를 진단하고 해결할 때 사용할 수 있습니다.

// MARK: - 성능 측정 도구

final class DependencyPerformanceMonitor: @unchecked Sendable {
    private let queue = DispatchQueue(label: "DependencyPerformanceMonitor", attributes: .concurrent)
    private var _resolutionTimes: [String: [TimeInterval]] = [:]
    private var _resolutionCounts: [String: Int] = [:]
    private var _totalResolutions: Int = 0

    /// 의존성 해결 시간을 기록합니다
    func recordResolution<T>(for type: T.Type, executionTime: TimeInterval) {
        let typeName = String(describing: type)

        queue.async(flags: .barrier) {
            // 해결 시간 기록
            if self._resolutionTimes[typeName] == nil {
                self._resolutionTimes[typeName] = []
            }
            self._resolutionTimes[typeName]?.append(executionTime)

            // 해결 횟수 증가
            self._resolutionCounts[typeName, default: 0] += 1
            self._totalResolutions += 1

            // 최근 1000개 항목만 유지 (메모리 관리)
            if let times = self._resolutionTimes[typeName], times.count > 1000 {
                self._resolutionTimes[typeName] = Array(times.suffix(1000))
            }
        }

        #logInfo("⏱️ [성능모니터] \(typeName) 해결: \(String(format: "%.3f", executionTime * 1000))ms")
    }

    /// 성능 통계를 반환합니다
    func getPerformanceStats() -> PerformanceStats {
        return queue.sync {
            var typeStats: [String: TypePerformanceStats] = [:]

            for (typeName, times) in _resolutionTimes {
                let avgTime = times.reduce(0, +) / Double(times.count)
                let maxTime = times.max() ?? 0
                let minTime = times.min() ?? 0
                let count = _resolutionCounts[typeName] ?? 0

                typeStats[typeName] = TypePerformanceStats(
                    typeName: typeName,
                    averageTime: avgTime,
                    maxTime: maxTime,
                    minTime: minTime,
                    resolutionCount: count
                )
            }

            return PerformanceStats(
                totalResolutions: _totalResolutions,
                typeStats: typeStats
            )
        }
    }

    /// 가장 느린 타입들을 반환합니다
    func getSlowestTypes(limit: Int = 5) -> [TypePerformanceStats] {
        let stats = getPerformanceStats()
        return Array(stats.typeStats.values
            .sorted { $0.averageTime > $1.averageTime }
            .prefix(limit))
    }

    /// 가장 많이 해결된 타입들을 반환합니다
    func getMostResolvedTypes(limit: Int = 5) -> [TypePerformanceStats] {
        let stats = getPerformanceStats()
        return Array(stats.typeStats.values
            .sorted { $0.resolutionCount > $1.resolutionCount }
            .prefix(limit))
    }
}

struct PerformanceStats {
    let totalResolutions: Int
    let typeStats: [String: TypePerformanceStats]
}

struct TypePerformanceStats {
    let typeName: String
    let averageTime: TimeInterval
    let maxTime: TimeInterval
    let minTime: TimeInterval
    let resolutionCount: Int

    var averageTimeMs: Double { averageTime * 1000 }
    var maxTimeMs: Double { maxTime * 1000 }
    var minTimeMs: Double { minTime * 1000 }
}

// MARK: - 의존성 그래프 분석기

final class DependencyGraphAnalyzer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "DependencyGraphAnalyzer", attributes: .concurrent)
    private var _dependencyChains: [String: [String]] = [:]
    private var _dependencyDepths: [String: Int] = [:]

    /// 의존성 체인을 분석하고 기록합니다
    func analyzeDependencyChain<T>(for type: T.Type, chain: [String]) {
        let typeName = String(describing: type)

        queue.async(flags: .barrier) {
            self._dependencyChains[typeName] = chain
            self._dependencyDepths[typeName] = chain.count

            #logInfo("📊 [그래프분석] \(typeName) 의존성 체인 깊이: \(chain.count)")
            #logInfo("   체인: \(chain.joined(separator: " → "))")
        }
    }

    /// 가장 깊은 의존성을 가진 타입들을 반환합니다
    func getDeepestDependencies(limit: Int = 5) -> [(String, Int)] {
        return queue.sync {
            return Array(_dependencyDepths.sorted { $0.value > $1.value }.prefix(limit))
        }
    }

    /// 특정 타입의 의존성 체인을 반환합니다
    func getDependencyChain(for typeName: String) -> [String]? {
        return queue.sync {
            return _dependencyChains[typeName]
        }
    }

    /// 모든 의존성 통계를 반환합니다
    func getDependencyStats() -> DependencyGraphStats {
        return queue.sync {
            let totalTypes = _dependencyChains.count
            let averageDepth = _dependencyDepths.isEmpty ? 0 :
                Double(_dependencyDepths.values.reduce(0, +)) / Double(_dependencyDepths.count)
            let maxDepth = _dependencyDepths.values.max() ?? 0

            return DependencyGraphStats(
                totalTypes: totalTypes,
                averageDepth: averageDepth,
                maxDepth: maxDepth,
                chains: _dependencyChains
            )
        }
    }
}

struct DependencyGraphStats {
    let totalTypes: Int
    let averageDepth: Double
    let maxDepth: Int
    let chains: [String: [String]]
}

// MARK: - 최적화 제안 엔진

final class OptimizationSuggestionEngine {
    private let performanceMonitor: DependencyPerformanceMonitor
    private let graphAnalyzer: DependencyGraphAnalyzer

    init(performanceMonitor: DependencyPerformanceMonitor, graphAnalyzer: DependencyGraphAnalyzer) {
        self.performanceMonitor = performanceMonitor
        self.graphAnalyzer = graphAnalyzer
    }

    /// 최적화 제안을 생성합니다
    func generateOptimizationSuggestions() -> [OptimizationSuggestion] {
        var suggestions: [OptimizationSuggestion] = []

        // 1. 느린 타입 최적화 제안
        let slowTypes = performanceMonitor.getSlowestTypes(limit: 3)
        for typeStats in slowTypes {
            if typeStats.averageTimeMs > 10.0 { // 10ms 이상
                suggestions.append(.slowResolution(
                    typeName: typeStats.typeName,
                    averageTime: typeStats.averageTimeMs,
                    suggestion: "싱글톤 패턴 적용을 고려하세요"
                ))
            }
        }

        // 2. 깊은 의존성 체인 최적화 제안
        let deepDependencies = graphAnalyzer.getDeepestDependencies(limit: 3)
        for (typeName, depth) in deepDependencies {
            if depth > 5 {
                suggestions.append(.deepDependency(
                    typeName: typeName,
                    depth: depth,
                    suggestion: "의존성 체인이 너무 깊습니다. 중간 계층을 줄이는 것을 고려하세요"
                ))
            }
        }

        // 3. 자주 해결되는 타입 캐싱 제안
        let frequentTypes = performanceMonitor.getMostResolvedTypes(limit: 3)
        for typeStats in frequentTypes {
            if typeStats.resolutionCount > 100 {
                suggestions.append(.frequentResolution(
                    typeName: typeStats.typeName,
                    count: typeStats.resolutionCount,
                    suggestion: "자주 해결되는 타입입니다. 싱글톤으로 등록하여 성능을 개선하세요"
                ))
            }
        }

        return suggestions
    }
}

enum OptimizationSuggestion {
    case slowResolution(typeName: String, averageTime: Double, suggestion: String)
    case deepDependency(typeName: String, depth: Int, suggestion: String)
    case frequentResolution(typeName: String, count: Int, suggestion: String)

    var description: String {
        switch self {
        case .slowResolution(let typeName, let avgTime, let suggestion):
            return "🐌 [느린해결] \(typeName): 평균 \(String(format: "%.2f", avgTime))ms - \(suggestion)"
        case .deepDependency(let typeName, let depth, let suggestion):
            return "🕳️ [깊은의존성] \(typeName): 깊이 \(depth) - \(suggestion)"
        case .frequentResolution(let typeName, let count, let suggestion):
            return "🔥 [빈번한해결] \(typeName): \(count)회 - \(suggestion)"
        }
    }
}

// MARK: - 통합 성능 최적화 도구

final class DependencyOptimizer {
    let performanceMonitor = DependencyPerformanceMonitor()
    let graphAnalyzer = DependencyGraphAnalyzer()
    private lazy var suggestionEngine = OptimizationSuggestionEngine(
        performanceMonitor: performanceMonitor,
        graphAnalyzer: graphAnalyzer
    )

    /// 의존성 해결을 모니터링합니다
    func monitorResolution<T>(for type: T.Type, executionTime: TimeInterval, chain: [String]) {
        performanceMonitor.recordResolution(for: type, executionTime: executionTime)
        graphAnalyzer.analyzeDependencyChain(for: type, chain: chain)
    }

    /// 종합 성능 리포트를 생성합니다
    func generatePerformanceReport() -> String {
        let perfStats = performanceMonitor.getPerformanceStats()
        let graphStats = graphAnalyzer.getDependencyStats()
        let suggestions = suggestionEngine.generateOptimizationSuggestions()

        var report = """
        📊 DiContainer 성능 분석 리포트
        =====================================

        📈 전체 통계:
        - 총 해결 횟수: \(perfStats.totalResolutions)회
        - 등록된 타입 수: \(graphStats.totalTypes)개
        - 평균 의존성 깊이: \(String(format: "%.1f", graphStats.averageDepth))
        - 최대 의존성 깊이: \(graphStats.maxDepth)

        🐌 가장 느린 타입들:
        """

        for typeStats in performanceMonitor.getSlowestTypes(limit: 3) {
            report += "\n- \(typeStats.typeName): 평균 \(String(format: "%.2f", typeStats.averageTimeMs))ms"
        }

        report += "\n\n🔥 가장 많이 해결된 타입들:"
        for typeStats in performanceMonitor.getMostResolvedTypes(limit: 3) {
            report += "\n- \(typeStats.typeName): \(typeStats.resolutionCount)회"
        }

        report += "\n\n💡 최적화 제안:"
        if suggestions.isEmpty {
            report += "\n- 현재 성능이 양호합니다! 🎉"
        } else {
            for suggestion in suggestions {
                report += "\n- \(suggestion.description)"
            }
        }

        return report
    }
}

// MARK: - 사용 예제

extension DIContainer {
    /// 성능 최적화 도구를 설정합니다
    func setupPerformanceOptimization() -> DependencyOptimizer {
        #logInfo("🔧 성능 최적화 도구 설정")

        let optimizer = DependencyOptimizer()

        // 컨테이너의 해결 과정을 모니터링하도록 설정
        // (실제 구현에서는 DiContainer 내부에 훅을 추가해야 함)

        #logInfo("✅ 성능 최적화 도구 설정 완료")
        return optimizer
    }
}

// MARK: - 최적화 도구 사용 예제

enum OptimizationExample {
    static func demonstrateOptimization() async {
        #logInfo("🎬 의존성 최적화 도구 데모 시작")

        let container = DIContainer()
        let optimizer = container.setupPerformanceOptimization()

        // 일부 의존성들을 시뮬레이션으로 모니터링
        optimizer.monitorResolution(
            for: String.self,
            executionTime: 0.001,
            chain: ["String"]
        )

        optimizer.monitorResolution(
            for: Array<String>.self,
            executionTime: 0.015,
            chain: ["Array<String>", "String"]
        )

        optimizer.monitorResolution(
            for: Dictionary<String, Any>.self,
            executionTime: 0.025,
            chain: ["Dictionary", "String", "Any"]
        )

        // 성능 리포트 생성
        let report = optimizer.generatePerformanceReport()
        #logInfo("📋 성능 리포트:\n\(report)")

        #logInfo("🎉 최적화 도구 데모 완료")
    }
}