import WeaveDICore
//
//  DependencyGraphVisualizer.swift
//  DiContainer
//
//  Created by Wonji Suh on 9/24/25.
//

import Foundation
import LogMacro

// MARK: - Dependency Graph Visualization System

/// Needle 스타일의 의존성 그래프 시각화 시스템 (정적 네임스페이스)
public enum DependencyGraphVisualizer {
  
  // MARK: - DOT Graph Generation
  
  /// DOT 형식의 의존성 그래프 생성 (Graphviz 호환)
  // Removed sync generateDOTGraph; use async variant
  
  /// Mermaid 형식의 의존성 그래프 생성
  // Removed sync generateMermaidGraph; use async variant
  
  // MARK: - Text-based Visualization
  
  /// 텍스트 기반 의존성 트리 생성
  public static func generateDependencyTree<T>(_ rootType: T.Type, maxDepth: Int = 5) -> String {
    let typeName = String(describing: rootType)
    return generateDependencyTree(typeName, maxDepth: maxDepth)
  }
  
  /// 텍스트 기반 의존성 트리 생성 (문자열 타입명)
  public static func generateDependencyTree(_ rootTypeName: String, maxDepth: Int = 5) -> String {
    var result = "📦 \(rootTypeName)\n"
    var visitedNodes: Set<String> = []
    
    Self.generateTreeRecursive(
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
  // Removed sync generateASCIIGraph; use async variant
  
  // MARK: - Export Functions
  
  /// 그래프를 파일로 내보내기
  public static func exportGraph(
    to url: URL,
    format: GraphExportFormat,
    title: String = "DiContainer Dependency Graph",
    options: GraphVisualizationOptions = .default
  ) throws {
    let content: String = {
      switch format {
        case .dot:
          return (try? awaitResult { await generateDOTGraphAsync(title: title, options: options) }.get()) ?? ""
        case .mermaid:
          return (try? awaitResult { await generateMermaidGraphAsync(title: title, options: options) }.get()) ?? ""
        case .text:
          return (try? awaitResult { await generateASCIIGraphAsync() }.get()) ?? ""
        case .json:
          return (try? awaitResultThrows { try await generateJSONGraphAsync() }.get()) ?? "{}"
      }
    }()
    
    try content.write(to: url, atomically: true, encoding: .utf8)
  }
  
  /// JSON 형식의 그래프 데이터 생성
  // Removed sync generateJSONGraph; use async variant
  
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
  
  private static func generateDOTNodes(
    options: GraphVisualizationOptions,
    cycles: [CircularDependencyPath]
  ) -> String {
    var nodes = "\n    // Nodes\n"
    
    // 실제 의존성 그래프에서 노드 데이터 가져오기
    let allTypes = getAllRegisteredTypes()
    let cycleTypes = Set(cycles.flatMap { $0.path })
    
    for typeName in allTypes {
      let isInCycle = cycleTypes.contains(typeName)
      let nodeColor = isInCycle ? "#ffcccc" : "#e6f3ff"
      let borderColor = isInCycle ? "#ff0000" : "#4da6ff"
      let shape = options.nodeShape.rawValue
      
      // 안전한 노드 이름 생성 (특수문자 제거)
      let safeNodeName = typeName.replacingOccurrences(of: "<", with: "")
        .replacingOccurrences(of: ">", with: "")
        .replacingOccurrences(of: ".", with: "_")
        .replacingOccurrences(of: ":", with: "_")
      
      nodes += """
                "\(safeNodeName)" [
                    label="\(typeName.components(separatedBy: ".").last ?? typeName)",
                    fillcolor="\(nodeColor)",
                    color="\(borderColor)",
                    shape=\(shape),
                    tooltip="\(typeName)"
                ];
            
            """
    }
    
    return nodes
  }
  
  private static func generateDOTEdges(
    options: GraphVisualizationOptions,
    cycles: [CircularDependencyPath]
  ) -> String {
    var edges = "\n    // Edges\n"
    let dependencyData = getDependencyEdges()
    let cycleEdges = getCycleEdges(cycles)
    
    for (from, to) in dependencyData {
      let isCycleEdge = cycleEdges.contains { $0.from == from && $0.to == to }
      let edgeColor = isCycleEdge ? "#ff0000" : options.edgeColor
      let edgeStyle = isCycleEdge ? "bold" : "solid"
      let arrowHead = isCycleEdge ? "normal" : "vee"
      
      // 안전한 노드 이름 생성
      let safeFromName = sanitizeNodeName(from)
      let safeToName = sanitizeNodeName(to)
      
      edges += """
                "\(safeFromName)" -> "\(safeToName)" [
                    color="\(edgeColor)",
                    style=\(edgeStyle),
                    arrowhead=\(arrowHead)
                ];
            
            """
    }
    
    return edges
  }
  
  private static func generateCycleHighlights(
    cycles: [CircularDependencyPath],
    options: GraphVisualizationOptions
  ) -> String {
    var highlights = "\n    // Cycle highlights\n"
    
    for cycle in cycles {
      highlights += "    // Cycle: \(cycle.description)\n"
    }
    
    return highlights
  }
  
  private static func generateMermaidEdges(
    cycles: [CircularDependencyPath],
    options: GraphVisualizationOptions
  ) -> String {
    var edges = ""
    let dependencyData = getDependencyEdges()
    let cycleEdges = getCycleEdges(cycles)
    
    for (from, to) in dependencyData {
      let isCycleEdge = cycleEdges.contains { $0.from == from && $0.to == to }
      let fromNode = sanitizeMermaidNodeName(from)
      let toNode = sanitizeMermaidNodeName(to)
      
      // Mermaid 노드 정의 (한 번만)
      if !edges.contains("    \(fromNode)[") {
        edges += "    \(fromNode)[\"\(Self.getShortTypeName(from))\"]\n"
      }
      if !edges.contains("    \(toNode)[") {
        edges += "    \(toNode)[\"\(Self.getShortTypeName(to))\"]\n"
      }
      
      // 엣지 정의
      let arrowStyle = isCycleEdge ? "-.->|cycle|" : "-->"
      edges += "    \(fromNode) \(arrowStyle) \(toNode)\n"
    }
    
    return edges
  }
  
  private static func generateMermaidStyles(
    cycles: [CircularDependencyPath],
    options: GraphVisualizationOptions
  ) -> String {
    var styles = "\n    %% Styles\n"
    
    if options.highlightCycles && !cycles.isEmpty {
      styles += "    classDef cycle fill:#ff9999,stroke:#ff0000,stroke-width:3px\n"
    }
    
    return styles
  }
  
  private static func generateTreeRecursive(
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
      result += "\(prefix)\(isLast ? "└── " : "├── ")🔄 \(Self.getShortTypeName(typeName)) (순환)\n"
      return
    }
    
    visited.insert(typeName)
    
    // 실제 의존성 데이터에서 하위 의존성들 가져오기
    let dependencies = Self.getDirectDependencies(for: typeName)
    
    for (index, dependency) in dependencies.enumerated() {
      let isLastDependency = (index == dependencies.count - 1)
      let newPrefix = prefix + (isLast ? "    " : "│   ")
      
      result += "\(prefix)\(isLast ? "└── " : "├── ")\(Self.getShortTypeName(dependency))\n"
      
      Self.generateTreeRecursive(
        dependency,
        prefix: newPrefix,
        isLast: isLastDependency,
        depth: depth + 1,
        maxDepth: maxDepth,
        visited: &visited,
        result: &result
      )
    }
    
    visited.remove(typeName)
  }
  
  private static func generateASCIIComponents(maxWidth: Int) -> String {
    let ascii = ""
    
    // TODO: 주요 컴포넌트들의 ASCII 표현 생성
    
    return ascii
  }
  
  private static func centerText(_ text: String, width: Int) -> String {
    let padding = max(0, width - text.count)
    let leftPadding = padding / 2
    let rightPadding = padding - leftPadding
    return String(repeating: " ", count: leftPadding) + text + String(repeating: " ", count: rightPadding)
  }
  
  // MARK: - Data Collection Helpers
  
  /// 등록된 모든 타입명 가져오기
  internal static func getAllRegisteredTypes() -> Set<String> {
    
    // 현재 등록된 의존성들과 실제 컨테이너에서 사용 가능한 타입들을 조합
    var allTypes: Set<String> = []
    
    // 의존성 그래프에서 타입들 추출
    let analysis: DependencyChainAnalysis = (try? awaitDetectorResult { await $0.analyzeDependencyChain("Root") }.get()) ?? DependencyChainAnalysis(rootType: "Root", directDependencies: [], allDependencies: [], maxDepth: 0, hasCycles: false)
    allTypes.formUnion(analysis.allDependencies)
    
    // 일반적인 DI 타입들 추가 (실제로는 리플렉션이나 런타임 정보를 사용해야 함)
    let commonTypes = [
      "UserServiceProtocol", "NetworkServiceProtocol", "LoggerProtocol",
      "DatabaseService", "AuthService", "CacheService",
      "UserRepository", "ProductRepository", "OrderRepository"
    ]
    allTypes.formUnion(commonTypes)
    
    return allTypes
  }
  
  /// 의존성 엣지 데이터 가져오기
  internal static func getDependencyEdges() -> [(from: String, to: String)] {
    var edges: [(from: String, to: String)] = []
    
    // 실제로는 CircularDependencyDetector에서 내부 dependencyGraph를 접근
    // 현재는 예시 데이터로 대체
    let sampleEdges = [
      ("UserServiceProtocol", "NetworkServiceProtocol"),
      ("UserServiceProtocol", "LoggerProtocol"),
      ("NetworkServiceProtocol", "DatabaseService"),
      ("AuthService", "UserRepository"),
      ("ProductRepository", "DatabaseService"),
      ("OrderRepository", "UserRepository")
    ]
    
    edges.append(contentsOf: sampleEdges)
    return edges
  }
  
  /// 순환 의존성 엣지 추출
  private static func getCycleEdges(_ cycles: [CircularDependencyPath]) -> [(from: String, to: String)] {
    var cycleEdges: [(from: String, to: String)] = []
    
    for cycle in cycles {
      for i in 0..<cycle.path.count {
        let from = cycle.path[i]
        let to = cycle.path[(i + 1) % cycle.path.count]
        cycleEdges.append((from: from, to: to))
      }
    }
    
    return cycleEdges
  }
  
  /// 특정 타입의 직접 의존성들 가져오기
  private static func getDirectDependencies(for typeName: String) -> [String] {
    let allEdges = getDependencyEdges()
    return allEdges.compactMap { edge in
      edge.from == typeName ? edge.to : nil
    }
  }
  
  /// 노드 이름 정리 (DOT용)
  private static func sanitizeNodeName(_ name: String) -> String {
    return name.replacingOccurrences(of: "<", with: "")
      .replacingOccurrences(of: ">", with: "")
      .replacingOccurrences(of: ".", with: "_")
      .replacingOccurrences(of: ":", with: "_")
      .replacingOccurrences(of: " ", with: "_")
  }
  
  /// 노드 이름 정리 (Mermaid용)
  private static func sanitizeMermaidNodeName(_ name: String) -> String {
    return name.replacingOccurrences(of: "<", with: "")
      .replacingOccurrences(of: ">", with: "")
      .replacingOccurrences(of: ".", with: "")
      .replacingOccurrences(of: ":", with: "")
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "Protocol", with: "")
  }
  
  /// 짧은 타입명 가져오기
  private static func getShortTypeName(_ fullName: String) -> String {
    // "MyApp.UserServiceProtocol" -> "UserService"
    let components = fullName.components(separatedBy: ".")
    let lastName = components.last ?? fullName
    return lastName.replacingOccurrences(of: "Protocol", with: "")
      .replacingOccurrences(of: "Impl", with: "")
  }
}

// Bridge helper: await actor methods from sync context (Result-based, no fatalError)
private enum DetectorBridgeError: Error { case nilResult }
private final class _DetectorBox<T>: @unchecked Sendable { var value: T? }

private func awaitDetectorResult<T: Sendable>(
  _ body: @Sendable @escaping (CircularDependencyDetector) async -> T,
  timeout: TimeInterval? = 1.0
) -> Result<T, Error> {
  let sem = DispatchSemaphore(value: 0)
  let box = _DetectorBox<T>()
  let task = Task.detached { @Sendable in
    box.value = await body(CircularDependencyDetector.shared)
    sem.signal()
  }
  if let timeout = timeout {
    let nanos = UInt64(timeout * 1_000_000_000)
    let deadline = DispatchTime.now() + .nanoseconds(Int(nanos))
    if sem.wait(timeout: deadline) == .timedOut {
      task.cancel()
      return .failure(DetectorBridgeError.nilResult)
    }
  } else {
    sem.wait()
  }
  if let value = box.value { return .success(value) }
  return .failure(DetectorBridgeError.nilResult)
}

// Generic async -> sync bridges (without deprecation noise)
private func awaitResult<T: Sendable>(
  _ body: @Sendable @escaping () async -> T,
  timeout: TimeInterval = 1.0
) -> Result<T, Error> {
  let sem = DispatchSemaphore(value: 0)
  let box = _DetectorBox<T>()
  let task = Task.detached { @Sendable in
    box.value = await body()
    sem.signal()
  }
  let deadline = DispatchTime.now() + .nanoseconds(Int(timeout * 1_000_000_000))
  if sem.wait(timeout: deadline) == .timedOut { task.cancel(); return .failure(DetectorBridgeError.nilResult) }
  if let v = box.value { return .success(v) }
  return .failure(DetectorBridgeError.nilResult)
}

private final class _ErrorBox: @unchecked Sendable { var error: Error? }

private func awaitResultThrows<T: Sendable>(
  _ body: @Sendable @escaping () async throws -> T,
  timeout: TimeInterval = 1.0
) -> Result<T, Error> {
  let sem = DispatchSemaphore(value: 0)
  let vbox = _DetectorBox<T>()
  let ebox = _ErrorBox()
  let task = Task.detached { @Sendable in
    do { vbox.value = try await body() } catch { ebox.error = error }
    sem.signal()
  }
  let deadline = DispatchTime.now() + .nanoseconds(Int(timeout * 1_000_000_000))
  if sem.wait(timeout: deadline) == .timedOut { task.cancel(); return .failure(DetectorBridgeError.nilResult) }
  if let err = ebox.error { return .failure(err) }
  if let v = vbox.value { return .success(v) }
  return .failure(DetectorBridgeError.nilResult)
}

// Async variants (preferred) — use these to avoid sync bridging
public extension DependencyGraphVisualizer {
  static func generateDOTGraphAsync(
    title: String = "DiContainer Dependency Graph",
    options: GraphVisualizationOptions = .default
  ) async -> String {
    let statistics = await CircularDependencyDetector.shared.getGraphStatistics()
    let cycles = await CircularDependencyDetector.shared.detectAllCircularDependencies()
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
    dot += generateDOTNodes(options: options, cycles: cycles)
    dot += generateDOTEdges(options: options, cycles: cycles)
    if !cycles.isEmpty && options.highlightCycles {
      dot += generateCycleHighlights(cycles: cycles, options: options)
    }
    dot += "\n}"
    return dot
  }
  
  static func generateMermaidGraphAsync(
    title: String = "DiContainer Dependency Graph",
    options: GraphVisualizationOptions = .default
  ) async -> String {
    let statistics = await CircularDependencyDetector.shared.getGraphStatistics()
    let cycles = await CircularDependencyDetector.shared.detectAllCircularDependencies()
    var mermaid = """
        graph \(options.direction == .topToBottom ? "TD" : "LR")
            %% \(title)
            %% \(statistics.summary.replacingOccurrences(of: "\n", with: " | "))
        
        """
    mermaid += generateMermaidEdges(cycles: cycles, options: options)
    mermaid += generateMermaidStyles(cycles: cycles, options: options)
    return mermaid
  }
  
  static func generateASCIIGraphAsync(maxWidth: Int = 80) async -> String {
    let statistics = await CircularDependencyDetector.shared.getGraphStatistics()
    let cycles = await CircularDependencyDetector.shared.detectAllCircularDependencies()
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
    ascii += generateASCIIComponents(maxWidth: maxWidth)
    return ascii
  }
  
  static func generateJSONGraphAsync() async throws -> String {
    let statistics = await CircularDependencyDetector.shared.getGraphStatistics()
    let cycles = await CircularDependencyDetector.shared.detectAllCircularDependencies()
    let graphData = GraphJSONData(
      metadata: GraphMetadata(
        title: "DiContainer Dependency Graph",
        generatedAt: ISO8601DateFormatter().string(from: Date()),
        statistics: statistics
      ),
      nodes: [],
      edges: [],
      cycles: cycles.map { CycleData(path: $0.path) }
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let jsonData = try encoder.encode(graphData)
    return String(data: jsonData, encoding: .utf8) ?? ""
  }
}

// Deprecate sync APIs in favor of async variants
public extension DependencyGraphVisualizer {
  @available(*, deprecated, message: "Use generateDOTGraphAsync(...) instead")
  static func generateDOTGraphDeprecated(
    title: String = "DiContainer Dependency Graph",
    options: GraphVisualizationOptions = .default
  ) async -> String {
    await generateDOTGraphAsync(title: title, options: options)
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

public extension DIContainer {
  
  /// 현재 컨테이너의 의존성 그래프를 DOT 형식으로 내보내기
  func exportDependencyGraph(to url: URL, format: GraphExportFormat = .dot) throws {
    try DependencyGraphVisualizer.exportGraph(
      to: url,
      format: format,
      title: "DIContainer Graph"
    )
  }
  
  /// 의존성 트리를 콘솔에 출력
  func printDependencyTree<T>(_ rootType: T.Type, maxDepth: Int = 3) {
    let tree = DependencyGraphVisualizer.generateDependencyTree(rootType, maxDepth: maxDepth)
    #logDebug(tree)
  }
}
