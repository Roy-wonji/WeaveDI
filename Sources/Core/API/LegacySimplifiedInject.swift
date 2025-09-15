//
//  LegacySimplifiedInject.swift
//  DiContainer
//
//  Created by Claude on 2025-09-14.
//

import Foundation
import LogMacro

// MARK: - Legacy Simplified Inject Property Wrapper

/// 레거시 단순화된 의존성 주입 프로퍼티 래퍼 (deprecated)
///
/// 새로운 코드에서는 `PropertyWrappers` 모듈의 `@Inject`를 사용하세요.
///
/// ## 마이그레이션:
/// ```swift
/// // Before (deprecated)
/// @LegacySimplifiedInject(\.service) var service: ServiceProtocol?
///
/// // After (recommended)
/// @Inject(\.service) var service: ServiceProtocol?
/// ```
@available(*, deprecated, message: "Use @Inject from PropertyWrappers module instead")
@propertyWrapper
public struct LegacySimplifiedInject<T> {
    private let keyPath: KeyPath<DependencyContainer, T?>

    public var wrappedValue: T {
        get {
            if let resolved = DependencyContainer.live[keyPath: keyPath] {
                return resolved
            }

            // T가 Optional 타입인지 확인
            if T.self is OptionalProtocol.Type {
                // Optional 타입이면 nil을 반환 (크래시 없음)
                return Optional<Any>.none as! T
            } else {
                // Non-optional 타입이면 더 친화적인 에러 메시지와 함께 fatalError
                let typeName = String(describing: T.self)
                let suggestion = "DI.register(\(typeName).self) { YourImplementation() }"

                fatalError("""
                🚨 [DI] Required dependency not found!

                Type: \(typeName)
                KeyPath: \(keyPath)

                💡 Fix by adding this to your app startup:
                   \(suggestion)

                🔍 Make sure you called this before accessing the @Inject property.
                """)
            }
        }
    }

    public init(_ keyPath: KeyPath<DependencyContainer, T?>) {
        self.keyPath = keyPath
    }
}

// MARK: - Optional Protocol Detection

/// Optional 타입 감지를 위한 내부 프로토콜
private protocol OptionalProtocol {
    static var wrappedType: Any.Type { get }
}

extension Optional: OptionalProtocol {
    static var wrappedType: Any.Type { return Wrapped.self }
}

// MARK: - Legacy Convenience Extensions

@available(*, deprecated, message: "Use PropertyWrappers module APIs instead")
public extension LegacySimplifiedInject {
    /// 타입 기반 레거시 주입 (KeyPath 없이)
    /// - Note: 내부적으로는 타입 해결을 시도하지만 KeyPath가 필요함
    static func typeOnly(_ type: T.Type) -> LegacySimplifiedInject<T> {
        // 임시 KeyPath - 실제 사용 시 문제가 될 수 있음
        fatalError("Type-only injection not supported in legacy wrapper. Use KeyPath-based injection instead.")
    }

    /// 조건부 레거시 주입
    static func conditional(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        condition: @escaping () -> Bool
    ) -> LegacySimplifiedInject<T> {
        // 조건부 로직은 복잡하므로 단순화된 버전만 제공
        return LegacySimplifiedInject<T>(keyPath)
    }
}

// MARK: - Legacy Migration Helpers

@available(*, deprecated, message: "Use modern DI.register() API instead")
public struct LegacyDIHelper {
    /// 레거시 방식으로 KeyPath와 타입을 동시에 등록
    public static func legacyRegister<T>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        type: T.Type,
        factory: @escaping @Sendable () -> T
    ) where T: Sendable {
        // 현대적 API로 위임
        DI.register(keyPath) {
            factory()
        }
    }

    /// 레거시 해결 방식
    @available(*, deprecated, message: "Use DI.resolve() instead")
    public static func legacyResolve<T>(
        _ keyPath: KeyPath<DependencyContainer, T?>
    ) -> T? {
        return DependencyContainer.live[keyPath: keyPath]
    }

    /// 레거시 필수 해결 방식
    @available(*, deprecated, message: "Use DI.requireResolve() instead")
    public static func legacyRequireResolve<T>(
        _ keyPath: KeyPath<DependencyContainer, T?>
    ) -> T {
        guard let resolved = DependencyContainer.live[keyPath: keyPath] else {
            let typeName = String(describing: T.self)
            fatalError("🚨 [Legacy DI] Required dependency not found: \(typeName)")
        }
        return resolved
    }
}

// MARK: - Legacy Documentation

/// 레거시 SimplifiedInject 시스템에 대한 문서화
///
/// ## 마이그레이션 가이드
///
/// ### 1. Property Wrapper 마이그레이션
/// ```swift
/// // 기존 (Deprecated)
/// @LegacySimplifiedInject(\.userService)
/// var userService: UserService?
///
/// // 신규 (권장)
/// @Inject(\.userService)
/// var userService: UserService?
/// ```
///
/// ### 2. 등록 방식 마이그레이션
/// ```swift
/// // 기존 (Deprecated)
/// LegacyDIHelper.legacyRegister(\.userService, type: UserService.self) {
///     DefaultUserService()
/// }
///
/// // 신규 (권장)
/// DI.register(\.userService) {
///     DefaultUserService()
/// }
/// ```
///
/// ### 3. 해결 방식 마이그레이션
/// ```swift
/// // 기존 (Deprecated)
/// let service = LegacyDIHelper.legacyResolve(\.userService)
///
/// // 신규 (권장)
/// let service = DI.resolve(UserService.self)
/// ```
@available(*, deprecated, message: "Legacy system deprecated. Use modern PropertyWrappers and DI APIs")
public enum LegacySimplifiedDISystem {
    /// 레거시 시스템의 제한사항들
    public static let limitations = [
        "KeyPath 기반 주입만 지원",
        "타입 기반 해결 불가능",
        "조건부 주입 미지원",
        "성능 최적화 부족",
        "캐싱 기능 없음",
        "검증 기능 부족"
    ]

    /// 신규 시스템의 이점들
    public static let modernBenefits = [
        "타입 기반 + KeyPath 기반 주입",
        "조건부 및 폴백 지원",
        "성능 최적화 및 캐싱",
        "검증 및 진단 기능",
        "플러그인 시스템 호환",
        "비동기 해결 지원"
    ]

    /// 마이그레이션 체크리스트
    public static func printMigrationChecklist() {
        #logInfo("""
        📋 [Legacy Migration Checklist]
        ===============================

        ✅ 해야 할 작업:
        1. @LegacySimplifiedInject → @Inject로 교체
        2. LegacyDIHelper → DI API로 교체
        3. 타입 기반 해결로 전환 고려
        4. 새로운 기능들 활용 (캐싱, 검증 등)

        ⚠️ 주의사항:
        - 레거시 시스템은 향후 제거 예정
        - 새 프로젝트에서는 현대적 API만 사용
        - 점진적 마이그레이션 권장

        🔗 참고:
        - PropertyWrappers 모듈 문서 확인
        - DI API 가이드 참조
        - 마이그레이션 가이드 숙지
        """)
    }
}