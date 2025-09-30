---
title: DependencyGraph
lang: ko-KR
---

# DependencyGraph

Records dependency relationships and exports them as DOT or Mermaid diagrams.
- Thread-safety: Implemented as an actor; all mutations are serialized.
- Usage: Call ``addNode(_:alias:)`` and ``addEdge(from:to:label:)-(_,To.Type,_)`` while wiring modules,
  then export with ``exportDOT()``/``exportMermaid()`` or file helpers.

```swift
public actor DependencyGraph {
  public static let shared = DependencyGraph()
}
```

  /// Directed edge in the dependency graph.
  /// Adds a node for the specified `type`.
  /// - Parameters:
  ///   - type: The type to record as a node.
  ///   - alias: Optional display name override.
  /// Adds an arbitrary node by display name.
  /// Adds a directed edge `From -> To` using types.
  /// - Parameters:
  ///   - from: Source type.
  ///   - to: Destination type.
  ///   - label: Optional edge label (e.g., "uses").
  /// Adds a directed edge `fromName -> toName` using display names.
  /// Exports the graph in Graphviz DOT format.
  /// Exports the graph in Mermaid flowchart format.
  /// Writes DOT output to a file.
  /// Writes Mermaid output to a Markdown file with fenced code block.
  /// Returns a snapshot of recorded nodes and edges.
