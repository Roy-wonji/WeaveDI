//
//  DependencyGraph.swift
//  DiContainer
//
//  Created by Assistant on 2025-09-15.
//

import Foundation
import LogMacro

/// Records dependency relationships and exports them as DOT or Mermaid diagrams.
///
/// - Thread-safety: Implemented as an actor; all mutations are serialized.
/// - Usage: Call ``addNode(_:)`` and ``addEdge(from:to:label:)`` while wiring modules,
///   then export with ``exportDOT()``/``exportMermaid()`` or file helpers.
public actor DependencyGraph {
    public static let shared = DependencyGraph()

    /// Directed edge in the dependency graph.
    public struct Edge: Hashable, Sendable {
        public let from: String
        public let to: String
        public let label: String?
        public init(from: String, to: String, label: String? = nil) {
            self.from = from
            self.to = to
            self.label = label
        }
    }

    private var nodes: Set<String> = []
    private var edges: Set<Edge> = []

    // MARK: - Record

    /// Adds a node for the specified `type`.
    /// - Parameters:
    ///   - type: The type to record as a node.
    ///   - alias: Optional display name override.
    public func addNode<T>(_ type: T.Type, alias: String? = nil) {
        let name = alias ?? String(describing: T.self)
        nodes.insert(name)
    }

    /// Adds an arbitrary node by display name.
    public func addNode(named name: String) { nodes.insert(name) }

    /// Adds a directed edge `From -> To` using types.
    /// - Parameters:
    ///   - from: Source type.
    ///   - to: Destination type.
    ///   - label: Optional edge label (e.g., "uses").
    public func addEdge<From, To>(from: From.Type, to: To.Type, label: String? = nil) {
        let fromName = String(describing: From.self)
        let toName = String(describing: To.self)
        nodes.insert(fromName)
        nodes.insert(toName)
        edges.insert(Edge(from: fromName, to: toName, label: label))
    }

    /// Adds a directed edge `fromName -> toName` using display names.
    public func addEdge(from fromName: String, to toName: String, label: String? = nil) {
        nodes.insert(fromName)
        nodes.insert(toName)
        edges.insert(Edge(from: fromName, to: toName, label: label))
    }

    // MARK: - Export

    /// Exports the graph in Graphviz DOT format.
    public func exportDOT() -> String {
        var lines: [String] = []
        lines.append("digraph Dependencies {")
        lines.append("  rankdir=LR;")
        // Nodes
        for n in nodes.sorted() {
            let safe = n.replacingOccurrences(of: " ", with: "_")
            lines.append("  \(safe) [label=\"\(n)\"];\n")
        }
        // Edges
        for e in edges.sorted(by: { $0.from < $1.from || ($0.from == $1.from && $0.to < $1.to) }) {
            let f = e.from.replacingOccurrences(of: " ", with: "_")
            let t = e.to.replacingOccurrences(of: " ", with: "_")
            if let label = e.label { lines.append("  \(f) -> \(t) [label=\"\(label)\"];\n") }
            else { lines.append("  \(f) -> \(t);") }
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    /// Exports the graph in Mermaid flowchart format.
    public func exportMermaid() -> String {
        var lines: [String] = []
        lines.append("flowchart LR")
        for e in edges.sorted(by: { $0.from < $1.from || ($0.from == $1.from && $0.to < $1.to) }) {
            let label = e.label.map { "|\($0)|" } ?? ""
            lines.append("  \(e.from) -->\(label) \(e.to)")
        }
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Write helpers
    /// Writes DOT output to a file.
    public func writeDOT(to path: String) throws {
        let dot = exportDOT()
        try dot.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
    }

    /// Writes Mermaid output to a Markdown file with fenced code block.
    public func writeMermaid(to path: String) throws {
        let md = """
        ```mermaid
        \(exportMermaid())
        ```
        """
        try md.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
    }

    // MARK: - Diagnostics
    /// Returns a snapshot of recorded nodes and edges.
    public func snapshot() -> (nodes: [String], edges: [Edge]) {
        (nodes.sorted(), Array(edges))
    }
}
