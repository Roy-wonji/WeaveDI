import Foundation
import WeaveDICore

// MARK: - Component Metadata Diagnostics

public extension UnifiedDI {
  struct ComponentDiagnostics: Codable, Sendable {
    public struct Issue: Codable, Sendable {
      public let type: String
      public let providers: [String]
      public let detail: String?
    }

    public let issues: [Issue]

    public init(issues: [Issue]) {
      self.issues = issues
    }
  }

  struct ComponentCycleReport: Codable, Sendable {
    public let cycles: [[String]]
    public let componentCount: Int
    public let edgeCount: Int

    public init(cycles: [[String]], componentCount: Int, edgeCount: Int) {
      self.cycles = cycles
      self.componentCount = componentCount
      self.edgeCount = edgeCount
    }
  }

  public static func componentMetadata() -> [ComponentMetadata] {
    ComponentMetadataRegistry.allMetadata()
  }

  public static func dumpComponentMetadata() -> String {
    ComponentMetadataRegistry.dumpMetadata()
  }

  public static func analyzeComponentMetadata() -> ComponentDiagnostics {
    let metadata = ComponentMetadataRegistry.allMetadata()
    var typeProviders: [String: [(component: String, scope: String)]] = [:]

    for meta in metadata {
      for (index, typeName) in meta.providedTypes.enumerated() {
        let scope = index < meta.scopes.count ? meta.scopes[index] : "unknown"
        typeProviders[typeName, default: []].append((meta.componentName, scope))
      }
    }

    var issues: [ComponentDiagnostics.Issue] = []

    for (type, entries) in typeProviders {
      let components = entries.map { $0.component }
      let uniqueComponents = Array(Set(components))
      if uniqueComponents.count > 1 {
        issues.append(.init(
          type: type,
          providers: uniqueComponents,
          detail: "Multiple components provide this type."
        ))
      }

      let scopes = entries.map { $0.scope }
      let uniqueScopes = Array(Set(scopes))
      if uniqueScopes.count > 1 {
        issues.append(.init(
          type: type,
          providers: uniqueComponents,
          detail: "Inconsistent scopes: \(uniqueScopes.joined(separator: ", "))"
        ))
      }
    }

    return ComponentDiagnostics(issues: issues)
  }

  public static func detectComponentCycles() -> ComponentCycleReport {
    let metadata = ComponentMetadataRegistry.allMetadata()
    let componentNames = Set(metadata.map { $0.componentName })
    var graph: [String: [String]] = [:]
    var edgeCount = 0

    for meta in metadata {
      let neighbors = meta.providedTypes.filter { componentNames.contains($0) }
      if !neighbors.isEmpty {
        graph[meta.componentName, default: []].append(contentsOf: neighbors)
        edgeCount += neighbors.count
      }
    }

    var recorded: Set<String> = []
    var cycles: [[String]] = []

    func visit(start: String, current: String, path: inout [String]) {
      path.append(current)

      for neighbor in graph[current, default: []] {
        if neighbor == start {
          var cycle = path
          cycle.append(neighbor)
          let (key, normalized) = canonicalizeCycle(cycle)
          if !key.isEmpty && !recorded.contains(key) {
            recorded.insert(key)
            cycles.append(normalized)
          }
        } else if !path.contains(neighbor) {
          visit(start: start, current: neighbor, path: &path)
        }
      }

      path.removeLast()
    }

    for node in graph.keys.sorted() {
      var path: [String] = []
      visit(start: node, current: node, path: &path)
    }

    cycles.sort { $0.joined(separator: " -> ") < $1.joined(separator: " -> ") }

    return ComponentCycleReport(
      cycles: cycles,
      componentCount: metadata.count,
      edgeCount: edgeCount
    )
  }

  private static func canonicalizeCycle(_ cycle: [String]) -> (String, [String]) {
    guard !cycle.isEmpty else { return ("", []) }
    var trimmed = cycle
    if let first = trimmed.first, let last = trimmed.last, first == last {
      trimmed.removeLast()
    }
    guard !trimmed.isEmpty else { return ("", []) }

    func rotations(of array: [String]) -> [[String]] {
      guard !array.isEmpty else { return [[]] }
      return (0..<array.count).map { index in
        Array(array[index...]) + Array(array[..<index])
      }
    }

    let candidates = rotations(of: trimmed) + rotations(of: trimmed.reversed())
    var bestSequence: [String] = []
    var bestKey = ""
    for sequence in candidates {
      let key = sequence.joined(separator: " -> ")
      if bestKey.isEmpty || key < bestKey {
        bestKey = key
        bestSequence = sequence
      }
    }
    return (bestKey, bestSequence)
  }
}
