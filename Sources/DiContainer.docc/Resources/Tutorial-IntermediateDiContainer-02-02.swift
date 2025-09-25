import Foundation
import DiContainer
import LogMacro

// MARK: - Conditional Injection System

/// 조건부 의존성 주입을 위한 Predicate 시스템
/// 복잡한 비즈니스 로직에 따라 동적으로 의존성을 결정

// MARK: - Injection Conditions

protocol InjectionCondition: Sendable {
    func shouldInject() async -> Bool
    var description: String { get }
}

struct UserRoleCondition: InjectionCondition {
    let requiredRole: UserRole
    let userService: UserService

    func shouldInject() async -> Bool {
        do {
            let currentUser = try await userService.getCurrentUser()
            return currentUser.role.hasPermission(for: requiredRole)
        } catch {
            #logError("🚨 [Condition] 사용자 역할 확인 실패: \(error)")
            return false
        }
    }

    var description: String {
        "사용자 역할: \(requiredRole.rawValue)"
    }
}

struct FeatureFlagCondition: InjectionCondition {
    let featureName: String
    let featureFlagService: FeatureFlagService

    func shouldInject() async -> Bool {
        await featureFlagService.isEnabled(feature: featureName)
    }

    var description: String {
        "기능 플래그: \(featureName)"
    }
}

struct EnvironmentCondition: InjectionCondition {
    let allowedEnvironments: Set<AppEnvironment>

    func shouldInject() async -> Bool {
        allowedEnvironments.contains(AppEnvironment.current)
    }

    var description: String {
        "환경: \(allowedEnvironments.map(\.rawValue).joined(separator: ", "))"
    }
}

struct TimeBasedCondition: InjectionCondition {
    let allowedTimeRange: ClosedRange<Int> // 24시간 형식

    func shouldInject() async -> Bool {
        let currentHour = Calendar.current.component(.hour, from: Date())
        return allowedTimeRange.contains(currentHour)
    }

    var description: String {
        "시간대: \(allowedTimeRange.lowerBound)시-\(allowedTimeRange.upperBound)시"
    }
}

// MARK: - Supporting Types

enum UserRole: String, Sendable {
    case guest = "guest"
    case user = "user"
    case premium = "premium"
    case admin = "admin"

    func hasPermission(for requiredRole: UserRole) -> Bool {
        switch (self, requiredRole) {
        case (.admin, _):
            return true
        case (.premium, .premium), (.premium, .user), (.premium, .guest):
            return true
        case (.user, .user), (.user, .guest):
            return true
        case (.guest, .guest):
            return true
        default:
            return false
        }
    }
}

struct User: Sendable {
    let id: String
    let email: String
    let role: UserRole
    let subscriptionType: SubscriptionType
}

protocol UserService: Sendable {
    func getCurrentUser() async throws -> User
}

protocol FeatureFlagService: Sendable {
    func isEnabled(feature: String) async -> Bool
    func setEnabled(feature: String, enabled: Bool) async
}

// MARK: - Conditional Injection Manager

/// 조건부 의존성 주입을 관리하는 매니저
final class ConditionalInjectionManager: @unchecked Sendable {
    static let shared = ConditionalInjectionManager()

    private let accessQueue = DispatchQueue(label: "ConditionalInjectionManager.access", attributes: .concurrent)
    private var _conditionalRegistrations: [String: ConditionalRegistration] = [:]

    private init() {}

    /// 조건부 의존성을 등록합니다
    func register<T>(
        _ type: T.Type,
        condition: InjectionCondition,
        factory: @escaping @Sendable () -> T,
        fallback: @escaping @Sendable () -> T? = { nil }
    ) {
        let key = String(describing: type)

        accessQueue.async(flags: .barrier) {
            self._conditionalRegistrations[key] = ConditionalRegistration(
                condition: condition,
                factory: factory,
                fallback: fallback
            )
        }

        #logInfo("📋 [Conditional] 조건부 등록: \(key)")
        #logInfo("  조건: \(condition.description)")
    }

    /// 조건에 따라 의존성을 해결합니다
    func resolve<T>(_ type: T.Type) async -> T? {
        let key = String(describing: type)

        guard let registration = accessQueue.sync(execute: { _conditionalRegistrations[key] }) else {
            #logError("❌ [Conditional] 등록되지 않은 타입: \(key)")
            return nil
        }

        let shouldInject = await registration.condition.shouldInject()

        if shouldInject {
            let instance = registration.factory() as! T
            #logInfo("✅ [Conditional] 조건 만족, 의존성 주입: \(key)")
            #logInfo("  조건: \(registration.condition.description)")
            return instance
        } else {
            #logInfo("⚠️ [Conditional] 조건 불만족, 폴백 사용: \(key)")
            #logInfo("  조건: \(registration.condition.description)")
            return registration.fallback() as? T
        }
    }

    /// 등록된 모든 조건들의 상태를 확인합니다
    func checkAllConditions() async -> [ConditionStatus] {
        let registrations = accessQueue.sync { _conditionalRegistrations }
        var statuses: [ConditionStatus] = []

        for (typeName, registration) in registrations {
            let isMet = await registration.condition.shouldInject()
            statuses.append(ConditionStatus(
                typeName: typeName,
                condition: registration.condition.description,
                isMet: isMet
            ))
        }

        return statuses.sorted { $0.typeName < $1.typeName }
    }
}

// MARK: - Supporting Structures

private struct ConditionalRegistration {
    let condition: InjectionCondition
    let factory: @Sendable () -> Any
    let fallback: @Sendable () -> Any?
}

struct ConditionStatus: Sendable {
    let typeName: String
    let condition: String
    let isMet: Bool

    var statusEmoji: String {
        isMet ? "✅" : "❌"
    }
}

// MARK: - Conditional Property Wrapper

/// 조건부 의존성 주입을 위한 Property Wrapper
@propertyWrapper
struct ConditionalInject<T> {
    private let type: T.Type
    private var _value: T?

    var wrappedValue: T? {
        get {
            if _value == nil {
                _value = Task {
                    await ConditionalInjectionManager.shared.resolve(type)
                }.result.value ?? nil
            }
            return _value
        }
    }

    init(_ type: T.Type) {
        self.type = type
        self._value = nil
    }
}

// MARK: - Feature Flag Service Implementation

final class DefaultFeatureFlagService: FeatureFlagService, @unchecked Sendable {
    private let accessQueue = DispatchQueue(label: "FeatureFlagService.access", attributes: .concurrent)
    private var _flags: [String: Bool] = [
        "premium_features": true,
        "admin_panel": false,
        "beta_ui": true,
        "analytics_tracking": true,
        "debug_mode": false
    ]

    func isEnabled(feature: String) async -> Bool {
        return accessQueue.sync {
            _flags[feature] ?? false
        }
    }

    func setEnabled(feature: String, enabled: Bool) async {
        accessQueue.async(flags: .barrier) {
            self._flags[feature] = enabled
        }
        #logInfo("🚩 [FeatureFlag] \(feature) = \(enabled)")
    }
}

final class MockUserService: UserService {
    private let currentUser: User

    init(user: User = User(id: "1", email: "user@example.com", role: .user, subscriptionType: .free)) {
        self.currentUser = user
    }

    func getCurrentUser() async throws -> User {
        await Task.sleep(nanoseconds: 100_000_000) // 0.1초 지연
        return currentUser
    }
}

// MARK: - Example Services

protocol PremiumService: Sendable {
    func getPremiumFeatures() async -> [String]
}

protocol AdminService: Sendable {
    func performAdminAction(action: String) async -> Bool
}

protocol AnalyticsService: Sendable {
    func trackEvent(name: String, properties: [String: Any]) async
}

final class DefaultPremiumService: PremiumService {
    func getPremiumFeatures() async -> [String] {
        #logInfo("💎 [Premium] 프리미엄 기능 조회")
        return ["advanced_analytics", "priority_support", "custom_themes"]
    }
}

final class DefaultAdminService: AdminService {
    func performAdminAction(action: String) async -> Bool {
        #logInfo("🔐 [Admin] 관리자 작업 수행: \(action)")
        await Task.sleep(nanoseconds: 200_000_000) // 0.2초 지연
        return true
    }
}

final class DefaultAnalyticsService: AnalyticsService {
    func trackEvent(name: String, properties: [String: Any]) async {
        #logInfo("📊 [Analytics] 이벤트 추적: \(name)")
        #logInfo("📊 [Analytics] 속성: \(properties)")
    }
}

// MARK: - Usage Example

/// 조건부 의존성 주입 사용 예제
final class ConditionalInjectionExample {
    @ConditionalInject(PremiumService.self) var premiumService
    @ConditionalInject(AdminService.self) var adminService
    @ConditionalInject(AnalyticsService.self) var analyticsService

    func setupConditionalDependencies() async {
        #logInfo("🎯 [Example] 조건부 의존성 설정 시작")

        let manager = ConditionalInjectionManager.shared
        let userService = MockUserService()
        let featureFlagService = DefaultFeatureFlagService()

        // Premium Service: 프리미엄 사용자에게만 제공
        manager.register(
            PremiumService.self,
            condition: UserRoleCondition(requiredRole: .premium, userService: userService),
            factory: { DefaultPremiumService() },
            fallback: { nil }
        )

        // Admin Service: 관리자에게만 제공
        manager.register(
            AdminService.self,
            condition: UserRoleCondition(requiredRole: .admin, userService: userService),
            factory: { DefaultAdminService() },
            fallback: { nil }
        )

        // Analytics Service: 기능 플래그와 시간 조건
        let analyticsCondition = CombinedCondition(conditions: [
            FeatureFlagCondition(featureName: "analytics_tracking", featureFlagService: featureFlagService),
            TimeBasedCondition(allowedTimeRange: 9...18) // 업무 시간에만 활성화
        ], operation: .and)

        manager.register(
            AnalyticsService.self,
            condition: analyticsCondition,
            factory: { DefaultAnalyticsService() },
            fallback: { NoOpAnalyticsService() }
        )

        #logInfo("✅ [Example] 조건부 의존성 설정 완료")
    }

    func demonstrateConditionalInjection() async {
        #logInfo("🎲 [Example] 조건부 의존성 주입 테스트")

        // Premium Service 테스트
        if let premium = premiumService {
            let features = await premium.getPremiumFeatures()
            #logInfo("💎 [Example] 프리미엄 기능: \(features)")
        } else {
            #logInfo("🚫 [Example] 프리미엄 서비스 이용 불가")
        }

        // Admin Service 테스트
        if let admin = adminService {
            let success = await admin.performAdminAction(action: "system_backup")
            #logInfo("🔐 [Example] 관리자 작업 결과: \(success)")
        } else {
            #logInfo("🚫 [Example] 관리자 서비스 이용 불가")
        }

        // Analytics Service 테스트
        if let analytics = analyticsService {
            await analytics.trackEvent(name: "feature_used", properties: [
                "feature": "conditional_injection",
                "timestamp": Date().timeIntervalSince1970
            ])
        }

        // 모든 조건 상태 확인
        let statuses = await ConditionalInjectionManager.shared.checkAllConditions()
        #logInfo("📊 [Example] 조건 상태 요약:")
        for status in statuses {
            #logInfo("  \(status.statusEmoji) \(status.typeName): \(status.condition)")
        }
    }
}

// MARK: - Combined Conditions

struct CombinedCondition: InjectionCondition {
    let conditions: [InjectionCondition]
    let operation: LogicalOperation

    enum LogicalOperation {
        case and, or
    }

    func shouldInject() async -> Bool {
        switch operation {
        case .and:
            for condition in conditions {
                if !(await condition.shouldInject()) {
                    return false
                }
            }
            return true

        case .or:
            for condition in conditions {
                if await condition.shouldInject() {
                    return true
                }
            }
            return false
        }
    }

    var description: String {
        let op = operation == .and ? " AND " : " OR "
        return conditions.map(\.description).joined(separator: op)
    }
}

// MARK: - No-Op Implementations

final class NoOpAnalyticsService: AnalyticsService {
    func trackEvent(name: String, properties: [String: Any]) async {
        // No operation - 조용히 무시
    }
}