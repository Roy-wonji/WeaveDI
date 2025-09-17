//
//  InteractiveDependencyVisualizer.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - Interactive Dependency Visualization System

/// 실시간 의존성 그래프 시각화 및 분석 도구
///
/// ## 개요
///
/// 기존 DependencyGraphVisualizer를 확장하여 실시간 모니터링과
/// 대화형 분석 기능을 제공합니다.
///
/// ## 핵심 기능
///
/// ### 🔄 실시간 모니터링
/// - 의존성 해결 과정 실시간 추적
/// - 성능 병목 지점 시각화
/// - Actor Hop 패턴 분석
///
/// ### 📊 대화형 분석
/// - 의존성 경로 탐색
/// - 영향도 분석 (Impact Analysis)
/// - 순환 의존성 상세 분석
///
/// ### 🎯 최적화 가이드
/// - 개선 포인트 자동 식별
/// - 리팩토링 제안
/// - 성능 개선 시뮬레이션
///
/// ## 사용 예시
///
/// ```swift
/// // 실시간 모니터링 시작
/// InteractiveDependencyVisualizer.startLiveMonitoring()
///
/// // 특정 타입의 영향도 분석
/// let impact = InteractiveDependencyVisualizer.analyzeImpact(of: UserService.self)
/// print(impact.summary)
///
/// // 대화형 HTML 리포트 생성
/// let html = InteractiveDependencyVisualizer.generateInteractiveReport()
/// try html.write(to: URL(fileURLWithPath: "dependency_report.html"))
/// ```
@MainActor
public enum InteractiveDependencyVisualizer {

    // MARK: - Configuration

    /// 실시간 모니터링 활성화 여부
    private static var isLiveMonitoringActive: Bool = false

    /// 실시간 데이터 수집기
    private static var liveDataCollector: LiveDataCollector?

    /// 분석 세션 관리
    private static var activeSessions: [String: AnalysisSession] = [:]

    // MARK: - Live Monitoring

    /// 실시간 모니터링 시작
    public static func startLiveMonitoring(options: LiveMonitoringOptions = .default) {
        guard !isLiveMonitoringActive else {
            #logDebug("⚠️ [InteractiveDependencyVisualizer] Live monitoring already active")
            return
        }

        liveDataCollector = LiveDataCollector(options: options)
        isLiveMonitoringActive = true

        #logDebug("✅ [InteractiveDependencyVisualizer] Live monitoring started")
    }

    /// 실시간 모니터링 중지
    public static func stopLiveMonitoring() {
        liveDataCollector = nil
        isLiveMonitoringActive = false
        #logDebug("🔴 [InteractiveDependencyVisualizer] Live monitoring stopped")
    }

    /// 현재 라이브 데이터 가져오기
    public static func getCurrentLiveData() -> LiveDependencyData? {
        return liveDataCollector?.getCurrentSnapshot()
    }

    // MARK: - Impact Analysis

    /// 타입의 영향도 분석
    public static func analyzeImpact<T>(of type: T.Type) -> ImpactAnalysisResult {
        let typeName = String(describing: type)
        return analyzeImpact(ofTypeName: typeName)
    }

    /// 타입명 기반 영향도 분석
    public static func analyzeImpact(ofTypeName typeName: String) -> ImpactAnalysisResult {
        let sessionId = "impact_\(typeName)_\(Date().timeIntervalSince1970)"
        let session = AnalysisSession(id: sessionId, type: .impactAnalysis, startTime: Date())
        activeSessions[sessionId] = session

        // 직접 의존성 분석
        let directDependencies = getDirectDependencies(for: typeName)
        let directDependents = getDirectDependents(for: typeName)

        // 간접 의존성 분석 (전체 그래프 탐색)
        let indirectDependencies = getIndirectDependencies(for: typeName, maxDepth: 5)
        let indirectDependents = getIndirectDependents(for: typeName, maxDepth: 5)

        // 순환 의존성 참여 여부
        let cycles = CircularDependencyDetector.shared.detectAllCircularDependencies()
        let involvedCycles = cycles.filter { $0.path.contains(typeName) }

        // 성능 메트릭 (ActorHopMetrics와 연동)
        let performanceImpact = analyzePerformanceImpact(for: typeName)

        let result = ImpactAnalysisResult(
            targetType: typeName,
            directDependencies: directDependencies,
            directDependents: directDependents,
            indirectDependencies: indirectDependencies,
            indirectDependents: indirectDependents,
            involvedCycles: involvedCycles,
            performanceImpact: performanceImpact,
            riskLevel: calculateRiskLevel(
                directDependents: directDependents.count,
                indirectDependents: indirectDependents.count,
                cycles: involvedCycles.count
            )
        )

        activeSessions.removeValue(forKey: sessionId)
        return result
    }

    /// 의존성 경로 탐색
    public static func findDependencyPath(from: String, to: String) -> DependencyPathResult {
        let paths = findAllPaths(from: from, to: to, maxDepth: 10)
        let shortestPath = paths.min { $0.count < $1.count }

        return DependencyPathResult(
            source: from,
            target: to,
            shortestPath: shortestPath ?? [],
            allPaths: paths,
            hasDirectConnection: paths.contains { $0.count == 2 },
            estimatedImpact: calculatePathImpact(paths)
        )
    }

    // MARK: - Interactive Report Generation

    /// 대화형 HTML 리포트 생성
    public static func generateInteractiveReport(
        title: String = "DiContainer Dependency Analysis",
        options: InteractiveReportOptions = .default
    ) -> String {
        let graphData = collectGraphData()
        let statistics = CircularDependencyDetector.shared.getGraphStatistics()
        let cycles = CircularDependencyDetector.shared.detectAllCircularDependencies()
        let performanceData = ActorHopMetrics.generateReport()

        return generateHTMLReport(
            title: title,
            graphData: graphData,
            statistics: statistics,
            cycles: cycles,
            performanceData: performanceData,
            options: options
        )
    }

    /// 실시간 대시보드 HTML 생성
    public static func generateLiveDashboard() -> String {
        let liveData = getCurrentLiveData()

        return """
        <!DOCTYPE html>
        <html lang="ko">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>DiContainer Live Dashboard</title>
            <script src="https://d3js.org/d3.v7.min.js"></script>
            <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
            <style>
                \(getDashboardCSS())
            </style>
        </head>
        <body>
            <div class="dashboard">
                <header>
                    <h1>🔄 DiContainer Live Dashboard</h1>
                    <div class="status \(isLiveMonitoringActive ? "active" : "inactive")">
                        \(isLiveMonitoringActive ? "🟢 Live" : "🔴 Offline")
                    </div>
                </header>

                <div class="metrics-grid">
                    <div class="metric-card">
                        <h3>📊 Resolution Metrics</h3>
                        <div id="resolution-chart"></div>
                    </div>

                    <div class="metric-card">
                        <h3>🔄 Actor Hops</h3>
                        <div id="actor-hop-chart"></div>
                    </div>

                    <div class="metric-card">
                        <h3>🌐 Dependency Graph</h3>
                        <div id="live-graph"></div>
                    </div>

                    <div class="metric-card">
                        <h3>⚠️ Issues</h3>
                        <div id="issues-list"></div>
                    </div>
                </div>
            </div>

            <script>
                \(getDashboardJavaScript(liveData: liveData))
            </script>
        </body>
        </html>
        """
    }

    // MARK: - Advanced Analysis

    /// 의존성 클러스터 분석
    public static func analyzeDependencyClusters() -> [DependencyCluster] {
        let allTypes = getAllRegisteredTypes()
        let edges = getDependencyEdges()

        // 그래프 클러스터링 알고리즘 적용
        let clusters = performCommunityDetection(nodes: allTypes, edges: edges)

        return clusters.map { clusterNodes in
            DependencyCluster(
                id: UUID().uuidString,
                members: clusterNodes,
                cohesion: calculateClusterCohesion(clusterNodes, edges: edges),
                interfaces: findClusterInterfaces(clusterNodes, edges: edges)
            )
        }
    }

    /// 레이어 아키텍처 검증
    public static func validateLayerArchitecture(layers: [ArchitectureLayer]) -> LayerValidationResult {
        var violations: [LayerViolation] = []
        let edges = getDependencyEdges()

        // 레이어 간 의존성 방향 검증
        for edge in edges {
            let sourceLayer = findLayerForType(edge.from, in: layers)
            let targetLayer = findLayerForType(edge.to, in: layers)

            if let source = sourceLayer, let target = targetLayer {
                if source.level < target.level {
                    violations.append(LayerViolation(
                        from: edge.from,
                        to: edge.to,
                        sourceLayer: source.name,
                        targetLayer: target.name,
                        violationType: .downwardDependency
                    ))
                }
            }
        }

        return LayerValidationResult(
            layers: layers,
            violations: violations,
            complianceScore: calculateComplianceScore(violations: violations, totalEdges: edges.count)
        )
    }

    // MARK: - Private Helpers

    private static func getDirectDependencies(for typeName: String) -> [String] {
        let edges = getDependencyEdges()
        return edges.compactMap { $0.from == typeName ? $0.to : nil }
    }

    private static func getDirectDependents(for typeName: String) -> [String] {
        let edges = getDependencyEdges()
        return edges.compactMap { $0.to == typeName ? $0.from : nil }
    }

    private static func getIndirectDependencies(for typeName: String, maxDepth: Int) -> [String] {
        var visited: Set<String> = []
        var dependencies: Set<String> = []

        func traverse(_ current: String, depth: Int) {
            guard depth < maxDepth, !visited.contains(current) else { return }
            visited.insert(current)

            let directDeps = getDirectDependencies(for: current)
            for dep in directDeps {
                dependencies.insert(dep)
                traverse(dep, depth: depth + 1)
            }
        }

        traverse(typeName, depth: 0)
        return Array(dependencies)
    }

    private static func getIndirectDependents(for typeName: String, maxDepth: Int) -> [String] {
        var visited: Set<String> = []
        var dependents: Set<String> = []

        func traverse(_ current: String, depth: Int) {
            guard depth < maxDepth, !visited.contains(current) else { return }
            visited.insert(current)

            let directDeps = getDirectDependents(for: current)
            for dep in directDeps {
                dependents.insert(dep)
                traverse(dep, depth: depth + 1)
            }
        }

        traverse(typeName, depth: 0)
        return Array(dependents)
    }

    private static func analyzePerformanceImpact(for typeName: String) -> PerformanceImpact {
        let report = ActorHopMetrics.generateReport()
        let typeStats = report.typeStatistics.first { $0.typeName == typeName }

        return PerformanceImpact(
            averageResolutionTime: typeStats?.averageDuration ?? 0,
            averageActorHops: typeStats?.averageHops ?? 0,
            resolutionCount: typeStats?.measurementCount ?? 0,
            performanceRank: calculatePerformanceRank(typeStats, in: report.typeStatistics)
        )
    }

    private static func calculateRiskLevel(directDependents: Int, indirectDependents: Int, cycles: Int) -> RiskLevel {
        let totalImpact = directDependents * 3 + indirectDependents + cycles * 10

        switch totalImpact {
        case 0...5: return .low
        case 6...15: return .medium
        case 16...30: return .high
        default: return .critical
        }
    }

    private static func findAllPaths(from: String, to: String, maxDepth: Int) -> [[String]] {
        var paths: [[String]] = []
        var currentPath: [String] = [from]

        func dfs(_ current: String, depth: Int) {
            guard depth < maxDepth else { return }

            if current == to {
                paths.append(currentPath)
                return
            }

            let neighbors = getDirectDependencies(for: current)
            for neighbor in neighbors {
                if !currentPath.contains(neighbor) {
                    currentPath.append(neighbor)
                    dfs(neighbor, depth: depth + 1)
                    currentPath.removeLast()
                }
            }
        }

        dfs(from, depth: 0)
        return paths
    }

    private static func calculatePathImpact(_ paths: [[String]]) -> Double {
        guard !paths.isEmpty else { return 0 }

        let averageLength = Double(paths.reduce(0) { $0 + $1.count }) / Double(paths.count)
        let pathCount = Double(paths.count)

        // 경로가 많고 길수록 영향도가 큽니다
        return averageLength * log2(pathCount + 1)
    }

    // MARK: - Data Collection

    private static func collectGraphData() -> GraphData {
        let nodes = getAllRegisteredTypes()
        let edges = getDependencyEdges()
        let clusters = analyzeDependencyClusters()

        return GraphData(
            nodes: Array(nodes),
            edges: edges,
            clusters: clusters
        )
    }

    private static func getAllRegisteredTypes() -> Set<String> {
        // DependencyGraphVisualizer의 기존 로직 재사용
        return DependencyGraphVisualizer.getAllRegisteredTypes()
    }

    private static func getDependencyEdges() -> [(from: String, to: String)] {
        // DependencyGraphVisualizer의 기존 로직 재사용
        return DependencyGraphVisualizer.getDependencyEdges()
    }

    // MARK: - HTML Generation Helpers

    private static func generateHTMLReport(
        title: String,
        graphData: GraphData,
        statistics: DependencyGraphStatistics,
        cycles: [CircularDependencyPath],
        performanceData: ActorHopReport,
        options: InteractiveReportOptions
    ) -> String {
        return """
        <!DOCTYPE html>
        <html lang="ko">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(title)</title>
            \(getReportHTMLHeaders())
        </head>
        <body>
            <div class="report-container">
                \(generateReportHeader(title: title, statistics: statistics))
                \(generateNavigationTabs())
                \(generateOverviewSection(statistics: statistics, cycles: cycles))
                \(generateGraphSection(graphData: graphData))
                \(generatePerformanceSection(performanceData: performanceData))
                \(generateCyclesSection(cycles: cycles))
                \(generateRecommendationsSection())
            </div>
            \(getReportJavaScript(graphData: graphData, cycles: cycles))
        </body>
        </html>
        """
    }

    private static func getReportHTMLHeaders() -> String {
        return """
        <script src="https://d3js.org/d3.v7.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; }
            .report-container { max-width: 1200px; margin: 0 auto; padding: 20px; }
            .metric-card { background: #f8f9fa; border-radius: 8px; padding: 20px; margin: 10px 0; }
            .graph-container { height: 600px; border: 1px solid #ddd; border-radius: 8px; }
            .cycle-warning { background: #fff3cd; border: 1px solid #ffeaa7; border-radius: 4px; padding: 10px; }
            .performance-good { color: #28a745; }
            .performance-warning { color: #ffc107; }
            .performance-danger { color: #dc3545; }
            .nav-tabs .nav-link { color: #495057; }
            .nav-tabs .nav-link.active { background-color: #007bff; color: white; }
        </style>
        """
    }

    private static func generateReportHeader(title: String, statistics: DependencyGraphStatistics) -> String {
        return """
        <header class="mb-4">
            <h1 class="text-primary">📊 \(title)</h1>
            <p class="text-muted">Generated on \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))</p>
            <div class="row">
                <div class="col-md-3">
                    <div class="metric-card text-center">
                        <h3 class="text-info">\(statistics.totalTypes)</h3>
                        <p>Total Types</p>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="metric-card text-center">
                        <h3 class="text-info">\(statistics.totalConnections)</h3>
                        <p>Connections</p>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="metric-card text-center">
                        <h3 class="text-warning">\(statistics.circularDependencies)</h3>
                        <p>Circular Dependencies</p>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="metric-card text-center">
                        <h3 class="text-success">\(String(format: "%.1f", statistics.averageComplexity))</h3>
                        <p>Avg Complexity</p>
                    </div>
                </div>
            </div>
        </header>
        """
    }

    private static func generateNavigationTabs() -> String {
        return """
        <ul class="nav nav-tabs" id="reportTabs" role="tablist">
            <li class="nav-item" role="presentation">
                <button class="nav-link active" id="overview-tab" data-bs-toggle="tab" data-bs-target="#overview" type="button">📈 Overview</button>
            </li>
            <li class="nav-item" role="presentation">
                <button class="nav-link" id="graph-tab" data-bs-toggle="tab" data-bs-target="#graph" type="button">🌐 Graph</button>
            </li>
            <li class="nav-item" role="presentation">
                <button class="nav-link" id="performance-tab" data-bs-toggle="tab" data-bs-target="#performance" type="button">⚡ Performance</button>
            </li>
            <li class="nav-item" role="presentation">
                <button class="nav-link" id="cycles-tab" data-bs-toggle="tab" data-bs-target="#cycles" type="button">🔄 Cycles</button>
            </li>
        </ul>
        """
    }

    private static func generateOverviewSection(statistics: DependencyGraphStatistics, cycles: [CircularDependencyPath]) -> String {
        return """
        <div class="tab-content mt-3">
            <div class="tab-pane fade show active" id="overview">
                <div class="row">
                    <div class="col-md-8">
                        <div class="metric-card">
                            <h4>📊 Dependency Statistics</h4>
                            <p>\(statistics.summary)</p>
                        </div>
                    </div>
                    <div class="col-md-4">
                        <div class="metric-card">
                            <h4>🏥 Health Score</h4>
                            <div class="progress mb-2">
                                <div class="progress-bar bg-\(getHealthScoreColor(statistics))" style="width: \(statistics.healthScore)%"></div>
                            </div>
                            <p>\(String(format: "%.1f", statistics.healthScore))% Healthy</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        """
    }

    private static func generateGraphSection(graphData: GraphData) -> String {
        return """
        <div class="tab-pane fade" id="graph">
            <div class="metric-card">
                <h4>🌐 Interactive Dependency Graph</h4>
                <div id="dependency-graph" class="graph-container"></div>
                <div class="mt-3">
                    <button class="btn btn-primary" onclick="resetGraphZoom()">Reset Zoom</button>
                    <button class="btn btn-secondary" onclick="toggleCycleHighlight()">Toggle Cycles</button>
                    <button class="btn btn-info" onclick="showClusterView()">Show Clusters</button>
                </div>
            </div>
        </div>
        """
    }

    private static func generatePerformanceSection(performanceData: ActorHopReport) -> String {
        return """
        <div class="tab-pane fade" id="performance">
            <div class="metric-card">
                <h4>⚡ Performance Analysis</h4>
                <div class="row">
                    <div class="col-md-6">
                        <canvas id="performance-chart"></canvas>
                    </div>
                    <div class="col-md-6">
                        <h5>🎯 Top Performers</h5>
                        \(generatePerformanceTable(performanceData.typeStatistics))
                    </div>
                </div>
            </div>
        </div>
        """
    }

    private static func generateCyclesSection(cycles: [CircularDependencyPath]) -> String {
        let cyclesList = cycles.isEmpty ? "<p>🎉 No circular dependencies found!</p>" :
            cycles.enumerated().map { index, cycle in
                """
                <div class="cycle-warning mb-2">
                    <h6>Cycle \(index + 1):</h6>
                    <p>\(cycle.path.joined(separator: " → ")) → \(cycle.path.first ?? "")</p>
                </div>
                """
            }.joined()

        return """
        <div class="tab-pane fade" id="cycles">
            <div class="metric-card">
                <h4>🔄 Circular Dependencies</h4>
                \(cyclesList)
            </div>
        </div>
        """
    }

    private static func generateRecommendationsSection() -> String {
        return """
        <div class="tab-pane fade" id="recommendations">
            <div class="metric-card">
                <h4>💡 Optimization Recommendations</h4>
                <div id="recommendations-list"></div>
            </div>
        </div>
        """
    }

    private static func getHealthScoreColor(_ statistics: DependencyGraphStatistics) -> String {
        switch statistics.healthScore {
        case 80...100: return "success"
        case 60...79: return "warning"
        default: return "danger"
        }
    }

    private static func generatePerformanceTable(_ typeStats: [TypeActorStats]) -> String {
        let topPerformers = typeStats.sorted { $0.averageDuration < $1.averageDuration }.prefix(5)

        let rows = topPerformers.map { stats in
            """
            <tr>
                <td>\(stats.typeName)</td>
                <td>\(String(format: "%.2f", stats.averageDuration * 1000))ms</td>
                <td>\(String(format: "%.1f", stats.averageHops))</td>
            </tr>
            """
        }.joined()

        return """
        <table class="table table-sm">
            <thead>
                <tr>
                    <th>Type</th>
                    <th>Avg Time</th>
                    <th>Avg Hops</th>
                </tr>
            </thead>
            <tbody>
                \(rows)
            </tbody>
        </table>
        """
    }

    private static func getReportJavaScript(graphData: GraphData, cycles: [CircularDependencyPath]) -> String {
        return """
        <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
        <script>
            // 여기에 D3.js 기반 대화형 그래프 구현
            // 실제 구현에서는 graphData와 cycles를 활용한 시각화
            console.log('Interactive report loaded');

            function resetGraphZoom() {
                // 그래프 줌 리셋 구현
            }

            function toggleCycleHighlight() {
                // 순환 의존성 하이라이트 토글 구현
            }

            function showClusterView() {
                // 클러스터 뷰 표시 구현
            }
        </script>
        """
    }

    // MARK: - Dashboard Helpers

    private static func getDashboardCSS() -> String {
        return """
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #f5f5f7; }
        .dashboard { max-width: 1400px; margin: 0 auto; padding: 20px; }
        header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 30px; }
        .status { padding: 8px 16px; border-radius: 20px; font-weight: 600; }
        .status.active { background: #d4f4dd; color: #1d7324; }
        .status.inactive { background: #f5d5d0; color: #c41e3a; }
        .metrics-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .metric-card { background: white; border-radius: 12px; padding: 24px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .metric-card h3 { margin-bottom: 16px; color: #1d1d1f; }
        """
    }

    private static func getDashboardJavaScript(liveData: LiveDependencyData?) -> String {
        return """
        const liveData = \(encodeLiveDataToJSON(liveData));

        // 차트 초기화 및 실시간 업데이트 로직
        function initializeDashboard() {
            // Chart.js를 사용한 실시간 차트 구현
            console.log('Dashboard initialized with live data:', liveData);
        }

        // 주기적으로 데이터 업데이트
        setInterval(() => {
            if (window.isLiveMonitoringActive) {
                updateDashboardData();
            }
        }, 5000);

        function updateDashboardData() {
            // 실시간 데이터 업데이트 구현
        }

        initializeDashboard();
        """
    }

    private static func encodeLiveDataToJSON(_ liveData: LiveDependencyData?) -> String {
        guard let data = liveData else { return "null" }

        // 실제로는 JSONEncoder를 사용하여 인코딩
        return """
        {
            "timestamp": "\(data.timestamp)",
            "activeResolutions": \(data.activeResolutions),
            "totalResolutions": \(data.totalResolutions),
            "averageHops": \(data.averageActorHops)
        }
        """
    }

    // MARK: - Clustering Algorithms

    private static func performCommunityDetection(nodes: Set<String>, edges: [(from: String, to: String)]) -> [[String]] {
        // 간단한 connected components 알고리즘 구현
        var visited: Set<String> = []
        var clusters: [[String]] = []

        for node in nodes {
            if !visited.contains(node) {
                var cluster: [String] = []
                var stack: [String] = [node]

                while !stack.isEmpty {
                    let current = stack.removeLast()
                    if !visited.contains(current) {
                        visited.insert(current)
                        cluster.append(current)

                        // 연결된 노드들 찾기
                        let connected = edges.compactMap { edge in
                            if edge.from == current { return edge.to }
                            if edge.to == current { return edge.from }
                            return nil
                        }

                        stack.append(contentsOf: connected.filter { !visited.contains($0) })
                    }
                }

                if !cluster.isEmpty {
                    clusters.append(cluster)
                }
            }
        }

        return clusters
    }

    private static func calculateClusterCohesion(_ members: [String], edges: [(from: String, to: String)]) -> Double {
        let memberSet = Set(members)
        let internalEdges = edges.filter { memberSet.contains($0.from) && memberSet.contains($0.to) }
        let maxPossibleEdges = members.count * (members.count - 1)

        return maxPossibleEdges > 0 ? Double(internalEdges.count) / Double(maxPossibleEdges) : 0
    }

    private static func findClusterInterfaces(_ members: [String], edges: [(from: String, to: String)]) -> [String] {
        let memberSet = Set(members)
        var interfaces: Set<String> = []

        for edge in edges {
            if memberSet.contains(edge.from) && !memberSet.contains(edge.to) {
                interfaces.insert(edge.from)
            }
            if memberSet.contains(edge.to) && !memberSet.contains(edge.from) {
                interfaces.insert(edge.to)
            }
        }

        return Array(interfaces)
    }

    // MARK: - Architecture Validation

    private static func findLayerForType(_ typeName: String, in layers: [ArchitectureLayer]) -> ArchitectureLayer? {
        return layers.first { layer in
            layer.types.contains(typeName) ||
            layer.patterns.contains { pattern in
                typeName.range(of: pattern, options: .regularExpression) != nil
            }
        }
    }

    private static func calculateComplianceScore(violations: [LayerViolation], totalEdges: Int) -> Double {
        guard totalEdges > 0 else { return 100.0 }
        let violationRate = Double(violations.count) / Double(totalEdges)
        return max(0, (1.0 - violationRate) * 100.0)
    }

    private static func calculatePerformanceRank(_ typeStats: TypeActorStats?, in allStats: [TypeActorStats]) -> Int {
        guard let stats = typeStats else { return allStats.count }

        let sorted = allStats.sorted { $0.averageDuration < $1.averageDuration }
        return sorted.firstIndex { $0.typeName == stats.typeName } ?? allStats.count
    }
}

// MARK: - Configuration Types

/// 실시간 모니터링 옵션
public struct LiveMonitoringOptions: Sendable {
    public var updateInterval: TimeInterval = 1.0
    public var maxHistorySize: Int = 1000
    public var trackPerformance: Bool = true
    public var trackActorHops: Bool = true

    public static let `default` = LiveMonitoringOptions()
}

/// 대화형 리포트 옵션
public struct InteractiveReportOptions: Sendable {
    public var includePerformanceData: Bool = true
    public var includeClusterAnalysis: Bool = true
    public var maxGraphNodes: Int = 100
    public var enableInteractivity: Bool = true

    public static let `default` = InteractiveReportOptions()
}

// MARK: - Data Models

/// 실시간 수집기
private class LiveDataCollector {
    let options: LiveMonitoringOptions
    private var resolutionHistory: [(timestamp: Date, typeName: String, duration: TimeInterval)] = []

    init(options: LiveMonitoringOptions) {
        self.options = options
    }

    func recordResolution(typeName: String, duration: TimeInterval) {
        let entry = (timestamp: Date(), typeName: typeName, duration: duration)
        resolutionHistory.append(entry)

        // 히스토리 크기 제한
        if resolutionHistory.count > options.maxHistorySize {
            resolutionHistory.removeFirst(resolutionHistory.count - options.maxHistorySize)
        }
    }

    func getCurrentSnapshot() -> LiveDependencyData {
        let now = Date()
        let recentEntries = resolutionHistory.filter { now.timeIntervalSince($0.timestamp) < 60 }

        return LiveDependencyData(
            timestamp: now,
            activeResolutions: recentEntries.count,
            totalResolutions: resolutionHistory.count,
            averageActorHops: 0.0, // 추후 구현 예정
            recentActivity: recentEntries.map { $0.typeName }
        )
    }

    @MainActor
    private func calculateAverageHops() -> Double {
        let report = ActorHopMetrics.generateReport()
        return report.averageHopsPerResolution
    }
}

/// 실시간 의존성 데이터
public struct LiveDependencyData: Sendable {
    public let timestamp: Date
    public let activeResolutions: Int
    public let totalResolutions: Int
    public let averageActorHops: Double
    public let recentActivity: [String]
}

/// 분석 세션
private struct AnalysisSession {
    let id: String
    let type: AnalysisType
    let startTime: Date

    enum AnalysisType {
        case impactAnalysis
        case pathFinding
        case clusterAnalysis
    }
}

/// 영향도 분석 결과
public struct ImpactAnalysisResult: Sendable {
    public let targetType: String
    public let directDependencies: [String]
    public let directDependents: [String]
    public let indirectDependencies: [String]
    public let indirectDependents: [String]
    public let involvedCycles: [CircularDependencyPath]
    public let performanceImpact: PerformanceImpact
    public let riskLevel: RiskLevel

    public var summary: String {
        return """
        🎯 Impact Analysis: \(targetType)

        📊 Dependencies:
        • Direct: \(directDependencies.count)
        • Indirect: \(indirectDependencies.count)

        👥 Dependents:
        • Direct: \(directDependents.count)
        • Indirect: \(indirectDependents.count)

        ⚡ Performance:
        • Resolution Time: \(String(format: "%.2f", performanceImpact.averageResolutionTime * 1000))ms
        • Actor Hops: \(String(format: "%.1f", performanceImpact.averageActorHops))

        🔄 Cycles: \(involvedCycles.count)

        ⚠️  Risk Level: \(riskLevel.description)
        """
    }
}

/// 의존성 경로 결과
public struct DependencyPathResult: Sendable {
    public let source: String
    public let target: String
    public let shortestPath: [String]
    public let allPaths: [[String]]
    public let hasDirectConnection: Bool
    public let estimatedImpact: Double
}

/// 성능 영향
public struct PerformanceImpact: Sendable {
    public let averageResolutionTime: TimeInterval
    public let averageActorHops: Double
    public let resolutionCount: Int
    public let performanceRank: Int
}

/// 위험 수준
public enum RiskLevel: Sendable, CustomStringConvertible {
    case low, medium, high, critical

    public var description: String {
        switch self {
        case .low: return "낮음"
        case .medium: return "보통"
        case .high: return "높음"
        case .critical: return "심각"
        }
    }
}

/// 의존성 클러스터
public struct DependencyCluster: Sendable {
    public let id: String
    public let members: [String]
    public let cohesion: Double
    public let interfaces: [String]
}

/// 아키텍처 레이어
public struct ArchitectureLayer: Sendable {
    public let name: String
    public let level: Int
    public let types: [String]
    public let patterns: [String]

    public init(name: String, level: Int, types: [String] = [], patterns: [String] = []) {
        self.name = name
        self.level = level
        self.types = types
        self.patterns = patterns
    }
}

/// 레이어 위반
public struct LayerViolation: Sendable {
    public let from: String
    public let to: String
    public let sourceLayer: String
    public let targetLayer: String
    public let violationType: ViolationType

    public enum ViolationType: Sendable {
        case downwardDependency
        case skipLayer
        case circularDependency
    }
}

/// 레이어 검증 결과
public struct LayerValidationResult: Sendable {
    public let layers: [ArchitectureLayer]
    public let violations: [LayerViolation]
    public let complianceScore: Double
}

/// 그래프 데이터
private struct GraphData: Sendable {
    let nodes: [String]
    let edges: [(from: String, to: String)]
    let clusters: [DependencyCluster]
}