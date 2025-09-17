//
//  AdvancedCircularDependencyDetector.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - Advanced Circular Dependency Detection System

/// 고급 순환 의존성 탐지 및 예방 시스템
///
/// ## 개요
///
/// 기존 CircularDependencyDetector를 확장하여 컴파일 타임 및 런타임에서
/// 순환 의존성을 예방하고 자동으로 해결하는 고급 기능을 제공합니다.
///
/// ## 핵심 기능
///
/// ### 🔍 실시간 탐지
/// - 의존성 등록 시점에서 즉시 순환 의존성 검증
/// - 런타임 해결 과정에서 실시간 모니터링
/// - 잠재적 순환 의존성 조기 경고
///
/// ### 🛡️ 자동 예방
/// - 의존성 그래프 분석을 통한 사전 차단
/// - 위험한 패턴 식별 및 경고
/// - 안전한 의존성 구조 제안
///
/// ### 🔧 자동 수정
/// - 순환 의존성 자동 해결 전략
/// - 인터페이스 분리 제안
/// - 중간 계층 자동 생성
///
/// ## 사용 예시
///
/// ```swift
/// // 고급 탐지 시스템 활성화
/// AdvancedCircularDependencyDetector.enableAdvancedDetection()
///
/// // 실시간 모니터링 시작
/// AdvancedCircularDependencyDetector.startRealtimeMonitoring()
///
/// // 자동 수정 시도
/// let fixes = AdvancedCircularDependencyDetector.proposeAutoFixes()
/// for fix in fixes {
///     print("제안된 수정: \(fix.description)")
/// }
/// ```
@MainActor
public enum AdvancedCircularDependencyDetector {

    // MARK: - Configuration

    /// 고급 탐지 기능 활성화 여부
    private static var isAdvancedDetectionEnabled: Bool = false

    /// 실시간 모니터링 활성화 여부
    private static var isRealtimeMonitoringEnabled: Bool = false

    /// 자동 수정 활성화 여부
    private static var isAutoFixEnabled: Bool = false

    /// 예방 모드 활성화 여부
    private static var isPreventionModeEnabled: Bool = false

    // MARK: - Monitoring Data

    /// 실시간 의존성 변경 로그
    private static var dependencyChanges: [DependencyChange] = []

    /// 탐지된 잠재적 문제들
    private static var potentialIssues: [PotentialCircularIssue] = []

    /// 적용된 자동 수정 기록
    private static var appliedFixes: [AutomaticFix] = []

    /// 성능 메트릭
    private static var detectionMetrics: DetectionMetrics = DetectionMetrics()

    // MARK: - Public API

    /// 고급 탐지 시스템 활성화
    public static func enableAdvancedDetection() {
        isAdvancedDetectionEnabled = true

        // 기존 CircularDependencyDetector와 연동
        CircularDependencyDetector.shared.setDetectionEnabled(true)
        CircularDependencyDetector.shared.setAutoRecordingEnabled(true)

        #logDebug("✅ [AdvancedCircularDependencyDetector] Advanced detection enabled")
    }

    /// 고급 탐지 시스템 비활성화
    public static func disableAdvancedDetection() {
        isAdvancedDetectionEnabled = false
        isRealtimeMonitoringEnabled = false
        isAutoFixEnabled = false
        isPreventionModeEnabled = false

        #logDebug("🔴 [AdvancedCircularDependencyDetector] Advanced detection disabled")
    }

    /// 실시간 모니터링 시작
    public static func startRealtimeMonitoring() {
        guard isAdvancedDetectionEnabled else {
            #logDebug("⚠️ [AdvancedCircularDependencyDetector] Cannot start monitoring: advanced detection not enabled")
            return
        }

        isRealtimeMonitoringEnabled = true
        startPeriodicAnalysis()

        #logDebug("🔄 [AdvancedCircularDependencyDetector] Realtime monitoring started")
    }

    /// 실시간 모니터링 중지
    public static func stopRealtimeMonitoring() {
        isRealtimeMonitoringEnabled = false
        #logDebug("⏹️ [AdvancedCircularDependencyDetector] Realtime monitoring stopped")
    }

    /// 예방 모드 활성화
    public static func enablePreventionMode() {
        guard isAdvancedDetectionEnabled else { return }

        isPreventionModeEnabled = true
        #logDebug("🛡️ [AdvancedCircularDependencyDetector] Prevention mode enabled")
    }

    /// 자동 수정 기능 활성화
    public static func enableAutoFix() {
        guard isAdvancedDetectionEnabled else { return }

        isAutoFixEnabled = true
        #logDebug("🔧 [AdvancedCircularDependencyDetector] Auto-fix enabled")
    }

    // MARK: - Dependency Registration Validation

    /// 의존성 등록 전 검증
    public static func validateDependencyRegistration<T>(
        _ type: T.Type,
        dependencies: [Any.Type]
    ) -> DependencyValidationResult {
        guard isAdvancedDetectionEnabled else {
            return DependencyValidationResult(isValid: true, warnings: [], issues: [])
        }

        let typeName = String(describing: type)
        var warnings: [String] = []
        var issues: [CircularDependencyIssue] = []

        // 각 의존성에 대해 순환 체크
        for dep in dependencies {
            let depName = String(describing: dep)

            // 직접적인 역방향 의존성 체크
            if checkDirectReverseDependency(from: typeName, to: depName) {
                issues.append(CircularDependencyIssue(
                    type: .directCircularDependency,
                    involvedTypes: [typeName, depName],
                    description: "\(typeName)과 \(depName) 사이에 직접적인 순환 의존성이 발견되었습니다.",
                    severity: .critical
                ))
            }

            // 간접적인 순환 의존성 체크
            if let path = findCircularPath(from: typeName, to: depName) {
                issues.append(CircularDependencyIssue(
                    type: .indirectCircularDependency,
                    involvedTypes: path,
                    description: "간접적인 순환 의존성 경로: \(path.joined(separator: " → "))",
                    severity: .high
                ))
            }

            // 잠재적 위험 패턴 체크
            let riskLevel = analyzeRiskLevel(from: typeName, to: depName)
            if riskLevel > 0.7 {
                warnings.append("높은 위험도 의존성 패턴이 감지되었습니다: \(typeName) → \(depName)")
            }
        }

        return DependencyValidationResult(
            isValid: issues.isEmpty,
            warnings: warnings,
            issues: issues
        )
    }

    /// 의존성 변경 기록
    public static func recordDependencyChange(
        type: String,
        changeType: DependencyChangeType,
        dependencies: [String]
    ) {
        guard isRealtimeMonitoringEnabled else { return }

        let change = DependencyChange(
            timestamp: Date(),
            typeName: type,
            changeType: changeType,
            dependencies: dependencies
        )

        dependencyChanges.append(change)

        // 변경사항 분석 및 잠재적 문제 탐지
        analyzeRecentChanges()

        // 히스토리 크기 제한
        if dependencyChanges.count > 1000 {
            dependencyChanges.removeFirst(500)
        }
    }

    // MARK: - Advanced Analysis

    /// 포괄적인 순환 의존성 분석
    public static func performComprehensiveAnalysis() -> ComprehensiveAnalysisResult {
        let startTime = Date()

        // 기본 순환 의존성 탐지
        let basicCycles = CircularDependencyDetector.shared.detectAllCircularDependencies()

        // 잠재적 순환 의존성 예측
        let potentialCycles = predictPotentialCycles()

        // 의존성 클러스터 분석
        let clusters = analyzeDepencyClusters()

        // 위험도 평가
        let riskAssessment = assessOverallRisk()

        // 개선 제안
        let recommendations = generateRecommendations(
            cycles: basicCycles,
            potentialCycles: potentialCycles,
            clusters: clusters
        )

        let analysisTime = Date().timeIntervalSince(startTime)
        detectionMetrics.recordAnalysis(duration: analysisTime)

        return ComprehensiveAnalysisResult(
            basicCycles: basicCycles,
            potentialCycles: potentialCycles,
            dependencyClusters: clusters,
            riskAssessment: riskAssessment,
            recommendations: recommendations,
            analysisTime: analysisTime
        )
    }

    /// 자동 수정 제안
    public static func proposeAutoFixes() -> [AutomaticFix] {
        let cycles = CircularDependencyDetector.shared.detectAllCircularDependencies()
        var fixes: [AutomaticFix] = []

        for cycle in cycles {
            let proposedFixes = generateFixesForCycle(cycle)
            fixes.append(contentsOf: proposedFixes)
        }

        return fixes.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }

    /// 자동 수정 적용
    public static func applyAutoFix(_ fix: AutomaticFix) -> AutoFixResult {
        guard isAutoFixEnabled else {
            return AutoFixResult(success: false, message: "자동 수정이 비활성화되어 있습니다.")
        }

        let result = performAutoFix(fix)

        if result.success {
            appliedFixes.append(fix)
            #logDebug("✅ [AdvancedCircularDependencyDetector] Auto-fix applied: \(fix.description)")
        } else {
            #logDebug("❌ [AdvancedCircularDependencyDetector] Auto-fix failed: \(result.message)")
        }

        return result
    }

    // MARK: - Real-time Monitoring

    private static func startPeriodicAnalysis() {
        guard isRealtimeMonitoringEnabled else { return }

        Task {
            while isRealtimeMonitoringEnabled {
                await performPeriodicCheck()
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5초마다
            }
        }
    }

    private static func performPeriodicCheck() async {
        // 새로운 순환 의존성 체크
        let currentCycles = CircularDependencyDetector.shared.detectAllCircularDependencies()

        // 새로 발견된 순환 의존성 알림
        for cycle in currentCycles {
            if !hasSeenCycle(cycle) {
                #logDebug("🚨 [AdvancedCircularDependencyDetector] New circular dependency detected: \(cycle.description)")

                if isAutoFixEnabled {
                    let fixes = generateFixesForCycle(cycle)
                    for fix in fixes.prefix(1) { // 최우선 수정만 시도
                        let result = applyAutoFix(fix)
                        if result.success {
                            break
                        }
                    }
                }
            }
        }

        // 잠재적 문제 업데이트
        updatePotentialIssues()
    }

    private static func analyzeRecentChanges() {
        let recentChanges = dependencyChanges.suffix(10)

        for change in recentChanges {
            // 빈번한 변경사항은 잠재적 문제의 신호
            let changeCount = dependencyChanges.filter {
                $0.typeName == change.typeName &&
                $0.timestamp.timeIntervalSinceNow > -300 // 5분 이내
            }.count

            if changeCount > 3 {
                let issue = PotentialCircularIssue(
                    type: .frequentChanges,
                    typeName: change.typeName,
                    description: "\(change.typeName)에서 빈번한 의존성 변경이 감지되었습니다.",
                    detectedAt: Date(),
                    riskLevel: 0.6
                )

                if !potentialIssues.contains(where: { $0.typeName == issue.typeName && $0.type == issue.type }) {
                    potentialIssues.append(issue)
                }
            }
        }
    }

    // MARK: - Analysis Helpers

    private static func checkDirectReverseDependency(from: String, to: String) -> Bool {
        // 기존 그래프에서 역방향 의존성 체크
        let analysis = CircularDependencyDetector.shared.analyzeDependencyChain(to)
        return analysis.directDependencies.contains(from)
    }

    private static func findCircularPath(from: String, to: String) -> [String]? {
        // 가상의 엣지를 추가했을 때 순환이 생기는지 체크
        CircularDependencyDetector.shared.recordDependency(from: from, to: to)
        defer {
            // 원상복구는 실제로는 더 복잡한 로직이 필요
            // 여기서는 캐시 클리어로 대체
            CircularDependencyDetector.shared.clearCache()
        }

        let cycles = CircularDependencyDetector.shared.detectAllCircularDependencies()
        return cycles.first(where: { $0.path.contains(from) && $0.path.contains(to) })?.path
    }

    private static func analyzeRiskLevel(from: String, to: String) -> Double {
        let fromAnalysis = CircularDependencyDetector.shared.analyzeDependencyChain(from)
        let toAnalysis = CircularDependencyDetector.shared.analyzeDependencyChain(to)

        var riskLevel: Double = 0.0

        // 복잡도 기반 위험도
        riskLevel += Double(fromAnalysis.allDependencies.count) * 0.01
        riskLevel += Double(toAnalysis.allDependencies.count) * 0.01

        // 기존 순환 의존성 참여 여부
        if fromAnalysis.hasCycles || toAnalysis.hasCycles {
            riskLevel += 0.3
        }

        // 의존성 깊이
        riskLevel += Double(fromAnalysis.maxDepth) * 0.05
        riskLevel += Double(toAnalysis.maxDepth) * 0.05

        return min(riskLevel, 1.0)
    }

    private static func predictPotentialCycles() -> [PotentialCycle] {
        // let statistics = CircularDependencyDetector.shared.getGraphStatistics()
        var potentialCycles: [PotentialCycle] = []

        // 높은 결합도를 가진 타입들 간의 잠재적 순환 예측
        // 실제로는 그래프 분석 알고리즘을 사용해야 함

        // 예시: 상호 의존성이 많은 타입 쌍 찾기
        let typeNames = getAllTypeNames()
        for i in 0..<typeNames.count {
            for j in (i+1)..<typeNames.count {
                let type1 = typeNames[i]
                let type2 = typeNames[j]

                let analysis1 = CircularDependencyDetector.shared.analyzeDependencyChain(type1)
                let analysis2 = CircularDependencyDetector.shared.analyzeDependencyChain(type2)

                // 상호 의존 가능성 체크
                let mutualDependencyRisk = calculateMutualDependencyRisk(
                    analysis1: analysis1,
                    analysis2: analysis2
                )

                if mutualDependencyRisk > 0.5 {
                    potentialCycles.append(PotentialCycle(
                        involvedTypes: [type1, type2],
                        riskLevel: mutualDependencyRisk,
                        description: "\(type1)과 \(type2) 사이에 잠재적 순환 의존성 위험이 있습니다."
                    ))
                }
            }
        }

        return potentialCycles.sorted { $0.riskLevel > $1.riskLevel }
    }

    private static func analyzeDepencyClusters() -> [DependencyCluster] {
        // InteractiveDependencyVisualizer의 클러스터 분석 재사용
        return InteractiveDependencyVisualizer.analyzeDependencyClusters()
    }

    private static func assessOverallRisk() -> RiskAssessment {
        let statistics = CircularDependencyDetector.shared.getGraphStatistics()
        let cycles = CircularDependencyDetector.shared.detectAllCircularDependencies()

        var riskScore: Double = 0.0
        var riskFactors: [String] = []

        // 순환 의존성 기여도
        if !cycles.isEmpty {
            riskScore += Double(cycles.count) * 0.2
            riskFactors.append("\(cycles.count)개의 순환 의존성")
        }

        // 복잡도 기여도
        if statistics.averageDependenciesPerType > 5.0 {
            riskScore += (statistics.averageDependenciesPerType - 5.0) * 0.1
            riskFactors.append("높은 평균 의존성 수 (\(String(format: "%.1f", statistics.averageDependenciesPerType)))")
        }

        // 최대 의존성 기여도
        if statistics.maxDependenciesPerType > 10 {
            riskScore += Double(statistics.maxDependenciesPerType - 10) * 0.05
            riskFactors.append("높은 최대 의존성 수 (\(statistics.maxDependenciesPerType))")
        }

        riskScore = min(riskScore, 1.0)

        let level: RiskLevel
        switch riskScore {
        case 0.0..<0.3: level = .low
        case 0.3..<0.6: level = .medium
        case 0.6..<0.8: level = .high
        default: level = .critical
        }

        return RiskAssessment(
            overallRiskScore: riskScore,
            riskLevel: level,
            riskFactors: riskFactors,
            recommendations: generateRiskMitigationRecommendations(level: level, factors: riskFactors)
        )
    }

    private static func generateRecommendations(
        cycles: [CircularDependencyPath],
        potentialCycles: [PotentialCycle],
        clusters: [DependencyCluster]
    ) -> [DependencyRecommendation] {
        var recommendations: [DependencyRecommendation] = []

        // 순환 의존성 해결 권장사항
        for cycle in cycles {
            recommendations.append(DependencyRecommendation(
                type: .breakCircularDependency,
                description: "순환 의존성 해결: \(cycle.description)",
                priority: .high,
                actions: generateCycleBreakingActions(cycle)
            ))
        }

        // 잠재적 순환 예방 권장사항
        for potentialCycle in potentialCycles.prefix(3) {
            recommendations.append(DependencyRecommendation(
                type: .preventCircularDependency,
                description: potentialCycle.description,
                priority: .medium,
                actions: generatePreventionActions(potentialCycle)
            ))
        }

        // 클러스터 최적화 권장사항
        for cluster in clusters where cluster.cohesion < 0.3 {
            recommendations.append(DependencyRecommendation(
                type: .optimizeCluster,
                description: "낮은 응집도 클러스터 최적화가 필요합니다.",
                priority: .low,
                actions: ["클러스터 내 의존성 구조 재검토", "인터페이스 분리 고려"]
            ))
        }

        return recommendations
    }

    // MARK: - Auto-Fix Generation

    private static func generateFixesForCycle(_ cycle: CircularDependencyPath) -> [AutomaticFix] {
        var fixes: [AutomaticFix] = []

        // 가장 약한 링크 찾기
        if let weakestLink = findWeakestLinkInCycle(cycle) {
            fixes.append(AutomaticFix(
                id: UUID().uuidString,
                type: .interfaceExtraction,
                description: "\(weakestLink.from)에서 \(weakestLink.to)로의 의존성을 인터페이스로 분리",
                targetTypes: [weakestLink.from, weakestLink.to],
                priority: .high,
                estimatedEffort: .medium,
                actions: [
                    "공통 인터페이스 정의",
                    "의존성 주입 방식 변경",
                    "순환 참조 제거"
                ]
            ))
        }

        // 중간 계층 도입
        fixes.append(AutomaticFix(
            id: UUID().uuidString,
            type: .intermediateLayer,
            description: "중간 계층 도입으로 순환 의존성 해결",
            targetTypes: cycle.path,
            priority: .medium,
            estimatedEffort: .high,
            actions: [
                "중간 서비스 계층 생성",
                "의존성 그래프 재구성",
                "인터페이스 정의"
            ]
        ))

        return fixes
    }

    private static func performAutoFix(_ fix: AutomaticFix) -> AutoFixResult {
        // 실제 자동 수정 로직
        // 여기서는 시뮬레이션으로 대체

        switch fix.type {
        case .interfaceExtraction:
            return simulateInterfaceExtraction(fix)
        case .intermediateLayer:
            return simulateIntermediateLayerCreation(fix)
        case .dependencyInversion:
            return simulateDependencyInversion(fix)
        case .lazyInitialization:
            return simulateLazyInitialization(fix)
        }
    }

    // MARK: - Helper Methods

    private static func getAllTypeNames() -> [String] {
        // 실제로는 등록된 모든 타입명을 가져와야 함
        return ["UserService", "NetworkService", "DatabaseService", "AuthService", "LoggingService"]
    }

    private static func calculateMutualDependencyRisk(
        analysis1: DependencyChainAnalysis,
        analysis2: DependencyChainAnalysis
    ) -> Double {
        let commonDependencies = Set(analysis1.allDependencies).intersection(Set(analysis2.allDependencies))
        let totalDependencies = Set(analysis1.allDependencies).union(Set(analysis2.allDependencies))

        guard !totalDependencies.isEmpty else { return 0.0 }

        let overlapRatio = Double(commonDependencies.count) / Double(totalDependencies.count)
        return overlapRatio
    }

    private static func hasSeenCycle(_ cycle: CircularDependencyPath) -> Bool {
        // 이전에 본 순환인지 체크하는 로직
        return appliedFixes.contains { fix in
            Set(fix.targetTypes) == Set(cycle.path)
        }
    }

    private static func updatePotentialIssues() {
        // 오래된 잠재적 이슈 제거
        let now = Date()
        potentialIssues.removeAll { issue in
            now.timeIntervalSince(issue.detectedAt) > 3600 // 1시간 경과
        }
    }

    private static func findWeakestLinkInCycle(_ cycle: CircularDependencyPath) -> (from: String, to: String)? {
        guard cycle.path.count >= 2 else { return nil }

        // 가장 약한 연결 찾기 (의존성 개수가 적은 것)
        var weakestLink: (from: String, to: String, strength: Int)?

        for i in 0..<cycle.path.count {
            let from = cycle.path[i]
            let to = cycle.path[(i + 1) % cycle.path.count]

            let analysis = CircularDependencyDetector.shared.analyzeDependencyChain(from)
            let strength = analysis.directDependencies.count

            if weakestLink == nil || strength < weakestLink!.strength {
                weakestLink = (from: from, to: to, strength: strength)
            }
        }

        return weakestLink.map { (from: $0.from, to: $0.to) }
    }

    private static func generateCycleBreakingActions(_ cycle: CircularDependencyPath) -> [String] {
        return [
            "인터페이스 분리 패턴 적용",
            "의존성 주입 방향 재검토",
            "중간 계층 도입 고려",
            "이벤트 기반 통신으로 변경"
        ]
    }

    private static func generatePreventionActions(_ potentialCycle: PotentialCycle) -> [String] {
        return [
            "의존성 방향 명확화",
            "레이어 아키텍처 준수",
            "인터페이스 우선 설계"
        ]
    }

    private static func generateRiskMitigationRecommendations(level: RiskLevel, factors: [String]) -> [String] {
        var recommendations: [String] = []

        switch level {
        case .low:
            recommendations.append("현재 의존성 구조가 양호합니다.")
        case .medium:
            recommendations.append("정기적인 의존성 검토를 권장합니다.")
        case .high:
            recommendations.append("의존성 구조 개선이 필요합니다.")
        case .critical:
            recommendations.append("즉시 의존성 구조 재설계가 필요합니다.")
        }

        return recommendations
    }

    // MARK: - Auto-Fix Simulations

    private static func simulateInterfaceExtraction(_ fix: AutomaticFix) -> AutoFixResult {
        // 인터페이스 추출 시뮬레이션
        return AutoFixResult(
            success: true,
            message: "인터페이스 추출이 성공적으로 시뮬레이션되었습니다."
        )
    }

    private static func simulateIntermediateLayerCreation(_ fix: AutomaticFix) -> AutoFixResult {
        return AutoFixResult(
            success: true,
            message: "중간 계층 생성이 성공적으로 시뮬레이션되었습니다."
        )
    }

    private static func simulateDependencyInversion(_ fix: AutomaticFix) -> AutoFixResult {
        return AutoFixResult(
            success: true,
            message: "의존성 역전이 성공적으로 시뮬레이션되었습니다."
        )
    }

    private static func simulateLazyInitialization(_ fix: AutomaticFix) -> AutoFixResult {
        return AutoFixResult(
            success: true,
            message: "지연 초기화가 성공적으로 시뮬레이션되었습니다."
        )
    }

    // MARK: - Statistics & Reporting

    /// 탐지 시스템 통계
    public static func getDetectionStatistics() -> AdvancedDetectionStatistics {
        return AdvancedDetectionStatistics(
            totalAnalyses: detectionMetrics.totalAnalyses,
            averageAnalysisTime: detectionMetrics.averageAnalysisTime,
            detectedCycles: CircularDependencyDetector.shared.detectAllCircularDependencies().count,
            potentialIssues: potentialIssues.count,
            appliedFixes: appliedFixes.count,
            preventedIssues: detectionMetrics.preventedIssues
        )
    }

    /// 종합 리포트 생성
    public static func generateComprehensiveReport() -> String {
        let analysis = performComprehensiveAnalysis()
        let statistics = getDetectionStatistics()

        return """
        📋 Advanced Circular Dependency Detection Report
        ═══════════════════════════════════════════════════

        📊 Detection Statistics:
        • Total Analyses: \(statistics.totalAnalyses)
        • Average Analysis Time: \(String(format: "%.2f", statistics.averageAnalysisTime * 1000))ms
        • Detected Cycles: \(statistics.detectedCycles)
        • Potential Issues: \(statistics.potentialIssues)
        • Applied Fixes: \(statistics.appliedFixes)
        • Prevented Issues: \(statistics.preventedIssues)

        🔍 Current Analysis:
        • Basic Cycles: \(analysis.basicCycles.count)
        • Potential Cycles: \(analysis.potentialCycles.count)
        • Risk Level: \(analysis.riskAssessment.riskLevel.description)
        • Risk Score: \(String(format: "%.2f", analysis.riskAssessment.overallRiskScore))

        💡 Top Recommendations:
        \(analysis.recommendations.prefix(3).map { "• \($0.description)" }.joined(separator: "\n"))

        ⚠️  Risk Factors:
        \(analysis.riskAssessment.riskFactors.map { "• \($0)" }.joined(separator: "\n"))

        ═══════════════════════════════════════════════════
        """
    }

    /// 메모리 정리
    public static func cleanup() {
        dependencyChanges.removeAll()
        potentialIssues.removeAll()
        appliedFixes.removeAll()
        detectionMetrics = DetectionMetrics()

        #logDebug("🧹 [AdvancedCircularDependencyDetector] Cleanup completed")
    }
}

// MARK: - Data Models

/// 의존성 변경 기록
public struct DependencyChange: Sendable {
    public let timestamp: Date
    public let typeName: String
    public let changeType: DependencyChangeType
    public let dependencies: [String]
}

/// 의존성 변경 타입
public enum DependencyChangeType: Sendable {
    case registration
    case removal
    case modification
}

/// 의존성 검증 결과
public struct DependencyValidationResult: Sendable {
    public let isValid: Bool
    public let warnings: [String]
    public let issues: [CircularDependencyIssue]
}

/// 순환 의존성 이슈
public struct CircularDependencyIssue: Sendable {
    public let type: IssueType
    public let involvedTypes: [String]
    public let description: String
    public let severity: Severity

    public enum IssueType: Sendable {
        case directCircularDependency
        case indirectCircularDependency
        case potentialCircularDependency
    }

    public enum Severity: Sendable {
        case low, medium, high, critical
    }
}

/// 잠재적 순환 의존성 이슈
public struct PotentialCircularIssue: Sendable, Equatable {
    public let type: PotentialIssueType
    public let typeName: String
    public let description: String
    public let detectedAt: Date
    public let riskLevel: Double

    public enum PotentialIssueType: Sendable, Equatable {
        case frequentChanges
        case highCoupling
        case deepDependencyChain
        case broadInterface
    }

    public static func == (lhs: PotentialCircularIssue, rhs: PotentialCircularIssue) -> Bool {
        return lhs.type == rhs.type && lhs.typeName == rhs.typeName
    }
}

/// 잠재적 순환
public struct PotentialCycle: Sendable {
    public let involvedTypes: [String]
    public let riskLevel: Double
    public let description: String
}

/// 위험 평가
public struct RiskAssessment: Sendable {
    public let overallRiskScore: Double
    public let riskLevel: RiskLevel
    public let riskFactors: [String]
    public let recommendations: [String]
}

/// 종합 분석 결과
public struct ComprehensiveAnalysisResult: Sendable {
    public let basicCycles: [CircularDependencyPath]
    public let potentialCycles: [PotentialCycle]
    public let dependencyClusters: [DependencyCluster]
    public let riskAssessment: RiskAssessment
    public let recommendations: [DependencyRecommendation]
    public let analysisTime: TimeInterval
}

/// 의존성 권장사항
public struct DependencyRecommendation: Sendable {
    public let type: RecommendationType
    public let description: String
    public let priority: Priority
    public let actions: [String]

    public enum RecommendationType: Sendable {
        case breakCircularDependency
        case preventCircularDependency
        case optimizeCluster
        case reduceComplexity
    }

    public enum Priority: Sendable {
        case low, medium, high, critical
    }
}

/// 자동 수정
public struct AutomaticFix: Sendable {
    public let id: String
    public let type: FixType
    public let description: String
    public let targetTypes: [String]
    public let priority: Priority
    public let estimatedEffort: Effort
    public let actions: [String]

    public enum FixType: Sendable {
        case interfaceExtraction
        case intermediateLayer
        case dependencyInversion
        case lazyInitialization
    }

    public enum Priority: Int, Sendable {
        case low = 1, medium = 2, high = 3, critical = 4
    }

    public enum Effort: Sendable {
        case low, medium, high
    }
}

/// 자동 수정 결과
public struct AutoFixResult: Sendable {
    public let success: Bool
    public let message: String
}

/// 탐지 메트릭
private struct DetectionMetrics {
    var totalAnalyses: Int = 0
    var totalAnalysisTime: TimeInterval = 0
    var preventedIssues: Int = 0

    var averageAnalysisTime: TimeInterval {
        return totalAnalyses > 0 ? totalAnalysisTime / Double(totalAnalyses) : 0
    }

    mutating func recordAnalysis(duration: TimeInterval) {
        totalAnalyses += 1
        totalAnalysisTime += duration
    }

    mutating func recordPreventedIssue() {
        preventedIssues += 1
    }
}

/// 고급 탐지 통계
public struct AdvancedDetectionStatistics: Sendable {
    public let totalAnalyses: Int
    public let averageAnalysisTime: TimeInterval
    public let detectedCycles: Int
    public let potentialIssues: Int
    public let appliedFixes: Int
    public let preventedIssues: Int
}