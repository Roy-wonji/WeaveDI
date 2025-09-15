//
//  AutoGraphGenerator.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - Automatic Graph Generation System

/// 자동 그래프 생성 시스템
public final class AutoGraphGenerator: @unchecked Sendable {

    // MARK: - Shared Instance

    public static let shared = AutoGraphGenerator()

    // MARK: - Properties

    private let visualizer = DependencyGraphVisualizer.shared
    private let detector = CircularDependencyDetector.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Auto Generation API

    /// 프로젝트의 모든 그래프를 자동으로 생성
    public func generateAllGraphs(
        outputDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        formats: [GraphExportFormat] = [.dot, .mermaid, .text],
        options: GraphVisualizationOptions = .default
    ) throws {
        #logInfo("🎨 자동 그래프 생성 시작...")

        // 출력 디렉토리 생성
        let graphsDir = outputDirectory.appendingPathComponent("dependency_graphs")
        try FileManager.default.createDirectory(at: graphsDir, withIntermediateDirectories: true)

        // 각 형식별로 그래프 생성
        for format in formats {
            try generateGraph(format: format, outputDirectory: graphsDir, options: options)
        }

        // HTML 대시보드 생성
        try generateHTMLDashboard(outputDirectory: graphsDir, options: options)

        #logInfo("✅ 자동 그래프 생성 완료!")
        #logDebug("📁 출력 디렉토리: \(graphsDir.path)")
    }

    /// 실시간 그래프 모니터링 시작
    public func startRealtimeGraphMonitoring(
        outputDirectory: URL,
        refreshInterval: TimeInterval = 5.0
    ) {
        #logInfo("🔄 실시간 그래프 모니터링 시작...")

        Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            do {
                try self.generateAllGraphs(outputDirectory: outputDirectory, formats: [.text, .mermaid])
                #logInfo("📊 그래프 업데이트됨 - \(Date())")
            } catch {
                #logError("❌ 그래프 업데이트 실패: \(error)")
            }
        }
    }

    /// 순환 의존성 자동 탐지 및 리포트 생성
    public func generateCircularDependencyReport(outputDirectory: URL) throws {
        #logInfo("🔍 순환 의존성 분석 중...")

        let cycles = detector.detectAllCircularDependencies()
        let statistics = detector.getGraphStatistics()

        let reportContent = generateCircularDependencyReportContent(cycles: cycles, statistics: statistics)

        let reportURL = outputDirectory.appendingPathComponent("circular_dependency_report.md")
        try reportContent.write(to: reportURL, atomically: true, encoding: .utf8)

        #logInfo("📋 순환 의존성 리포트 생성: \(reportURL.path)")

        // 순환 의존성이 발견된 경우 추가 처리
        if !cycles.isEmpty {
            #logError("⚠️  \(cycles.count)개의 순환 의존성 발견!")
            for (index, cycle) in cycles.enumerated() {
                #logDebug("   \(index + 1). \(cycle.description)")
            }

            // 순환 의존성 전용 그래프 생성
            try generateCycleOnlyGraph(cycles: cycles, outputDirectory: outputDirectory)
        }
    }

    /// 의존성 메트릭 대시보드 생성
    public func generateMetricsDashboard(outputDirectory: URL) throws {
        #logInfo("📊 메트릭 대시보드 생성 중...")

        let statistics = detector.getGraphStatistics()
        let cycles = detector.detectAllCircularDependencies()

        let dashboardHTML = generateMetricsDashboardHTML(statistics: statistics, cycles: cycles)
        let dashboardURL = outputDirectory.appendingPathComponent("metrics_dashboard.html")

        try dashboardHTML.write(to: dashboardURL, atomically: true, encoding: .utf8)
        #logInfo("🎯 메트릭 대시보드 생성: \(dashboardURL.path)")
    }

    // MARK: - Private Helpers

    private func generateGraph(
        format: GraphExportFormat,
        outputDirectory: URL,
        options: GraphVisualizationOptions
    ) throws {
        let filename: String
        let content: String

        switch format {
        case .dot:
            filename = "dependency_graph.dot"
            content = visualizer.generateDOTGraph(options: options)

        case .mermaid:
            filename = "dependency_graph.mmd"
            content = visualizer.generateMermaidGraph(options: options)

        case .text:
            filename = "dependency_tree.txt"
            content = visualizer.generateASCIIGraph()

        case .json:
            filename = "dependency_graph.json"
            content = try visualizer.generateJSONGraph()
        }

        let fileURL = outputDirectory.appendingPathComponent(filename)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        #logInfo("📄 \(filename) 생성됨")

        // DOT 파일의 경우 PNG/SVG 변환 시도
        if format == .dot {
            try convertDOTToImages(dotFile: fileURL, outputDirectory: outputDirectory)
        }
    }

    private func convertDOTToImages(dotFile: URL, outputDirectory: URL) throws {
        #if os(macOS)
        let dotPath = dotFile.path
        let baseURL = outputDirectory.appendingPathComponent("dependency_graph")

        // PNG 생성
        let pngCommand = "dot -Tpng \"\(dotPath)\" -o \"\(baseURL.appendingPathExtension("png").path)\""
        _ = try? executeShellCommand(pngCommand)

        // SVG 생성
        let svgCommand = "dot -Tsvg \"\(dotPath)\" -o \"\(baseURL.appendingPathExtension("svg").path)\""
        _ = try? executeShellCommand(svgCommand)

        #logInfo("🖼️  이미지 파일 생성 시도 (Graphviz 필요)")
        #else
        // iOS / 다른 플랫폼에서는 외부 프로세스 실행이 불가하므로 스킵
        #logInfo("ℹ️ Graphviz 이미지 변환은 이 플랫폼에서 지원되지 않습니다. (DOT 파일만 생성)")
        #endif
    }

    private func executeShellCommand(_ command: String) throws -> String {
        #if os(macOS)
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", command]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
        #else
        throw NSError(domain: "AutoGraphGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Shell command execution is not supported on this platform."])
        #endif
    }

    private func generateHTMLDashboard(
        outputDirectory: URL,
        options: GraphVisualizationOptions
    ) throws {
        let dashboardHTML = """
        <!DOCTYPE html>
        <html lang="ko">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>DiContainer 의존성 그래프 대시보드</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
                .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                .header { text-align: center; margin-bottom: 30px; }
                .graph-section { margin: 20px 0; }
                .graph-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
                .graph-card { border: 1px solid #ddd; border-radius: 8px; padding: 15px; background: #fafafa; }
                .graph-card h3 { margin-top: 0; color: #333; }
                .download-btn { display: inline-block; padding: 8px 16px; background: #007AFF; color: white; text-decoration: none; border-radius: 4px; margin: 5px; }
                .stats { background: #e3f2fd; padding: 15px; border-radius: 8px; margin: 20px 0; }
                pre { background: #f8f9fa; padding: 15px; border-radius: 4px; overflow-x: auto; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🎨 DiContainer 의존성 그래프 대시보드</h1>
                    <p>자동 생성된 의존성 그래프와 분석 결과</p>
                    <p><small>생성 시간: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium))</small></p>
                </div>

                <div class="stats">
                    <h2>📊 통계 정보</h2>
                    <pre>\(detector.getGraphStatistics().summary)</pre>
                </div>

                <div class="graph-section">
                    <h2>📋 사용 가능한 그래프</h2>
                    <div class="graph-grid">
                        <div class="graph-card">
                            <h3>🌐 DOT 그래프 (Graphviz)</h3>
                            <p>전문적인 그래프 시각화 도구용</p>
                            <a href="dependency_graph.dot" class="download-btn">DOT 다운로드</a>
                            <a href="dependency_graph.png" class="download-btn">PNG 다운로드</a>
                            <a href="dependency_graph.svg" class="download-btn">SVG 다운로드</a>
                        </div>

                        <div class="graph-card">
                            <h3>🧜‍♀️ Mermaid 그래프</h3>
                            <p>GitHub, Notion 등에서 바로 사용 가능</p>
                            <a href="dependency_graph.mmd" class="download-btn">Mermaid 다운로드</a>
                        </div>

                        <div class="graph-card">
                            <h3>📝 텍스트 트리</h3>
                            <p>콘솔에서 바로 확인 가능한 ASCII 아트</p>
                            <a href="dependency_tree.txt" class="download-btn">텍스트 다운로드</a>
                        </div>

                        <div class="graph-card">
                            <h3>📊 JSON 데이터</h3>
                            <p>프로그래밍 방식으로 처리 가능한 구조화된 데이터</p>
                            <a href="dependency_graph.json" class="download-btn">JSON 다운로드</a>
                        </div>
                    </div>
                </div>

                <div class="graph-section">
                    <h2>⚙️ 사용법</h2>
                    <h3>Graphviz로 이미지 생성:</h3>
                    <pre>dot -Tpng dependency_graph.dot -o graph.png</pre>

                    <h3>Mermaid 온라인 에디터:</h3>
                    <p><a href="https://mermaid.live" target="_blank">https://mermaid.live</a></p>
                </div>
            </div>
        </body>
        </html>
        """

        let dashboardURL = outputDirectory.appendingPathComponent("index.html")
        try dashboardHTML.write(to: dashboardURL, atomically: true, encoding: .utf8)

        #logInfo("🌐 HTML 대시보드 생성: \(dashboardURL.path)")
    }

    private func generateCircularDependencyReportContent(
        cycles: [CircularDependencyPath],
        statistics: DependencyGraphStatistics
    ) -> String {
        var report = """
        # 순환 의존성 분석 리포트

        생성 일시: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .medium))

        ## 📊 전체 통계

        \(statistics.summary)

        """

        if cycles.isEmpty {
            report += """

            ## ✅ 순환 의존성 없음

            축하합니다! 현재 의존성 그래프에서 순환 의존성이 발견되지 않았습니다.

            """
        } else {
            report += """

            ## ⚠️ 발견된 순환 의존성 (\(cycles.count)개)

            """

            for (index, cycle) in cycles.enumerated() {
                report += """

                ### \(index + 1). 순환 \(index + 1)
                **경로:** \(cycle.description)
                **길이:** \(cycle.path.count - 1)단계

                """
            }

            report += """

            ## 🔧 해결 방안

            1. **인터페이스 분리**: 순환하는 의존성들 사이에 추상화 계층 도입
            2. **의존성 역전**: 상위 레벨 모듈이 하위 레벨 모듈에 의존하지 않도록 설계
            3. **이벤트 기반 통신**: 직접적인 의존성 대신 이벤트/델리게이트 패턴 사용
            4. **모듈 재구성**: 관련 기능들을 하나의 모듈로 통합하여 순환 제거

            """
        }

        return report
    }

    private func generateCycleOnlyGraph(
        cycles: [CircularDependencyPath],
        outputDirectory: URL
    ) throws {
        // 순환 의존성만 포함하는 특별한 그래프 생성
        let cycleOptions = GraphVisualizationOptions()
        let cycleGraph = visualizer.generateDOTGraph(
            title: "Circular Dependencies Only",
            options: cycleOptions
        )

        let cycleURL = outputDirectory.appendingPathComponent("circular_dependencies_only.dot")
        try cycleGraph.write(to: cycleURL, atomically: true, encoding: .utf8)

        #logInfo("🔄 순환 의존성 전용 그래프 생성: \(cycleURL.path)")
    }

    private func generateMetricsDashboardHTML(
        statistics: DependencyGraphStatistics,
        cycles: [CircularDependencyPath]
    ) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>DiContainer 메트릭 대시보드</title>
            <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
            <style>
                body { font-family: Arial, sans-serif; padding: 20px; }
                .metric-card { border: 1px solid #ddd; border-radius: 8px; padding: 20px; margin: 10px; background: white; }
                .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
                .metric-value { font-size: 2em; font-weight: bold; color: #007AFF; }
                .cycle-warning { background: #ffebee; border-left: 4px solid #f44336; padding: 15px; }
            </style>
        </head>
        <body>
            <h1>📊 DiContainer 메트릭 대시보드</h1>

            <div class="grid">
                <div class="metric-card">
                    <h3>총 타입 수</h3>
                    <div class="metric-value">\(statistics.totalTypes)</div>
                </div>

                <div class="metric-card">
                    <h3>총 의존성 수</h3>
                    <div class="metric-value">\(statistics.totalDependencies)</div>
                </div>

                <div class="metric-card">
                    <h3>평균 의존성/타입</h3>
                    <div class="metric-value">\(String(format: "%.1f", statistics.averageDependenciesPerType))</div>
                </div>

                <div class="metric-card">
                    <h3>순환 의존성</h3>
                    <div class="metric-value" style="color: \(cycles.isEmpty ? "#4CAF50" : "#f44336")">\(statistics.detectedCycles)</div>
                </div>
            </div>

            \(cycles.isEmpty ? "" : """
            <div class="cycle-warning">
                <h3>⚠️ 순환 의존성 경고</h3>
                <p>\(cycles.count)개의 순환 의존성이 발견되었습니다. 즉시 수정이 필요합니다.</p>
            </div>
            """)

            <div style="margin-top: 30px;">
                <p><small>최종 업데이트: \(Date())</small></p>
            </div>
        </body>
        </html>
        """
    }
}

// MARK: - CLI Integration

public extension AutoGraphGenerator {

    /// 명령줄에서 사용할 수 있는 빠른 생성 메서드
    static func quickGenerate(
        outputPath: String? = nil,
        includeImages: Bool = true
    ) throws {
        let outputURL: URL
        if let path = outputPath {
            outputURL = URL(fileURLWithPath: path)
        } else {
            outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        }

        let formats: [GraphExportFormat] = includeImages ? [.dot, .mermaid, .text, .json] : [.mermaid, .text]

        try AutoGraphGenerator.shared.generateAllGraphs(
            outputDirectory: outputURL,
            formats: formats
        )

        try AutoGraphGenerator.shared.generateCircularDependencyReport(outputDirectory: outputURL.appendingPathComponent("dependency_graphs"))
        try AutoGraphGenerator.shared.generateMetricsDashboard(outputDirectory: outputURL.appendingPathComponent("dependency_graphs"))
    }
}
