---
title: UnifiedDI
lang: ko-KR
---

# UnifiedDI

## 개요
`UnifiedDI`는 현대적이고 직관적인 의존성 주입 API입니다.
복잡한 기능들을 제거하고 핵심 기능에만 집중하여 이해하기 쉽고 사용하기 간편합니다.
## 설계 철학
- **단순함이 최고**: 복잡한 기능보다 명확한 API
- **타입 안전성**: 컴파일 타임에 모든 오류 검증
- **직관적 사용**: 코드만 봐도 이해할 수 있는 API
## 기본 사용법
```swift
// 1. 등록하고 즉시 사용
let repository = UnifiedDI.register(UserRepository.self) {
    UserRepositoryImpl()
}
// 2. 나중에 조회
let service = UnifiedDI.resolve(UserService.self)
// 3. 필수 의존성 (실패 시 크래시)
let logger = UnifiedDI.requireResolve(Logger.self)
```

```swift
public enum UnifiedDI {
}
```

  /// 의존성을 등록하고 즉시 생성된 인스턴스를 반환합니다 (권장 방식)
  /// 가장 직관적인 의존성 등록 방법입니다.
  /// 팩토리를 즉시 실행하여 인스턴스를 생성하고, 컨테이너에 등록한 후 반환합니다.
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - factory: 인스턴스를 생성하는 클로저
  /// - Returns: 생성된 인스턴스
  /// ### 사용 예시:
  /// ```swift
  /// let repository = UnifiedDI.register(UserRepository.self) {
  ///     UserRepositoryImpl()
  /// }
  /// // repository를 바로 사용 가능
  /// ```
  /// DIContainerActor를 사용한 비동기 의존성 등록 (권장)
  /// @DIContainerActor 기반의 thread-safe한 의존성 등록을 제공합니다.
  /// DIContainer.registerAsync와 같은 방식으로 동작합니다.
  /// ### 사용 예시:
  /// ```swift
  /// Task {
  ///     let instance = await UnifiedDI.registerAsync(UserService.self) {
  ///         UserServiceImpl()
  ///     }
  ///     // instance를 바로 사용 가능
  /// }
  /// ```
  /// KeyPath를 사용한 타입 안전한 등록 (UnifiedDI.register(\.keyPath) 스타일)
  /// WeaveDI.Container의 KeyPath를 사용하여 더욱 타입 안전하게 등록합니다.
  /// ### 사용 예시:
  /// ```swift
  /// let repository = UnifiedDI.register(\.productInterface) {
  ///     ProductRepositoryImpl()
  /// }
  /// ```
  /// 등록된 의존성을 조회합니다 (안전한 방법)
  /// 의존성이 등록되지 않은 경우 nil을 반환하므로 크래시 없이 안전하게 처리할 수 있습니다.
  /// 권장하는 안전한 의존성 해결 방법입니다.
  /// - Parameter type: 조회할 타입
  /// - Returns: 해결된 인스턴스 (없으면 nil)
  /// ### 사용 예시:
  /// ```swift
  /// if let service = UnifiedDI.resolve(UserService.self) {
  ///     // 서비스 사용
  /// } else {
  ///     // 대체 로직 수행
  /// }
  /// ```
  /// KeyPath를 사용하여 의존성을 조회합니다
  /// - Parameter keyPath: WeaveDI.Container 내의 KeyPath
  /// - Returns: 해결된 인스턴스 (없으면 nil)
  /// DIContainerActor를 사용한 비동기 의존성 조회 (권장)
  /// @DIContainerActor 기반의 thread-safe한 의존성 해결을 제공합니다.
  /// DIContainer.resolveAsync와 같은 방식으로 동작합니다.
  /// ### 사용 예시:
  /// ```swift
  /// Task {
  ///     if let service = await UnifiedDI.resolveAsync(UserService.self) {
  ///         // 서비스 사용
  ///     }
  /// }
  /// ```
  /// DIContainerActor를 사용한 필수 의존성 조회 (실패 시 nil 반환)
  /// 반드시 등록되어 있어야 하는 의존성을 비동기적으로 조회합니다.
  /// DIContainer.resolveAsync와 같은 방식으로 동작하며, 실패시 nil을 반환합니다.
  /// ### 사용 예시:
  /// ```swift
  /// Task {
  ///     if let service = await UnifiedDI.requireResolveAsync(UserService.self) {
  ///         // 서비스 사용
  ///     }
  /// }
  /// ```
  /// 필수 의존성을 조회합니다 (실패 시 명확한 에러 메시지와 함께 크래시)
  /// 반드시 등록되어 있어야 하는 의존성을 조회할 때 사용합니다.
  /// 등록되지 않은 경우 개발자 친화적인 에러 메시지와 함께 앱이 종료됩니다.
  /// - Parameter type: 조회할 타입
  /// - Returns: 해결된 인스턴스 (항상 성공)
  /// ### ⚠️ 주의사항:
  /// 프로덕션 환경에서는 `resolve(_:)` 사용을 권장합니다.
  /// ### 사용 예시:
  /// ```swift
  /// let logger = UnifiedDI.requireResolve(Logger.self)
  /// // logger는 항상 유효한 인스턴스
  /// ```
  /// 의존성을 조회하거나 기본값을 반환합니다 (항상 성공)
  /// 의존성이 없어도 항상 성공하는 안전한 해결 방법입니다.
  /// 기본 구현체나 Mock 객체를 제공할 때 유용합니다.
  /// - Parameters:
  ///   - type: 조회할 타입
  ///   - defaultValue: 해결 실패 시 사용할 기본값
  /// - Returns: 해결된 인스턴스 또는 기본값
  /// ### 사용 예시:
  /// ```swift
  /// let logger = UnifiedDI.resolve(Logger.self, default: ConsoleLogger())
  /// // logger는 항상 유효한 인스턴스
  /// ```
  /// 등록된 의존성을 해제합니다
  /// 특정 타입의 의존성을 컨테이너에서 제거합니다.
  /// 주로 테스트나 메모리 정리 시 사용합니다.
  /// - Parameter type: 해제할 타입
  /// ### 사용 예시:
  /// ```swift
  /// UnifiedDI.release(UserService.self)
  /// // 이후 resolve 시 nil 반환
  /// ```
  /// 모든 등록된 의존성을 해제합니다 (테스트용)
  /// 주로 테스트 환경에서 각 테스트 간 격리를 위해 사용합니다.
  /// 프로덕션에서는 사용을 권장하지 않습니다.
  /// ### ⚠️ 주의사항:
  /// 메인 스레드에서만 호출해야 합니다.
  /// ### 사용 예시:
  /// ```swift
  /// // 테스트 setUp에서
  /// override func setUp() {
  ///     super.setUp()
  ///     UnifiedDI.releaseAll()
  /// }
  /// ```
고급 기능들을 위한 네임스페이스
일반적인 사용에서는 필요하지 않은 고급 기능들을 별도로 분리했습니다.
설계 철학에 따라 핵심 기능과 분리하여 복잡도를 줄였습니다.

```swift
public extension UnifiedDI {
}
```

  /// 조건부 등록을 위한 네임스페이스
    /// 조건에 따라 다른 구현체를 등록합니다
    /// - Parameters:
    ///   - type: 등록할 타입
    ///   - condition: 등록 조건
    ///   - factory: 조건이 true일 때 사용할 팩토리
    ///   - fallback: 조건이 false일 때 사용할 팩토리
    /// - Returns: 생성된 인스턴스
자동 의존성 주입 기능 확장

```swift
public extension UnifiedDI {
}
```

  /// 🚀 자동 생성된 의존성 그래프를 시각화합니다
  /// 별도 설정 없이 자동으로 수집된 의존성 관계를 확인할 수 있습니다.
  /// ### 사용 예시:
  /// ```swift
  /// // 현재까지 자동 수집된 의존성 그래프 출력
  /// print(UnifiedDI.autoGraph)
  /// ```
  /// ⚡ 자동 최적화된 타입들을 반환합니다
  /// 사용 패턴을 분석하여 자동으로 성능 최적화가 적용된 타입들입니다.
  /// ⚠️ 자동 감지된 순환 의존성을 반환합니다
  /// 의존성 등록/해결 과정에서 자동으로 감지된 순환 의존성입니다.
  /// 📊 자동 수집된 성능 통계를 반환합니다
  /// 각 타입의 사용 빈도가 자동으로 추적됩니다.
  /// 🔍 특정 타입이 자동 최적화되었는지 확인합니다
  /// - Parameter type: 확인할 타입
  /// - Returns: 최적화 여부
  /// ⚙️ 자동 최적화 기능을 제어합니다
  /// - Parameter enabled: 활성화 여부 (기본값: true)
  /// 🧹 자동 수집된 통계를 초기화합니다
  /// 📋 자동 로깅 레벨을 설정합니다
  /// - Parameter level: 로깅 레벨
  ///   - `.all`: 모든 로그 출력 (기본값)
  ///   - `.registration`: 등록만 로깅
  ///   - `.optimization`: 최적화만 로깅
  ///   - `.errors`: 에러만 로깅
  ///   - `.off`: 로깅 끄기
  /// 📋 현재 로깅 레벨을 반환합니다 (스냅샷)
  /// 현재 로깅 레벨(동기 접근용, 스냅샷)
  /// 🎯 자동 Actor 최적화 제안 (스냅샷 기반 간단 규칙)
  /// 🔒 자동 감지된 타입 안전성 이슈 (간단 규칙)
  /// 🛠️ 자동으로 수정된 타입들 (상위 사용 빈도 기준 예시)
  /// ⚡ Actor hop 통계 (간단 규칙: 이름에 Actor 포함)
  /// 📊 비동기 성능 통계 (간단 규칙: 이름에 async/Async 포함)
  /// 최적화 설정을 간편하게 조정합니다
  /// - Parameters:
  ///   - debounceMs: 디바운스 간격 (50-500ms, 기본값: 100ms)
  ///   - threshold: 자주 사용되는 타입 임계값 (5-100회, 기본값: 10회)
  ///   - realTimeUpdate: 실시간 그래프 업데이트 여부 (기본값: true)
  /// 그래프 변경 히스토리를 가져옵니다
  /// - Parameter limit: 최대 반환 개수 (기본값: 10)
  /// - Returns: 최근 변경 히스토리

```swift
public extension UnifiedDI {
  /// 📊 현재 등록된 모든 모듈 보기 (최적화 정보 포함)
  static func showModules() async {
    await AutoDIOptimizer.shared.showAll()
  }
}
```

  /// 📈 간단한 요약 정보
  /// 🔗 특정 모듈의 의존성 보기
  /// ⚡ 최적화 제안 보기
  /// 📊 자주 사용되는 타입 TOP 5
  /// 🔧 최적화 기능 켜기/끄기
  /// 🧹 모니터링 초기화
  /// 테스트 전용: 비동기 등록 완료 대기
  /// 비동기 등록 후 호출하여 등록이 완료될 때까지 대기합니다.
  /// Task.yield()를 사용하여 가벼운 대기를 수행합니다.
  /// ### 사용 예시:
  /// ```swift
  /// func testAsyncRegistration() async {
  ///     _ = UnifiedDI.register(UserService.self) { UserServiceImpl() }
  ///     await UnifiedDI.waitForRegistration()
  ///     let service = UnifiedDI.resolve(UserService.self)
  ///     XCTAssertNotNil(service)
  /// }
  /// ```
Compile-time dependency graph verification macro
Detects circular dependencies and validates dependency relationships at compile time
Usage:
```swift
@DependencyGraph([
    UserService.self: [NetworkService.self, Logger.self],
    NetworkService.self: [Logger.self]
])
extension WeaveDI {}
```

```swift
public macro DependencyGraph<T>(_ dependencies: T) = #externalMacro(module: "WeaveDIMacros", type: "DependencyGraphMacro")
}
```

Static factory generation for zero-cost dependency resolution
Compiles dependencies into static methods for maximum performance
  /// Configure static factory optimization
  /// Enables compile-time dependency resolution like Needle
  /// Static resolve with compile-time optimization
  /// Zero runtime cost when USE_STATIC_FACTORY is enabled
  /// Internal static factory resolver (compile-time optimized)
  /// Compare performance with Needle
Migration tools for developers moving from Uber's Needle framework
  /// Migration guide and helper for Needle users
  /// Check if migration is beneficial
  /// Validate Needle-style dependency setup
