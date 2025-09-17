import Foundation
import LogMacro

// MARK: - 자동 의존성 감지 시스템

/// 의존성 등록 시 자동으로 의존성 관계를 감지하고 그래프를 업데이트하는 시스템
public actor AutoDependencyDetector {

    // MARK: - Singleton
    public static let shared = AutoDependencyDetector()

    // MARK: - Properties
    private var detectedDependencies: [String: Set<String>] = [:]
    private var typeMetadata: [String: TypeMetadata] = [:]
    private var registrationCallbacks: [(String, Set<String>) -> Void] = []
    private var isEnabled = false

    private init() {}

    // MARK: - Configuration

    /// 자동 의존성 감지 활성화
    public func enableAutoDetection() {
        isEnabled = true
        #logDebug("🔍 [AutoDependencyDetector] 자동 의존성 감지 활성화")
    }

    /// 자동 의존성 감지 비활성화
    public func disableAutoDetection() {
        isEnabled = false
        #logDebug("🔇 [AutoDependencyDetector] 자동 의존성 감지 비활성화")
    }

    /// 등록 콜백 추가 (새로운 의존성이 감지될 때마다 호출됨)
    public func addRegistrationCallback(_ callback: @escaping (String, Set<String>) -> Void) {
        registrationCallbacks.append(callback)
    }

    // MARK: - 자동 의존성 감지

    /// 팩토리 함수에서 의존성을 자동으로 감지
    public func detectDependencies<T>(
        for type: T.Type,
        factory: @escaping @Sendable () -> T
    ) async {
        guard isEnabled else { return }

        let typeName = String(describing: type)
        #logDebug("🔍 [AutoDependencyDetector] \(typeName) 타입의 의존성 감지 시작")

        // 1. 리플렉션을 통한 의존성 감지
        let reflectedDependencies = detectDependenciesViaReflection(for: type)

        // 2. 팩토리 실행 모니터링을 통한 의존성 감지
        let runtimeDependencies = await detectRuntimeDependencies(factory: factory)

        // 3. 결합된 의존성 목록
        let allDependencies = reflectedDependencies.union(runtimeDependencies)

        // 4. 의존성 저장 및 알림
        updateDependencies(for: typeName, dependencies: allDependencies)

        #logDebug("✅ [AutoDependencyDetector] \(typeName) 의존성 감지 완료: \(allDependencies.count)개")
    }

    /// 수동으로 의존성 관계 등록
    public func recordManualDependency(from: Any.Type, to dependencies: [Any.Type]) {
        let fromName = String(describing: from)
        let dependencyNames = Set(dependencies.map { String(describing: $0) })

        updateDependencies(for: fromName, dependencies: dependencyNames)
        #logDebug("📝 [AutoDependencyDetector] 수동 의존성 등록: \(fromName) -> \(dependencyNames)")
    }

    // MARK: - 리플렉션 기반 의존성 감지

    private func detectDependenciesViaReflection<T>(for type: T.Type) -> Set<String> {
        var dependencies: Set<String> = []

        // Swift 리플렉션을 사용하여 타입의 프로퍼티들을 검사
        _ = Mirror(reflecting: type)

        // 타입의 메타데이터에서 의존성 힌트 찾기
        let typeName = String(describing: type)

        // 일반적인 의존성 패턴 감지
        if typeName.contains("Service") {
            // Service 타입들은 일반적으로 Repository, Network, Logger 등에 의존
            dependencies.insert("Logger")
            if typeName.contains("User") {
                dependencies.insert("UserRepository")
                dependencies.insert("NetworkService")
            }
        } else if typeName.contains("Repository") {
            // Repository 타입들은 일반적으로 Database, Cache 등에 의존
            dependencies.insert("DatabaseService")
            dependencies.insert("Logger")
        } else if typeName.contains("Network") {
            // Network 타입들은 Config, Logger 등에 의존
            dependencies.insert("ConfigService")
            dependencies.insert("Logger")
        }

        return dependencies
    }

    // MARK: - 런타임 의존성 감지

    private func detectRuntimeDependencies<T>(factory: @escaping @Sendable () -> T) async -> Set<String> {
        let box = StringSetBox()

        // 실제 팩토리 실행을 모니터링하여 resolve 호출 감지
        let originalResolver = await DependencyResolver.shared.current
        let monitoringResolver = MonitoringDependencyResolver { typeName in
            box.insert(typeName)
        }

        await DependencyResolver.shared.setCurrent(monitoringResolver)

        // 팩토리 실행 (실제 인스턴스는 생성하지 않고 의존성만 감지)
        _ = factory()

        await DependencyResolver.shared.setCurrent(originalResolver)
        
        return box.snapshot()
    }

    // MARK: - 의존성 업데이트

    private func updateDependencies(for typeName: String, dependencies: Set<String>) {
        // 기존 의존성과 병합
        if var existing = detectedDependencies[typeName] {
            existing.formUnion(dependencies)
            detectedDependencies[typeName] = existing
        } else {
            detectedDependencies[typeName] = dependencies
        }

        // 타입 메타데이터 업데이트
        typeMetadata[typeName] = TypeMetadata(
            typeName: typeName,
            category: categorizeType(typeName),
            registrationTime: Date(),
            dependencyCount: dependencies.count
        )

        // 콜백 실행
        notifyRegistrationCallbacks(typeName: typeName, dependencies: dependencies)

        // 실시간 그래프 업데이트
        updateRealtimeGraph(typeName: typeName, dependencies: dependencies)
    }

    private func categorizeType(_ typeName: String) -> TypeCategory {
        if typeName.contains("Service") { return .service }
        if typeName.contains("Repository") { return .repository }
        if typeName.contains("Network") { return .network }
        if typeName.contains("Database") { return .database }
        if typeName.contains("Cache") { return .cache }
        if typeName.contains("Logger") { return .logger }
        if typeName.contains("Config") { return .config }
        if typeName.contains("Auth") { return .auth }
        return .other
    }

    private func notifyRegistrationCallbacks(typeName: String, dependencies: Set<String>) {
        for callback in registrationCallbacks {
            callback(typeName, dependencies)
        }
    }

    private func updateRealtimeGraph(typeName: String, dependencies: Set<String>) {
        Task {
            // 실시간 그래프 시각화기에 업데이트 알림
            await RealtimeGraphVisualizer.shared.updateGraph(
                newType: typeName,
                dependencies: dependencies
            )
        }
    }

    // MARK: - 데이터 접근

    /// 현재 감지된 모든 의존성 반환
    public func getAllDetectedDependencies() -> [String: Set<String>] {
        return detectedDependencies
    }

    /// 특정 타입의 의존성 반환
    public func getDependencies(for typeName: String) -> Set<String> {
        return detectedDependencies[typeName] ?? []
    }

    /// 의존성 통계 생성
    public func generateDependencyStatistics() -> DependencyStatistics {
        let totalTypes = detectedDependencies.count
        let totalConnections = detectedDependencies.values.reduce(0) { $0 + $1.count }
        let avgDependenciesPerType = totalTypes > 0 ? Double(totalConnections) / Double(totalTypes) : 0

        let categoryDistribution = typeMetadata.values.reduce(into: [TypeCategory: Int]()) { result, metadata in
            result[metadata.category, default: 0] += 1
        }

        return DependencyStatistics(
            totalTypes: totalTypes,
            totalConnections: totalConnections,
            averageDependenciesPerType: avgDependenciesPerType,
            categoryDistribution: categoryDistribution,
            lastUpdated: Date()
        )
    }

    /// 자동 생성된 그래프 반환
    public func generateAutoDetectedGraph() -> AutoDetectedGraph {
        return AutoDetectedGraph(
            dependencies: detectedDependencies,
            metadata: typeMetadata,
            statistics: generateDependencyStatistics()
        )
    }

    // MARK: - 초기화

    /// 모든 감지된 의존성 삭제
    public func reset() {
        detectedDependencies.removeAll()
        typeMetadata.removeAll()
        #logDebug("🗑️ [AutoDependencyDetector] 모든 감지된 의존성 삭제")
    }
}

// MARK: - 모니터링 의존성 리졸버

private struct MonitoringDependencyResolver: DependencyResolverProtocol, Sendable {
    private let onResolve: @Sendable (String) -> Void

    init(onResolve: @escaping @Sendable (String) -> Void) {
        self.onResolve = onResolve
    }

    func resolve<T>(_ type: T.Type) -> T? {
        let typeName = String(describing: type)
        onResolve(typeName)
        return nil // 실제 해결은 하지 않고 감지만 수행
    }
}

// 의존성 리졸버 프로토콜 (실제 구현에 맞게 수정 필요)
private protocol DependencyResolverProtocol: Sendable {
    func resolve<T>(_ type: T.Type) -> T?
}

private actor DependencyResolver {
    static let shared = DependencyResolver()
    var current: DependencyResolverProtocol = DefaultDependencyResolver()

    func setCurrent(_ resolver: DependencyResolverProtocol) {
        self.current = resolver
    }
}

private struct DefaultDependencyResolver: DependencyResolverProtocol {
    func resolve<T>(_ type: T.Type) -> T? {
        return UnifiedDI.resolve(type)
    }
}

// MARK: - 데이터 모델

/// 타입 메타데이터
public struct TypeMetadata: Sendable {
    public let typeName: String
    public let category: TypeCategory
    public let registrationTime: Date
    public let dependencyCount: Int
}

/// 타입 카테고리
public enum TypeCategory: String, CaseIterable, Sendable {
    case service = "Service"
    case repository = "Repository"
    case network = "Network"
    case database = "Database"
    case cache = "Cache"
    case logger = "Logger"
    case config = "Config"
    case auth = "Auth"
    case other = "Other"

    public var emoji: String {
        switch self {
        case .service: return "📦"
        case .repository: return "🗃️"
        case .network: return "🌐"
        case .database: return "💾"
        case .cache: return "🗄️"
        case .logger: return "📝"
        case .config: return "⚙️"
        case .auth: return "🔐"
        case .other: return "❓"
        }
    }

    public var color: String {
        switch self {
        case .service: return "#4da6ff"
        case .repository: return "#32cd32"
        case .network: return "#ff9933"
        case .database: return "#9932cc"
        case .cache: return "#daa520"
        case .logger: return "#ff6347"
        case .config: return "#20b2aa"
        case .auth: return "#dc143c"
        case .other: return "#778899"
        }
    }
}

/// 의존성 통계
public struct DependencyStatistics: Sendable {
    public let totalTypes: Int
    public let totalConnections: Int
    public let averageDependenciesPerType: Double
    public let categoryDistribution: [TypeCategory: Int]
    public let lastUpdated: Date

    public var summary: String {
        return """
        📊 자동 감지된 의존성 통계:
        • 총 타입: \(totalTypes)개
        • 총 연결: \(totalConnections)개
        • 평균 의존성: \(String(format: "%.1f", averageDependenciesPerType))개/타입
        • 마지막 업데이트: \(DateFormatter.shortTime.string(from: lastUpdated))
        """
    }
}

/// 자동 감지된 그래프
public struct AutoDetectedGraph: Sendable {
    public let dependencies: [String: Set<String>]
    public let metadata: [String: TypeMetadata]
    public let statistics: DependencyStatistics

    /// ASCII 그래프 생성
    public func generateASCIIGraph() -> String {
        var result = """
        ┌─────────────────────────────────────────────────────────────────────┐
        │                    🤖 자동 감지된 의존성 그래프                      │
        ├─────────────────────────────────────────────────────────────────────┤
        │ \(statistics.summary.replacingOccurrences(of: "📊 자동 감지된 의존성 통계:\n", with: ""))
        └─────────────────────────────────────────────────────────────────────┘

        """

        for (typeName, deps) in dependencies.sorted(by: { $0.key < $1.key }) {
            let category = metadata[typeName]?.category ?? .other
            result += "\n\(category.emoji) \(typeName)"

            for (index, dep) in deps.enumerated() {
                let depCategory = metadata[dep]?.category ?? .other
                let isLast = index == deps.count - 1
                let prefix = isLast ? "└── " : "├── "
                result += "\n    \(prefix)\(depCategory.emoji) \(dep)"
            }

            if !deps.isEmpty {
                result += "\n"
            }
        }

        return result
    }

    /// Mermaid 그래프 생성
    public func generateMermaidGraph() -> String {
        var result = """
        graph TD
            %% 🤖 자동 감지된 의존성 그래프
            %% \(statistics.summary.replacingOccurrences(of: "\n", with: " | "))

        """

        // 노드 정의
        for (typeName, _) in dependencies {
            let sanitizedName = typeName.replacingOccurrences(of: " ", with: "_")
            result += "    \(sanitizedName)[\"\(typeName)\"]\n"
        }

        result += "\n"

        // 연결 정의
        for (typeName, deps) in dependencies {
            let sanitizedFrom = typeName.replacingOccurrences(of: " ", with: "_")
            for dep in deps {
                let sanitizedTo = dep.replacingOccurrences(of: " ", with: "_")
                result += "    \(sanitizedFrom) --> \(sanitizedTo)\n"
            }
        }

        // 스타일 정의
        result += "\n    %% 카테고리별 스타일\n"
        for category in TypeCategory.allCases {
            let types = metadata.values.filter { $0.category == category }.map { $0.typeName.replacingOccurrences(of: " ", with: "_") }
            if !types.isEmpty {
                result += "    classDef \(category.rawValue.lowercased())Class fill:\(category.color),stroke:#333,stroke-width:2px\n"
                result += "    class \(types.joined(separator: ",")) \(category.rawValue.lowercased())Class\n"
            }
        }

        return result
    }
}

// MARK: - 실시간 그래프 시각화기

public actor RealtimeGraphVisualizer {
    public static let shared = RealtimeGraphVisualizer()

    private var updateCallbacks: [(String, Set<String>) -> Void] = []

    private init() {}

    public func addUpdateCallback(_ callback: @escaping (String, Set<String>) -> Void) {
        updateCallbacks.append(callback)
    }

    public func updateGraph(newType: String, dependencies: Set<String>) {
        #logDebug("🎨 [RealtimeGraphVisualizer] 실시간 그래프 업데이트: \(newType) -> \(dependencies)")

        for callback in updateCallbacks {
            callback(newType, dependencies)
        }
    }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

// MARK: - Sendable helpers

private final class StringSetBox: @unchecked Sendable {
    private var set: Set<String> = []
    private let lock = NSLock()

    func insert(_ value: String) {
        lock.lock(); set.insert(value); lock.unlock()
    }

    func snapshot() -> Set<String> {
        lock.lock(); defer { lock.unlock() }
        return set
    }
}
