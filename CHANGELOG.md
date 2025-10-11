# Changelog

All notable changes to this project will be documented in this file.

## [3.3.0] - 2025-10-12

### 🚀 Major Performance Enhancements
- **Environment Flags Optimization**: Complete elimination of performance monitoring overhead in production
  - `DI_MONITORING_ENABLED` compilation flag for conditional performance tracking
  - 0% Task creation overhead in release builds
  - Maintains full monitoring capabilities in debug mode
  - Smart conditional compilation throughout `UnifiedDI` and `DIAdvanced.Performance`
  - Files: `Sources/Core/API/UnifiedDI.swift`, `Sources/Core/API/DIAdvanced.swift`

- **Advanced Performance Monitoring System**: Comprehensive performance optimization framework
  - Memory-efficient tracking with conditional data storage
  - Real-time metrics collection in development environments
  - Automatic optimization suggestions and bottleneck detection
  - CI/CD pipeline integration for performance validation
  - Documentation: `docs/api/performanceOptimizations.md`, `docs/ko/api/performanceOptimizations.md`

### 🎯 TCA Integration Improvements
- **TCA Bridge Policy Configuration**: Dynamic dependency priority control for flexible TCA integration
  - `TCABridgePolicy` enum with `.testPriority`, `.livePriority`, and `.contextual` modes
  - Runtime policy switching for different deployment environments
  - Context-aware value selection based on execution environment
  - SwiftUI integration support for developer settings
  - Files: `Sources/Core/Integration/TCASmartSync.swift`
  - Documentation: `docs/api/tcaPolicyConfiguration.md`, `docs/ko/api/tcaPolicyConfiguration.md`

### 🏗️ Enhanced Batch Registration
- **Modern Result Builder DSL**: Completely redesigned batch registration system
  - `@BatchRegistrationBuilder` for declarative dependency registration
  - Support for factory, default value, and conditional registration patterns
  - Type-safe compilation with full Swift Result Builder features
  - Conditional registration blocks and array-based registration support
  - Files: `Sources/Core/API/DIAdvanced.swift`
  - Documentation: `docs/api/batchRegistration.md`, `docs/ko/api/batchRegistration.md`

### 🛡️ Automatic Issue Detection
- **ComponentDiagnostics System**: Revolutionary automatic dependency analysis
  - Compile-time detection of duplicate providers and scope inconsistencies
  - Automatic solution suggestions and detailed problem reports
  - CI/CD pipeline integration for automated validation
  - JSON export capabilities for external tooling integration
  - Zero false positives with precise metadata analysis
  - Documentation: `docs/api/componentDiagnostics.md`, `docs/ko/api/componentDiagnostics.md`

### 🔧 Code Quality Improvements
- **Warning Resolution**: Complete elimination of Swift compiler warnings
  - Fixed conditional cast warnings in `TCASmartSync.swift`
  - Improved type safety with runtime protocol checking
  - Enhanced error handling and edge case management
  - Cleaner codebase with optimized performance paths

### 📚 Comprehensive Documentation
- **Environment Flags Documentation**: Complete guide to compile-time optimization
  - Build configuration examples and CI/CD integration
  - Performance benchmarking and memory usage analysis
  - Documentation: `docs/api/environmentFlags.md`, `docs/ko/api/environmentFlags.md`

### 🎨 Developer Experience
- **Enhanced IDE Support**: Improved autocomplete and type inference
- **Better Error Messages**: More descriptive compilation and runtime errors
- **Performance Insights**: Detailed metrics and optimization recommendations

---

## [3.2.1] - 2025-10-03

### 🎉 추가됨
- **문서 강화**: Swift-dependencies 통합 가이드 제공
- 실제 마이그레이션 예제와 구체적인 타입 주입 패턴
- 성능 비교 표와 벤치마크 결과
- 통합 관련 FAQ 섹션 추가
- 점진적 마이그레이션을 위한 하이브리드 접근 방식 문서화
- 한국어/영어 버전 모두 업데이트

- **DependencyValues 통합**: 완전한 예제 및 테스트 추가
- `DependencyValuesIntegrationTests.swift`에 포괄적인 테스트 커버리지
- 실제 환율 서비스 예제 포함
- 성능 벤치마킹 테스트 추가
- 테스트용 Mock 구현 제공
- 비동기 컨텍스트 주입 예제

- **예제 프로젝트**: WeaveDI + swift-dependencies 통합 작동 예제 제공
- `Example/DependencyValuesExample` 패키지
- 다양한 주입 패턴 시연
- 실서비스 vs Mock 서비스 구현
- 성능 비교 구현

---


### 🔧 개선됨
- **@Injected 구현**: 단순화 및 최적화
- 불필요한 `dynamicMember` 서브스크립트 제거
- `InjectedValues`에 대한 더 나은 KeyPath 지원
- 사용자 정의 의존성 등록을 위한 더 깔끔한 템플릿 제공

- **문서 업데이트**: @Inject → @Injected 변경 반영
- 전체 API 문서 예제 최신화
- 프로퍼티 래퍼 참조 정정
- 실제 사용자 패턴 기반 코드 예제 강화

---

### 🐛 수정됨
- **문서 일관성**: @Injected 사용 통일
- 혼용된 @Inject/@Injected 참조 수정
- 튜토리얼 예제 최신화
- API 레퍼런스 문서 정정

## [3.2.0] - 2025-10-01

### 🎉 Added
- **@Injected Property Wrapper**: New TCA-style dependency injection inspired by The Composable Architecture
- KeyPath-based access: `@Injected(\.apiClient) var apiClient`
- Type-based access: `@Injected(ExchangeUseCaseImpl.self) var useCase`
- `InjectedKey` protocol for defining dependencies
- `InjectedValues` container for managing injected values
- `withInjectedValues` for testing and overriding dependencies
- Non-mutating access (no `mutating get` required)
- Full compile-time type safety
- 파일: `Sources/PropertyWrappers/Dependency.swift`

- **AppDI Simplification**: Streamlined app initialization with `AppDIManager`
- `bootstrapInTask` with `@DIContainerActor` for actor-safe initialization
- `AppDIManager.shared.registerDefaultDependencies()` for automatic registration
- Module-based registration with `asyncForEach` for parallel processing
- Cleaner app setup with less boilerplate
- 파일: `Sources/Core/AppDI/AppDIManager.swift`

### ⚠️ Deprecated
- **@Inject Property Wrapper**: Will be removed in 4.0.0
- Use `@Injected` instead for modern, type-safe dependency injection
- Migration guide available at `/docs/guide/migration-3.2.0.md`

- **@SafeInject Property Wrapper**: Will be removed in 4.0.0
- Use `@Injected` with proper `InjectedKey` definitions instead
- Migration guide available at `/docs/guide/migration-3.2.0.md`

### 📚 Documentation
- Comprehensive English and Korean documentation for `@Injected`
- `/docs/api/injected.md` (English)
- `/docs/ko/api/injected.md` (Korean)
- AppDI Simplification guide with real-world examples
- `/docs/guide/appDiSimplification.md` (English)
- `/docs/ko/guide/appDiSimplification.md` (Korean)
- Updated API reference with deprecation notices
- Migration guides from `@Inject` and `@SafeInject` to `@Injected`
- VitePress documentation site improvements

### 🔧 Improvements
- Better actor safety with `@DIContainerActor`
- Improved Swift 6 concurrency support
- Enhanced type safety across the framework
- Performance optimizations in dependency resolution

## [3.1.0] - 2025-09-27

### Added
#### 🚀 런타임 핫패스 미세최적화
- **TypeID + 인덱스 접근 시스템**
- ObjectIdentifier → Int 슬롯 ID 매핑으로 딕셔너리 대신 O(1) 배열 인덱스 접근
- 타입 초기화 비용 제거 및 메모리 접근 패턴 최적화
- 파일: `Sources/Core/Optimized/OptimizedTypeRegistry.swift`

- **스냅샷/락-프리 읽기 시스템**
- 불변 Storage 클래스 기반 스냅샷 방식으로 읽기 경합 제거
- 원자적 포인터 교체로 쓰기 시에만 락 사용, 읽기는 완전 락-프리
- 파일: `Sources/Core/Optimized/AtomicStorage.swift`

- **inlinable + final + @_alwaysEmitIntoClient 최적화**
- 핫패스 API에 인라인 최적화 속성 적용으로 함수 호출 오버헤드 축소
- 클라이언트 코드에 직접 인라인 방출로 크로스 모듈 최적화 지원
- 파일: `Sources/Core/Optimized/FastDI.swift`

- **코스트리 반영 및 팩토리 체이닝 제거**
- 팩토리 중간 단계 없는 직접 호출 경로 생성
- 의존성 체인 플래튼화로 다단계 팩토리 호출 비용 제거
- 파일: `Sources/Core/Optimized/DirectCallRegistry.swift`

- **스코프별 정적 저장소 + once 초기화**
- 싱글톤/세션/리퀘스트 스코프별 전용 저장소 분리
- 원자적 once 초기화로 싱글톤 생성 경합 제거
- 파일: `Sources/Core/Optimized/OptimizedScopeStorage.swift`

### Changed
- **UnifiedDI 내부 최적화 통합**
- 기존 API 유지하면서 내부적으로 최적화 경로 적용
- `enableOptimization()` / `disableOptimization()`으로 최적화 모드 제어
- 기존 동작과 100% 호환성 보장

- **성능 개선**
- resolve 경로에서 딕셔너리 탐색 → 배열 인덱스 접근으로 전환
- 읽기 경합 제거로 멀티스레드 환경에서 처리량 향상
- 싱글톤 초기화 once 보장으로 경합 조건 제거

### Performance
- 핫패스 해결 성능 **50-80%** 향상 (예상)
- 멀티스레드 읽기 처리량 **2-3배** 개선 (예상)
- 메모리 접근 패턴 최적화로 캐시 히트율 향상


## [3.0.0] - 2025-09-25

### Breaking
- AutoDIOptimizer 읽기 API 일원화 및 표면 축소
- AutoDIOptimizer의 다수 읽기용 nonisolated(static) API를 내부화(internal) 또는 Deprecated로 전환했습니다.
- 외부에서는 UnifiedDI/DIContainer의 동기 헬퍼(스냅샷 기반)만 사용하세요.
- 내부 동작(자동 수집/최적화)은 동일하며, 공용 읽기 경로만 통일되었습니다.
- AutoMonitor 동일 글로벌 액터로 정렬
- AutoMonitor를 @DIActor로 통일하여 내부 hop을 제거했습니다. 외부 API 시그니처는 동일합니다.

### Added
- Benchmarks 실행 타깃 추가(간단 벤치 템플릿)
- Target: Benchmarks (swift run -c release Benchmarks)
- 인자: --count 10k/100k/1M, --debounce 50/100/200, --quick
- p50/p95/p99 및 total(ms) 출력
- DocC/README 문서 보강
- Bootstrap 가이드 추가(동기/비동기/혼합/조건부/보장/테스트)
- Deprecated 읽기 API → 대체 경로 표 추가
- 디바운스 설정 노출
- UnifiedDI.configureOptimization(debounceMs:)로 AutoDIOptimizer 디바운스 간격 제어(50~1000ms)

### Changed
- 읽기 경로 완전 일원화(스냅샷 기반 동기 반환)
- UnifiedDI/DIContainer에서 autoGraph/optimizedTypes/circularDependencies/stats/isOptimized가 스냅샷에서 즉시 반환되도록 간소화
- 핫패스 fire-and-forget
- register/resolve 추적은 비차단 전송(Task { @DIActor in ... })으로 전환 → p95/p99 지연 개선에 유리
- 스냅샷/그래프 갱신 디바운스(기본 100ms)
- 대량 호출 시 CPU/로그 부하 감소
- 로깅 레벨 설정 일관성 개선
- UnifiedDI.setLogLevel은 먼저 스냅샷을 즉시 갱신 후 액터에 위임(테스트/동기 읽기 일관성 향상)

### Removed
- DocC의 미사용/구 문서 제거
- BootstrapRationale.md, BootstrapSystem.md, DocumentationStandards.md 삭제
- 플러그인 시스템 관련 톱페이지 섹션 제거(기능 비노출)

### Fixed
- “No 'async' operations occur within 'await' expression” 경고 제거(비동기 경로 정리, fire-and-forget 조정)
- 테스트 안정성 개선
- 스냅샷 반영 대기를 폴링(waitUntil/waitAsyncUntil)으로 통일
- 전체 테스트 통과 확인

### [2.3.0] - 2025-09-25

### Breaking
- DIContainer 동기화 변경
- DIContainer.getAutoGeneratedGraph(), getOptimizedTypes(), getDetectedCircularDependencies(), getUsageStatistics(), isAutoOptimized(_:)가 동기 함수로 변경됨. 호출부의 await 제거 필요. 파일: Sources/Core/Container/DIContainer.swift:536
- UnifiedDI 동기화 변경
- UnifiedDI.autoGraph(), optimizedTypes(), circularDependencies(), stats(), isOptimized(_:)가 동기 함수로 변경됨. 호출부의 await 제거 필요. 파일: Sources/Core/API/UnifiedDI.swift:318

### Added
- 동기 접근용 로깅 레벨 프로퍼티 추가: UnifiedDI.logLevel. 파일: Sources/Core/API/UnifiedDI.swift:393
- 그래프 시각화에 “등록된 노드(타입)” 출력 추가. 파일: Sources/Core/Auto/AutoDIOptimizer.swift:270

### Changed
- AutoDIOptimizer 스레드 안전화
- NSLock 기반 내부 상태 보호 및 스냅샷 접근 도입(등록/해결/그래프/통계/순환 탐지). 파일: Sources/Core/Auto/AutoDIOptimizer.swift:31
- getCurrentLogLevel()이 실제 설정 값을 반환하도록 수정. 파일: Sources/Core/Auto/AutoDIOptimizer.swift:100
- trackResolution(_:)가 최적화 비활성화 상태에서도 사용 통계를 항상 집계하도록 변경(최적화 제안만 비활성화). 파일: Sources/Core/Auto/AutoDIOptimizer.swift:63

### Fixed
- 동시성 접근 시 간헐적 크래시(EXC_BAD_ACCESS) 해결: AutoDIOptimizer 내부 데이터 경쟁 제거. 파일: Sources/Core/Auto/AutoDIOptimizer.swift
- “No 'async' operations occur within 'await' expression” 경고 제거: 동기 함수로 시그니처 정리. 파일: Sources/Core/Container/DIContainer.swift:536, Sources/Core/API/UnifiedDI.swift:318
- “Result of call to 'registerIf' is unused” 경고 제거: @discardableResult 추가. 파일: Sources/Core/API/UnifiedDI.swift:302

## [2.2.0] - 2025-09-24

### Added
- Visualizer 비동기 API 추가: generateDOTGraphAsync / generateMermaidGraphAsync / generateASCIIGraphAsync / generateJSONGraphAsync
- 실시간 그래프 업데이트 토글 API: AutoDIOptimizer.shared.setRealtimeGraphEnabled(Bool) (기본 true)
- 프리웜 보조: AutoDIOptimizer.topUsedTypes(limit:) 추가

### Changed
- Visualizer 완전 async 전환: exportGraph는 내부 브리지로 async API 호출
- 문서(CoreAPIs.md) 예제를 async 기반으로 갱신
- UnifiedRegistry 완전 async 해석으로 전환; 내부 순환탐지 기록을 await로 직접 호출하여 오버헤드 제거
- @unchecked Sendable 최소화: ValueBox를 Sendable(value: any Sendable)로 변경, 제네릭 제약(where T: Sendable) 정비
- 실시간 그래프 업데이트 동작: off 시 실시간 동기화 중지, on 시 즉시 1회 동기화 후 100ms 디바운스로 재개
- 그래프 업데이트 최적화: updateGraph를 diff 기반(추가/제거 엣지) + 100ms 디바운스로 성능 개선

### Removed
- Visualizer 동기 생성 API 제거 (메이저 변경)
- UnifiedRegistry 동기 해석 API 제거(메이저): resolve(:) / resolveAny(:) / resolveAnyBox(_:) / resolve(keyPath:)

## [2.1.0] - 2024-09-24

### Added
- AutoDIOptimizer: 자동 의존성 그래프 생성 및 성능 최적화 시스템
- 자동 사용 통계 수집 및 백그라운드 최적화 (30초 주기)
- 자동 순환 의존성 감지 및 LogMacro 통합 로깅
- Swift DocC 문서 업데이트 (AutoDIOptimizer.md 추가)

### Changed
- 핵심 3개 PropertyWrapper로 단순화: @Inject, @Factory, @SafeInject
- DIContainer 통합: WeaveDI.Container + Container → DIContainer
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
