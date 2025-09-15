//
//  CircularDependencyDetector.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation

// MARK: - Circular Dependency Detection System

/// 순환 의존성 탐지 시스템
///
/// 메인 스레드 전용이 아니어도 사용할 수 있도록 내부 동기화 큐로 보호합니다.
public final class CircularDependencyDetector: @unchecked Sendable {

    // MARK: - Shared Instance

    public static let shared = CircularDependencyDetector()

    // MARK: - Properties

    /// 동시성 안전성을 위한 동기화 큐 (concurrent reads, barrier writes)
    private let syncQueue = DispatchQueue(label: "com.diContainer.circularDependencyDetector", attributes: .concurrent)

    /// 현재 해결 중인 의존성 스택
    private var resolutionStack: [String] = []

    /// 의존성 그래프 (타입 → 의존하는 타입들)
    private var dependencyGraph: [String: Set<String>] = [:]

    /// 탐지된 순환 의존성들
    private var detectedCycles: Set<CircularDependencyPath> = []

    /// 탐지 활성화 여부
    private var isDetectionEnabled: Bool = true

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// 순환 의존성 탐지 활성화/비활성화
    public func setDetectionEnabled(_ enabled: Bool) {
        syncQueue.sync(flags: .barrier) {
            self.isDetectionEnabled = enabled
            if !enabled {
                self.resolutionStack.removeAll()
                self.dependencyGraph.removeAll()
                self.detectedCycles.removeAll()
            }
        }
    }

    /// 의존성 해결 시작 (스택에 추가)
    public func beginResolution<T>(_ type: T.Type) throws {
        let typeName = String(describing: type)
        try beginResolution(typeName)
    }

    /// 의존성 해결 시작 (문자열 타입명)
    public func beginResolution(_ typeName: String) throws {
        var errorToThrow: SafeDIError? = nil
        syncQueue.sync(flags: .barrier) {
            guard self.isDetectionEnabled else { return }

            if self.resolutionStack.contains(typeName) {
                let cyclePath = self.createCyclePath(to: typeName)
                let circularDependency = CircularDependencyPath(path: cyclePath)
                self.detectedCycles.insert(circularDependency)
                errorToThrow = .circularDependency(path: cyclePath)
            } else {
                self.resolutionStack.append(typeName)
            }
        }
        if let e = errorToThrow { throw e }
    }

    /// 의존성 해결 완료 (스택에서 제거)
    public func endResolution<T>(_ type: T.Type) {
        let typeName = String(describing: type)
        endResolution(typeName)
    }

    /// 의존성 해결 완료 (문자열 타입명)
    public func endResolution(_ typeName: String) {
        syncQueue.sync(flags: .barrier) {
            guard self.isDetectionEnabled else { return }
            if let index = self.resolutionStack.lastIndex(of: typeName) {
                self.resolutionStack.remove(at: index)
            }
        }
    }

    /// 의존성 관계 기록
    public func recordDependency<From, To>(from: From.Type, to: To.Type) {
        let fromTypeName = String(describing: from)
        let toTypeName = String(describing: to)
        recordDependency(from: fromTypeName, to: toTypeName)
    }

    /// 의존성 관계 기록 (문자열 타입명)
    public func recordDependency(from: String, to: String) {
        syncQueue.sync(flags: .barrier) {
            guard self.isDetectionEnabled else { return }
            self.dependencyGraph[from, default: []].insert(to)
        }
    }

    /// 전체 의존성 그래프에서 순환 의존성 탐지
    public func detectAllCircularDependencies() -> [CircularDependencyPath] {
        // 스냅샷 후 외부에서 계산
        let snapshot: (graph: [String: Set<String>], enabled: Bool) = syncQueue.sync {
            (self.dependencyGraph, self.isDetectionEnabled)
        }
        guard snapshot.enabled else { return [] }

        var allCycles: Set<CircularDependencyPath> = []
        for startNode in snapshot.graph.keys {
            var visited: Set<String> = []
            var recursionStack: Set<String> = []
            var currentPath: [String] = []
            findCyclesFromNode(
                startNode,
                in: snapshot.graph,
                visited: &visited,
                recursionStack: &recursionStack,
                currentPath: &currentPath,
                allCycles: &allCycles
            )
        }
        return Array(allCycles).sorted { $0.path.count < $1.path.count }
    }

    /// 특정 타입의 의존성 체인 분석
    public func analyzeDependencyChain<T>(_ type: T.Type) -> DependencyChainAnalysis {
        let typeName = String(describing: type)
        return analyzeDependencyChain(typeName)
    }

    /// 특정 타입의 의존성 체인 분석 (문자열 타입명)
    public func analyzeDependencyChain(_ typeName: String) -> DependencyChainAnalysis {
        // 스냅샷 찍고 계산
        let snapshot: (graph: [String: Set<String>], cycles: Set<CircularDependencyPath>) = syncQueue.sync {
            (self.dependencyGraph, self.detectedCycles)
        }
        var directDependencies: [String] = []
        var allDependencies: Set<String> = []
        var maxDepth = 0

        if let direct = snapshot.graph[typeName] {
            directDependencies = Array(direct)
        }
        // 재귀 계산은 별도 헬퍼 사용 (헬퍼는 외부 그래프를 읽지 않도록 변경)
        collectAllDependencies(typeName, from: snapshot.graph, collected: &allDependencies, depth: 0, maxDepth: &maxDepth)

        return DependencyChainAnalysis(
            rootType: typeName,
            directDependencies: directDependencies,
            allDependencies: Array(allDependencies),
            maxDepth: maxDepth,
            hasCycles: snapshot.cycles.contains { $0.path.contains(typeName) }
        )
    }

    /// 의존성 그래프 통계
    public func getGraphStatistics() -> DependencyGraphStatistics {
        let snapshot = syncQueue.sync { (self.dependencyGraph, self.detectedCycles) }
        let totalTypes = snapshot.0.keys.count
        let totalDependencies = snapshot.0.values.reduce(0) { $0 + $1.count }
        let averageDependencies = totalTypes > 0 ? Double(totalDependencies) / Double(totalTypes) : 0
        let maxDependencies = snapshot.0.values.map { $0.count }.max() ?? 0
        let typesWithoutDependencies = snapshot.0.values.filter { $0.isEmpty }.count

        return DependencyGraphStatistics(
            totalTypes: totalTypes,
            totalDependencies: totalDependencies,
            averageDependenciesPerType: averageDependencies,
            maxDependenciesPerType: maxDependencies,
            typesWithoutDependencies: typesWithoutDependencies,
            detectedCycles: snapshot.1.count
        )
    }

    /// 캐시 및 상태 초기화
    public func clearCache() {
        syncQueue.sync(flags: .barrier) {
            self.resolutionStack.removeAll()
            self.dependencyGraph.removeAll()
            self.detectedCycles.removeAll()
        }
    }

    // MARK: - Private Helpers

    private func createCyclePath(to typeName: String) -> [String] {
        guard let startIndex = resolutionStack.firstIndex(of: typeName) else {
            return resolutionStack + [typeName]
        }

        return Array(resolutionStack[startIndex...]) + [typeName]
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

        if let dependencies = graph[node] {
            for dependency in dependencies {
                if !visited.contains(dependency) {
                    findCyclesFromNode(
                        dependency,
                        in: graph,
                        visited: &visited,
                        recursionStack: &recursionStack,
                        currentPath: &currentPath,
                        allCycles: &allCycles
                    )
                } else if recursionStack.contains(dependency) {
                    // 순환 발견
                    if let cycleStartIndex = currentPath.firstIndex(of: dependency) {
                        let cyclePath = Array(currentPath[cycleStartIndex...]) + [dependency]
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

        guard let dependencies = graph[typeName] else { return }

        for dependency in dependencies {
            if !collected.contains(dependency) {
                collected.insert(dependency)
                collectAllDependencies(dependency, from: graph, collected: &collected, depth: depth + 1, maxDepth: &maxDepth)
            }
        }
    }
}

// MARK: - Data Structures

/// 순환 의존성 경로
public struct CircularDependencyPath: Hashable, CustomStringConvertible {
    public let path: [String]

    public init(path: [String]) {
        self.path = path
    }

    public var description: String {
        return path.joined(separator: " → ")
    }
}

/// 의존성 체인 분석 결과
public struct DependencyChainAnalysis {
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

public extension DependencyContainer {

    /// 순환 의존성 탐지와 함께 안전한 의존성 해결
    func safeResolveWithCircularDetection<T>(_ type: T.Type) throws -> T {
        try CircularDependencyDetector.shared.beginResolution(type)
        defer { CircularDependencyDetector.shared.endResolution(type) }

        guard let resolved = resolve(type) else {
            throw SafeDIError.dependencyNotFound(type: String(describing: type), keyPath: nil)
        }

        return resolved
    }
}
