---
title: DependencyGraphVisualizer
lang: ko-KR
---

# DependencyGraphVisualizer

Needle 스타일의 의존성 그래프 시각화 시스템 (정적 네임스페이스)

```swift
public enum DependencyGraphVisualizer {
}
```

  /// DOT 형식의 의존성 그래프 생성 (Graphviz 호환)
  /// Mermaid 형식의 의존성 그래프 생성
  /// 텍스트 기반 의존성 트리 생성
  /// 텍스트 기반 의존성 트리 생성 (문자열 타입명)
  /// ASCII 아트 스타일의 그래프 생성
  /// 그래프를 파일로 내보내기
  /// JSON 형식의 그래프 데이터 생성
  /// 대화형 HTML 그래프 생성 (D3.js 기반)
  /// 등록된 모든 타입명 가져오기
  /// 의존성 엣지 데이터 가져오기
  /// 순환 의존성 엣지 추출
  /// 특정 타입의 직접 의존성들 가져오기
  /// 노드 이름 정리 (DOT용)
  /// 노드 이름 정리 (Mermaid용)
  /// 짧은 타입명 가져오기

```swift
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
}
```

그래프 시각화 옵션

```swift
public struct GraphVisualizationOptions: Sendable {
  public var direction: GraphDirection = .topToBottom
  public var nodeShape: NodeShape = .box
  public var backgroundColor: String = "white"
  public var edgeColor: String = "#333333"
  public var highlightCycles: Bool = true
  public var showStatistics: Bool = true
  public var maxNodesPerLevel: Int = 10
}
```

그래프 내보내기 형식

```swift
public enum GraphExportFormat {
  case dot       // Graphviz DOT
  case mermaid   // Mermaid
  case text      // ASCII 텍스트
  case json      // JSON 데이터
}
```

  /// 현재 컨테이너의 의존성 그래프를 DOT 형식으로 내보내기
  /// 의존성 트리를 콘솔에 출력
