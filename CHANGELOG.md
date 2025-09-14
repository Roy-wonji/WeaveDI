# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] - 2025-09-14

### Added
- UnifiedDI: 단일 진입점 등록/해결 API 추가 (sync/async 통합 경험)
- UnifiedRegistry: 통합 레지스트리(싱글톤/동기/비동기 팩토리, KeyPath 매핑)
- AutoDependencyResolver: 메인 액터 기반 자동 해석(옵션 토글/타입 제외 포함)
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

