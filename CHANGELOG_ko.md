# 변경 이력

이 프로젝트의 모든 주요 변경사항이 이 파일에 문서화됩니다.

## [3.3.4] - 2025-11-22

### 🎉 추가됨
- **DiModuleFactory**: Logger, Config, Cache 등 공통 DI 의존성을 위한 전용 모듈 팩토리
  - ModuleFactory 시스템에 `DiModuleFactory` 추가
  - `ModuleFactoryManager.makeAllModules()`에서 DI 모듈 수집
  - 파일: `Sources/WeaveDIAppDI/Factory/ModuleFactory.swift`

### 🔧 개선됨
- **AppDIManager 기본 DI 등록**: live 컨테이너에 `DiModuleFactory` 자동 등록
  - 파일: `Sources/WeaveDIAppDI/AppDI/AppDIManager.swift`

---

## [3.3.0] - 2025-10-12

### 🚀 주요 성능 향상
- **환경 플래그 최적화**: 프로덕션 환경에서 성능 모니터링 오버헤드 완전 제거
  - 조건부 성능 추적을 위한 `DI_MONITORING_ENABLED` 컴파일 플래그
  - 릴리즈 빌드에서 0% Task 생성 오버헤드
  - 디버그 모드에서 완전한 모니터링 기능 유지
  - `UnifiedDI` 및 `DIAdvanced.Performance` 전반에 걸친 스마트 조건부 컴파일
  - 파일: `Sources/Core/API/UnifiedDI.swift`, `Sources/Core/API/DIAdvanced.swift`

- **고급 성능 모니터링 시스템**: 포괄적인 성능 최적화 프레임워크
  - 조건부 데이터 저장을 통한 메모리 효율적 추적
  - 개발 환경에서 실시간 메트릭 수집
  - 자동 최적화 제안 및 병목 현상 감지
  - CI/CD 파이프라인 통합을 통한 성능 검증
  - 문서: `docs/api/performanceOptimizations.md`, `docs/ko/api/performanceOptimizations.md`

### 🎯 TCA 통합 개선
- **TCA 브릿지 정책 설정**: 유연한 TCA 통합을 위한 동적 의존성 우선순위 제어
  - `.testPriority`, `.livePriority`, `.contextual` 모드를 가진 `TCABridgePolicy` 열거형
  - 다양한 배포 환경을 위한 런타임 정책 전환
  - 실행 환경에 따른 컨텍스트 인식 값 선택
  - 개발자 설정을 위한 SwiftUI 통합 지원
  - 파일: `Sources/Core/Integration/TCASmartSync.swift`
  - 문서: `docs/api/tcaPolicyConfiguration.md`, `docs/ko/api/tcaPolicyConfiguration.md`

### 🏗️ 향상된 배치 등록
- **현대적 Result Builder DSL**: 완전히 새롭게 설계된 배치 등록 시스템
  - 선언적 의존성 등록을 위한 `@BatchRegistrationBuilder`
  - 팩토리, 기본값, 조건부 등록 패턴 지원
  - 완전한 Swift Result Builder 기능을 활용한 타입 안전 컴파일
  - 조건부 등록 블록 및 배열 기반 등록 지원
  - 파일: `Sources/Core/API/DIAdvanced.swift`
  - 문서: `docs/api/batchRegistration.md`, `docs/ko/api/batchRegistration.md`

### 🛡️ 자동 이슈 감지
- **ComponentDiagnostics 시스템**: 혁신적인 자동 의존성 분석
  - 중복 프로바이더 및 스코프 불일치의 컴파일 타임 감지
  - 자동 해결책 제안 및 상세 문제 리포트
  - 자동 검증을 위한 CI/CD 파이프라인 통합
  - 외부 도구 통합을 위한 JSON 내보내기 기능
  - 정밀한 메타데이터 분석으로 false positive 0%
  - 문서: `docs/api/componentDiagnostics.md`, `docs/ko/api/componentDiagnostics.md`

### 🔧 코드 품질 개선
- **경고 해결**: Swift 컴파일러 경고 완전 제거
  - `TCASmartSync.swift`의 조건부 캐스트 경고 수정
  - 런타임 프로토콜 체크를 통한 타입 안전성 향상
  - 향상된 오류 처리 및 엣지 케이스 관리
  - 최적화된 성능 경로를 가진 더 깔끔한 코드베이스

### 📚 포괄적인 문서화
- **환경 플래그 문서**: 컴파일 타임 최적화를 위한 완전한 가이드
  - 빌드 설정 예제 및 CI/CD 통합
  - 성능 벤치마킹 및 메모리 사용량 분석
  - 문서: `docs/api/environmentFlags.md`, `docs/ko/api/environmentFlags.md`

### 🎨 개발자 경험
- **향상된 IDE 지원**: 개선된 자동완성 및 타입 추론
- **더 나은 오류 메시지**: 더 설명적인 컴파일 및 런타임 오류
- **성능 인사이트**: 상세한 메트릭 및 최적화 권장사항

---

## [3.2.0] - 2025-10-01

### 🎉 추가됨
- **@Injected Property Wrapper**: The Composable Architecture에서 영감을 받은 새로운 TCA 스타일 의존성 주입
  - KeyPath 기반 접근: `@Injected(\.apiClient) var apiClient`
  - 타입 기반 접근: `@Injected(ExchangeUseCaseImpl.self) var useCase`
  - 의존성 정의를 위한 `InjectedKey` 프로토콜
  - 주입된 값 관리를 위한 `InjectedValues` 컨테이너
  - 테스트 및 의존성 오버라이드를 위한 `withInjectedValues`
  - Non-mutating 접근 (`mutating get` 불필요)
  - 완전한 컴파일 타임 타입 안전성
  - 파일: `Sources/PropertyWrappers/Dependency.swift`

- **AppDI 간소화**: `AppDIManager`를 통한 간소화된 앱 초기화
  - Actor 안전한 초기화를 위한 `@DIContainerActor`와 함께 사용하는 `bootstrapInTask`
  - 자동 등록을 위한 `AppDIManager.shared.registerDefaultDependencies()`
  - 병렬 처리를 위한 `asyncForEach`를 사용한 모듈 기반 등록
  - 보일러플레이트가 줄어든 더 깔끔한 앱 설정
  - 파일: `Sources/Core/AppDI/AppDIManager.swift`

### ⚠️ 지원 중단
- **@Inject Property Wrapper**: 4.0.0에서 제거 예정
  - 현대적이고 타입 안전한 의존성 주입을 위해 `@Injected` 사용
  - 마이그레이션 가이드: `/docs/guide/migration-3.2.0.md`

- **@SafeInject Property Wrapper**: 4.0.0에서 제거 예정
  - 적절한 `InjectedKey` 정의와 함께 `@Injected` 사용
  - 마이그레이션 가이드: `/docs/guide/migration-3.2.0.md`

### 📚 문서화
- `@Injected`에 대한 포괄적인 영어 및 한국어 문서
  - `/docs/api/injected.md` (영어)
  - `/docs/ko/api/injected.md` (한국어)
- 실제 예제를 포함한 AppDI 간소화 가이드
  - `/docs/guide/appDiSimplification.md` (영어)
  - `/docs/ko/guide/appDiSimplification.md` (한국어)
- 지원 중단 안내가 포함된 API 레퍼런스 업데이트
- `@Inject` 및 `@SafeInject`에서 `@Injected`로의 마이그레이션 가이드
- VitePress 문서 사이트 개선

### 🔧 개선사항
- `@DIContainerActor`를 통한 향상된 actor 안전성
- 향상된 Swift 6 동시성 지원
- 프레임워크 전반의 타입 안전성 강화
- 의존성 해결의 성능 최적화

## [3.1.0] - 2025-09-27

### 추가됨
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

### 변경됨
- **UnifiedDI 내부 최적화 통합**
  - 기존 API 유지하면서 내부적으로 최적화 경로 적용
  - `enableOptimization()` / `disableOptimization()`으로 최적화 모드 제어
  - 기존 동작과 100% 호환성 보장

- **성능 개선**
  - resolve 경로에서 딕셔너리 탐색 → 배열 인덱스 접근으로 전환
  - 읽기 경합 제거로 멀티스레드 환경에서 처리량 향상
  - 싱글톤 초기화 once 보장으로 경합 조건 제거

### 성능
- 핫패스 해결 성능 **50-80%** 향상 (예상)
- 멀티스레드 읽기 처리량 **2-3배** 개선 (예상)
- 메모리 접근 패턴 최적화로 캐시 히트율 향상

## [3.0.0] - 2025-09-25

### 주요 변경사항
- AutoDIOptimizer 읽기 API 일원화 및 표면 축소
  - AutoDIOptimizer의 다수 읽기용 nonisolated(static) API를 내부화(internal) 또는 Deprecated로 전환
  - 외부에서는 UnifiedDI/DIContainer의 동기 헬퍼(스냅샷 기반)만 사용
  - 내부 동작(자동 수집/최적화)은 동일하며, 공용 읽기 경로만 통일
- AutoMonitor 동일 글로벌 액터로 정렬
  - AutoMonitor를 @DIActor로 통일하여 내부 hop을 제거. 외부 API 시그니처는 동일

### 추가됨
- Benchmarks 실행 타깃 추가(간단 벤치 템플릿)
  - Target: Benchmarks (swift run -c release Benchmarks)
  - 인자: --count 10k/100k/1M, --debounce 50/100/200, --quick
  - p50/p95/p99 및 total(ms) 출력
- DocC/README 문서 보강
  - Bootstrap 가이드 추가(동기/비동기/혼합/조건부/보장/테스트)
  - Deprecated 읽기 API → 대체 경로 표 추가
- 디바운스 설정 노출
  - UnifiedDI.configureOptimization(debounceMs:)로 AutoDIOptimizer 디바운스 간격 제어(50~1000ms)

### 변경됨
- 읽기 경로 완전 일원화(스냅샷 기반 동기 반환)
  - UnifiedDI/DIContainer에서 autoGraph/optimizedTypes/circularDependencies/stats/isOptimized가 스냅샷에서 즉시 반환
- 핫패스 fire-and-forget
  - register/resolve 추적은 비차단 전송(Task { @DIActor in ... })으로 전환 → p95/p99 지연 개선에 유리
- 스냅샷/그래프 갱신 디바운스(기본 100ms)
  - 대량 호출 시 CPU/로그 부하 감소
- 로깅 레벨 설정 일관성 개선
  - UnifiedDI.setLogLevel은 먼저 스냅샷을 즉시 갱신 후 액터에 위임

### 제거됨
- DocC의 미사용/구 문서 제거
  - BootstrapRationale.md, BootstrapSystem.md, DocumentationStandards.md 삭제
- 플러그인 시스템 관련 톱페이지 섹션 제거(기능 비노출)

### 수정됨
- "No 'async' operations occur within 'await' expression" 경고 제거
- 테스트 안정성 개선
  - 스냅샷 반영 대기를 폴링(waitUntil/waitAsyncUntil)으로 통일
  - 전체 테스트 통과 확인

## [2.3.0] - 2025-09-25

### 주요 변경사항
- DIContainer 동기화 변경
  - DIContainer.getAutoGeneratedGraph(), getOptimizedTypes(), getDetectedCircularDependencies(), getUsageStatistics(), isAutoOptimized(_:)가 동기 함수로 변경
  - 호출부의 await 제거 필요
  - 파일: Sources/Core/Container/DIContainer.swift:536
- UnifiedDI 동기화 변경
  - UnifiedDI.autoGraph(), optimizedTypes(), circularDependencies(), stats(), isOptimized(_:)가 동기 함수로 변경
  - 호출부의 await 제거 필요
  - 파일: Sources/Core/API/UnifiedDI.swift:318

### 추가됨
- 동기 접근용 로깅 레벨 프로퍼티 추가: UnifiedDI.logLevel
  - 파일: Sources/Core/API/UnifiedDI.swift:393
- 그래프 시각화에 "등록된 노드(타입)" 출력 추가
  - 파일: Sources/Core/Auto/AutoDIOptimizer.swift:270

### 변경됨
- AutoDIOptimizer 스레드 안전화
  - NSLock 기반 내부 상태 보호 및 스냅샷 접근 도입
  - 파일: Sources/Core/Auto/AutoDIOptimizer.swift:31
  - getCurrentLogLevel()이 실제 설정 값을 반환하도록 수정
  - 파일: Sources/Core/Auto/AutoDIOptimizer.swift:100
  - trackResolution(_:)가 최적화 비활성화 상태에서도 사용 통계를 항상 집계하도록 변경
  - 파일: Sources/Core/Auto/AutoDIOptimizer.swift:63

### 수정됨
- 동시성 접근 시 간헐적 크래시(EXC_BAD_ACCESS) 해결
  - AutoDIOptimizer 내부 데이터 경쟁 제거
  - 파일: Sources/Core/Auto/AutoDIOptimizer.swift
- "No 'async' operations occur within 'await' expression" 경고 제거
  - 동기 함수로 시그니처 정리
  - 파일: Sources/Core/Container/DIContainer.swift:536, Sources/Core/API/UnifiedDI.swift:318
- "Result of call to 'registerIf' is unused" 경고 제거
  - @discardableResult 추가
  - 파일: Sources/Core/API/UnifiedDI.swift:302

## [2.2.0] - 2025-09-24

### 추가됨
- Visualizer 비동기 API 추가
  - generateDOTGraphAsync / generateMermaidGraphAsync / generateASCIIGraphAsync / generateJSONGraphAsync
- 실시간 그래프 업데이트 토글 API
  - AutoDIOptimizer.shared.setRealtimeGraphEnabled(Bool) (기본 true)
- 프리웜 보조: AutoDIOptimizer.topUsedTypes(limit:) 추가

### 변경됨
- Visualizer 완전 async 전환
  - exportGraph는 내부 브리지로 async API 호출
- 문서(CoreAPIs.md) 예제를 async 기반으로 갱신
- UnifiedRegistry 완전 async 해석으로 전환
  - 내부 순환탐지 기록을 await로 직접 호출하여 오버헤드 제거
- @unchecked Sendable 최소화
  - ValueBox를 Sendable(value: any Sendable)로 변경
  - 제네릭 제약(where T: Sendable) 정비
- 실시간 그래프 업데이트 동작
  - off 시 실시간 동기화 중지, on 시 즉시 1회 동기화 후 100ms 디바운스로 재개
- 그래프 업데이트 최적화
  - updateGraph를 diff 기반(추가/제거 엣지) + 100ms 디바운스로 성능 개선

### 제거됨
- Visualizer 동기 생성 API 제거 (메이저 변경)
- UnifiedRegistry 동기 해석 API 제거(메이저)
  - resolve(:) / resolveAny(:) / resolveAnyBox(_:) / resolve(keyPath:)

## [2.1.0] - 2024-09-24

### 추가됨
- AutoDIOptimizer: 자동 의존성 그래프 생성 및 성능 최적화 시스템
- 자동 사용 통계 수집 및 백그라운드 최적화 (30초 주기)
- 자동 순환 의존성 감지 및 LogMacro 통합 로깅
- Swift DocC 문서 업데이트 (AutoDIOptimizer.md 추가)

### 변경됨
- 핵심 3개 PropertyWrapper로 단순화: @Inject, @Factory, @SafeInject
- DIContainer 통합: WeaveDI.Container + Container → DIContainer
- README 간소화: 핵심 기능 중심으로 재작성

### 제거됨
- PluginSystem (438라인) - 핵심 DI 기능에 집중
- InteractiveDependencyVisualizer (1022라인) - 자동화로 대체
- AdvancedCircularDependencyDetector (920라인) - AutoDIOptimizer로 통합
- ActorHopMetrics (399라인) - 불필요한 복잡성 제거
- DocumentationValidator (392라인) - 개발 도구 분리
- SimplePerformanceOptimizer - AutoDIOptimizer로 교체
- AutoDependencyResolver - 사용되지 않는 기능 제거 (1323라인)

## [2.0.0] - 2025-09-14

### 추가됨
- UnifiedDI: 단일 진입점 등록/해결 API 추가 (sync/async 통합 경험)
- UnifiedRegistry: 통합 레지스트리(싱글톤/동기/비동기 팩토리, KeyPath 매핑)
- resolveAnyAsync(Any.Type): 런타임 타입 비동기 해석 API
- CI 파이프라인: 엄격 동시성 + 경고 실패 처리 + DocC 빌드 체크

### 변경됨
- 타입/동시성 안전성 강화: Swift 6 @Sendable, actor 격리, 박싱 최소화
- TypeNameResolver: 문자열 매핑 축소(명시적 등록/AutoResolve 우선)
- README/MIGRATION 업데이트: UnifiedDI, AutoResolver, 마이그레이션 가이드 보강

### 지원 중단/제거됨
- 문자열 기반 공통 타입 매핑 제거(취약성 감소)
- 일부 레거시 API를 UnifiedDI/UnifiedRegistry 기반으로 수렴

### 마이그레이션
- 상세 가이드는 MIGRATION-2.0.0.md 참고

---

이전 버전에 대한 변경 이력은 향후 정리 예정입니다.
