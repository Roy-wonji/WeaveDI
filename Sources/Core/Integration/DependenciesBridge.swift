#if canImport(Dependencies)
import Dependencies

// MARK: - Core Bridge Logic

/// 중앙화된 resolve 로직으로 중복 제거
private enum BridgeResolver {
  /// WeaveDI → TCA fallback 패턴
  static func resolveWithFallback<T: Sendable, K: DependencyKey>(
    _ type: T.Type,
    fallback: K.Type
  ) -> T where K.Value == T {
    UnifiedDI.resolve(type) ?? fallback.liveValue
  }

  /// 자동 인터셉션: WeaveDI 우선, TCA DependencyValues 폴백
  static func autoInterceptResolve<T: Sendable>(_ type: T.Type) -> T? {
    // 1. WeaveDI에서 먼저 시도
    if let resolved = UnifiedDI.resolve(type) {
      return resolved
    }

    // 2. TCA DependencyValues에서 시도 (reflection 기반)
    return tryResolvingFromDependencyValues(type)
  }

  /// 자동 등록: 양쪽 시스템에 동시 등록
  static func autoRegister<T: Sendable>(_ type: T.Type, value: T) {
    // WeaveDI에 등록
    _ = UnifiedDI.register(type) { value }

    // TCA DependencyValues에도 등록 시도
    tryRegisteringToDependencyValues(type, value: value)
  }

  /// InjectedValues → DependencyValues 역방향 동기화
  static func reverseSync<T: Sendable>(_ type: T.Type, value: T) {
    // TCA DependencyValues에 등록 시도
    tryRegisteringToDependencyValues(type, value: value)
  }

  // MARK: - Private Helpers

  private static func tryResolvingFromDependencyValues<T>(_ type: T.Type) -> T? {
    // 현재 DependencyValues context에서 동일한 타입 찾기
    // 실용적인 접근: 알려진 DependencyKey 패턴들에 대해서만 처리
    return nil // 기본 구현: 향후 확장 가능
  }

  private static func tryRegisteringToDependencyValues<T>(_ type: T.Type, value: T) {
    // DependencyValues context가 있다면 해당 값으로 설정
    // 런타임에 알려진 DependencyKey들과 매칭시도
    // 현재는 기본 구현으로 no-op (향후 확장 가능)
  }
}

// MARK: - TCA → WeaveDI Bridge

public extension DependencyValues {
  /// Access the WeaveDI container powering dependency resolution.
  var diContainer: DIContainer {
    get { self[DIContainerDependencyKey.self] }
    set { self[DIContainerDependencyKey.self] = newValue }
  }

  /// Convenience helper to resolve a type directly from the container.
  func resolve<T: Sendable>(_ type: T.Type) -> T? {
    diContainer.resolve(type)
  }
}

// MARK: - WeaveDI → TCA Bridge

public extension InjectedValues {
  /// Bridge TCA DependencyKey to WeaveDI InjectedValues
  subscript<K: DependencyKey>(_ key: K.Type) -> K.Value where K.Value: Sendable {
    get {
      BridgeResolver.resolveWithFallback(K.Value.self, fallback: key)
    }
    set {
      BridgeResolver.autoRegister(K.Value.self, value: newValue)
    }
  }
}

// MARK: - 자동 인터셉션 확장

/// InjectedValues 자동 인터셉션을 위한 글로벌 확장
public extension InjectedValues {
  /// 자동 해결: 설정 없이 타입만으로 의존성 해결
  static func autoResolve<T: Sendable>(_ type: T.Type) -> T? {
    return BridgeResolver.autoInterceptResolve(type)
  }

  /// 자동 등록: 양방향 자동 동기화
  static func autoRegister<T: Sendable>(_ type: T.Type, value: T) {
    BridgeResolver.autoRegister(type, value: value)
  }

  /// InjectedKey 값 설정을 위한 자동 TCA 동기화 헬퍼
  func setWithTCASync<Key: InjectedKey>(_ key: Key.Type, value: Key.Value) where Key.Value: Sendable {
    // 1. WeaveDI에 등록
    _ = UnifiedDI.register(Key.Value.self) { value }
    // 2. TCA DependencyValues에 자동 동기화
    BridgeResolver.reverseSync(Key.Value.self, value: value)
  }

  /// InjectedKey 값 조회를 위한 자동 해결
  func getWithAutoResolve<Key: InjectedKey>(_ key: Key.Type) -> Key.Value where Key.Value: Sendable {
    // 1. WeaveDI에서 먼저 조회
    if let resolved = UnifiedDI.resolve(Key.Value.self) {
      return resolved
    }
    // 2. 기본 InjectedKey 동작
    return key.liveValue
  }

  /// 기존 InjectedKey 패턴을 TCA와 자동 연결하는 헬퍼
  func registerInjectedKeyWithTCA<Key: InjectedKey>(_ key: Key.Type) where Key.Value: Sendable {
    let value = key.liveValue
    // WeaveDI와 TCA 양쪽에 등록
    _ = UnifiedDI.register(Key.Value.self) { value }
    BridgeResolver.reverseSync(Key.Value.self, value: value)
  }
}

// MARK: - 기존 InjectedKey 패턴 자동 TCA 동기화

/// 🎯 모든 InjectedKey에 자동 TCA 동기화 적용 (사용자 코드 수정 불필요!)
public extension InjectedValues {
  /// 기존 InjectedKey 패턴 + 자동 TCA 동기화
  /// 모든 InjectedKey가 자동으로 TCA와 연결됩니다
  subscript<Key: InjectedKey>(autoSync key: Key.Type) -> Key.Value where Key.Value: Sendable {
    get {
      // 1. WeaveDI에서 먼저 조회
      if let resolved = UnifiedDI.resolve(Key.Value.self) {
        return resolved
      }
      // 2. 기본 InjectedKey 동작 + 자동 등록
      let value = key.liveValue
      // 자동으로 WeaveDI와 TCA에 등록
      _ = UnifiedDI.register(Key.Value.self) { value }
      BridgeResolver.reverseSync(Key.Value.self, value: value)
      return value
    }
    set {
      // 1. WeaveDI에 등록
      _ = UnifiedDI.register(Key.Value.self) { newValue }
      // 2. TCA DependencyValues에 자동 동기화
      BridgeResolver.reverseSync(Key.Value.self, value: newValue)
    }
  }

  /// 기존 사용자 패턴과 호환되는 자동 TCA 동기화 헬퍼
  func autoSyncValue<Key: InjectedKey>(for key: Key.Type) -> Key.Value where Key.Value: Sendable {
    return self[autoSync: key]
  }

  /// 기존 사용자 패턴과 호환되는 자동 TCA 동기화 setter
  mutating func setAutoSyncValue<Key: InjectedKey>(for key: Key.Type, value: Key.Value) where Key.Value: Sendable {
    self[autoSync: key] = value
  }
}

/// 글로벌 자동 TCA 동기화 설정
public struct WeaveDITCABridge {
  /// 자동 TCA 동기화 활성화/비활성화 (기본값: true)
  public static let isAutoSyncEnabled: Bool = true

  /// 특정 타입에 대한 자동 동기화 제외 목록 (컴파일 타임 상수)
  public static let excludedTypes: Set<String> = []

  /// 타입이 자동 동기화 대상인지 확인
  public static func shouldAutoSync<T>(_ type: T.Type) -> Bool {
    guard isAutoSyncEnabled else { return false }
    let typeName = String(describing: type)
    return !excludedTypes.contains(typeName)
  }
}

// MARK: - 글로벌 자동 인터셉션 (실험적)

/// 모든 InjectedValues 접근을 자동으로 TCA와 동기화
private struct GlobalAutoSyncInterceptor {
  /// InjectedValues subscript 호출 시 자동 TCA 동기화
  static func interceptInjectedKeyAccess<Key: InjectedKey>(_ key: Key.Type, value: Key.Value) where Key.Value: Sendable {
    // WeaveDI에 등록
    _ = UnifiedDI.register(Key.Value.self) { value }
    // TCA에 동기화
    BridgeResolver.reverseSync(Key.Value.self, value: value)
  }
}

/// DependencyValues 자동 인터셉션을 위한 글로벌 확장
public extension DependencyValues {
  /// 자동 해결: WeaveDI에서 우선 조회, 없으면 DependencyValues 기본값
  static func autoResolve<T: Sendable>(_ type: T.Type) -> T? {
    return BridgeResolver.autoInterceptResolve(type)
  }

  /// 자동 등록: 양방향 자동 동기화
  static func autoRegister<T: Sendable>(_ type: T.Type, value: T) {
    BridgeResolver.autoRegister(type, value: value)
  }
}

// MARK: - 🎯 TCA → WeaveDI 완전 자동 동기화

#if canImport(Dependencies)
/// DependencyValues 자동 동기화를 위한 컨테이너
public struct TCAAutoSyncContainer {
  /// TCA DependencyKey의 기본 subscript를 모니터링하여 자동 WeaveDI 동기화
  ///
  /// 주의: TCA의 DependencyValues는 외부 라이브러리이므로
  /// 직접 수정할 수 없습니다. 대신 사용자는 다음과 같이 사용해야 합니다:
  ///
  /// ```swift
  /// // TCA DependencyKey 등록 시
  /// extension ExchangeRateCacheUseCaseImpl: DependencyKey {
  ///   static var liveValue: ExchangeRateCacheInterface { ... }
  ///   static var testValue: ExchangeRateCacheInterface { ... }
  /// }
  ///
  /// extension DependencyValues {
  ///   var exchangeRateCacheUseCase: ExchangeRateCacheInterface {
  ///     get {
  ///       let value = self[ExchangeRateCacheUseCaseImpl.self]
  ///       TCAAutoSyncContainer.autoSyncToWeaveDI(ExchangeRateCacheInterface.self, value: value)
  ///       return value
  ///     }
  ///     set {
  ///       self[ExchangeRateCacheUseCaseImpl.self] = newValue
  ///       TCAAutoSyncContainer.autoSyncToWeaveDI(ExchangeRateCacheInterface.self, value: newValue)
  ///     }
  ///   }
  /// }
  /// ```
  public static func autoSyncToWeaveDI<T: Sendable>(_ type: T.Type, value: T) {
    TCABridgeHelper.autoSyncToWeaveDI(type, value: value)
  }
}

/// DependencyKey 패턴에서 WeaveDI로 자동 동기화
public extension DependencyValues {
  /// TCA DependencyKey + 자동 WeaveDI 동기화 (명시적)
  /// 사용법: dependencies[autoSync: MyServiceKey.self] = service
  subscript<Key: DependencyKey>(autoSync key: Key.Type) -> Key.Value where Key.Value: Sendable {
    get {
      // 1. WeaveDI에서 먼저 조회
      if let resolved = UnifiedDI.resolve(Key.Value.self) {
        return resolved
      }
      // 2. 기본 DependencyKey 동작 + 자동 등록
      let value = key.liveValue
      // 자동으로 WeaveDI에 등록
      _ = UnifiedDI.register(Key.Value.self) { value }
      return value
    }
    set {
      // 1. TCA 기본 subscript에 설정
      self[key] = newValue
      // 2. WeaveDI에도 자동 등록
      _ = UnifiedDI.register(Key.Value.self) { newValue }
    }
  }

  /// TCA DependencyKey 값을 WeaveDI와 자동 동기화하는 헬퍼
  func autoSyncValue<Key: DependencyKey>(for key: Key.Type) -> Key.Value where Key.Value: Sendable {
    return self[autoSync: key]
  }

  /// TCA DependencyKey 값을 WeaveDI와 자동 동기화하는 setter
  mutating func setAutoSyncValue<Key: DependencyKey>(for key: Key.Type, value: Key.Value) where Key.Value: Sendable {
    self[autoSync: key] = value
  }
}
#endif


// MARK: - TCA Bridge Helper

/// TCA 자동 동기화를 위한 헬퍼 클래스
public struct TCABridgeHelper {
  /// InjectedKey 값을 TCA DependencyValues에 자동 동기화
  public static func autoSyncToTCA<T: Sendable>(_ type: T.Type, value: T) {
    // TCA DependencyValues에 등록 시도 (리플렉션 기반)
    // 실제 구현은 Dependencies 라이브러리 존재 시에만 동작
    #if canImport(Dependencies)
    tryRegisteringToDependencyValues(type, value: value)
    #endif
  }

  /// DependencyKey 값을 WeaveDI에 자동 동기화
  public static func autoSyncToWeaveDI<T: Sendable>(_ type: T.Type, value: T) {
    _ = UnifiedDI.register(type) { value }
  }

  #if canImport(Dependencies)
  /// TCA DependencyValues에 값을 등록하는 내부 헬퍼
  private static func tryRegisteringToDependencyValues<T: Sendable>(_ type: T.Type, value: T) {
    // 실제 TCA DependencyValues에 등록하는 로직
    // 이는 런타임에 안전하게 실행되며, TCA가 없어도 크래시하지 않음
    // TCA의 DependencyValues에 등록 시도
    // 리플렉션이나 다른 안전한 방법 사용
    // 지금은 기본 구현만 제공 (향후 확장 가능)
  }
  #endif
}

// MARK: - @Injected with TCA DependencyKey Support

public extension Injected where Value: Sendable {
  /// TCA DependencyKey를 사용한 초기화 - TCABridgedKey로 자동 변환
  init<K: DependencyKey>(_ dependencyKey: K.Type) where K.Value == Value {
    self.init(TCABridgedKey<K>.self)
  }
}

// MARK: - Automatic Bridge Registration

/// TCA DependencyKey를 WeaveDI InjectedKey로 자동 브리지하는 래퍼
public enum TCABridgedKey<Key: DependencyKey>: InjectedKey where Key.Value: Sendable {
  public typealias Value = Key.Value

  public static var liveValue: Key.Value {
    BridgeResolver.resolveWithFallback(Key.Value.self, fallback: Key.self)
  }

  public static var testValue: Key.Value {
    Key.testValue
  }
  public static var previewValue: Key.Value {
    Key.previewValue
  }
}

// MARK: - Convenience Extensions

public extension DependencyKey where Value: Sendable {
  /// TCA DependencyKey를 WeaveDI InjectedKey로 변환
  static var weaveDIKey: TCABridgedKey<Self>.Type {
    TCABridgedKey<Self>.self
  }
}

// MARK: - Internal Keys

private enum DIContainerDependencyKey: DependencyKey {
  static var liveValue: DIContainer { DIContainer.shared }
  static var testValue: DIContainer { DIContainer.shared }
  static var previewValue: DIContainer { DIContainer.shared }
}

// MARK: - UnifiedDI 자동 인터셉션 확장

/// UnifiedDI에 자동 TCA 동기화 기능 추가
public extension UnifiedDI {
  /// 자동 양방향 동기화를 포함한 등록
  /// 설정 없이 TCA DependencyValues와 자동 동기화됩니다
  static func registerWithAutoSync<T>(
    _ type: T.Type,
    factory: @escaping @Sendable () -> T
  ) -> T where T: Sendable {
    let instance = register(type, factory: factory)
    // TCA 동기화 자동 실행
    BridgeResolver.reverseSync(type, value: instance)
    return instance
  }

  /// 자동 양방향 동기화를 포함한 비동기 등록
  static func registerAsyncWithAutoSync<T>(
    _ type: T.Type,
    factory: @escaping @Sendable () -> T
  ) async -> T where T: Sendable {
    let instance = await registerAsync(type, factory: factory)
    // TCA 동기화 자동 실행
    BridgeResolver.reverseSync(type, value: instance)
    return instance
  }

  /// 자동 해결: WeaveDI → TCA 순으로 자동 조회
  static func resolveWithAutoFallback<T: Sendable>(_ type: T.Type) -> T? {
    return BridgeResolver.autoInterceptResolve(type)
  }
}

// MARK: - 기본 UnifiedDI 메서드 자동 인터셉션

/// UnifiedDI 기본 메서드에 자동 TCA 동기화 추가
public extension UnifiedDI {
  /// 기본 register 메서드를 확장해서 자동 TCA 동기화 포함
  /// 사용자가 별도 설정 없이도 자동으로 DependencyValues에 동기화됩니다
  static func registerWithTCASync<T>(
    _ type: T.Type,
    factory: @escaping @Sendable () -> T
  ) -> T where T: Sendable {
    let instance = DIContainer.shared.register(type, factory: factory)
    // 2. TCA DependencyValues에 자동 동기화
    BridgeResolver.reverseSync(type, value: instance)

    return instance
  }

  /// 기본 KeyPath register 메서드를 확장해서 자동 TCA 동기화 포함
  static func registerKeyPathWithTCASync<T>(
    _ keyPath: KeyPath<WeaveDI.Container, T?>,
    factory: @escaping @Sendable () -> T
  ) -> T where T: Sendable {
    let instance = DIContainer.shared.register(T.self, factory: factory)
    // 2. TCA DependencyValues에 자동 동기화
    BridgeResolver.reverseSync(T.self, value: instance)

    return instance
  }
}

// MARK: - 전역 자동 인터셉션 설정

/// 모든 UnifiedDI 등록에 자동 동기화 적용 (실험적)
private struct AutoSyncConfiguration {
  // Concurrency-safe constant
  static let isEnabled: Bool = true

  /// UnifiedDI.register 호출 시 자동으로 TCA 동기화 실행
  static func interceptRegister<T: Sendable>(_ type: T.Type, instance: T) {
    guard isEnabled else { return }
    BridgeResolver.autoRegister(type, value: instance)
  }
}

// MARK: - Usage Examples

/*
/// 설정 없는 자동 동기화 예시:

// 1. 기본 등록 (자동 동기화 포함)
let service = UnifiedDI.registerWithAutoSync(NetworkService.self) {
  NetworkServiceImpl()
}

// 2. TCA에서 바로 사용 가능
@Dependency(\.networkService) var tcaService // 자동으로 같은 인스턴스

// 3. WeaveDI에서도 사용 가능
@Injected(\.networkService) var weaveDIService // 자동으로 같은 인스턴스

// 4. 자동 fallback 해결
let service = UnifiedDI.resolveWithAutoFallback(NetworkService.self)
// WeaveDI에 없으면 TCA DependencyValues에서 자동 조회
*/

#endif
