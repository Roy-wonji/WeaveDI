//
//  DICompatibility.swift
//  DiContainer
//
//  Created by Claude on 2025-09-14.
//

import Foundation

// MARK: - Migration Aliases (for backward compatibility)

/// 기존 API와의 호환성을 위한 별칭들
/// 이들은 향후 deprecation 예정
public typealias SimpleDI = DI

// Legacy property wrapper aliases - will be deprecated
@available(*, deprecated, message: "Use @Inject from PropertyWrappers module instead")
public typealias SimpleInject<T> = LegacySimplifiedInject<T>

// MARK: - Version 1.x Compatibility Layer

/// Version 1.x와의 호환성을 위한 레거시 API들
@available(*, deprecated, message: "Use modern DI APIs instead")
public enum LegacyCompatibility {

    /// 1.x 버전 스타일의 등록
    @available(*, deprecated, message: "Use DI.register() instead")
    public static func legacyRegister<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) {
        DI.register(type) { factory() }
    }

    /// 1.x 버전 스타일의 해결
    @available(*, deprecated, message: "Use DI.resolve() instead")
    public static func legacyResolve<T>(_ type: T.Type) -> T? {
        return DI.resolve(type)
    }

    /// 1.x 버전 스타일의 싱글톤 등록
    @available(*, deprecated, message: "Use DI.register() with captured instance instead")
    public static func legacyRegisterSingleton<T: Sendable>(_ type: T.Type, instance: T) {
        let capturedInstance = instance
        DI.register(type) { [capturedInstance] in capturedInstance }
    }

    /// 1.x 버전 스타일의 해제
    @available(*, deprecated, message: "Use DI.release() instead")
    public static func legacyRelease<T>(_ type: T.Type) {
        DI.release(type)
    }
}

// MARK: - Pre-2.0 API Compatibility

/// 2.0 이전 버전과의 호환성을 위한 API들
@available(*, deprecated, message: "Migrate to 2.0 APIs")
public enum PreTwoPointZeroCompatibility {

    /// 이전 버전의 컨테이너 직접 접근
    @available(*, deprecated, message: "Use DI.resolve() or @Inject instead")
    public static var container: DependencyContainer {
        return DependencyContainer.live
    }

    /// 이전 버전의 수동 부트스트랩
    @available(*, deprecated, message: "Use modern bootstrap APIs")
    public static func manualBootstrap() {
        // 이전 버전에서는 수동 부트스트랩이 필요했음
        print("⚠️ [Legacy] Manual bootstrap is deprecated. Modern DI handles this automatically.")
    }

    /// 이전 버전의 타입 안전성 검사
    @available(*, deprecated, message: "Type safety is now built-in")
    public static func checkTypeSafety<T>(_ type: T.Type) -> Bool {
        return DI.isRegistered(type)
    }

    /// 이전 버전의 스코프 관리
    @available(*, deprecated, message: "Use modern scoping mechanisms")
    public static func enterScope(_ name: String) {
        print("⚠️ [Legacy] Scope '\(name)' management is deprecated. Use modern scoping.")
    }

    /// 이전 버전의 스코프 해제
    @available(*, deprecated, message: "Use modern scoping mechanisms")
    public static func exitScope(_ name: String) {
        print("⚠️ [Legacy] Scope '\(name)' exit is deprecated.")
    }
}

// MARK: - Migration Utilities

/// 마이그레이션을 돕는 유틸리티들
public enum MigrationUtilities {

    /// 현재 사용 중인 레거시 API를 검출하고 경고를 표시
    public static func detectLegacyUsage() {
        #if DEBUG
        print("""
        🔍 [Migration] Legacy API Detection
        ===================================

        이 메서드를 호출하여 레거시 API 사용을 확인할 수 있습니다.
        실제 구현에서는 런타임 분석이나 정적 분석 도구를 사용하세요.

        📋 확인해야 할 항목:
        • @LegacySimplifiedInject → @Inject
        • LegacyCompatibility.* → DI.*
        • 직접 컨테이너 접근 → DI API 사용
        • 수동 스코프 관리 → 자동 스코프 관리
        """)
        #endif
    }

    /// 마이그레이션 진행률을 추정
    public static func estimateMigrationProgress() -> MigrationProgress {
        // 실제 구현에서는 코드베이스를 분석하여 진행률 계산
        return MigrationProgress(
            totalItems: 100,
            migratedItems: 75,
            remainingItems: 25,
            percentage: 75.0
        )
    }

    /// 마이그레이션 우선순위를 제안
    public static func suggestMigrationPriority() -> [MigrationTask] {
        return [
            MigrationTask(
                title: "Property Wrapper 마이그레이션",
                priority: .high,
                description: "@LegacySimplifiedInject를 @Inject로 교체"
            ),
            MigrationTask(
                title: "직접 컨테이너 접근 제거",
                priority: .high,
                description: "DependencyContainer.live 직접 접근을 DI API로 교체"
            ),
            MigrationTask(
                title: "레거시 헬퍼 클래스 제거",
                priority: .medium,
                description: "LegacyDIHelper 사용을 현대적 API로 교체"
            ),
            MigrationTask(
                title: "수동 스코프 관리 제거",
                priority: .low,
                description: "이전 버전의 스코프 관리를 자동화된 시스템으로 교체"
            )
        ]
    }
}

// MARK: - Migration Data Structures

public struct MigrationProgress {
    public let totalItems: Int
    public let migratedItems: Int
    public let remainingItems: Int
    public let percentage: Double

    public var isComplete: Bool {
        return remainingItems == 0
    }

    public var description: String {
        return "마이그레이션 진행률: \(migratedItems)/\(totalItems) (\(String(format: "%.1f", percentage))%)"
    }
}

public struct MigrationTask {
    public let title: String
    public let priority: Priority
    public let description: String

    public enum Priority: String, CaseIterable {
        case high = "높음"
        case medium = "보통"
        case low = "낮음"

        public var emoji: String {
            switch self {
            case .high: return "🔴"
            case .medium: return "🟡"
            case .low: return "🟢"
            }
        }
    }

    public var formattedDescription: String {
        return "\(priority.emoji) [\(priority.rawValue)] \(title): \(description)"
    }
}

// MARK: - Deprecated API Warning System

#if DEBUG
/// 개발 중 레거시 API 사용에 대한 경고 시스템
@MainActor
public final class DeprecationWarningSystem {
    public static let shared = DeprecationWarningSystem()

    private var warningCount: [String: Int] = [:]
    private let maxWarningsPerAPI = 3

    private init() {}

    /// 레거시 API 사용 시 경고 발생
    public func warn(api: String, replacement: String) {
        let currentCount = warningCount[api, default: 0]
        guard currentCount < maxWarningsPerAPI else { return }

        warningCount[api] = currentCount + 1

        print("""
        ⚠️ [Deprecation Warning \(currentCount + 1)/\(maxWarningsPerAPI)]
        Legacy API: \(api)
        Replacement: \(replacement)

        이 API는 향후 버전에서 제거될 예정입니다.
        마이그레이션 가이드를 참조하여 업데이트하세요.
        """)

        if currentCount + 1 == maxWarningsPerAPI {
            print("📝 [Note] '\(api)' 에 대한 추가 경고는 표시되지 않습니다.")
        }
    }

    /// 모든 경고 통계 표시
    public func printWarningStatistics() {
        guard !warningCount.isEmpty else {
            print("✅ [Deprecation] 레거시 API 사용이 감지되지 않았습니다!")
            return
        }

        print("""
        📊 [Deprecation Statistics]
        ==========================
        """)

        for (api, count) in warningCount.sorted(by: { $0.key < $1.key }) {
            print("• \(api): \(count)회 사용")
        }

        let totalWarnings = warningCount.values.reduce(0, +)
        print("\n총 \(totalWarnings)개의 레거시 API 사용이 감지되었습니다.")
        print("마이그레이션을 권장합니다.")
    }
}
#endif

// MARK: - Future Compatibility Notes

/// 미래 버전과의 호환성을 위한 노트들
public enum FutureCompatibilityNotes {
    /// 계획된 변경사항들
    public static let plannedChanges = [
        "3.0: Swift 6.0 완전 호환성",
        "3.1: 향상된 성능 최적화",
        "3.2: 추가 플러그인 시스템 기능",
        "4.0: Swift Concurrency 완전 통합"
    ]

    /// 호환성 유지 계획
    public static let compatibilityPromise = """
    DiContainer는 semantic versioning을 따릅니다:
    • Major 버전: Breaking changes 포함
    • Minor 버전: 새로운 기능, 하위 호환성 유지
    • Patch 버전: 버그 수정, 완전 호환

    Deprecation 정책:
    • 최소 1개 major 버전 동안 deprecated API 유지
    • 충분한 마이그레이션 시간 제공
    • 자세한 마이그레이션 가이드 제공
    """
}