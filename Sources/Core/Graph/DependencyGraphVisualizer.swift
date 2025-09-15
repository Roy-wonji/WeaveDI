//
//  DependencyGraphVisualizer.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation

// MARK: - Dependency Graph Visualization System

/// Needle 스타일의 의존성 그래프 시각화 시스템
public final class DependencyGraphVisualizer: @unchecked Sendable {

    // MARK: - Shared Instance

    public static let shared = DependencyGraphVisualizer()

    // MARK: - Properties

    private let detector = CircularDependencyDetector.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - DOT Graph Generation

    /// DOT 형식의 의존성 그래프 생성 (Graphviz 호환)
    public func generateDOTGraph(
        title: String = "DiContainer Dependency Graph",
        options: GraphVisualizationOptions = .default
    ) -> String {
        let statistics = detector.getGraphStatistics()
        let cycles = detector.detectAllCircularDependencies()

        var dot = """
        digraph "\(title)" {
            // Graph properties
            rankdir=\(options.direction.rawValue);
            bgcolor="\(options.backgroundColor)";
            node [shape=\(options.nodeShape.rawValue), style=filled];
            edge [color="\(options.edgeColor)"];

            // Graph title
            labelloc="t";
            label="\(title)\\n\(statistics.summary.replacingOccurrences(of: "\n", with: "\\n"))";

        """

        // 노드 정의
        dot += generateDOTNodes(options: options, cycles: cycles)

        // 엣지 정의
        dot += generateDOTEdges(options: options, cycles: cycles)

        // 순환 의존성 하이라이트
        if !cycles.isEmpty && options.highlightCycles {
            dot += generateCycleHighlights(cycles: cycles, options: options)
        }

        dot += "\n}"
        return dot
    }

    /// Mermaid 형식의 의존성 그래프 생성
    public func generateMermaidGraph(
        title: String = "DiContainer Dependency Graph",
        options: GraphVisualizationOptions = .default
    ) -> String {
        let statistics = detector.getGraphStatistics()
        let cycles = detector.detectAllCircularDependencies()

        var mermaid = """
        graph \(options.direction == .topToBottom ? "TD" : "LR")
            %% \(title)
            %% \(statistics.summary.replacingOccurrences(of: "\n", with: " | "))

        """

        // 의존성 관계 추가
        mermaid += generateMermaidEdges(cycles: cycles, options: options)

        // 스타일 정의
        mermaid += generateMermaidStyles(cycles: cycles, options: options)

        return mermaid
    }

    // MARK: - Text-based Visualization

    /// 텍스트 기반 의존성 트리 생성
    public func generateDependencyTree<T>(_ rootType: T.Type, maxDepth: Int = 5) -> String {
        let typeName = String(describing: rootType)
        return generateDependencyTree(typeName, maxDepth: maxDepth)
    }

    /// 텍스트 기반 의존성 트리 생성 (문자열 타입명)
    public func generateDependencyTree(_ rootTypeName: String, maxDepth: Int = 5) -> String {
        var result = "📦 \(rootTypeName)\n"
        var visitedNodes: Set<String> = []

        generateTreeRecursive(
            rootTypeName,
            prefix: "",
            isLast: true,
            depth: 0,
            maxDepth: maxDepth,
            visited: &visitedNodes,
            result: &result
        )

        return result
    }

    /// ASCII 아트 스타일의 그래프 생성
    public func generateASCIIGraph(maxWidth: Int = 80) -> String {
        let statistics = detector.getGraphStatistics()
        let cycles = detector.detectAllCircularDependencies()

        var ascii = """
        ┌\(String(repeating: "─", count: maxWidth - 2))┐
        │\(centerText("DiContainer Dependency Graph", width: maxWidth - 2))│
        ├\(String(repeating: "─", count: maxWidth - 2))┤
        │\(centerText(statistics.summary.components(separatedBy: "\n").first ?? "", width: maxWidth - 2))│
        """

        if !cycles.isEmpty {
            ascii += """
            ├\(String(repeating: "─", count: maxWidth - 2))┤
            │\(centerText("⚠️  \(cycles.count) 순환 의존성 발견", width: maxWidth - 2))│
            """
        }

        ascii += """
        └\(String(repeating: "─", count: maxWidth - 2))┘

        """

        // 주요 컴포넌트들 표시
        ascii += generateASCIIComponents(maxWidth: maxWidth)

        return ascii
    }

    // MARK: - Export Functions

    /// 그래프를 파일로 내보내기
    public func exportGraph(
        to url: URL,
        format: GraphExportFormat,
        title: String = "DiContainer Dependency Graph",
        options: GraphVisualizationOptions = .default
    ) throws {
        let content: String

        switch format {
        case .dot:
            content = generateDOTGraph(title: title, options: options)
        case .mermaid:
            content = generateMermaidGraph(title: title, options: options)
        case .text:
            content = generateASCIIGraph()
        case .json:
            content = try generateJSONGraph()
        }

        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// JSON 형식의 그래프 데이터 생성
    public func generateJSONGraph() throws -> String {
        let statistics = detector.getGraphStatistics()
        let cycles = detector.detectAllCircularDependencies()

        let graphData = GraphJSONData(
            metadata: GraphMetadata(
                title: "DiContainer Dependency Graph",
                generatedAt: ISO8601DateFormatter().string(from: Date()),
                statistics: statistics
            ),
            nodes: [], // TODO: 실제 노드 데이터 추가
            edges: [], // TODO: 실제 엣지 데이터 추가
            cycles: cycles.map { CycleData(path: $0.path) }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(graphData)
        return String(data: jsonData, encoding: .utf8) ?? ""
    }

    // MARK: - Interactive Graph Generation

    /// 대화형 HTML 그래프 생성 (D3.js 기반)
    public func generateInteractiveHTMLGraph(
        title: String = "DiContainer Dependency Graph"
    ) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>\(title)</title>
            <script src="https://d3js.org/d3.v7.min.js"></script>
            <style>
                body { font-family: Arial, sans-serif; margin: 20px; }
                .node { cursor: pointer; }
                .node.cycle { stroke: red; stroke-width: 3px; }
                .link { stroke: #999; stroke-opacity: 0.6; }
                .link.cycle { stroke: red; stroke-width: 2px; }
                .tooltip { position: absolute; padding: 10px; background: rgba(0,0,0,0.8);
                          color: white; border-radius: 5px; pointer-events: none; }
            </style>
        </head>
        <body>
            <h1>\(title)</h1>
            <div id="graph"></div>
            <script>
                // TODO: D3.js 기반 대화형 그래프 구현
                // 실제 구현에서는 JSON 데이터를 로드하여 시각화
            </script>
        </body>
        </html>
        """
    }

    // MARK: - Private Helpers

    private func generateDOTNodes(
        options: GraphVisualizationOptions,
        cycles: [CircularDependencyPath]
    ) -> String {
        var nodes = "\n    // Nodes\n"

        // TODO: 실제 노드 데이터 처리
        // 현재는 예시 구현

        return nodes
    }

    private func generateDOTEdges(
        options: GraphVisualizationOptions,
        cycles: [CircularDependencyPath]
    ) -> String {
        var edges = "\n    // Edges\n"

        // TODO: 실제 엣지 데이터 처리

        return edges
    }

    private func generateCycleHighlights(
        cycles: [CircularDependencyPath],
        options: GraphVisualizationOptions
    ) -> String {
        var highlights = "\n    // Cycle highlights\n"

        for cycle in cycles {
            highlights += "    // Cycle: \(cycle.description)\n"
        }

        return highlights
    }

    private func generateMermaidEdges(
        cycles: [CircularDependencyPath],
        options: GraphVisualizationOptions
    ) -> String {
        var edges = ""

        // TODO: 실제 Mermaid 엣지 생성

        return edges
    }

    private func generateMermaidStyles(
        cycles: [CircularDependencyPath],
        options: GraphVisualizationOptions
    ) -> String {
        var styles = "\n    %% Styles\n"

        if options.highlightCycles && !cycles.isEmpty {
            styles += "    classDef cycle fill:#ff9999,stroke:#ff0000,stroke-width:3px\n"
        }

        return styles
    }

    private func generateTreeRecursive(
        _ typeName: String,
        prefix: String,
        isLast: Bool,
        depth: Int,
        maxDepth: Int,
        visited: inout Set<String>,
        result: inout String
    ) {
        guard depth < maxDepth else { return }

        if visited.contains(typeName) {
            result += "\(prefix)\(isLast ? "└── " : "├── ")🔄 \(typeName) (순환)\n"
            return
        }

        visited.insert(typeName)

        // TODO: 실제 의존성 데이터 처리

        visited.remove(typeName)
    }

    private func generateASCIIComponents(maxWidth: Int) -> String {
        var ascii = ""

        // TODO: 주요 컴포넌트들의 ASCII 표현 생성

        return ascii
    }

    private func centerText(_ text: String, width: Int) -> String {
        let padding = max(0, width - text.count)
        let leftPadding = padding / 2
        let rightPadding = padding - leftPadding
        return String(repeating: " ", count: leftPadding) + text + String(repeating: " ", count: rightPadding)
    }
}

// MARK: - Configuration Types

/// 그래프 시각화 옵션
public struct GraphVisualizationOptions: Sendable {
    public var direction: GraphDirection = .topToBottom
    public var nodeShape: NodeShape = .box
    public var backgroundColor: String = "white"
    public var edgeColor: String = "#333333"
    public var highlightCycles: Bool = true
    public var showStatistics: Bool = true
    public var maxNodesPerLevel: Int = 10

    public static let `default` = GraphVisualizationOptions()

    public enum GraphDirection: String, Sendable {
        case topToBottom = "TB"
        case leftToRight = "LR"
        case bottomToTop = "BT"
        case rightToLeft = "RL"
    }

    public enum NodeShape: String, Sendable {
        case box = "box"
        case circle = "circle"
        case ellipse = "ellipse"
        case diamond = "diamond"
    }
}

/// 그래프 내보내기 형식
public enum GraphExportFormat {
    case dot       // Graphviz DOT
    case mermaid   // Mermaid
    case text      // ASCII 텍스트
    case json      // JSON 데이터
}

// MARK: - JSON Data Structures

private struct GraphJSONData: Codable {
    let metadata: GraphMetadata
    let nodes: [NodeData]
    let edges: [EdgeData]
    let cycles: [CycleData]
}

private struct GraphMetadata: Codable {
    let title: String
    let generatedAt: String
    let statistics: DependencyGraphStatistics
}

private struct NodeData: Codable {
    let id: String
    let label: String
    let type: String
    let level: Int
}

private struct EdgeData: Codable {
    let source: String
    let target: String
    let type: String
}

private struct CycleData: Codable {
    let path: [String]
}

// MARK: - Extensions

// Codable conformance moved to the original declaration in CircularDependencyDetector.swift

// MARK: - Public Convenience Functions

public extension DependencyContainer {

    /// 현재 컨테이너의 의존성 그래프를 DOT 형식으로 내보내기
    func exportDependencyGraph(to url: URL, format: GraphExportFormat = .dot) throws {
        try DependencyGraphVisualizer.shared.exportGraph(
            to: url,
            format: format,
            title: "DependencyContainer Graph"
        )
    }

    /// 의존성 트리를 콘솔에 출력
    func printDependencyTree<T>(_ rootType: T.Type, maxDepth: Int = 3) {
        let tree = DependencyGraphVisualizer.shared.generateDependencyTree(rootType, maxDepth: maxDepth)
        print(tree)
    }
}
