import Foundation
import DiContainer
import LogMacro

// MARK: - Dependency Graph Optimizer

/// 의존성 체인의 성능 병목지점을 찾고 최적화하는 시스템

final class DependencyGraphOptimizer: @unchecked Sendable {
    private let accessQueue = DispatchQueue(label: "DependencyGraphOptimizer.access", attributes: .concurrent)
    private var _resolutionTimes: [String: [TimeInterval]] = [:]
    private var _dependencyChains: [String: [String]] = [:]
    private var _circularDependencies: Set<String> = []

    /// 의존성 해결 시간을 추적합니다
    func trackResolutionTime<T>(for type: T.Type, executionTime: TimeInterval) {
        let typeName = String(describing: type)

        accessQueue.async(flags: .barrier) {
            if self._resolutionTimes[typeName] == nil {
                self._resolutionTimes[typeName] = []
            }
            self._resolutionTimes[typeName]?.append(executionTime)

            // 최근 100개 항목만 유지
            if let times = self._resolutionTimes[typeName], times.count > 100 {
                self._resolutionTimes[typeName] = Array(times.suffix(100))
            }
        }

        #logInfo("⏱️ [GraphOptimizer] \(typeName) 해결 시간: \(String(format: "%.3f", executionTime))ms")
    }

    /// 의존성 체인을 분석합니다
    func analyzeDependencyChain<T>(for type: T.Type, chain: [String]) {
        let typeName = String(describing: type)

        accessQueue.async(flags: .barrier) {
            self._dependencyChains[typeName] = chain

            // 순환 의존성 감지
            if self.detectCircularDependency(in: chain) {
                self._circularDependencies.insert(typeName)
                #logError("🔄 [GraphOptimizer] 순환 의존성 감지: \(typeName)")
            }
        }

        #logInfo("📊 [GraphOptimizer] 의존성 체인 분석: \(typeName) -> \(chain.joined(separator: " -> "))")
    }

    /// 성능 병목지점을 찾습니다
    func identifyBottlenecks() -> [PerformanceBottleneck] {
        return accessQueue.sync {
            var bottlenecks: [PerformanceBottleneck] = []

            for (typeName, times) in _resolutionTimes {
                guard !times.isEmpty else { continue }

                let averageTime = times.reduce(0, +) / Double(times.count)
                let maxTime = times.max() ?? 0
                let minTime = times.min() ?? 0

                // 평균 해결 시간이 10ms 이상이거나 최대 시간이 50ms 이상인 경우 병목지점으로 판단
                if averageTime > 0.01 || maxTime > 0.05 {
                    let bottleneck = PerformanceBottleneck(
                        typeName: typeName,
                        averageResolutionTime: averageTime,
                        maxResolutionTime: maxTime,
                        minResolutionTime: minTime,
                        sampleCount: times.count,
                        dependencyChainLength: _dependencyChains[typeName]?.count ?? 0,
                        hasCircularDependency: _circularDependencies.contains(typeName)
                    )
                    bottlenecks.append(bottleneck)
                }
            }

            // 평균 해결 시간 기준으로 정렬
            return bottlenecks.sorted { $0.averageResolutionTime > $1.averageResolutionTime }
        }
    }

    /// 최적화 제안을 생성합니다
    func generateOptimizationSuggestions() -> [OptimizationSuggestion] {
        let bottlenecks = identifyBottlenecks()
        var suggestions: [OptimizationSuggestion] = []

        for bottleneck in bottlenecks {
            if bottleneck.hasCircularDependency {
                suggestions.append(.resolveCircularDependency(typeName: bottleneck.typeName))
            }

            if bottleneck.dependencyChainLength > 5 {
                suggestions.append(.simplifyDependencyChain(
                    typeName: bottleneck.typeName,
                    chainLength: bottleneck.dependencyChainLength
                ))
            }

            if bottleneck.averageResolutionTime > 0.02 {
                suggestions.append(.cacheFrequentlyUsed(
                    typeName: bottleneck.typeName,
                    averageTime: bottleneck.averageResolutionTime
                ))
            }

            if bottleneck.maxResolutionTime > bottleneck.averageResolutionTime * 3 {
                suggestions.append(.investigatePerformanceSpikes(
                    typeName: bottleneck.typeName,
                    maxTime: bottleneck.maxResolutionTime
                ))
            }
        }

        return suggestions
    }

    /// 최적화 리포트를 생성합니다
    func generateOptimizationReport() async -> OptimizationReport {
        let bottlenecks = identifyBottlenecks()
        let suggestions = generateOptimizationSuggestions()
        let circularDeps = accessQueue.sync { Array(_circularDependencies) }

        let totalTypes = accessQueue.sync { _resolutionTimes.count }
        let totalResolutions = accessQueue.sync {
            _resolutionTimes.values.reduce(0) { $0 + $1.count }
        }

        let report = OptimizationReport(
            timestamp: Date(),
            totalRegisteredTypes: totalTypes,
            totalResolutions: totalResolutions,
            bottlenecks: bottlenecks,
            circularDependencies: circularDeps,
            optimizationSuggestions: suggestions,
            overallHealthScore: calculateHealthScore(bottlenecks: bottlenecks, circularDeps: circularDeps)
        )

        #logInfo("📋 [GraphOptimizer] 최적화 리포트 생성 완료")
        #logInfo("  • 등록된 타입: \(totalTypes)개")
        #logInfo("  • 총 해결 횟수: \(totalResolutions)회")
        #logInfo("  • 병목지점: \(bottlenecks.count)개")
        #logInfo("  • 순환 의존성: \(circularDeps.count)개")
        #logInfo("  • 건강 점수: \(String(format: "%.1f", report.overallHealthScore))/100")

        return report
    }

    // MARK: - Private Methods

    private func detectCircularDependency(in chain: [String]) -> Bool {
        var visited = Set<String>()

        for dependency in chain {
            if visited.contains(dependency) {
                return true
            }
            visited.insert(dependency)
        }

        return false
    }

    private func calculateHealthScore(bottlenecks: [PerformanceBottleneck], circularDeps: [String]) -> Double {
        var score: Double = 100.0

        // 병목지점마다 점수 감소
        score -= Double(bottlenecks.count) * 5.0

        // 순환 의존성마다 점수 대폭 감소
        score -= Double(circularDeps.count) * 20.0

        // 심각한 병목지점 추가 감점
        let severebottlenecks = bottlenecks.filter { $0.averageResolutionTime > 0.05 }
        score -= Double(severebottlenecks.count) * 10.0

        return max(0.0, min(100.0, score))
    }

    /// 리셋 (테스트용)
    func reset() {
        accessQueue.async(flags: .barrier) {
            self._resolutionTimes.removeAll()
            self._dependencyChains.removeAll()
            self._circularDependencies.removeAll()
        }
    }
}

// MARK: - Supporting Types

struct PerformanceBottleneck: Sendable {
    let typeName: String
    let averageResolutionTime: TimeInterval
    let maxResolutionTime: TimeInterval
    let minResolutionTime: TimeInterval
    let sampleCount: Int
    let dependencyChainLength: Int
    let hasCircularDependency: Bool

    var severityLevel: BottleneckSeverity {
        if hasCircularDependency {
            return .critical
        } else if averageResolutionTime > 0.05 {
            return .high
        } else if averageResolutionTime > 0.02 {
            return .medium
        } else {
            return .low
        }
    }
}

enum BottleneckSeverity: String, Sendable {
    case low = "낮음"
    case medium = "보통"
    case high = "높음"
    case critical = "심각"
}

enum OptimizationSuggestion: Sendable {
    case resolveCircularDependency(typeName: String)
    case simplifyDependencyChain(typeName: String, chainLength: Int)
    case cacheFrequentlyUsed(typeName: String, averageTime: TimeInterval)
    case investigatePerformanceSpikes(typeName: String, maxTime: TimeInterval)

    var description: String {
        switch self {
        case .resolveCircularDependency(let typeName):
            return "순환 의존성 해결 필요: \(typeName)"
        case .simplifyDependencyChain(let typeName, let chainLength):
            return "의존성 체인 단순화 필요: \(typeName) (현재 깊이: \(chainLength))"
        case .cacheFrequentlyUsed(let typeName, let averageTime):
            return "자주 사용되는 타입 캐싱 고려: \(typeName) (평균: \(String(format: "%.2f", averageTime * 1000))ms)"
        case .investigatePerformanceSpikes(let typeName, let maxTime):
            return "성능 스파이크 조사 필요: \(typeName) (최대: \(String(format: "%.2f", maxTime * 1000))ms)"
        }
    }
}

struct OptimizationReport: Sendable {
    let timestamp: Date
    let totalRegisteredTypes: Int
    let totalResolutions: Int
    let bottlenecks: [PerformanceBottleneck]
    let circularDependencies: [String]
    let optimizationSuggestions: [OptimizationSuggestion]
    let overallHealthScore: Double

    func printDetailedReport() {
        #logInfo("=" * 50)
        #logInfo("📊 의존성 그래프 최적화 리포트")
        #logInfo("=" * 50)
        #logInfo("⏰ 생성 시간: \(timestamp)")
        #logInfo("📦 등록된 타입: \(totalRegisteredTypes)개")
        #logInfo("🔄 총 해결 횟수: \(totalResolutions)회")
        #logInfo("💯 건강 점수: \(String(format: "%.1f", overallHealthScore))/100")
        #logInfo("")

        if !bottlenecks.isEmpty {
            #logInfo("🚨 성능 병목지점 (\(bottlenecks.count)개):")
            for (index, bottleneck) in bottlenecks.enumerated() {
                #logInfo("  \(index + 1). \(bottleneck.typeName)")
                #logInfo("     평균: \(String(format: "%.2f", bottleneck.averageResolutionTime * 1000))ms")
                #logInfo("     최대: \(String(format: "%.2f", bottleneck.maxResolutionTime * 1000))ms")
                #logInfo("     체인 길이: \(bottleneck.dependencyChainLength)")
                #logInfo("     심각도: \(bottleneck.severityLevel.rawValue)")
            }
            #logInfo("")
        }

        if !circularDependencies.isEmpty {
            #logInfo("🔄 순환 의존성 (\(circularDependencies.count)개):")
            for circularDep in circularDependencies {
                #logInfo("  • \(circularDep)")
            }
            #logInfo("")
        }

        if !optimizationSuggestions.isEmpty {
            #logInfo("💡 최적화 제안 (\(optimizationSuggestions.count)개):")
            for (index, suggestion) in optimizationSuggestions.enumerated() {
                #logInfo("  \(index + 1). \(suggestion.description)")
            }
        }

        #logInfo("=" * 50)
    }
}

// MARK: - Enhanced DIContainer with Performance Tracking

extension DIContainer {
    /// 성능 추적과 함께 의존성 해결
    func resolveWithTracking<T>(_ type: T.Type, optimizer: DependencyGraphOptimizer) async -> T? {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = await resolve(type)
        let endTime = CFAbsoluteTimeGetCurrent()

        let executionTime = endTime - startTime
        optimizer.trackResolutionTime(for: type, executionTime: executionTime)

        return result
    }

    /// 의존성 체인과 함께 등록
    func registerWithChainTracking<T>(
        _ type: T.Type,
        dependencyChain: [String] = [],
        optimizer: DependencyGraphOptimizer,
        factory: @escaping @Sendable () -> T
    ) {
        // 의존성 체인 분석
        optimizer.analyzeDependencyChain(for: type, chain: dependencyChain)

        // 기존 등록 방식
        register(type, factory: factory)
    }
}

// MARK: - Usage Example

/// 의존성 그래프 최적화 사용 예제
final class DependencyGraphExample {
    private let optimizer = DependencyGraphOptimizer()
    private let container = DIContainer.shared

    func setupOptimizedDependencies() async {
        #logInfo("🔧 [GraphExample] 최적화된 의존성 설정 시작")

        // 의존성 체인과 함께 등록
        container.registerWithChainTracking(
            OrderProcessingUseCase.self,
            dependencyChain: [
                "OrderProcessingUseCase",
                "UserService", "ProductService", "OrderService",
                "PaymentService", "ShippingService", "NotificationService",
                "UserRepository", "ProductRepository", "OrderRepository"
            ],
            optimizer: optimizer
        ) {
            DefaultOrderProcessingUseCase()
        }

        // 여러 번 해결하여 성능 데이터 수집
        for i in 1...50 {
            let _ = await container.resolveWithTracking(OrderProcessingUseCase.self, optimizer: optimizer)
            if i % 10 == 0 {
                #logInfo("📊 [GraphExample] 성능 측정 진행률: \(i)/50")
            }
        }

        // 최적화 리포트 생성
        let report = await optimizer.generateOptimizationReport()
        report.printDetailedReport()

        #logInfo("✅ [GraphExample] 최적화 분석 완료")
    }
}

// MARK: - String Extension for Logging

private extension String {
    static func * (string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}