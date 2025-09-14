//
//  DocumentationStandards.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/19/25.
//

import Foundation

// MARK: - Documentation Standards for DiContainer

/// ## DiContainer 문서화 표준
///
/// 이 파일은 DiContainer 프로젝트의 모든 문서화 표준과 템플릿을 정의합니다.
/// 일관성 있는 문서화를 통해 코드의 가독성과 유지보수성을 향상시킵니다.
///
/// ## 문서화 원칙
///
/// ### 🎯 명확성 (Clarity)
/// - 기술적 정확성을 유지하면서도 이해하기 쉬운 설명
/// - 구체적인 사용 예시와 코드 샘플 제공
/// - 복잡한 개념을 단계별로 설명
///
/// ### 🔄 일관성 (Consistency)
/// - 동일한 포맷과 스타일 사용
/// - 표준화된 섹션 구조
/// - 통일된 용어 사용
///
/// ### 🚀 실용성 (Practicality)
/// - 실제 사용 시나리오에 기반한 예시
/// - 마이그레이션 가이드 포함
/// - 문제 해결 방법 제시
///
/// ### 🔍 검색 가능성 (Searchability)
/// - 표준 용어 사용 (Swift community standards)
/// - 키워드 최적화
/// - 명확한 제목과 섹션 구분

public enum DocumentationStandards {

    // MARK: - Standard Templates

    /// 공개 API 문서화 템플릿
    public static let publicAPITemplate = """
    /// ## 개요
    ///
    /// [API의 목적과 역할을 간단히 설명]
    ///
    /// ## 핵심 특징
    ///
    /// ### 🎯 [주요 특징 1]
    /// - **설명**: [특징에 대한 설명]
    /// - **장점**: [이 특징의 장점]
    /// - **사용 시기**: [언제 사용하는지]
    ///
    /// ### 🔄 [주요 특징 2]
    /// - **설명**: [특징에 대한 설명]
    /// - **장점**: [이 특징의 장점]
    /// - **사용 시기**: [언제 사용하는지]
    ///
    /// ## 사용 예시
    ///
    /// ### 기본 사용법
    /// ```swift
    /// // 기본적인 사용 예시
    /// let example = APIExample()
    /// example.performAction()
    /// ```
    ///
    /// ### 고급 사용법
    /// ```swift
    /// // 복잡한 사용 시나리오
    /// let advanced = APIExample()
    /// advanced.configure { config in
    ///     config.option = value
    /// }
    /// ```
    ///
    /// ## 마이그레이션 가이드
    ///
    /// ### 기존 API에서
    /// ```swift
    /// // Before
    /// oldAPI.doSomething()
    ///
    /// // After
    /// newAPI.performAction()
    /// ```
    ///
    /// - Parameter [매개변수 이름]: [매개변수 설명]
    /// - Returns: [반환값 설명]
    /// - Throws: [발생 가능한 에러 설명]
    ///
    /// - Note: [추가 참고사항]
    /// - Important: [중요한 주의사항]
    /// - Warning: [경고사항]
    /// - SeeAlso: [관련 API 또는 문서 링크]
    """

    /// 내부 구현 문서화 템플릿
    public static let internalImplementationTemplate = """
    /// ## 내부 구현
    ///
    /// [구현의 목적과 역할]
    ///
    /// ## 동작 원리
    ///
    /// ### 1단계: [단계명]
    /// - [단계별 설명]
    ///
    /// ### 2단계: [단계명]
    /// - [단계별 설명]
    ///
    /// ## 성능 특성
    /// - **시간 복잡도**: O([복잡도])
    /// - **공간 복잡도**: O([복잡도])
    /// - **동시성**: [동시성 특성]
    ///
    /// ## 제한사항
    /// - [제한사항 1]
    /// - [제한사항 2]
    ///
    /// - Note: [구현 관련 참고사항]
    """

    /// 프로토콜 문서화 템플릿
    public static let protocolTemplate = """
    /// ## 개요
    ///
    /// `[프로토콜명]`은 [프로토콜의 역할과 목적]을 정의하는 프로토콜입니다.
    ///
    /// ## 요구사항
    ///
    /// ### 필수 구현
    /// - `[메서드명]`: [메서드 역할]
    /// - `[프로퍼티명]`: [프로퍼티 역할]
    ///
    /// ### 선택적 구현
    /// - `[메서드명]`: [메서드 역할] (기본 구현 제공)
    ///
    /// ## 구현 예시
    ///
    /// ```swift
    /// struct ExampleImplementation: [프로토콜명] {
    ///     func requiredMethod() {
    ///         // 구현 내용
    ///     }
    /// }
    /// ```
    ///
    /// ## 관련 타입
    /// - `[관련타입1]`: [관계 설명]
    /// - `[관련타입2]`: [관계 설명]
    """
}

// MARK: - Documentation Guidelines

/// 문서화 가이드라인
public enum DocumentationGuidelines {

    /// 표준 용어집
    public enum StandardTerms {
        /// 의존성 주입 관련 용어
        public enum DependencyInjection {
            public static let container = "Container"
            public static let factory = "Factory"
            public static let singleton = "Singleton"
            public static let registration = "Registration"
            public static let resolution = "Resolution"
            public static let dependency = "Dependency"
            public static let injection = "Injection"
            public static let lifecycle = "Lifecycle"
        }

        /// 동시성 관련 용어
        public enum Concurrency {
            public static let threadSafe = "Thread-safe"
            public static let actor = "Actor"
            public static let sendable = "Sendable"
            public static let isolation = "Isolation"
            public static let concurrency = "Concurrency"
            public static let async = "Asynchronous"
            public static let sync = "Synchronous"
        }

        /// 성능 관련 용어
        public enum Performance {
            public static let optimization = "Optimization"
            public static let complexity = "Complexity"
            public static let efficiency = "Efficiency"
            public static let scalability = "Scalability"
            public static let throughput = "Throughput"
            public static let latency = "Latency"
        }
    }

    /// 섹션 순서 가이드라인
    public enum SectionOrder {
        /// 공개 API 문서의 권장 섹션 순서
        public static let publicAPI = [
            "개요 (Overview)",
            "핵심 특징 (Key Features)",
            "사용 예시 (Usage Examples)",
            "마이그레이션 가이드 (Migration Guide)",
            "매개변수/반환값 (Parameters/Returns)",
            "주의사항 (Notes/Warnings)",
            "관련 링크 (See Also)"
        ]

        /// 내부 구현 문서의 권장 섹션 순서
        public static let internalImplementation = [
            "내부 구현 (Internal Implementation)",
            "동작 원리 (How it Works)",
            "성능 특성 (Performance Characteristics)",
            "제한사항 (Limitations)",
            "구현 노트 (Implementation Notes)"
        ]
    }

    /// 코드 예시 가이드라인
    public enum CodeExamples {
        /// 예시 코드 작성 원칙
        public static let principles = [
            "실제 사용 가능한 코드 제공",
            "단계적 복잡도 증가 (기본 → 고급)",
            "주석을 통한 설명 추가",
            "에러 처리 방법 포함",
            "성능 최적화 팁 제공"
        ]

        /// 예시 코드 카테고리
        public static let categories = [
            "기본 사용법 (Basic Usage)",
            "고급 사용법 (Advanced Usage)",
            "최적화 팁 (Optimization Tips)",
            "문제 해결 (Troubleshooting)",
            "마이그레이션 (Migration)"
        ]
    }
}

// MARK: - Documentation Quality Checklist

/// 문서화 품질 체크리스트
public enum DocumentationQualityChecklist {

    /// 필수 요소 체크리스트
    public static let essentialElements = [
        "[ ] 명확한 개요 (Clear overview)",
        "[ ] 구체적인 사용 예시 (Concrete usage examples)",
        "[ ] 매개변수와 반환값 설명 (Parameter and return descriptions)",
        "[ ] 에러 조건 설명 (Error conditions)",
        "[ ] 관련 API 링크 (Related API references)"
    ]

    /// 품질 기준
    public static let qualityCriteria = [
        "[ ] 기술적 정확성 (Technical accuracy)",
        "[ ] 이해 가능성 (Comprehensibility)",
        "[ ] 완전성 (Completeness)",
        "[ ] 최신성 (Up-to-date information)",
        "[ ] 일관성 (Consistency with project standards)"
    ]

    /// 사용성 체크리스트
    public static let usabilityChecklist = [
        "[ ] 검색 가능한 키워드 포함 (Searchable keywords)",
        "[ ] 단계별 가이드 제공 (Step-by-step guidance)",
        "[ ] 일반적인 문제 해결책 포함 (Common problem solutions)",
        "[ ] 마이그레이션 경로 제공 (Migration paths)",
        "[ ] 성능 고려사항 언급 (Performance considerations)"
    ]
}

// MARK: - Localization Guidelines

/// 다국어 문서화 가이드라인
public enum LocalizationGuidelines {

    /// 언어별 우선순위
    public static let languagePriority = [
        "한국어 (Korean) - Primary",
        "영어 (English) - Secondary",
        "일본어 (Japanese) - Future consideration"
    ]

    /// 혼합 사용 규칙
    public static let mixedLanguageRules = [
        "기술 용어는 영어 원문 유지 (예: Actor, Sendable)",
        "설명문은 한국어 우선 작성",
        "코드 주석은 영어 사용",
        "사용 예시는 한국어 설명 + 영어 코드",
        "에러 메시지는 한국어 제공"
    ]

    /// 표준 번역 용어집
    public static let translationGlossary = [
        "Container": "컨테이너",
        "Factory": "팩토리",
        "Singleton": "싱글톤",
        "Registration": "등록",
        "Resolution": "해결",
        "Dependency": "의존성",
        "Injection": "주입",
        "Thread-safe": "스레드 안전한",
        "Performance": "성능",
        "Optimization": "최적화"
    ]
}

// MARK: - Documentation Validation

#if DEBUG
/// 문서화 검증 도구 (디버그 빌드에서만 사용)
public enum DocumentationValidator {

    /// 문서화 완성도 검사
    public static func validateDocumentation(for type: Any.Type) -> ValidationResult {
        let typeName = String(describing: type)

        // 실제 검증 로직은 리플렉션이나 소스 코드 분석이 필요하므로
        // 여기서는 기본적인 구조만 제공

        return ValidationResult(
            typeName: typeName,
            hasOverview: true, // 실제로는 검증 로직 필요
            hasUsageExamples: true,
            hasParameterDocumentation: true,
            completenessScore: 0.85
        )
    }

    /// 검증 결과
    public struct ValidationResult {
        public let typeName: String
        public let hasOverview: Bool
        public let hasUsageExamples: Bool
        public let hasParameterDocumentation: Bool
        public let completenessScore: Double

        public var isComplete: Bool {
            return completenessScore >= 0.8 &&
                   hasOverview &&
                   hasUsageExamples &&
                   hasParameterDocumentation
        }

        public var recommendations: [String] {
            var recommendations: [String] = []

            if !hasOverview {
                recommendations.append("Add comprehensive overview section")
            }
            if !hasUsageExamples {
                recommendations.append("Include practical usage examples")
            }
            if !hasParameterDocumentation {
                recommendations.append("Document all parameters and return values")
            }
            if completenessScore < 0.8 {
                recommendations.append("Improve overall documentation completeness")
            }

            return recommendations
        }
    }
}
#endif

// MARK: - Documentation Automation

/// 문서화 자동화 도구
public enum DocumentationAutomation {

    /// 자동 문서 생성 설정
    public static let autoGenerationConfig = [
        "generateForPublicAPIs": true,
        "includeUsageExamples": true,
        "generateMigrationGuides": true,
        "includePerformanceNotes": true,
        "validateDocumentation": true
    ]

    /// 문서화 메트릭
    public static let documentationMetrics = [
        "coveragePercentage": "문서화 커버리지",
        "completenessScore": "완성도 점수",
        "consistencyRating": "일관성 평가",
        "usabilityIndex": "사용성 지수"
    ]
}