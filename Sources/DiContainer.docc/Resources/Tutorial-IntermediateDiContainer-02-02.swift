import Foundation
import DiContainer
import LogMacro

// MARK: - KeyPath와 조건부 등록 시스템

/// 런타임 조건과 KeyPath를 활용하여 유연하고 동적인 의존성 주입을
/// 구현하는 고급 패턴들을 다룹니다.

// MARK: - 조건부 등록 기반 구조

/// 조건에 따라 다른 구현체를 선택하는 조건부 등록 시스템
final class ConditionalRegistrationManager {
    private var conditions: [String: () -> Bool] = [:]
    private var factories: [String: [ConditionFactory]] = [:]

    /// 조건을 등록합니다
    func registerCondition(name: String, condition: @escaping () -> Bool) {
        conditions[name] = condition
        #logInfo("📋 조건 등록: \(name)")
    }

    /// 조건부 팩토리를 등록합니다
    func registerConditionalFactory<T>(
        for type: T.Type,
        condition: String,
        priority: Int = 0,
        factory: @escaping () -> T
    ) {
        let key = String(describing: type)
        let conditionFactory = ConditionFactory(
            condition: condition,
            priority: priority,
            factory: { factory() }
        )

        if factories[key] == nil {
            factories[key] = []
        }
        factories[key]?.append(conditionFactory)

        // 우선순위별로 정렬
        factories[key]?.sort { $0.priority > $1.priority }

        #logInfo("🏭 조건부 팩토리 등록: \(key) (조건: \(condition), 우선순위: \(priority))")
    }

    /// 조건에 맞는 인스턴스를 해결합니다
    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        guard let typeFactories = factories[key] else { return nil }

        for factory in typeFactories {
            if let condition = conditions[factory.condition], condition() {
                #logInfo("✅ 조건부 해결: \(key) (조건: \(factory.condition))")
                return factory.factory() as? T
            }
        }

        #logWarning("⚠️ 조건에 맞는 팩토리를 찾을 수 없음: \(key)")
        return nil
    }
}

private struct ConditionFactory {
    let condition: String
    let priority: Int
    let factory: () -> Any
}

// MARK: - KeyPath 기반 의존성 주입

/// KeyPath를 사용하여 프로퍼티 기반 의존성 주입을 구현합니다
final class KeyPathInjector {
    private var injectionRules: [String: Any] = [:]

    /// KeyPath 기반 주입 규칙을 등록합니다
    func registerInjection<Root, Value>(
        keyPath: WritableKeyPath<Root, Value>,
        value: Value
    ) {
        let key = "\(Root.self).\(keyPath)"
        injectionRules[key] = value
        #logInfo("🗝️ KeyPath 주입 규칙 등록: \(key)")
    }

    /// 인스턴스에 KeyPath 기반 주입을 수행합니다
    func inject<Root>(into instance: inout Root) {
        let typeName = String(describing: Root.self)
        #logInfo("🔧 KeyPath 주입 시작: \(typeName)")

        // 실제 구현에서는 리플렉션이나 매크로를 사용해야 함
        // 여기서는 개념적 예제로만 구현

        #logInfo("✅ KeyPath 주입 완료: \(typeName)")
    }
}

// MARK: - 실용적인 조건부 등록 예제

// MARK: 사용자 권한 기반 서비스

enum UserRole: String, Sendable {
    case guest = "guest"
    case user = "user"
    case admin = "admin"
    case superAdmin = "super_admin"

    var permissions: Set<Permission> {
        switch self {
        case .guest:
            return [.read]
        case .user:
            return [.read, .write]
        case .admin:
            return [.read, .write, .delete, .manage]
        case .superAdmin:
            return [.read, .write, .delete, .manage, .systemAdmin]
        }
    }
}

enum Permission: String, Sendable {
    case read = "read"
    case write = "write"
    case delete = "delete"
    case manage = "manage"
    case systemAdmin = "system_admin"
}

/// 현재 사용자 컨텍스트를 관리하는 서비스
final class UserContextService: @unchecked Sendable {
    private var _currentUserRole: UserRole = .guest
    private let queue = DispatchQueue(label: "UserContextService", attributes: .concurrent)

    var currentUserRole: UserRole {
        get { queue.sync { _currentUserRole } }
        set { queue.async(flags: .barrier) { self._currentUserRole = newValue } }
    }

    func hasPermission(_ permission: Permission) -> Bool {
        return currentUserRole.permissions.contains(permission)
    }

    func setUserRole(_ role: UserRole) {
        currentUserRole = role
        #logInfo("👤 사용자 역할 변경: \(role.rawValue)")
    }
}

// 권한별 다른 데이터 서비스

protocol DataService: Sendable {
    func getData() async throws -> [String]
    func createData(_ data: String) async throws
    func deleteData(_ id: String) async throws
}

final class GuestDataService: DataService {
    func getData() async throws -> [String] {
        #logInfo("👁️ [Guest] 읽기 전용 데이터 반환")
        return ["public_data_1", "public_data_2"]
    }

    func createData(_ data: String) async throws {
        throw DataServiceError.permissionDenied("게스트는 데이터를 생성할 수 없습니다")
    }

    func deleteData(_ id: String) async throws {
        throw DataServiceError.permissionDenied("게스트는 데이터를 삭제할 수 없습니다")
    }
}

final class UserDataService: DataService {
    func getData() async throws -> [String] {
        #logInfo("👤 [User] 사용자 데이터 반환")
        return ["user_data_1", "user_data_2", "shared_data"]
    }

    func createData(_ data: String) async throws {
        #logInfo("➕ [User] 데이터 생성: \(data)")
    }

    func deleteData(_ id: String) async throws {
        throw DataServiceError.permissionDenied("일반 사용자는 데이터를 삭제할 수 없습니다")
    }
}

final class AdminDataService: DataService {
    func getData() async throws -> [String] {
        #logInfo("👑 [Admin] 모든 데이터 반환")
        return ["admin_data", "user_data_1", "user_data_2", "system_data"]
    }

    func createData(_ data: String) async throws {
        #logInfo("➕ [Admin] 데이터 생성: \(data)")
    }

    func deleteData(_ id: String) async throws {
        #logInfo("🗑️ [Admin] 데이터 삭제: \(id)")
    }
}

enum DataServiceError: Error, LocalizedError {
    case permissionDenied(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let message):
            return "권한 오류: \(message)"
        }
    }
}

// MARK: 기능 플래그 기반 서비스

/// 기능 플래그를 관리하는 서비스
final class FeatureFlagService: @unchecked Sendable {
    private var _flags: [String: Bool] = [:]
    private let queue = DispatchQueue(label: "FeatureFlagService", attributes: .concurrent)

    func setFlag(_ name: String, enabled: Bool) {
        queue.async(flags: .barrier) {
            self._flags[name] = enabled
        }
        #logInfo("🚩 기능 플래그 설정: \(name) = \(enabled)")
    }

    func isEnabled(_ name: String) -> Bool {
        return queue.sync {
            return _flags[name] ?? false
        }
    }

    func getAllFlags() -> [String: Bool] {
        return queue.sync { _flags }
    }
}

// 기능 플래그에 따른 다른 알고리즘 구현

protocol RecommendationEngine: Sendable {
    func generateRecommendations(for userId: String) async -> [String]
}

final class BasicRecommendationEngine: RecommendationEngine {
    func generateRecommendations(for userId: String) async -> [String] {
        #logInfo("🔍 [Basic] 기본 추천 알고리즘 실행")
        return ["item1", "item2", "item3"]
    }
}

final class MLRecommendationEngine: RecommendationEngine {
    func generateRecommendations(for userId: String) async -> [String] {
        #logInfo("🤖 [ML] 머신러닝 추천 알고리즘 실행")
        try? await Task.sleep(nanoseconds: 500_000_000) // ML 처리 시뮬레이션
        return ["ml_item1", "ml_item2", "ml_item3", "ml_item4"]
    }
}

final class AIRecommendationEngine: RecommendationEngine {
    func generateRecommendations(for userId: String) async -> [String] {
        #logInfo("🧠 [AI] AI 추천 알고리즘 실행")
        try? await Task.sleep(nanoseconds: 1_000_000_000) // AI 처리 시뮬레이션
        return ["ai_item1", "ai_item2", "ai_item3", "ai_item4", "ai_item5"]
    }
}

// MARK: - 조건부 등록을 통한 DI 설정

extension DIContainer {
    /// 조건부 등록 시스템을 설정합니다
    func setupConditionalRegistration() async {
        #logInfo("🔧 조건부 등록 시스템 설정")

        let userContext = UserContextService()
        let featureFlags = FeatureFlagService()

        // 기본 서비스들 등록
        registerSingleton(UserContextService.self) { userContext }
        registerSingleton(FeatureFlagService.self) { featureFlags }

        // 조건부 등록 매니저 설정
        let conditionalManager = ConditionalRegistrationManager()

        // 조건들 등록
        conditionalManager.registerCondition(name: "isGuest") {
            userContext.currentUserRole == .guest
        }

        conditionalManager.registerCondition(name: "isUser") {
            userContext.currentUserRole == .user
        }

        conditionalManager.registerCondition(name: "isAdmin") {
            [.admin, .superAdmin].contains(userContext.currentUserRole)
        }

        conditionalManager.registerCondition(name: "mlEnabled") {
            featureFlags.isEnabled("ml_recommendations")
        }

        conditionalManager.registerCondition(name: "aiEnabled") {
            featureFlags.isEnabled("ai_recommendations")
        }

        // 데이터 서비스 조건부 등록 (권한별)
        conditionalManager.registerConditionalFactory(
            for: DataService.self,
            condition: "isAdmin",
            priority: 3
        ) { AdminDataService() }

        conditionalManager.registerConditionalFactory(
            for: DataService.self,
            condition: "isUser",
            priority: 2
        ) { UserDataService() }

        conditionalManager.registerConditionalFactory(
            for: DataService.self,
            condition: "isGuest",
            priority: 1
        ) { GuestDataService() }

        // 추천 엔진 조건부 등록 (기능 플래그별)
        conditionalManager.registerConditionalFactory(
            for: RecommendationEngine.self,
            condition: "aiEnabled",
            priority: 3
        ) { AIRecommendationEngine() }

        conditionalManager.registerConditionalFactory(
            for: RecommendationEngine.self,
            condition: "mlEnabled",
            priority: 2
        ) { MLRecommendationEngine() }

        // 기본 추천 엔진 (항상 활성화)
        conditionalManager.registerCondition(name: "always") { true }
        conditionalManager.registerConditionalFactory(
            for: RecommendationEngine.self,
            condition: "always",
            priority: 1
        ) { BasicRecommendationEngine() }

        // 조건부 매니저를 컨테이너에 등록
        registerSingleton(ConditionalRegistrationManager.self) { conditionalManager }

        // 기능 플래그 초기값 설정
        featureFlags.setFlag("ml_recommendations", enabled: false)
        featureFlags.setFlag("ai_recommendations", enabled: false)

        #logInfo("✅ 조건부 등록 시스템 설정 완료")
    }

    /// 조건부 해결을 수행합니다
    func resolveConditionally<T>(_ type: T.Type) -> T? {
        let conditionalManager: ConditionalRegistrationManager = resolve()
        return conditionalManager.resolve(type)
    }
}

// MARK: - 조건부 등록 사용 예제

final class ConditionalDependencyDemo {
    private let container = DIContainer()

    init() async {
        await container.setupConditionalRegistration()
    }

    /// 사용자 권한별 데이터 서비스 테스트
    func testUserRoleBasedServices() async {
        #logInfo("🎭 사용자 권한별 서비스 테스트")

        let userContext: UserContextService = container.resolve()

        // 게스트로 시작
        userContext.setUserRole(.guest)
        await testDataService()

        // 일반 사용자로 변경
        userContext.setUserRole(.user)
        await testDataService()

        // 관리자로 변경
        userContext.setUserRole(.admin)
        await testDataService()
    }

    /// 기능 플래그별 추천 엔진 테스트
    func testFeatureFlagBasedServices() async {
        #logInfo("🚩 기능 플래그별 서비스 테스트")

        let featureFlags: FeatureFlagService = container.resolve()

        // 기본 추천 엔진
        await testRecommendationEngine()

        // ML 추천 엔진 활성화
        featureFlags.setFlag("ml_recommendations", enabled: true)
        await testRecommendationEngine()

        // AI 추천 엔진 활성화 (ML은 비활성화)
        featureFlags.setFlag("ml_recommendations", enabled: false)
        featureFlags.setFlag("ai_recommendations", enabled: true)
        await testRecommendationEngine()

        // 둘 다 활성화 (우선순위에 따라 AI 선택)
        featureFlags.setFlag("ml_recommendations", enabled: true)
        featureFlags.setFlag("ai_recommendations", enabled: true)
        await testRecommendationEngine()
    }

    private func testDataService() async {
        guard let dataService = container.resolveConditionally(DataService.self) else {
            #logError("❌ DataService를 해결할 수 없습니다")
            return
        }

        do {
            let data = try await dataService.getData()
            #logInfo("📊 데이터 조회 성공: \(data)")

            try await dataService.createData("test_data")
            #logInfo("✅ 데이터 생성 성공")

        } catch {
            #logWarning("⚠️ 데이터 서비스 작업 제한: \(error.localizedDescription)")
        }
    }

    private func testRecommendationEngine() async {
        guard let engine = container.resolveConditionally(RecommendationEngine.self) else {
            #logError("❌ RecommendationEngine을 해결할 수 없습니다")
            return
        }

        let recommendations = await engine.generateRecommendations(for: "user123")
        #logInfo("🎯 추천 결과: \(recommendations)")
    }
}

// MARK: - 조건부 등록 데모

enum ConditionalRegistrationExample {
    static func demonstrateConditionalRegistration() async {
        #logInfo("🎬 조건부 등록 데모 시작")

        let demo = await ConditionalDependencyDemo()

        #logInfo("1️⃣ 사용자 권한별 서비스 테스트")
        await demo.testUserRoleBasedServices()

        #logInfo("\n2️⃣ 기능 플래그별 서비스 테스트")
        await demo.testFeatureFlagBasedServices()

        #logInfo("🎉 조건부 등록 데모 완료")
    }
}