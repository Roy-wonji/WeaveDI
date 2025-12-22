import WeaveDICore
//
//  CircularDependencyDetector.swift
//  DiContainer
//
//  Created by Wonja Suh on 9/24/25.
//

import Foundation
import LogMacro

// MARK: - Circular Dependency Detection System (Actor)

public actor CircularDependencyDetector {
  public static let shared = CircularDependencyDetector()
  
  private var resolutionStack: [String] = []
  private var dependencyGraph: [String: Set<String>] = [:]
  private var detectedCycles: Set<CircularDependencyPath> = []
  private var isDetectionEnabled: Bool = true
  private var isAutoRecordingEnabled: Bool = false
  
  // Configuration
  public func setDetectionEnabled(_ enabled: Bool) {
    isDetectionEnabled = enabled
    if !enabled {
      resolutionStack.removeAll()
      dependencyGraph.removeAll()
      detectedCycles.removeAll()
    }
  }
  
  public func setAutoRecordingEnabled(_ enabled: Bool) {
    isAutoRecordingEnabled = enabled
  }
  
  // Resolution tracking
  public func beginResolution<T>(_ type: T.Type) throws { try beginResolution(String(describing: type)) }
  
  public func beginResolution(_ typeName: String) throws {
    guard isDetectionEnabled else { return }
    if resolutionStack.contains(typeName) {
      let cyclePath = createCyclePath(to: typeName)
      detectedCycles.insert(CircularDependencyPath(path: cyclePath))
      throw SafeDIError.circularDependency(path: cyclePath)
    }
    resolutionStack.append(typeName)
  }
  
  public func endResolution<T>(_ type: T.Type) { endResolution(String(describing: type)) }
  
  public func endResolution(_ typeName: String) {
    guard isDetectionEnabled else { return }
    if let idx = resolutionStack.lastIndex(of: typeName) { resolutionStack.remove(at: idx) }
  }
  
  // Graph building
  public func recordDependency<From, To>(from: From.Type, to: To.Type) {
    recordDependency(from: String(describing: from), to: String(describing: to))
  }
  
  public func recordDependency(from: String, to: String) {
    guard isDetectionEnabled else { return }
    dependencyGraph[from, default: []].insert(to)
  }
  
  public func removeDependency(from: String, to: String) {
    guard isDetectionEnabled else { return }
    if var set = dependencyGraph[from] {
      set.remove(to)
      if set.isEmpty { dependencyGraph.removeValue(forKey: from) } else { dependencyGraph[from] = set }
    }
  }
  
  public func recordAutoEdgeIfEnabled(for resolvedType: Any.Type) {
    let targetTypeName = String(describing: resolvedType)
    guard isDetectionEnabled, isAutoRecordingEnabled else { return }
    guard let from = resolutionStack.last, from != targetTypeName else { return }
    dependencyGraph[from, default: []].insert(targetTypeName)
  }
  
  // Analysis
  public func detectAllCircularDependencies() -> [CircularDependencyPath] {
    var allCycles: Set<CircularDependencyPath> = []
    let snapshot = dependencyGraph
    for start in snapshot.keys {
      var visited: Set<String> = []
      var stack: Set<String> = []
      var path: [String] = []
      findCyclesFromNode(start, in: snapshot, visited: &visited, recursionStack: &stack, currentPath: &path, allCycles: &allCycles)
    }
    return Array(allCycles).sorted { $0.path.count < $1.path.count }
  }
  
  public func analyzeDependencyChain<T>(_ type: T.Type) -> DependencyChainAnalysis { analyzeDependencyChain(String(describing: type)) }
  
  public func analyzeDependencyChain(_ typeName: String) -> DependencyChainAnalysis {
    let snapshotGraph = dependencyGraph
    let snapshotCycles = detectedCycles
    var direct: [String] = []
    var all: Set<String> = []
    var maxDepth = 0
    if let d = snapshotGraph[typeName] { direct = Array(d) }
    collectAllDependencies(typeName, from: snapshotGraph, collected: &all, depth: 0, maxDepth: &maxDepth)
    return DependencyChainAnalysis(
      rootType: typeName,
      directDependencies: direct,
      allDependencies: Array(all),
      maxDepth: maxDepth,
      hasCycles: snapshotCycles.contains { $0.path.contains(typeName) }
    )
  }
  
  public func getGraphStatistics() -> DependencyGraphStatistics {
    let graph = dependencyGraph
    let cycles = detectedCycles
    let totalTypes = graph.keys.count
    let totalDeps = graph.values.reduce(0) { $0 + $1.count }
    let avg = totalTypes > 0 ? Double(totalDeps) / Double(totalTypes) : 0
    let maxDeps = graph.values.map { $0.count }.max() ?? 0
    let without = graph.values.filter { $0.isEmpty }.count
    return DependencyGraphStatistics(
      totalTypes: totalTypes,
      totalDependencies: totalDeps,
      averageDependenciesPerType: avg,
      maxDependenciesPerType: maxDeps,
      typesWithoutDependencies: without,
      detectedCycles: cycles.count
    )
  }
  
  public func clearCache() {
    resolutionStack.removeAll()
    dependencyGraph.removeAll()
    detectedCycles.removeAll()
  }
  
  // Helpers
  private func createCyclePath(to name: String) -> [String] {
    if let start = resolutionStack.firstIndex(of: name) {
      return Array(resolutionStack[start...]) + [name]
    }
    return resolutionStack + [name]
  }
  
  private func findCyclesFromNode(
    _ node: String,
    in graph: [String: Set<String>],
    visited: inout Set<String>,
    recursionStack: inout Set<String>,
    currentPath: inout [String],
    allCycles: inout Set<CircularDependencyPath>
  ) {
    visited.insert(node)
    recursionStack.insert(node)
    currentPath.append(node)
    if let deps = graph[node] {
      for dep in deps {
        if !visited.contains(dep) {
          findCyclesFromNode(dep, in: graph, visited: &visited, recursionStack: &recursionStack, currentPath: &currentPath, allCycles: &allCycles)
        } else if recursionStack.contains(dep) {
          if let idx = currentPath.firstIndex(of: dep) {
            let cyclePath = Array(currentPath[idx...]) + [dep]
            allCycles.insert(CircularDependencyPath(path: cyclePath))
          }
        }
      }
    }
    recursionStack.remove(node)
    currentPath.removeLast()
  }
  
  private func collectAllDependencies(
    _ typeName: String,
    from graph: [String: Set<String>],
    collected: inout Set<String>,
    depth: Int,
    maxDepth: inout Int
  ) {
    maxDepth = max(maxDepth, depth)
    guard let deps = graph[typeName] else { return }
    for dep in deps where !collected.contains(dep) {
      collected.insert(dep)
      collectAllDependencies(dep, from: graph, collected: &collected, depth: depth + 1, maxDepth: &maxDepth)
    }
  }
}

// MARK: - Data Structures

/// 순환 의존성 경로
public struct CircularDependencyPath: Hashable, CustomStringConvertible, Sendable {
  public let path: [String]
  
  public init(path: [String]) {
    self.path = path
  }
  
  public var description: String {
    return path.joined(separator: " → ")
  }
}

/// 의존성 체인 분석 결과
public struct DependencyChainAnalysis: Sendable {
  public let rootType: String
  public let directDependencies: [String]
  public let allDependencies: [String]
  public let maxDepth: Int
  public let hasCycles: Bool
  
  public var summary: String {
    return """
        의존성 체인 분석: \(rootType)
        - 직접 의존성: \(directDependencies.count)개
        - 전체 의존성: \(allDependencies.count)개
        - 최대 깊이: \(maxDepth)
        - 순환 의존성: \(hasCycles ? "발견됨" : "없음")
        """
  }
}

/// 의존성 그래프 통계
public struct DependencyGraphStatistics: Codable, Sendable {
  public let totalTypes: Int
  public let totalDependencies: Int
  public let averageDependenciesPerType: Double
  public let maxDependenciesPerType: Int
  public let typesWithoutDependencies: Int
  public let detectedCycles: Int
  
  // 추가 속성들
  public var totalConnections: Int { totalDependencies }
  public var circularDependencies: Int { detectedCycles }
  public var averageComplexity: Double { averageDependenciesPerType }
  public var healthScore: Double {
    // 간단한 건강도 계산
    let cycleScore = detectedCycles == 0 ? 50.0 : max(0, 50.0 - Double(detectedCycles) * 10.0)
    let complexityScore = averageDependenciesPerType <= 3.0 ? 50.0 : max(0, 50.0 - (averageDependenciesPerType - 3.0) * 10.0)
    return cycleScore + complexityScore
  }
  
  public var summary: String {
    return """
        의존성 그래프 통계:
        - 총 타입 수: \(totalTypes)
        - 총 의존성 수: \(totalDependencies)
        - 평균 의존성/타입: \(String(format: "%.1f", averageDependenciesPerType))
        - 최대 의존성/타입: \(maxDependenciesPerType)
        - 의존성 없는 타입: \(typesWithoutDependencies)
        - 탐지된 순환: \(detectedCycles)개
        """
  }
}

// MARK: - Safe Resolution with Circular Detection

public extension DIContainer {
  
  /// 순환 의존성 탐지와 함께 안전한 의존성 해결
  func safeResolveWithCircularDetection<T>(_ type: T.Type) async throws -> T where T: Sendable {
    try await CircularDependencyDetector.shared.beginResolution(type)
    defer { Task { await CircularDependencyDetector.shared.endResolution(type) } }
    
    guard let resolved = resolve(type) else {
      throw SafeDIError.dependencyNotFound(type: String(describing: type), keyPath: nil)
    }
    
    return resolved
  }
}
