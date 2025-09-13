//
//  ContainerInject.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - Container Inject (Crash-Free Optional Injection)

/// 크래시 없는 옵셔널 의존성 주입 프로퍼티 래퍼
/// 
/// 이 프로퍼티 래퍼는 의존성이 등록되지 않아도 크래시 없이 nil을 반환합니다.
/// 선택적 의존성이나 기능 플래그에 따라 동작이 달라지는 컴포넌트에 적합합니다.
///
/// ## 특징:
/// - 🛡️ **크래시 방지**: 등록되지 않은 의존성은 nil 반환
/// - 📊 **상세한 로깅**: 의존성 해결 과정 추적
/// - 🔄 **지연 해결**: 처음 접근할 때 의존성 해결 시도
/// - ⚡ **경량**: 최소한의 오버헤드로 동작
/// - 🎯 **명확한 의도**: 옵셔널 타입으로 선택적임을 표현
///
/// ## 사용법:
/// ```swift
/// @ContainerInject(\.analyticsService)
/// private var analyticsService: AnalyticsServiceProtocol?
/// 
/// func trackEvent(_ event: String) {
///     analyticsService?.track(event) // nil이어도 안전
/// }
/// ```
///
/// ## 언제 사용할까:
/// - 🔧 **선택적 기능**: 분석, 로깅, 메트릭 등
/// - 🎛️ **기능 플래그**: A/B 테스트, 실험적 기능
/// - 🌐 **환경별 차이**: 개발/운영 환경에서 다른 동작
/// - 📱 **플랫폼별 기능**: iOS/macOS에서 다른 구현
@propertyWrapper
public struct ContainerInject<T: Sendable> {
    
    // MARK: - Properties
    
    /// DependencyContainer 내부의 T? 프로퍼티를 가리키는 KeyPath
    private let keyPath: KeyPath<DependencyContainer, T?>
    
    /// 의존성 해결 상태를 추적하는 플래그
    private var resolutionAttempted: Bool = false
    
    /// 해결된 의존성을 캐시
    private var cachedDependency: T?
    
    /// 의존성이 사용된 위치 정보 (로깅용)
    private let sourceLocation: OptionalSourceLocation
    
    /// 해결 전략 설정
    private let strategy: ResolutionStrategy
    
    // MARK: - Initialization
    
    /// 기본 ContainerInject 초기화
    /// 
    /// - Parameters:
    ///   - keyPath: 의존성을 가리키는 KeyPath
    ///   - strategy: 해결 전략 (기본: .lazy)
    ///   - file: 호출 파일 (자동 전달)
    ///   - function: 호출 함수 (자동 전달)
    ///   - line: 호출 라인 (자동 전달)
    public init(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        strategy: ResolutionStrategy = .lazy,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        self.keyPath = keyPath
        self.strategy = strategy
        self.sourceLocation = OptionalSourceLocation(
            file: String(describing: file),
            function: String(describing: function),
            line: Int(line)
        )
    }
    
    // MARK: - Property Wrapper Implementation
    
    /// 옵셔널 의존성을 반환합니다
    /// 등록되지 않은 경우 nil을 반환하며 크래시하지 않습니다
    public var wrappedValue: T? {
        mutating get {
            switch strategy {
            case .lazy:
                return resolveLazily()
            case .eager:
                return resolveEagerly()
            case .cached:
                return resolveCached()
            }
        }
    }
    
    /// 의존성 해결 상태 정보
    public var projectedValue: InjectionInfo {
        InjectionInfo(
            isResolved: cachedDependency != nil,
            typeName: String(describing: T.self),
            resolutionAttempted: resolutionAttempted,
            sourceLocation: sourceLocation
        )
    }
    
    // MARK: - Resolution Strategies
    
    /// 지연 해결: 매번 접근할 때마다 해결 시도
    private mutating func resolveLazily() -> T? {
        let typeName = String(describing: T.self)
        
        // 1. DependencyContainer에서 직접 조회
        if let value = DependencyContainer.live[keyPath: keyPath] {
            #logDebug("✅ [ContainerInject] Resolved \(typeName) from DependencyContainer")
            return value
        }
        
        // 2. AutoRegistrationRegistry에서 조회
        if let instance = AutoRegistrationRegistry.shared.createInstance(for: T.self) {
            #logDebug("✅ [ContainerInject] Resolved \(typeName) from AutoRegistrationRegistry")
            // DependencyContainer에도 등록해 둠
            DependencyContainer.live.register(T.self, instance: instance)
            return instance
        }
        
        // 3. 해결 실패 - 로깅하고 nil 반환
        if !resolutionAttempted {
            logResolutionFailure(for: typeName)
            resolutionAttempted = true
        }
        
        return nil
    }
    
    /// 즉시 해결: 첫 번째 접근에서만 해결 시도하고 결과 캐시
    private mutating func resolveEagerly() -> T? {
        if resolutionAttempted {
            return cachedDependency
        }
        
        resolutionAttempted = true
        cachedDependency = attemptResolution()
        return cachedDependency
    }
    
    /// 캐시된 해결: 성공할 때까지 계속 시도하되 성공하면 캐시
    private mutating func resolveCached() -> T? {
        if let cached = cachedDependency {
            return cached
        }
        
        let resolved = attemptResolution()
        if resolved != nil {
            cachedDependency = resolved
        }
        
        return resolved
    }
    
    /// 의존성 해결 시도
    private mutating func attemptResolution() -> T? {
        let typeName = String(describing: T.self)
        
        #logDebug("🔍 [ContainerInject] Attempting to resolve \(typeName)")
        
        // 1. DependencyContainer에서 조회
        if let value = DependencyContainer.live[keyPath: keyPath] {
            #logDebug("✅ [ContainerInject] Found \(typeName) in DependencyContainer")
            return value
        }
        
        // 2. AutoRegistrationRegistry에서 조회
        if let instance = AutoRegistrationRegistry.shared.createInstance(for: T.self) {
            #logInfo("🔧 [ContainerInject] Found \(typeName) in AutoRegistrationRegistry, registering to container")
            DependencyContainer.live.register(T.self, instance: instance)
            return instance
        }
        
        // 3. 해결 실패 로깅
        logResolutionFailure(for: typeName)
        return nil
    }
    
    /// 해결 실패 로깅
    private func logResolutionFailure(for typeName: String) {
        #logInfo("⚠️ [ContainerInject] Optional dependency \(typeName) not found - returning nil")
        #logDebug("📍 [ContainerInject] Location: \(sourceLocation.shortFileName):\(sourceLocation.line)")
        #logDebug("🔍 [ContainerInject] Function: \(sourceLocation.function)")
        
        let registeredCount = AutoRegistrationRegistry.shared.registeredCount
        if registeredCount == 0 {
            #logInfo("💡 [ContainerInject] No dependencies registered yet. Consider registering \(typeName) with AutoRegister.add()")
        } else {
            #logDebug("📊 [ContainerInject] Currently registered dependencies: \(registeredCount)")
        }
    }
}

// MARK: - Resolution Strategy

/// 의존성 해결 전략
public enum ResolutionStrategy {
    /// 지연 해결: 매번 접근할 때마다 해결 시도 (기본값)
    case lazy
    /// 즉시 해결: 첫 번째 접근에서만 해결 시도하고 결과 캐시
    case eager  
    /// 캐시된 해결: 성공할 때까지 계속 시도하되 성공하면 캐시
    case cached
}

// MARK: - Injection Information

/// 의존성 주입 상태 정보
public struct InjectionInfo {
    /// 의존성이 해결되었는지 여부
    public let isResolved: Bool
    /// 타입 이름
    public let typeName: String
    /// 해결 시도 여부
    public let resolutionAttempted: Bool
    /// 소스 위치
    public let sourceLocation: OptionalSourceLocation
    
    /// 디버깅 정보 출력
    public func printDebugInfo() {
        #logInfo("""
        📊 [ContainerInject] Injection Info for \(typeName):
        ├─ Resolved: \(isResolved)
        ├─ Attempted: \(resolutionAttempted)
        ├─ Location: \(sourceLocation.shortFileName):\(sourceLocation.line)
        └─ Function: \(sourceLocation.function)
        """)
    }
}

// MARK: - Optional Source Location

/// 옵셔널 의존성의 소스 위치 정보
public struct OptionalSourceLocation {
    let file: String
    let function: String
    let line: Int
    
    var shortFileName: String {
        URL(fileURLWithPath: file).lastPathComponent
    }
}

// MARK: - Convenience Extensions

public extension ContainerInject {
    
    /// 기본 팩토리와 함께 초기화 (Fallback 제공)
    /// 
    /// - Parameters:
    ///   - keyPath: 의존성을 가리키는 KeyPath
    ///   - defaultFactory: 등록되지 않은 경우 사용할 기본 팩토리
    ///   - strategy: 해결 전략
    init(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        defaultFactory: @Sendable @escaping () -> T,
        strategy: ResolutionStrategy = .lazy,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        self.keyPath = keyPath
        self.strategy = strategy
        self.sourceLocation = OptionalSourceLocation(
            file: String(describing: file),
            function: String(describing: function),
            line: Int(line)
        )
        
        // 기본 팩토리를 AutoRegistrationRegistry에 등록
        let typeName = String(describing: T.self)
        #logDebug("🔧 [ContainerInject] Registering default factory for \(typeName)")
        AutoRegistrationRegistry.shared.register(T.self, factory: defaultFactory)
    }
}

// MARK: - Usage Examples and Documentation

/// ContainerInject 사용 예제 및 가이드
public enum ContainerInjectGuide {
    
    /// 사용 예제 출력
    public static func printUsageExamples() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                         🛡️ CONTAINERINJECT USAGE GUIDE                      ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║                           WHEN TO USE CONTAINERINJECT:                       ║
        ║                                                                               ║
        ║  ✅ Optional Features (Analytics, Logging, Metrics)                         ║
        ║  ✅ Feature Flags & A/B Testing                                             ║
        ║  ✅ Environment-specific Services                                            ║
        ║  ✅ Platform-specific Implementations                                        ║
        ║  ✅ Third-party SDK Integrations                                            ║
        ║                                                                               ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                              📝 BASIC USAGE                                  ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║  class AnalyticsManager {                                                    ║
        ║      @ContainerInject(\\.analyticsService)                                   ║
        ║      private var analytics: AnalyticsServiceProtocol?                        ║
        ║                                                                               ║
        ║      func trackEvent(_ event: String) {                                      ║
        ║          analytics?.track(event) // Safe - no crash if nil                   ║
        ║      }                                                                       ║
        ║  }                                                                           ║
        ║                                                                               ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                          🔧 ADVANCED USAGE WITH FALLBACK                     ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║  class FeatureFlagService {                                                  ║
        ║      @ContainerInject(\\.remoteConfig, defaultFactory: {                     ║
        ║          LocalConfigService() // Fallback implementation                     ║
        ║      })                                                                      ║
        ║      private var config: ConfigServiceProtocol?                              ║
        ║                                                                               ║
        ║      func isFeatureEnabled(_ feature: String) -> Bool {                      ║
        ║          return config?.isEnabled(feature) ?? false                          ║
        ║      }                                                                       ║
        ║  }                                                                           ║
        ║                                                                               ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                           📊 DEBUGGING WITH PROJECTED VALUE                  ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║  class DebuggableService {                                                   ║
        ║      @ContainerInject(\\.debugService)                                       ║
        ║      private var debugService: DebugServiceProtocol?                         ║
        ║                                                                               ║
        ║      func performAction() {                                                  ║
        ║          if $debugService.isResolved {                                       ║
        ║              print("Debug service is available")                             ║
        ║          }                                                                   ║
        ║          debugService?.log("Action performed")                               ║
        ║      }                                                                       ║
        ║                                                                               ║
        ║      func printDebugInfo() {                                                 ║
        ║          $debugService.printDebugInfo()                                      ║
        ║      }                                                                       ║
        ║  }                                                                           ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 전략 비교 가이드 출력
    public static func printStrategyGuide() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                           🎯 RESOLUTION STRATEGIES                            ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║  STRATEGY    │ PERFORMANCE │ MEMORY │ USE CASE                               ║
        ║  ────────────┼─────────────┼────────┼──────────────────────────────────────  ║
        ║  .lazy       │     ⚡⚡     │   🟢   │ Default - retry every access           ║
        ║  .eager      │     ⚡⚡⚡   │   🟡   │ One-time resolution, cache result      ║
        ║  .cached     │     ⚡⚡⚡   │   🟡   │ Retry until success, then cache        ║
        ║                                                                               ║
        ║  EXAMPLES:                                                                    ║
        ║                                                                               ║
        ║  @ContainerInject(\\.service, strategy: .lazy)      // Default              ║
        ║  @ContainerInject(\\.service, strategy: .eager)     // One-time try         ║
        ║  @ContainerInject(\\.service, strategy: .cached)    // Retry then cache     ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
}