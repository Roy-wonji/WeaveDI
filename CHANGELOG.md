으# Changelog

All notable changes to this project will be documented in this file.

## [2.1.0] - 2024-09-24

### Added
- AutoDIOptimizer: 자동 의존성 그래프 생성 및 성능 최적화 시스템
- 자동 사용 통계 수집 및 백그라운드 최적화 (30초 주기)
- 자동 순환 의존성 감지 및 LogMacro 통합 로깅
- Swift DocC 문서 업데이트 (AutoDIOptimizer.md 추가)

### Changed
- 핵심 3개 PropertyWrapper로 단순화: @Inject, @Factory, @SafeInject
- DIContainer 통합: DependencyContainer + Container → DIContainer
- README 간소화: 핵심 기능 중심으로 재작성

### Removed
- PluginSystem (438라인) - 핵심 DI 기능에 집중
- InteractiveDependencyVisualizer (1022라인) - 자동화로 대체
- AdvancedCircularDependencyDetector (920라인) - AutoDIOptimizer로 통합
- ActorHopMetrics (399라인) - 불필요한 복잡성 제거
- DocumentationValidator (392라인) - 개발 도구 분리
- SimplePerformanceOptimizer - AutoDIOptimizer로 교체
- AutoDependencyResolver - 사용되지 않는 기능 제거 (1323라인)

## [2.0.0] - 2025-09-14

### Added
- UnifiedDI: 단일 진입점 등록/해결 API 추가 (sync/async 통합 경험)
- UnifiedRegistry: 통합 레지스트리(싱글톤/동기/비동기 팩토리, KeyPath 매핑)
- resolveAnyAsync(Any.Type): 런타임 타입 비동기 해석 API
- CI 파이프라인: 엄격 동시성 + 경고 실패 처리 + DocC 빌드 체크

### Changed
- 타입/동시성 안전성 강화: Swift 6 @Sendable, actor 격리, 박싱 최소화
- TypeNameResolver: 문자열 매핑 축소(명시적 등록/AutoResolve 우선)
- README/MIGRATION 업데이트: UnifiedDI, AutoResolver, 마이그레이션 가이드 보강

### Deprecated/Removed
- 문자열 기반 공통 타입 매핑 제거(취약성 감소)
- 일부 레거시 API를 UnifiedDI/UnifiedRegistry 기반으로 수렴

### Migration
- 상세 가이드는 MIGRATION-2.0.0.md 참고

---

이전 버전에 대한 변경 이력은 향후 정리 예정입니다.

